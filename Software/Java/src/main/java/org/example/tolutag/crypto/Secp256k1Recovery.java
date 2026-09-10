package org.example.tolutag.crypto;

import java.math.BigInteger;
import java.util.Arrays;

/**
 * Self-contained secp256k1 elliptic-curve arithmetic for ECDSA public-key
 * recovery - the operation Ethereum's {@code ecrecover} performs.
 *
 * <p>No third-party dependency: affine point math over {@link BigInteger} with a
 * modular square root (secp256k1's field prime is {@code p ≡ 3 (mod 4)}, so the
 * root is {@code a^((p+1)/4) mod p}).
 *
 * <p>Used to establish the ECDSA recovery id {@code v}: the SE05x returns only
 * {@code r} and {@code s}, so the correct {@code v} is found by recovering the
 * public key for each candidate and keeping the one that matches the chip's own
 * key - never by assuming a value.
 */
public final class Secp256k1Recovery {

    private static final BigInteger P = new BigInteger(
            "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F", 16);
    private static final BigInteger B = BigInteger.valueOf(7);
    private static final BigInteger GX = new BigInteger(
            "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798", 16);
    private static final BigInteger GY = new BigInteger(
            "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8", 16);

    /** The secp256k1 group order {@code n}. */
    public static final BigInteger CURVE_ORDER = new BigInteger(
            "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", 16);

    private static final Point G = new Point(GX, GY);

    private Secp256k1Recovery() {
        // Utility class - no instances.
    }

    /** @return the uncompressed public point {@code 0x04||X||Y} of private key {@code d}. */
    public static byte[] publicKeyFromPrivate(BigInteger d) {
        return G.multiply(d.mod(CURVE_ORDER)).encodeUncompressed();
    }

    /**
     * Recovers the uncompressed public point for one ECDSA recovery id.
     *
     * @param recId  recovery id (0 or 1 for Ethereum)
     * @param r      signature r
     * @param s      signature s (low form)
     * @param digest the 32-byte signed digest
     * @return the 65-byte uncompressed point, or {@code null} if this recId does
     *         not yield a valid key
     */
    public static byte[] recoverPublicKey(int recId, BigInteger r, BigInteger s, byte[] digest) {
        BigInteger n = CURVE_ORDER;
        // x = r + (recId / 2) * n; Ethereum only uses recId 0/1, so x = r.
        BigInteger x = r.add(BigInteger.valueOf(recId / 2L).multiply(n));
        if (x.compareTo(P) >= 0) {
            return null;
        }
        Point bigR = decompress(x, recId & 1);
        if (bigR == null || !bigR.multiply(n).isInfinity()) {
            return null;
        }

        BigInteger e = new BigInteger(1, digest).mod(n);
        BigInteger rInv = r.modInverse(n);
        // Q = rInv * (s*R - e*G)
        Point sR = bigR.multiply(s.mod(n));
        Point eG = G.multiply(e).negate();
        Point sum = sR.add(eG);
        Point q = sum.multiply(rInv);
        return q.isInfinity() ? null : q.encodeUncompressed();
    }

    /** Decompresses an x-coordinate to the point whose y has the given low bit. */
    private static Point decompress(BigInteger x, int yBit) {
        BigInteger ySquared = x.modPow(BigInteger.valueOf(3), P).add(B).mod(P);
        BigInteger y = modSqrt(ySquared);
        if (y == null) {
            return null;
        }
        if ((y.testBit(0) ? 1 : 0) != yBit) {
            y = P.subtract(y);
        }
        return new Point(x, y);
    }

    /** Square root modulo the field prime P (P ≡ 3 mod 4). */
    private static BigInteger modSqrt(BigInteger a) {
        BigInteger candidate = a.modPow(P.add(BigInteger.ONE).shiftRight(2), P);
        return candidate.multiply(candidate).mod(P).equals(a.mod(P)) ? candidate : null;
    }

    /** Immutable affine point on secp256k1; {@code null} coordinates mean infinity. */
    private static final class Point {
        private final BigInteger x;
        private final BigInteger y;

        private Point(BigInteger x, BigInteger y) {
            this.x = x;
            this.y = y;
        }

        private static final Point INFINITY = new Point(null, null);

        private boolean isInfinity() {
            return x == null;
        }

        private Point negate() {
            return isInfinity() ? this : new Point(x, P.subtract(y));
        }

        private Point add(Point other) {
            if (isInfinity()) {
                return other;
            }
            if (other.isInfinity()) {
                return this;
            }
            if (x.equals(other.x)) {
                if (y.equals(other.y)) {
                    return doublePoint();
                }
                return INFINITY; // P + (-P)
            }
            BigInteger slope = other.y.subtract(y).multiply(other.x.subtract(x).modInverse(P)).mod(P);
            return fromSlope(slope, other.x);
        }

        private Point doublePoint() {
            if (isInfinity() || y.signum() == 0) {
                return INFINITY;
            }
            BigInteger three = BigInteger.valueOf(3);
            BigInteger slope = x.multiply(x).multiply(three)
                    .multiply(y.shiftLeft(1).modInverse(P)).mod(P);
            return fromSlope(slope, x);
        }

        private Point fromSlope(BigInteger slope, BigInteger otherX) {
            BigInteger xr = slope.multiply(slope).subtract(x).subtract(otherX).mod(P);
            BigInteger yr = slope.multiply(x.subtract(xr)).subtract(y).mod(P);
            return new Point(xr, yr);
        }

        private Point multiply(BigInteger k) {
            Point result = INFINITY;
            Point addend = this;
            BigInteger scalar = k;
            while (scalar.signum() > 0) {
                if (scalar.testBit(0)) {
                    result = result.add(addend);
                }
                addend = addend.doublePoint();
                scalar = scalar.shiftRight(1);
            }
            return result;
        }

        private byte[] encodeUncompressed() {
            byte[] out = new byte[65];
            out[0] = 0x04;
            copyInto(x, out, 1);
            copyInto(y, out, 33);
            return out;
        }

        private static void copyInto(BigInteger value, byte[] out, int offset) {
            byte[] bytes = value.toByteArray();
            // Drop a possible sign byte, left-pad to 32.
            int length = Math.min(bytes.length, 32);
            byte[] fixed = Arrays.copyOfRange(bytes, bytes.length - length, bytes.length);
            System.arraycopy(fixed, 0, out, offset + (32 - length), length);
        }
    }
}
