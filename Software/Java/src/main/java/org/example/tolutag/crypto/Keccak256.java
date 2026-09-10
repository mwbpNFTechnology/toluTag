package org.example.tolutag.crypto;

/**
 * Self-contained Keccak-256 implementation, as used by Ethereum.
 *
 * <p>This is the original Keccak (padding byte {@code 0x01}), <em>not</em> the
 * later NIST SHA3-256 (padding {@code 0x06}); the two produce different digests.
 * Rate = 1088 bits (136 bytes), capacity = 512 bits, output = 32 bytes.
 *
 * <p>No third-party dependency and no silent fallback: if the input is valid,
 * the output is a genuine Keccak-256 digest.
 */
public final class Keccak256 {

    private static final int RATE_BYTES = 136;   // 1600-bit state minus 512-bit capacity
    private static final int OUTPUT_BYTES = 32;
    private static final int LANES = 25;         // 5 x 5 state lanes

    private static final long[] ROUND_CONSTANTS = {
            0x0000000000000001L, 0x0000000000008082L, 0x800000000000808aL, 0x8000000080008000L,
            0x000000000000808bL, 0x0000000080000001L, 0x8000000080008081L, 0x8000000000008009L,
            0x000000000000008aL, 0x0000000000000088L, 0x0000000080008009L, 0x000000008000000aL,
            0x000000008000808bL, 0x800000000000008bL, 0x8000000000008089L, 0x8000000000008003L,
            0x8000000000008002L, 0x8000000000000080L, 0x000000000000800aL, 0x800000008000000aL,
            0x8000000080008081L, 0x8000000000008080L, 0x0000000080000001L, 0x8000000080008008L
    };

    private static final int[] ROTATION_OFFSETS = {
            0, 1, 62, 28, 27,
            36, 44, 6, 55, 20,
            3, 10, 43, 25, 39,
            41, 45, 15, 21, 8,
            18, 2, 61, 56, 14
    };

    private Keccak256() {
        // Utility class - no instances.
    }

    /**
     * Computes the Keccak-256 digest of {@code input}.
     *
     * @param input the message bytes
     * @return a 32-byte digest
     */
    public static byte[] digest(byte[] input) {
        long[] state = new long[LANES];

        // --- Absorb -------------------------------------------------------
        int offset = 0;
        int fullBlocks = input.length / RATE_BYTES;
        for (int block = 0; block < fullBlocks; block++) {
            absorb(state, input, offset);
            keccakF(state);
            offset += RATE_BYTES;
        }

        // Final block: copy the remainder and apply Keccak padding (0x01 ... 0x80).
        byte[] lastBlock = new byte[RATE_BYTES];
        int remaining = input.length - offset;
        System.arraycopy(input, offset, lastBlock, 0, remaining);
        lastBlock[remaining] ^= 0x01;
        lastBlock[RATE_BYTES - 1] ^= (byte) 0x80;
        absorb(state, lastBlock, 0);
        keccakF(state);

        // --- Squeeze (one block is enough for a 32-byte output) -----------
        byte[] output = new byte[OUTPUT_BYTES];
        for (int i = 0; i < OUTPUT_BYTES; i++) {
            output[i] = (byte) (state[i / 8] >>> (8 * (i % 8)));
        }
        return output;
    }

    private static void absorb(long[] state, byte[] data, int offset) {
        for (int i = 0; i < RATE_BYTES / 8; i++) {
            state[i] ^= readLaneLittleEndian(data, offset + i * 8);
        }
    }

    private static long readLaneLittleEndian(byte[] data, int offset) {
        long lane = 0;
        for (int i = 0; i < 8; i++) {
            lane |= (data[offset + i] & 0xFFL) << (8 * i);
        }
        return lane;
    }

    private static void keccakF(long[] state) {
        long[] c = new long[5];
        long[] d = new long[5];
        long[] b = new long[LANES];

        for (int round = 0; round < 24; round++) {
            // Theta
            for (int x = 0; x < 5; x++) {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
            }
            for (int x = 0; x < 5; x++) {
                d[x] = c[(x + 4) % 5] ^ Long.rotateLeft(c[(x + 1) % 5], 1);
            }
            for (int x = 0; x < 5; x++) {
                for (int y = 0; y < 5; y++) {
                    state[x + 5 * y] ^= d[x];
                }
            }

            // Rho and Pi
            for (int x = 0; x < 5; x++) {
                for (int y = 0; y < 5; y++) {
                    int index = x + 5 * y;
                    int newIndex = y + 5 * ((2 * x + 3 * y) % 5);
                    b[newIndex] = Long.rotateLeft(state[index], ROTATION_OFFSETS[index]);
                }
            }

            // Chi
            for (int x = 0; x < 5; x++) {
                for (int y = 0; y < 5; y++) {
                    int index = x + 5 * y;
                    state[index] = b[index] ^ ((~b[(x + 1) % 5 + 5 * y]) & b[(x + 2) % 5 + 5 * y]);
                }
            }

            // Iota
            state[0] ^= ROUND_CONSTANTS[round];
        }
    }
}
