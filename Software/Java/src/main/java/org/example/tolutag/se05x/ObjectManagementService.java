package org.example.tolutag.se05x;

import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Generic object management on the SE05x: deleting a Secure Object by its
 * identifier, regardless of type.
 */
public final class ObjectManagementService {

    private final Se05xChannel channel;

    public ObjectManagementService(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Attempts to delete the object with the given identifier.
     *
     * @return {@code true} if the object was deleted, {@code false} if the card
     *         refused (e.g. the object is deletion-protected or does not exist)
     * @throws CardException if the transport fails
     */
    public boolean delete(ObjectId objectId) throws CardException {
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_MGMT,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_DELETE_OBJECT,
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes())));
        return response.getSW() == Se05xApdu.SW_SUCCESS;
    }
}
