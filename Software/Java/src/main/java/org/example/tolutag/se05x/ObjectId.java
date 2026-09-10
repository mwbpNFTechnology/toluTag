package org.example.tolutag.se05x;

import org.example.tolutag.util.Hex;

import java.util.Arrays;

/**
 * A 4-byte SE05x object identifier.
 *
 * <p>Immutable value object, constructed from an explicit 8-character hex string.
 */
public final class ObjectId {

    private final byte[] value;

    private ObjectId(byte[] value) {
        this.value = value;
    }

    /**
     * Parses an object id from exactly 8 hex characters (4 bytes).
     *
     * @throws IllegalArgumentException if the string is not 8 hex digits
     */
    public static ObjectId fromHex(String hex) {
        String cleaned = hex.trim();
        if (!cleaned.matches("[0-9A-Fa-f]{8}")) {
            throw new IllegalArgumentException("Object ID must be 8 hex characters: " + hex);
        }
        return new ObjectId(Hex.toBytes(cleaned));
    }

    /**
     * Parses an object id from up to 8 hex characters, left-padding shorter
     * input with zeros (so {@code "2222"} becomes {@code "00002222"}).
     *
     * @throws IllegalArgumentException if the input is empty, longer than 8
     *                                  characters, or not valid hex
     */
    public static ObjectId fromHexPadded(String hex) {
        String cleaned = hex.trim();
        if (cleaned.isEmpty() || cleaned.length() > 8 || !cleaned.matches("[0-9A-Fa-f]+")) {
            throw new IllegalArgumentException("Object ID must be 1-8 hex characters: " + hex);
        }
        return fromHex("0".repeat(8 - cleaned.length()) + cleaned);
    }

    /** @return a defensive copy of the 4 identifier bytes. */
    public byte[] bytes() {
        return value.clone();
    }

    /** @return the identifier as a big-endian 32-bit value (e.g. for a policy auth id). */
    public int toInt() {
        return ((value[0] & 0xFF) << 24) | ((value[1] & 0xFF) << 16)
                | ((value[2] & 0xFF) << 8) | (value[3] & 0xFF);
    }

    /** @return the identifier as an upper-case hex string. */
    public String toHex() {
        return Hex.toHex(value);
    }

    @Override
    public String toString() {
        return toHex();
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof ObjectId id && Arrays.equals(value, id.value);
    }

    @Override
    public int hashCode() {
        return Arrays.hashCode(value);
    }
}
