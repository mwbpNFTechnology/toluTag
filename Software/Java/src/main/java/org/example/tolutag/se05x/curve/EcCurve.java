package org.example.tolutag.se05x.curve;

import java.util.List;

/**
 * An elliptic curve that can be provisioned onto the SE05x.
 *
 * <p>Implementations expose the SE05x curve identifier and the raw bytes of
 * each {@link CurveParameter}. Adding support for another curve is a matter of
 * providing a new implementation.
 */
public interface EcCurve {

    /** @return a human-readable curve name, e.g. {@code "secp256k1"}. */
    String name();

    /** @return the SE05x curve identifier byte. */
    byte curveId();

    /**
     * @param parameter the parameter to fetch
     * @return the big-endian bytes of the requested parameter
     */
    byte[] parameter(CurveParameter parameter);

    /**
     * @return the parameters in the order they should be written to the card.
     */
    default List<CurveParameter> parameterOrder() {
        return List.of(CurveParameter.values());
    }
}
