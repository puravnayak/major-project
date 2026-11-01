#!/usr/bin/env python3
"""
===============================================================================
Vivado PPA Data Extraction and Analysis Parser
===============================================================================
Specification: docs/06_ppa_parser.md

Reads Vivado synthesis reports (utilization, timing, power), extracts key
metrics (LUTs, FFs, WNS, Total Power), computes Fmax, Throughput, and
Energy per Hash, and appends the results to a CSV file (ppa_results.csv).
===============================================================================
"""

import argparse
import csv
import os
import re
import sys


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Extract PPA (Power, Performance, Area) metrics from Vivado reports."
    )
    parser.add_argument(
        "--report_dir",
        type=str,
        required=True,
        help="Path to directory containing Vivado report files (*.rpt)",
    )
    parser.add_argument(
        "--version_name",
        type=str,
        required=True,
        help="Name of architecture version (e.g., v1_baseline, v2_iot_edge)",
    )
    parser.add_argument(
        "--cycles_per_block",
        type=int,
        default=65,
        help="Clock cycles required to process one block execution batch (default: 65)",
    )
    parser.add_argument(
        "--block_size_bits",
        type=int,
        default=512,
        help="Total input data size in bits processed per execution batch (default: 512, e.g. 1024 for dual-core)",
    )
    parser.add_argument(
        "--target_period_ns",
        type=float,
        default=10.0,
        help="Target clock period constraint in nanoseconds (default: 10.0)",
    )
    parser.add_argument(
        "--output_csv",
        type=str,
        default="ppa_results.csv",
        help="Path to output CSV file (default: ppa_results.csv)",
    )
    return parser.parse_args()


def read_file_safe(filepath):
    """Safely read text file content, returning None if missing or unreadable."""
    if not os.path.exists(filepath):
        print(f"[WARNING] Report file not found: {filepath}")
        return None
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()
    except Exception as e:
        print(f"[WARNING] Error reading {filepath}: {e}")
        return None


def extract_utilization(report_dir):
    """Extract Slice LUTs and Slice Registers from post_synth_utilization.rpt."""
    filepath = os.path.join(report_dir, "post_synth_utilization.rpt")
    content = read_file_safe(filepath)
    if not content:
        return "N/A", "N/A"

    luts = "N/A"
    ffs = "N/A"

    # Regex patterns for Slice / CLB LUTs
    lut_patterns = [
        r"\|\s*(?:Slice|CLB)\s+LUTs\*?\s*\|\s*(\d+)",
        r"\|\s*LUT as Logic\s*\|\s*(\d+)",
        r"Slice LUTs\s*\|\s*(\d+)",
    ]
    for pat in lut_patterns:
        match = re.search(pat, content, re.IGNORECASE)
        if match:
            luts = int(match.group(1))
            break

    # Regex patterns for Slice Registers / Flip Flops
    ff_patterns = [
        r"\|\s*(?:Slice|CLB)\s+Registers\*?\s*\|\s*(\d+)",
        r"\|\s*Register as Flip Flop\s*\|\s*(\d+)",
        r"\|\s*Flip Flop\s*\|\s*(\d+)",
        r"Slice Registers\s*\|\s*(\d+)",
    ]
    for pat in ff_patterns:
        match = re.search(pat, content, re.IGNORECASE)
        if match:
            ffs = int(match.group(1))
            break

    if luts == "N/A":
        print(f"[WARNING] Could not extract LUT count from {filepath}")
    if ffs == "N/A":
        print(f"[WARNING] Could not extract Register/FF count from {filepath}")

    return luts, ffs


