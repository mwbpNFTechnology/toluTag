package org.example.tolutag.se05x;

import org.example.tolutag.se05x.policy.EcKeyPolicy;
import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Creates, writes and reads SE05x BinaryFile objects - arbitrary byte arrays,
 * used here to store and retrieve a plain string.
 *
 * <p>A BinaryFile has a fixed length set when it is created; a later update must
 * fit within that length. Because a single APDU is limited (buffer 270 bytes),
 * this service writes in one shot, so the payload must be modest
 * (see {@link #MAX_SINGLE_WRITE}).
 */
public final class BinaryFileService {

    /** Conservative max data length for a single-APDU create/write. */
    public static final int MAX_SINGLE_WRITE = 200;

    private static final int EXPECTED_RESPONSE_LENGTH = 256;

    private final Se05xChannel channel;

    public BinaryFileService(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Creates a new BinaryFile sized to {@code data} and writes it, applying the
     * given policy.
     *
     * @throws ApduException            if the card rejects the command (e.g. the
     *                                  id is already in use)
     * @throws IllegalArgumentException if the data is empty or too large
     * @throws CardException            if the transport fails
     */
    public void create(ObjectId objectId, byte[] data, EcKeyPolicy policy) throws CardException {
        requireWritableSize(data);
        byte[] payload = Tlv.concat(
                policy.toTlv(),
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()),
                Tlv.encode(Se05xApdu.TAG_3, twoBytes(data.length)), // file length (creation only)
                Tlv.encode(Se05xApdu.TAG_4, data));
        write("Create binary file", payload);
    }

    /**
     * Overwrites the contents of an existing BinaryFile. The data must fit the
     * length the file was created with.
     */
    public void update(ObjectId objectId, byte[] data) throws CardException {
        requireWritableSize(data);
        byte[] payload = Tlv.concat(
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()),
                Tlv.encode(Se05xApdu.TAG_4, data));
        write("Update binary file", payload);
    }

    /**
     * Reads the full contents of a BinaryFile.
     *
     * @throws ApduException if the card rejects the read
     * @throws CardException if the transport fails
     */
    public byte[] read(ObjectId objectId) throws CardException {
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_READ,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_DEFAULT,
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()), EXPECTED_RESPONSE_LENGTH));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("Read binary file", response.getSW());
        }
        byte[] value = Tlv.findValue(response.getData(), Se05xApdu.TAG_1);
        return value != null ? value : response.getData();
    }

    private void write(String operation, byte[] payload) throws CardException {
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_WRITE,
                Se05xApdu.P1_BINARY, Se05xApdu.P2_DEFAULT, payload, EXPECTED_RESPONSE_LENGTH));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException(operation, response.getSW());
        }
    }

    private static void requireWritableSize(byte[] data) {
        if (data.length == 0) {
            throw new IllegalArgumentException("Binary file needs at least 1 byte");
        }
        if (data.length > MAX_SINGLE_WRITE) {
            throw new IllegalArgumentException(
                    "Data too large for a single write (" + data.length + " > " + MAX_SINGLE_WRITE + " bytes)");
        }
    }

    private static byte[] twoBytes(int value) {
        return new byte[] {(byte) (value >>> 8), (byte) value};
    }
}
