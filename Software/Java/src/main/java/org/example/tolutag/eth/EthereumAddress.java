package org.example.tolutag.eth;

import org.example.tolutag.crypto.Keccak256;
import org.example.tolutag.util.Hex;

import java.util.Arrays;

/**
 * A 20-byte Ethereum address, derived from a secp256k1 public key.
 *
 * <p>Immutable value object; {@link #toString()} yields the {@code 0x}-prefixed
 * hex form.
 */
public final class EthereumAddress {

    private static final byte UNCOMPRESSED_PREFIX = 0x04;
    private static final int ADDRESS_LENGTH = 20;

    private final byte[] value;

    private EthereumAddress(byte[] value) {
        this.value = value;
    }

    /**
     * Derives the address from an uncompressed secp256k1 public point
     * ({@code 0x04 || X || Y}): Keccak-256 of {@code X || Y}, last 20 bytes.
     *
     * @throws IllegalArgumentException if the point is not uncompressed
     */
    public static EthereumAddress fromPublicKey(byte[] uncompressedPoint) {
        if (uncompressedPoint.length == 0 || uncompressedPoint[0] != UNCOMPRESSED_PREFIX) {
            throw new IllegalArgumentException("Expected an uncompressed public key (0x04 prefix)");
        }
        byte[] xy = Arrays.copyOfRange(uncompressedPoint, 1, uncompressedPoint.length);
        byte[] hash = Keccak256.digest(xy);
        byte[] address = Arrays.copyOfRange(hash, hash.length - ADDRESS_LENGTH, hash.length);
        return new EthereumAddress(address);
    }

    /** @return the {@code 0x}-prefixed hex representation. */
    public String hex() {
        return "0x" + Hex.toHex(value);
    }

    @Override
    public String toString() {
        return hex();
    }
}
