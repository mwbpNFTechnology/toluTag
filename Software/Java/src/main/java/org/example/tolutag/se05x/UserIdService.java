package org.example.tolutag.se05x;

import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Creates UserID Authentication Objects on the SE05x (WriteUserID, spec
 * §4.7.1.5).
 *
 * <p>A UserID holds a 4-to-16-byte secret (a PIN). Binding another object's
 * policy to this UserID's identifier means operations on that object require a
 * session authenticated with the PIN.
 */
public final class UserIdService {

    /** Minimum UserID value length (bytes). */
    public static final int MIN_PIN_LENGTH = 4;
    /** Maximum UserID value length (bytes). */
    public static final int MAX_PIN_LENGTH = 16;

    private static final byte INS_WRITE_AUTH_OBJECT = Se05xApdu.INS_WRITE | Se05xApdu.INS_AUTH_OBJECT;

    private final Se05xChannel channel;

    public UserIdService(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Creates a UserID Authentication Object with the given secret (PIN).
     *
     * @param objectId the identifier for the new UserID
     * @param pin      the 4-to-16-byte secret
     * @throws ApduException            if the card rejects the command
     * @throws IllegalArgumentException if the PIN length is out of range
     * @throws CardException            if the transport fails
     */
    public void create(ObjectId objectId, byte[] pin) throws CardException {
        if (pin.length < MIN_PIN_LENGTH || pin.length > MAX_PIN_LENGTH) {
            throw new IllegalArgumentException(
                    "PIN must be " + MIN_PIN_LENGTH + " to " + MAX_PIN_LENGTH + " bytes, got " + pin.length);
        }
        byte[] payload = Tlv.concat(
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()),
                Tlv.encode(Se05xApdu.TAG_2, pin));

        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, INS_WRITE_AUTH_OBJECT,
                Se05xApdu.P1_USERID, Se05xApdu.P2_DEFAULT, payload));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("Create UserID", response.getSW());
        }
    }
}