def extract_timing(report_dir):
    """Extract Worst Negative Slack (WNS) from post_synth_timing.rpt."""
    filepath = os.path.join(report_dir, "post_synth_timing.rpt")
    content = read_file_safe(filepath)
    if not content:
        return "N/A"

    wns = "N/A"

    # Pattern 1: Explicit "Worst Negative Slack (WNS): <val>ns"
    m1 = re.search(r"Worst Negative Slack \(WNS\):\s*([-\d\.]+)", content, re.IGNORECASE)
    if m1:
        try:
            return float(m1.group(1))
        except ValueError:
            pass

    # Pattern 2: Design Timing Summary table header followed by data row
    # WNS(ns)      TNS(ns) ...
    # -------      ------- ...
    #   1.234        0.000 ...
    table_match = re.search(
        r"WNS\(ns\).*?\n\s*-+\s+-+\s+[^\n]*\n\s*([-\d\.]+)",
        content,
        re.DOTALL | re.IGNORECASE,
    )
    if table_match:
        try:
            return float(table_match.group(1))
        except ValueError:
            pass

    # Pattern 3: Fallback line search for WNS table row
    lines = content.splitlines()
    for idx, line in enumerate(lines):
        if "WNS(ns)" in line and idx + 2 < len(lines):
            tokens = lines[idx + 2].strip().split()
            if tokens:
                try:
                    return float(tokens[0])
                except ValueError:
                    pass

    print(f"[WARNING] Could not extract WNS from {filepath}")
    return wns


def extract_power(report_dir):
    """Extract Total On-Chip Power (W) from post_synth_power.rpt."""
    filepath = os.path.join(report_dir, "post_synth_power.rpt")
    content = read_file_safe(filepath)
    if not content:
        return "N/A"

    # Standard Vivado power table:
    # | Total On-Chip Power (W) | 0.123 |
    # or "Total On-Chip Power (W) : 0.123"
    patterns = [
        r"Total On-Chip Power \(W\)[\s\|:]+([0-9\.]+)",
        r"\|\s*Total On-Chip Power \(W\)\s*\|\s*([0-9\.]+)",
    ]

    for pat in patterns:
        match = re.search(pat, content, re.IGNORECASE)
        if match:
            try:
                return float(match.group(1))
            except ValueError:
                pass

    print(f"[WARNING] Could not extract Total On-Chip Power from {filepath}")
    return "N/A"


def calculate_metrics(target_period_ns, cycles_per_block, wns, total_power, block_size_bits=512):
    """
    Compute Fmax (MHz), Throughput (Mbps), and Energy per Hash (nJ).
    
    Formulas:
      T_min = target_period_ns - WNS
      Fmax (GHz) = 1.0 / T_min
      Fmax (MHz) = Fmax (GHz) * 1000 = 1000.0 / T_min
      Throughput (Mbps) = (block_size_bits * Fmax_GHz * 1e9) / (cycles_per_block * 1e6)
                        = (block_size_bits * Fmax_MHz) / cycles_per_block
      Energy/Hash (nJ) = (Total_Power * cycles_per_block * 1e9) / (Fmax_GHz * 1e9 * num_blocks)
                       = (Total_Power * cycles_per_block) / (fmax_ghz * num_blocks)
                       = (Total_Power * cycles_per_block * 1000.0) / (Fmax_MHz * num_blocks)
    """
    fmax_mhz = "N/A"
    throughput_mbps = "N/A"
    energy_per_hash_nj = "N/A"

    # Compute Fmax and Throughput if WNS is available
    if isinstance(wns, (int, float)):
        t_min = target_period_ns - wns
        if t_min > 0:
            fmax_ghz = 1.0 / t_min
            fmax_mhz_val = fmax_ghz * 1000.0
            fmax_mhz = round(fmax_mhz_val, 2)

            if cycles_per_block > 0:
                tp_val = (float(block_size_bits) * fmax_mhz_val) / cycles_per_block
                throughput_mbps = round(tp_val, 2)

                # Compute Energy per Hash if Power is available
                if isinstance(total_power, (int, float)):
                    # Energy = Power * Time = Power * (cycles / Freq_Hz)
                    # Energy per Hash (nJ) accounts for multiple parallel blocks
                    num_blocks = block_size_bits / 512.0 if block_size_bits > 0 else 1.0
                    energy_val = (total_power * cycles_per_block) / (fmax_ghz * num_blocks)
                    energy_per_hash_nj = round(energy_val, 3)
        else:
            print(f"[WARNING] Achieved clock period T_min <= 0 ({t_min} ns). Invalid WNS.")

    return fmax_mhz, throughput_mbps, energy_per_hash_nj


