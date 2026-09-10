package org.example.tolutag.se05x;

import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Reads objects and their metadata from the SE05x: the public point of an EC key
 * pair, the chip's unique id, and per-object type / size / attributes, plus an
 * existence check.
 */
public final class Se05xReader {

    private static final int EXPECTED_RESPONSE_LENGTH = 256;
    private static final byte UNCOMPRESSED_POINT_PREFIX = 0x04;
    private static final int UNCOMPRESSED_POINT_LENGTH = 65; // 0x04 + X(32) + Y(32)

    private final Se05xChannel channel;

    public Se05xReader(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Reads the public key of an EC key pair and returns its 65-byte
     * uncompressed point ({@code 0x04 || X || Y}).
     *
     * @throws ApduException if the card rejects the read or no point is found
     * @throws CardException if the transport fails
     */
    public byte[] readPublicKeyPoint(ObjectId objectId) throws CardException {
        byte[] response = transmit("Read public key", Se05xApdu.INS_READ, Se05xApdu.P2_DEFAULT,
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()));
        byte[] point = extractUncompressedPoint(response);
        if (point == null) {
            throw new ApduException("Read public key (no EC point in response)", Se05xApdu.SW_SUCCESS);
        }
        return point;
    }

    /**
     * Reads the chip's factory unique identifier (the value bytes only).
     */
    public byte[] readUniqueId() throws CardException {
        byte[] response = transmit("Read unique ID", Se05xApdu.INS_READ, Se05xApdu.P2_DEFAULT,
                Tlv.encode(Se05xApdu.TAG_1, Se05xApdu.RESERVED_ID_UNIQUE_ID));
        return valueOrWhole(response, Se05xApdu.TAG_1);
    }

    /**
     * @return {@code true} if an object with this identifier exists on the chip.
     */
    public boolean exists(ObjectId objectId) throws CardException {
        byte[] response = transmit("Check object exists", Se05xApdu.INS_MGMT, Se05xApdu.P2_EXIST,
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()));
        byte[] result = Tlv.findValue(response, Se05xApdu.TAG_1);
        return result != null && result.length == 1 && result[0] == Se05xApdu.RESULT_SUCCESS;
    }

    /**
     * @return the object's type byte (decode with {@link SecureObjectType}).
     */
    public int readType(ObjectId objectId) throws CardException {
        byte[] response = transmit("Read type", Se05xApdu.INS_READ, Se05xApdu.P2_TYPE,
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()));
        byte[] type = Tlv.findValue(response, Se05xApdu.TAG_1);
        if (type == null || type.length == 0) {
            throw new ApduException("Read type (missing type in response)", Se05xApdu.SW_SUCCESS);
        }
        return type[0] & 0xFF;
    }

    /**
     * @return the object's size in bytes (for EC keys, the curve size).
     */
    public int readSize(ObjectId objectId) throws CardException {
        byte[] response = transmit("Read size", Se05xApdu.INS_READ, Se05xApdu.P2_SIZE,
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()));
        byte[] size = Tlv.findValue(response, Se05xApdu.TAG_1);
        if (size == null || size.length == 0) {
            throw new ApduException("Read size (missing size in response)", Se05xApdu.SW_SUCCESS);
        }
        int value = 0;
        for (byte b : size) {
            value = (value << 8) | (b & 0xFF);
        }
        return value;
    }

    /**
     * Reads the object's attribute buffer (no attestation), which carries the
     * {@link Origin} among other fields.
     */
    public ObjectAttributes readAttributes(ObjectId objectId) throws CardException {
        byte[] response = transmit("Read attributes", Se05xApdu.INS_READ, Se05xApdu.P2_ATTRIBUTES,
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()));
        byte[] attributes = Tlv.findValue(response, Se05xApdu.TAG_3);
        if (attributes == null) {
            throw new ApduException("Read attributes (missing attributes in response)", Se05xApdu.SW_SUCCESS);
        }
        return ObjectAttributes.parse(attributes);
    }

    private byte[] transmit(String operation, byte ins, byte p2, byte[] data) throws CardException {
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, ins, Se05xApdu.P1_DEFAULT, p2, data, EXPECTED_RESPONSE_LENGTH));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException(operation, response.getSW());
        }
        return response.getData();
    }

    /** Returns the value of the given tag, or the whole buffer if no such TLV. */
    private static byte[] valueOrWhole(byte[] response, byte tag) {
        byte[] value = Tlv.findValue(response, tag);
        return value != null ? value : response;
    }

    /** Locates the 65-byte uncompressed EC point within a read response. */
    private static byte[] extractUncompressedPoint(byte[] response) {
        for (int i = 0; i + UNCOMPRESSED_POINT_LENGTH <= response.length; i++) {
            if (response[i] == UNCOMPRESSED_POINT_PREFIX) {
                byte[] point = new byte[UNCOMPRESSED_POINT_LENGTH];
                System.arraycopy(response, i, point, 0, UNCOMPRESSED_POINT_LENGTH);
                return point;
            }
        }
        return null;
    }
}
