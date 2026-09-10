package org.example.tolutag.se05x;

import org.example.tolutag.se05x.curve.EcCurve;
import org.example.tolutag.se05x.policy.EcKeyPolicy;
import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Creates, reads, and deletes EC key pairs on the SE05x.
 *
 * <p>A "protected" key pair carries a policy that omits the DELETE permission,
 * so the secure element will refuse to remove it.
 */
public final class EcKeyPairService {

    private static final int READ_EXPECTED_LENGTH = 256;
    private static final byte P1_EC_KEY_PAIR = Se05xApdu.P1_KEY_PAIR | Se05xApdu.P1_EC;

    private final Se05xChannel channel;

    public EcKeyPairService(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Generates a key pair whose policy is enforced by the secure element.
     *
     * @throws ApduException if the card rejects the command
     * @throws CardException if the transport fails
     */
    public void createProtected(ObjectId objectId, EcCurve curve, EcKeyPolicy policy) throws CardException {
        byte[] data = Tlv.concat(
                policy.toTlv(),
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()),
                Tlv.encode(Se05xApdu.TAG_2, curve.curveId()));
        writeKeyPair("Create protected key", data);
    }

    /**
     * Generates a key pair with no explicit policy.
     *
     * @throws ApduException if the card rejects the command
     * @throws CardException if the transport fails
     */
    public void createStandard(ObjectId objectId, EcCurve curve) throws CardException {
        byte[] data = Tlv.concat(
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()),
                Tlv.encode(Se05xApdu.TAG_2, curve.curveId()));
        writeKeyPair("Create key", data);
    }

    private void writeKeyPair(String operation, byte[] data) throws CardException {
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_WRITE,
                P1_EC_KEY_PAIR, Se05xApdu.P2_DEFAULT, data));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException(operation, response.getSW());
        }
    }

    /**
     * Reads the public key of an existing key object.
     *
     * @return the raw response data (the encoded public key)
     * @throws ApduException if the card rejects the command
     * @throws CardException if the transport fails
     */
    public byte[] readPublicKey(ObjectId objectId) throws CardException {
        byte[] data = Tlv.encode(Se05xApdu.TAG_1, objectId.bytes());
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_READ,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_DEFAULT, data, READ_EXPECTED_LENGTH));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("Read public key", response.getSW());
        }
        return response.getData();
    }

    /**
     * Attempts to delete a key object.
     *
     * @return {@code true} if the object was deleted, {@code false} if the card
     *         refused (e.g. because the key is deletion-protected)
     * @throws CardException if the transport fails
     */
    public boolean delete(ObjectId objectId) throws CardException {
        return new ObjectManagementService(channel).delete(objectId);
    }
}
