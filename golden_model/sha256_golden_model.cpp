#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <array>
#include <cstdint>
#include <cstring>

/**
 * ============================================================================
 * SHA-256 Golden Reference Model
 * ============================================================================
 * Specification: FIPS PUB 180-4 Secure Hash Standard (SHS)
 * Target Project: Energy-Efficient SHA-256 Cryptographic Accelerator (FPGA)
 *
 * This golden software model generates reference test vectors (input blocks,
 * intermediate round states A-H, and final digests) for hardware RTL
 * verification in Vivado testbenches.
 * ============================================================================
 */

namespace sha256 {

// ----------------------------------------------------------------------------
// Bitwise Rotations and Shifts (32-bit)
// ----------------------------------------------------------------------------

inline uint32_t rotr(uint32_t x, uint32_t n) {
    return (x >> n) | (x << (32 - n));
}

inline uint32_t shr(uint32_t x, uint32_t n) {
    return x >> n;
}

// ----------------------------------------------------------------------------
// Core SHA-256 Logical Functions
// ----------------------------------------------------------------------------

inline uint32_t ch(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (~x & z);
}

inline uint32_t maj(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (x & z) ^ (y & z);
}

// ----------------------------------------------------------------------------
// Core SHA-256 Sigma Transformation Functions
// ----------------------------------------------------------------------------

inline uint32_t big_sigma0(uint32_t x) {
    return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
}

inline uint32_t big_sigma1(uint32_t x) {
    return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
}

inline uint32_t small_sigma0(uint32_t x) {
    return rotr(x, 7) ^ rotr(x, 18) ^ shr(x, 3);
}

inline uint32_t small_sigma1(uint32_t x) {
    return rotr(x, 17) ^ rotr(x, 19) ^ shr(x, 10);
}

// ----------------------------------------------------------------------------
// Initial Hash Values (FIPS 180-4 section 5.3.3)
// First 32 bits of the fractional parts of the square roots of first 8 primes
// ----------------------------------------------------------------------------
constexpr std::array<uint32_t, 8> INITIAL_H = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

// ----------------------------------------------------------------------------
// Round Constants K[0..63] (FIPS 180-4 section 4.2.2)
// First 32 bits of fractional parts of cube roots of first 64 primes
// ----------------------------------------------------------------------------
constexpr std::array<uint32_t, 64> K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

// ----------------------------------------------------------------------------
// Data Structures for Model Output
// ----------------------------------------------------------------------------

struct RoundState {
    uint32_t round;
    uint32_t a, b, c, d, e, f, g, h;
};

struct BlockData {
    std::array<uint32_t, 16> words; // 16 32-bit big-endian words (512 bits)
};

struct SHA256Result {
    std::vector<BlockData> blocks;
    std::vector<std::vector<RoundState>> intermediate_states; // [block_index][round_0..63]
    std::array<uint32_t, 8> final_hash_words;
    std::string hex_digest;
};

// ----------------------------------------------------------------------------
// SHA-256 Engine Class
// ----------------------------------------------------------------------------
class SHA256Model {
public:
    // Pad arbitrary byte stream according to FIPS 180-4 Section 5.1.1
    static std::vector<uint8_t> pad_message(const uint8_t* data, size_t length_bytes) {
        std::vector<uint8_t> padded(data, data + length_bytes);
        uint64_t total_bits = static_cast<uint64_t>(length_bytes) * 8ULL;

        // Append '1' bit (0x80 byte)
        padded.push_back(0x80);

        // Pad with '0' bits until length mod 64 is 56 bytes (448 bits)
        while ((padded.size() % 64) != 56) {
            padded.push_back(0x00);
        }

        // Append 64-bit big-endian integer length
        for (int i = 7; i >= 0; --i) {
            padded.push_back(static_cast<uint8_t>((total_bits >> (i * 8)) & 0xFF));
        }

        return padded;
    }

