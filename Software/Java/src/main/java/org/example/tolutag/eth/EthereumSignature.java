package org.example.tolutag.eth;

import org.example.tolutag.crypto.DerEcdsaSignature;
import org.example.tolutag.util.Hex;

import java.math.BigInteger;

/**
 * An Ethereum-format ECDSA signature: the {@code r} and {@code s} components as
 * 32-byte (64 hex-char) values, the recovery id {@code v}, and the signed
 * message hash.
 *
 * <p>Immutable value object.
 */
public final class EthereumSignature {

    private static final int COMPONENT_HEX_LENGTH = 64;

    private final String r;
    private final String s;
    private final int v;
    private final String messageHash;

    private EthereumSignature(String r, String s, int v, String messageHash) {
        this.r = r;
        this.s = s;
        this.v = v;
        this.messageHash = messageHash;
    }

    /**
     * Builds an Ethereum signature from a parsed DER signature, applying the
     * low-{@code s} normalization required by Ethereum.
     *
     * @param signature   the parsed DER signature
     * @param curveOrder  the secp256k1 curve order {@code n}
     * @param messageHash the 32-byte hash that was signed
     * @param v           the recovery id (typically 27 or 28)
     */
    public static EthereumSignature from(DerEcdsaSignature signature, BigInteger curveOrder,
                                         byte[] messageHash, int v) {
        DerEcdsaSignature canonical = signature.normalizeLowS(curveOrder);
        return new EthereumSignature(
                padComponent(canonical.r()),
                padComponent(canonical.s()),
                v,
                Hex.toHex(messageHash));
    }

    private static String padComponent(BigInteger value) {
        String hex = value.toString(16);
        if (hex.length() < COMPONENT_HEX_LENGTH) {
            hex = "0".repeat(COMPONENT_HEX_LENGTH - hex.length()) + hex;
        }
        return hex;
    }

    /** @return the {@code r} component as 64 lower-case hex characters. */
    public String r() {
        return r;
    }

    /** @return the {@code s} component as 64 lower-case hex characters. */
    public String s() {
        return s;
    }

    /** @return the recovery id {@code v}. */
    public int v() {
        return v;
    }

    /** @return the signed message hash as hex. */
    public String messageHash() {
        return messageHash;
    }
}
