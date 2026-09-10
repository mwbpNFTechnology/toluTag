package org.example.tolutag.util;

/**
 * Utility helpers for converting between byte arrays and their hexadecimal
 * string representation.
 *
 * <p>This class is stateless and cannot be instantiated.
 */
public final class Hex {

    private Hex() {
        // Utility class - no instances.
    }

    /**
     * Encodes a byte array as an upper-case hexadecimal string.
     *
     * @param bytes the bytes to encode (must not be {@code null})
     * @return the hex string, two characters per byte
     */
    public static String toHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }

    /**
     * Decodes a hexadecimal string into a byte array.
     *
     * @param hex a string of hex digits with an even length
     * @return the decoded bytes
     * @throws IllegalArgumentException if the string has odd length or
     *                                  contains non-hex characters
     */
    public static byte[] toBytes(String hex) {
        String cleaned = hex.trim();
        int len = cleaned.length();
        if (len % 2 != 0) {
            throw new IllegalArgumentException("Hex string must have an even length: " + hex);
        }
        byte[] out = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            int hi = Character.digit(cleaned.charAt(i), 16);
            int lo = Character.digit(cleaned.charAt(i + 1), 16);
            if (hi < 0 || lo < 0) {
                throw new IllegalArgumentException("Invalid hex character in: " + hex);
            }
            out[i / 2] = (byte) ((hi << 4) + lo);
        }
        return out;
    }
}