    // Process padded bytes into 512-bit blocks (each consisting of 16 32-bit big-endian words)
    static std::vector<BlockData> parse_blocks(const std::vector<uint8_t>& padded_data) {
        size_t num_blocks = padded_data.size() / 64;
        std::vector<BlockData> blocks(num_blocks);

        for (size_t b = 0; b < num_blocks; ++b) {
            size_t block_offset = b * 64;
            for (size_t w = 0; w < 16; ++w) {
                size_t word_offset = block_offset + w * 4;
                blocks[b].words[w] = (static_cast<uint32_t>(padded_data[word_offset])     << 24) |
                                    (static_cast<uint32_t>(padded_data[word_offset + 1]) << 16) |
                                    (static_cast<uint32_t>(padded_data[word_offset + 2]) << 8)  |
                                    (static_cast<uint32_t>(padded_data[word_offset + 3]));
            }
        }

        return blocks;
    }

    // Run the full SHA-256 algorithm and capture all intermediate state
    static SHA256Result compute(const uint8_t* data, size_t length_bytes) {
        SHA256Result result;

        std::vector<uint8_t> padded = pad_message(data, length_bytes);
        result.blocks = parse_blocks(padded);

        std::array<uint32_t, 8> H = INITIAL_H;
        result.intermediate_states.resize(result.blocks.size());

        for (size_t blk_idx = 0; blk_idx < result.blocks.size(); ++blk_idx) {
            const auto& M = result.blocks[blk_idx].words;

            // 1. Message schedule expansion W[0..63]
            std::array<uint32_t, 64> W{};
            for (size_t t = 0; t < 16; ++t) {
                W[t] = M[t];
            }
            for (size_t t = 16; t < 64; ++t) {
                W[t] = small_sigma1(W[t - 2]) + W[t - 7] + small_sigma0(W[t - 15]) + W[t - 16];
            }

            // 2. Initialize working variables
            uint32_t a = H[0];
            uint32_t b = H[1];
            uint32_t c = H[2];
            uint32_t d = H[3];
            uint32_t e = H[4];
            uint32_t f = H[5];
            uint32_t g = H[6];
            uint32_t h = H[7];

            result.intermediate_states[blk_idx].reserve(64);

            // 3. 64 rounds of compression
            for (uint32_t t = 0; t < 64; ++t) {
                uint32_t T1 = h + big_sigma1(e) + ch(e, f, g) + K[t] + W[t];
                uint32_t T2 = big_sigma0(a) + maj(a, b, c);

                h = g;
                g = f;
                f = e;
                e = d + T1;
                d = c;
                c = b;
                b = a;
                a = T1 + T2;

                // Record intermediate state after round t
                result.intermediate_states[blk_idx].push_back(RoundState{t, a, b, c, d, e, f, g, h});
            }

            // 4. Compute intermediate hash values
            H[0] += a;
            H[1] += b;
            H[2] += c;
            H[3] += d;
            H[4] += e;
            H[5] += f;
            H[6] += g;
            H[7] += h;
        }

        result.final_hash_words = H;

        // Convert final 256-bit hash words to 64-character lowercase hex string
        std::ostringstream ss;
        for (uint32_t val : H) {
            ss << std::hex << std::setfill('0') << std::setw(8) << val;
        }
        result.hex_digest = ss.str();

        return result;
    }

    // Helper for std::string
    static SHA256Result compute_string(const std::string& input) {
        return compute(reinterpret_cast<const uint8_t*>(input.data()), input.size());
    }

    // Helper for file input
    static SHA256Result compute_file(const std::string& filepath) {
        std::ifstream file(filepath, std::ios::binary | std::ios::ate);
        if (!file.is_open()) {
            throw std::runtime_error("Failed to open file: " + filepath);
        }

        std::streamsize size = file.tellg();
        file.seekg(0, std::ios::beg);

        std::vector<uint8_t> buffer(static_cast<size_t>(size));
        if (size > 0) {
            if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
                throw std::runtime_error("Failed to read file: " + filepath);
            }
        }

        return compute(buffer.data(), buffer.size());
    }
};

// ----------------------------------------------------------------------------
// Verification Output File Generators
// Strictly adhering to Vivado $readmemh / testbench specifications
// ----------------------------------------------------------------------------

/**
 * 1. input_vectors.txt:
 * Contains fully padded 512-bit (64-byte) message blocks.
 * Format: One 512-bit block per line, represented as 16 contiguous 32-bit hex words (128 hex chars).
 */
