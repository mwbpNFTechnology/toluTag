package org.example.tolutag.se05x;

/**
 * The {@code Origin} attribute of a Secure Object (SE05x spec Table 32): where
 * the object's key material came from.
 *
 * <p>For an EC key pair this answers the key question "was it generated on-chip
 * or imported": {@link #INTERNAL} means the chip generated it (random), while
 * {@link #EXTERNAL} means it was imported from outside.
 */
public enum Origin {

    /** Generated outside the module and imported (0x01). */
    EXTERNAL((byte) 0x01, "imported (generated outside the chip)"),
    /** Generated inside the module (0x02) - i.e. random on-chip generation. */
    INTERNAL((byte) 0x02, "generated on-chip (random)"),
    /** Trust-provisioned by NXP (0x03). */
    PROVISIONED((byte) 0x03, "NXP trust-provisioned"),
    /** Value not recognized. */
    UNKNOWN((byte) 0x00, "unknown");

    private final byte value;
    private final String description;

    Origin(byte value, String description) {
        this.value = value;
        this.description = description;
    }

    /** @return the raw attribute byte. */
    public byte value() {
        return value;
    }

    /** @return a human-readable description. */
    public String description() {
        return description;
    }

    /** @return {@code true} if the key was generated on-chip (random). */
    public boolean isGeneratedOnChip() {
        return this == INTERNAL;
    }

    /** @return {@code true} if the key was imported. */
    public boolean isImported() {
        return this == EXTERNAL;
    }

    /**
     * @param value the raw origin byte
     * @return the matching {@link Origin}, or {@link #UNKNOWN}
     */
    public static Origin fromByte(byte value) {
        for (Origin origin : values()) {
            if (origin != UNKNOWN && origin.value == value) {
                return origin;
            }
        }
        return UNKNOWN;
    }
}