def write_csv(output_csv, row_data, headers):
    """Write or append row_data to output_csv, adding headers if newly created."""
    file_exists = os.path.exists(output_csv)
    
    # Ensure parent directory exists if specified
    out_dir = os.path.dirname(output_csv)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(output_csv, mode="a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(headers)
        writer.writerow(row_data)

    print(f"[SUCCESS] Appended results for '{row_data[0]}' to {output_csv}")


def main():
    args = parse_arguments()

    print("================================================================")
    print(" Vivado PPA Data Extraction & Metric Calculator")
    print("================================================================")
    print(f" Report Directory   : {args.report_dir}")
    print(f" Version Name       : {args.version_name}")
    print(f" Cycles per Block   : {args.cycles_per_block}")
    print(f" Block Size (bits)  : {args.block_size_bits}")
    print(f" Target Period (ns) : {args.target_period_ns}")
    print(f" Output CSV File    : {args.output_csv}")
    print("----------------------------------------------------------------")

    # 1. Extract Raw Metrics
    luts, ffs = extract_utilization(args.report_dir)
    wns = extract_timing(args.report_dir)
    total_power = extract_power(args.report_dir)

    # 2. Compute Derived Metrics
    fmax_mhz, throughput_mbps, energy_per_hash_nj = calculate_metrics(
        args.target_period_ns, args.cycles_per_block, wns, total_power, args.block_size_bits
    )

    # 3. Format Extracted Values
    wns_str = f"{wns:.3f}" if isinstance(wns, (int, float)) else str(wns)
    power_str = f"{total_power:.4f}" if isinstance(total_power, (int, float)) else str(total_power)
    fmax_str = f"{fmax_mhz:.2f}" if isinstance(fmax_mhz, (int, float)) else str(fmax_mhz)
    tp_str = f"{throughput_mbps:.2f}" if isinstance(throughput_mbps, (int, float)) else str(throughput_mbps)
    energy_str = f"{energy_per_hash_nj:.3f}" if isinstance(energy_per_hash_nj, (int, float)) else str(energy_per_hash_nj)

    print(f" [EXTRACTED] Slice LUTs      : {luts}")
    print(f" [EXTRACTED] Slice Registers : {ffs}")
    print(f" [EXTRACTED] WNS (ns)        : {wns_str}")
    print(f" [EXTRACTED] Total Power (W) : {power_str}")
    print(f" [COMPUTED]  Fmax (MHz)      : {fmax_str}")
    print(f" [COMPUTED]  Throughput      : {tp_str} Mbps")
    print(f" [COMPUTED]  Energy per Hash : {energy_str} nJ")
    print("----------------------------------------------------------------")

    # 4. CSV Header and Row Structure
    # Version | LUTs | FFs | WNS (ns) | Fmax (MHz) | Total Power (W) | Throughput (Mbps) | Energy/Hash (nJ)
    headers = [
        "Version",
        "LUTs",
        "FFs",
        "WNS (ns)",
        "Fmax (MHz)",
        "Total Power (W)",
        "Throughput (Mbps)",
        "Energy/Hash (nJ)",
    ]

    row = [
        args.version_name,
        luts,
        ffs,
        wns_str,
        fmax_str,
        power_str,
        tp_str,
        energy_str,
    ]

    # 5. Append to Master CSV
    write_csv(args.output_csv, row, headers)


if __name__ == "__main__":
    main()