bool write_input_vectors(const std::string& filename, const std::vector<BlockData>& blocks) {
    std::ofstream ofs(filename, std::ios::trunc);
    if (!ofs.is_open()) {
        std::cerr << "Error: Unable to open file for writing: " << filename << std::endl;
        return false;
    }

    for (const auto& block : blocks) {
        for (size_t i = 0; i < 16; ++i) {
            ofs << std::hex << std::setfill('0') << std::setw(8) << block.words[i];
        }
        ofs << "\n";
    }

    return true;
}

/**
 * 2. intermediate_states.txt:
 * Captures the state of the 8 working variables (A, B, C, D, E, F, G, H) after each round.
 * Format: 256-bit hex word per line (64 contiguous hex chars: A B C D E F G H).
 * Strictly compatible with Verilog $readmemh into reg [255:0] mem.
 */
bool write_intermediate_states(const std::string& filename,
                               const std::vector<std::vector<RoundState>>& all_states) {
    std::ofstream ofs(filename, std::ios::trunc);
    if (!ofs.is_open()) {
        std::cerr << "Error: Unable to open file for writing: " << filename << std::endl;
        return false;
    }

    for (size_t b = 0; b < all_states.size(); ++b) {
        if (all_states.size() > 1) {
            ofs << "// Block " << b << "\n";
        }

        for (const auto& st : all_states[b]) {
            // Output all 64 intermediate states (rounds 0..63) after each compression round
            ofs << std::hex << std::setfill('0')
                << std::setw(8) << st.a
                << std::setw(8) << st.b
                << std::setw(8) << st.c
                << std::setw(8) << st.d
                << std::setw(8) << st.e
                << std::setw(8) << st.f
                << std::setw(8) << st.g
                << std::setw(8) << st.h
                << "\n";
        }
    }

    return true;
}

/**
 * 3. final_hashes.txt:
 * The final 256-bit hash.
 * Format: One 256-bit hash per line (64 hex characters).
 */
bool write_final_hashes(const std::string& filename, const std::string& hex_digest) {
    std::ofstream ofs(filename, std::ios::trunc);
    if (!ofs.is_open()) {
        std::cerr << "Error: Unable to open file for writing: " << filename << std::endl;
        return false;
    }

    ofs << hex_digest << "\n";
    return true;
}

bool write_final_hashes(const std::string& filename, const std::vector<std::string>& hex_digests) {
    std::ofstream ofs(filename, std::ios::trunc);
    if (!ofs.is_open()) {
        std::cerr << "Error: Unable to open file for writing: " << filename << std::endl;
        return false;
    }

    for (const auto& d : hex_digests) {
        ofs << d << "\n";
    }
    return true;
}

} // namespace sha256

