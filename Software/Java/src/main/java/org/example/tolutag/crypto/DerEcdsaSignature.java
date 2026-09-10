package org.example.tolutag.crypto;

import java.math.BigInteger;

/**
 * An ECDSA signature parsed from its ASN.1 DER encoding
 * ({@code SEQUENCE { r INTEGER, s INTEGER }}), exposed as {@code r} and {@code s}
 * integers.
 *
 * <p>Immutable. {@link #normalizeLowS(BigInteger)} returns the canonical
 * low-{@code s} form required by Ethereum (EIP-2).
 */
public final class DerEcdsaSignature {

    private static final int SEQUENCE_TAG = 0x30;
    private static final int INTEGER_TAG = 0x02;

    private final BigInteger r;
    private final BigInteger s;

    private DerEcdsaSignature(BigInteger r, BigInteger s) {
        this.r = r;
        this.s = s;
    }

    /**
     * Parses a DER-encoded ECDSA signature.
     *
     * @throws IllegalArgumentException if the bytes are not a valid
     *                                  {@code SEQUENCE { INTEGER, INTEGER }}
     */
    public static DerEcdsaSignature parse(byte[] der) {
        if (der.length < 2 || (der[0] & 0xFF) != SEQUENCE_TAG) {
            throw new IllegalArgumentException("Not a valid ASN.1 SEQUENCE");
        }

        int rTagPos = 2;
        if ((der[rTagPos] & 0xFF) != INTEGER_TAG) {
            throw new IllegalArgumentException("Expected INTEGER tag for r");
        }
        int rLength = der[rTagPos + 1] & 0xFF;
        BigInteger r = readInteger(der, rTagPos + 2, rLength);

        int sTagPos = rTagPos + 2 + rLength;
        if (sTagPos + 1 >= der.length || (der[sTagPos] & 0xFF) != INTEGER_TAG) {
            throw new IllegalArgumentException("Expected INTEGER tag for s");
        }
        int sLength = der[sTagPos + 1] & 0xFF;
        BigInteger s = readInteger(der, sTagPos + 2, sLength);

        return new DerEcdsaSignature(r, s);
    }

    private static BigInteger readInteger(byte[] der, int offset, int length) {
        if (offset + length > der.length) {
            throw new IllegalArgumentException("Truncated INTEGER in DER signature");
        }
        byte[] magnitude = new byte[length];
        System.arraycopy(der, offset, magnitude, 0, length);
        return new BigInteger(1, magnitude); // always positive
    }

    public BigInteger r() {
        return r;
    }

    public BigInteger s() {
        return s;
    }

    /**
     * Returns the canonical low-{@code s} form: if {@code s} is greater than
     * half the curve order, it is replaced by {@code order - s} (an equivalent
     * signature), as required by Ethereum.
     *
     * @param order the curve order {@code n}
     */
    public DerEcdsaSignature normalizeLowS(BigInteger order) {
        BigInteger halfOrder = order.shiftRight(1);
        if (s.compareTo(halfOrder) > 0) {
            return new DerEcdsaSignature(r, order.subtract(s));
        }
        return this;
    }
}
