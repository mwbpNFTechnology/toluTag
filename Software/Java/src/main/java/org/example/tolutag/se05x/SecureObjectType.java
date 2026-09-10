package org.example.tolutag.se05x;

import java.util.HashMap;
import java.util.Map;

/**
 * Decoder for the SE05x {@code SecureObjectType} byte (spec Table 30) returned by
 * ReadType.
 *
 * <p>For EC objects the type byte encodes both the curve and the role
 * (key pair / private / public) - e.g. {@code 0x5D} is an secp256k1 key pair -
 * so there is no plain {@code EC_KEY_PAIR} value; this class resolves the byte to
 * a readable description.
 */
public final class SecureObjectType {

    /** The role an EC object plays. */
    public enum Role {
        KEY_PAIR("key pair"), PRIVATE("private key"), PUBLIC("public key");

        private final String label;

        Role(String label) {
            this.label = label;
        }

        public String label() {
            return label;
        }
    }

    // Weierstrass EC families, in the spec's block order starting at 0x21,
    // each occupying 4 consecutive type values (pair, private, public, reserved).
    private static final String[] WEIERSTRASS_CURVES = {
            "NIST_P192", "NIST_P224", "NIST_P256", "NIST_P384", "NIST_P521",
            "Brainpool160", "Brainpool192", "Brainpool224", "Brainpool256",
            "Brainpool320", "Brainpool384", "Brainpool512",
            "Secp160k1", "Secp192k1", "Secp224k1", "Secp256k1"
    };

    private static final Map<Integer, String> DESCRIPTIONS = buildDescriptions();

    private SecureObjectType() {
        // Utility class - no instances.
    }

    /**
     * @param typeByte the type byte from ReadType (unsigned)
     * @return a human-readable description, e.g. {@code "EC key pair (Secp256k1)"}
     */
    public static String describe(int typeByte) {
        String description = DESCRIPTIONS.get(typeByte & 0xFF);
        return description != null
                ? description
                : String.format("unknown type (0x%02X)", typeByte & 0xFF);
    }

    private static Map<Integer, String> buildDescriptions() {
        Map<Integer, String> map = new HashMap<>();

        // Base (non-curve-specific) types, Table 30.
        map.put(0x01, "EC key pair");
        map.put(0x02, "EC private key");
        map.put(0x03, "EC public key");
        map.put(0x04, "RSA key pair");
        map.put(0x05, "RSA key pair (CRT)");
        map.put(0x06, "RSA private key");
        map.put(0x07, "RSA private key (CRT)");
        map.put(0x08, "RSA public key");
        map.put(0x09, "AES key");
        map.put(0x0A, "DES key");
        map.put(0x0B, "Binary file");
        map.put(0x0C, "UserID");
        map.put(0x0D, "Counter");
        map.put(0x0F, "PCR");
        map.put(0x11, "HMAC key");

        // Curve-specific Weierstrass EC types (0x21 upward, 4 values per curve).
        int base = 0x21;
        for (int i = 0; i < WEIERSTRASS_CURVES.length; i++) {
            putEcCurve(map, base + i * 4, WEIERSTRASS_CURVES[i]);
        }

        // Edwards / Montgomery families.
        putEcCurve(map, 0x65, "ED25519");
        putEcCurve(map, 0x69, "MONT_DH_25519");
        putEcCurve(map, 0x71, "MONT_DH_448");

        return map;
    }

    private static void putEcCurve(Map<Integer, String> map, int blockStart, String curve) {
        map.put(blockStart + Role.KEY_PAIR.ordinal(), "EC " + Role.KEY_PAIR.label() + " (" + curve + ")");
        map.put(blockStart + Role.PRIVATE.ordinal(), "EC " + Role.PRIVATE.label() + " (" + curve + ")");
        map.put(blockStart + Role.PUBLIC.ordinal(), "EC " + Role.PUBLIC.label() + " (" + curve + ")");
    }
}
