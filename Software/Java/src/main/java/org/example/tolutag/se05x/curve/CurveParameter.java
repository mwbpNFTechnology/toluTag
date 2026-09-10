package org.example.tolutag.se05x.curve;

/**
 * The individual parameters that define an elliptic curve on the SE05x, each
 * paired with the selector byte the applet uses to identify it.
 *
 * <p>The declaration order is also the order in which the parameters should be
 * written to the card.
 */
public enum CurveParameter {

    /** Field prime {@code p}. */
    PRIME((byte) 0x10),
    /** Curve coefficient {@code a}. */
    A((byte) 0x01),
    /** Curve coefficient {@code b}. */
    B((byte) 0x02),
    /** Generator (base) point {@code G}, uncompressed. */
    G((byte) 0x04),
    /** Order {@code n} of the generator point. */
    N((byte) 0x08);

    private final byte selector;

    CurveParameter(byte selector) {
        this.selector = selector;
    }

    /** @return the SE05x selector byte for this parameter. */
    public byte selector() {
        return selector;
    }
}