// ----------------------------------------------------------------------------
// Main Application & Self-Test
// ----------------------------------------------------------------------------
int main(int argc, char* argv[]) {
    std::string test_input = "abc";
    bool custom_mode = false;
    bool is_file = false;
    std::string target_path = "";

    // Parse command line arguments if provided
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-s" && i + 1 < argc) {
            test_input = argv[++i];
            custom_mode = true;
        } else if (arg == "-f" && i + 1 < argc) {
            target_path = argv[++i];
            custom_mode = true;
            is_file = true;
        } else if (arg == "-h" || arg == "--help") {
            std::cout << "Usage: " << argv[0] << " [options]\n"
                      << "Options:\n"
                      << "  (no args)       Run standard test on \"abc\" and generate verification files\n"
                      << "  -s <string>     Hash custom string and generate verification files\n"
                      << "  -f <filepath>   Hash file contents and generate verification files\n"
                      << "  -h, --help      Display this help menu\n";
            return 0;
        }
    }

    std::cout << "========================================================\n";
    std::cout << " SHA-256 C++ Golden Reference Model\n";
    std::cout << " FPGA Hardware Verification Test Vector Generator\n";
    std::cout << "========================================================\n\n";

    sha256::SHA256Result res;
    std::vector<sha256::BlockData> all_blocks;
    std::vector<std::vector<sha256::RoundState>> all_states;
    std::vector<std::string> all_digests;

    try {
        if (is_file) {
            std::cout << "[INFO] Processing file: " << target_path << "\n";
            res = sha256::SHA256Model::compute_file(target_path);
            all_blocks = res.blocks;
            all_states = res.intermediate_states;
            all_digests.push_back(res.hex_digest);
        } else if (custom_mode) {
            std::cout << "[INFO] Processing custom string input: \"" << test_input << "\"\n";
            res = sha256::SHA256Model::compute_string(test_input);
            all_blocks = res.blocks;
            all_states = res.intermediate_states;
            all_digests.push_back(res.hex_digest);
        } else {
            // Default: Generate 16 distinct test vectors to support single-core, dual-core, and 16-core tests
            std::cout << "[INFO] Generating 16 Test Vectors for 16-Core Mega-Array Verification...\n";
            std::vector<std::string> test_strings = {
                "abc",
                "",
                "message digest test block 02",
                "The quick brown fox jumps over",
                "hardware sha256 test vector 04",
                "cryptographic core test vector 05",
                "mega-array 16 core test stream 06",
                "zynq pynq-z2 fpga test stream 07",
                "parallel pipelined test stream 08",
                "unrolled datapath test stream 09",
                "high throughput test stream 10",
                "carry save adder test stream 11",
                "sliding window sched test str 12",
                "constant lookup rom test str 13",
                "verification assertion stream 14",
                "final verification block stream 15"
            };

            for (size_t i = 0; i < test_strings.size(); ++i) {
                sha256::SHA256Result r = sha256::SHA256Model::compute_string(test_strings[i]);
                all_blocks.push_back(r.blocks[0]);
                all_states.push_back(r.intermediate_states[0]);
                all_digests.push_back(r.hex_digest);
            }

            res = sha256::SHA256Model::compute_string("abc");
        }
    } catch (const std::exception& e) {
        std::cerr << "[ERROR] Execution failed: " << e.what() << "\n";
        return 1;
    }

    std::cout << "[INFO] Primary Vector : \"abc\"\n";
    std::cout << "[INFO] Total Blocks   : " << all_blocks.size() << "\n";
    std::cout << "[INFO] Vector 0 Hash  : " << all_digests[0] << "\n";
    if (all_digests.size() > 1) {
        std::cout << "[INFO] Vector 1 Hash  : " << all_digests[1] << "\n";
    }

    // Known standard NIST SHA-256 test vector for "abc"
    const std::string NIST_ABC_HASH = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    if (all_digests[0] == NIST_ABC_HASH) {
        std::cout << "[TEST] Result         : >>> PASS <<< (Matches NIST standard vector)\n\n";
    } else {
        std::cerr << "[TEST] Result         : >>> FAIL <<< (Hash mismatch!)\n\n";
        return 1;
    }

    // Write verification files
    const std::string input_vec_file = "input_vectors.txt";
    const std::string inter_states_file = "intermediate_states.txt";
    const std::string final_hashes_file = "final_hashes.txt";

    std::cout << "[FILE] Writing input vectors to: " << input_vec_file << " ... ";
    if (sha256::write_input_vectors(input_vec_file, all_blocks)) {
        std::cout << "DONE (" << all_blocks.size() << " blocks)\n";
    } else {
        std::cerr << "FAILED\n";
        return 1;
    }

    std::cout << "[FILE] Writing intermediate states to: " << inter_states_file << " ... ";
    if (sha256::write_intermediate_states(inter_states_file, all_states)) {
        std::cout << "DONE (" << all_states.size() * 64 << " states)\n";
    } else {
        std::cerr << "FAILED\n";
        return 1;
    }

    std::cout << "[FILE] Writing final hashes to: " << final_hashes_file << " ... ";
    if (sha256::write_final_hashes(final_hashes_file, all_digests)) {
        std::cout << "DONE (" << all_digests.size() << " digests)\n";
    } else {
        std::cerr << "FAILED\n";
        return 1;
    }

    std::cout << "\n[SUCCESS] All verification files successfully generated for Vivado RTL testbenches.\n";
    return 0;
}
