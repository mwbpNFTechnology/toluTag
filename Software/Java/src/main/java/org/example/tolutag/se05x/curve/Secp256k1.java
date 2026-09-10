package org.example.tolutag.se05x.curve;

import org.example.tolutag.util.Hex;

import java.util.EnumMap;
import java.util.Map;

/**
 * The secp256k1 curve (the curve used by Bitcoin and Ethereum), as provisioned
 * onto the SE05x.
 *
 * <p>Stateless and immutable; access the shared instance via {@link #INSTANCE}.
 */
public final class Secp256k1 implements EcCurve {

    /** Shared, immutable instance. */
    public static final Secp256k1 INSTANCE = new Secp256k1();

    private static final byte CURVE_ID = 0x10;

    private static final String PRIME = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F";
    private static final String A = "0000000000000000000000000000000000000000000000000000000000000000";
    private static final String B = "0000000000000000000000000000000000000000000000000000000000000007";
    private static final String G = "0479BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"
            + "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8";
    private static final String N = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141";

    private final Map<CurveParameter, byte[]> parameters;

    private Secp256k1() {
        Map<CurveParameter, byte[]> map = new EnumMap<>(CurveParameter.class);
        map.put(CurveParameter.PRIME, Hex.toBytes(PRIME));
        map.put(CurveParameter.A, Hex.toBytes(A));
        map.put(CurveParameter.B, Hex.toBytes(B));
        map.put(CurveParameter.G, Hex.toBytes(G));
        map.put(CurveParameter.N, Hex.toBytes(N));
        this.parameters = map;
    }

    @Override
    public String name() {
        return "secp256k1";
    }

    @Override
    public byte curveId() {
        return CURVE_ID;
    }

    @Override
    public byte[] parameter(CurveParameter parameter) {
        // Defensive copy so callers cannot mutate the shared parameter bytes.
        return parameters.get(parameter).clone();
    }
}
