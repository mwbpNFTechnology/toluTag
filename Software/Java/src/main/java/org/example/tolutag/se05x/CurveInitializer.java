package org.example.tolutag.se05x;

import org.example.tolutag.se05x.curve.CurveParameter;
import org.example.tolutag.se05x.curve.EcCurve;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Provisions an elliptic curve onto the SE05x: creates the curve object and
 * then writes each of its parameters.
 *
 * <p>Some SE05x variants ship with well-known curves pre-installed, in which
 * case (re-)creating the curve may return a non-success status. This class
 * therefore reports success per step rather than throwing, letting the caller
 * decide whether to proceed.
 */
public final class CurveInitializer {

    private final Se05xChannel channel;

    public CurveInitializer(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Creates the curve and writes all of its parameters.
     *
     * @param curve the curve to provision
     * @return {@code true} if every parameter was written successfully
     * @throws CardException if the transport fails
     */
    public boolean initialize(EcCurve curve) throws CardException {
        createCurve(curve);
        boolean allSet = true;
        for (CurveParameter parameter : curve.parameterOrder()) {
            allSet &= writeParameter(curve, parameter);
        }
        return allSet;
    }

    private void createCurve(EcCurve curve) throws CardException {
        byte[] data = Tlv.encode(Se05xApdu.TAG_1, curve.curveId());
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_WRITE,
                Se05xApdu.P1_CURVE, Se05xApdu.P2_CREATE, data));
        // A non-success SW here usually means the curve already exists; the
        // parameter writes below will confirm whether it is usable.
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            System.out.printf("Curve create returned SW=0x%04X (continuing)%n", response.getSW());
        }
    }

    private boolean writeParameter(EcCurve curve, CurveParameter parameter) throws CardException {
        byte[] data = Tlv.concat(
                Tlv.encode(Se05xApdu.TAG_1, curve.curveId()),
                Tlv.encode(Se05xApdu.TAG_2, parameter.selector()),
                Tlv.encode(Se05xApdu.TAG_3, curve.parameter(parameter)));

        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_WRITE,
                Se05xApdu.P1_CURVE, Se05xApdu.P2_PARAM, data));

        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            System.out.printf("Failed to set parameter %s: SW=0x%04X%n", parameter, response.getSW());
            return false;
        }
        return true;
    }
}
