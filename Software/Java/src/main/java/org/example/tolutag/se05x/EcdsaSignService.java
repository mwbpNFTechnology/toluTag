package org.example.tolutag.se05x;

import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Signs a pre-computed 32-byte digest with an EC key pair on the SE05x and
 * returns the raw ASN.1 DER signature.
 */
public final class EcdsaSignService {

    private static final int EXPECTED_RESPONSE_LENGTH = 256;
    private static final int SEQUENCE_TAG = 0x30;

    private final Se05xChannel channel;

    public EcdsaSignService(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Signs {@code digest} with the key identified by {@code objectId}.
     *
     * @param digest the 32-byte hash to sign
     * @return the DER-encoded {@code SEQUENCE { r, s }} signature
     * @throws ApduException if the card rejects the command or returns no
     *                       recognizable signature
     * @throws CardException if the transport fails
     */
    public byte[] signDigest(ObjectId objectId, byte[] digest) throws CardException {
        byte[] data = Tlv.concat(
                Tlv.encode(Se05xApdu.TAG_1, objectId.bytes()),
                Tlv.encode(Se05xApdu.TAG_2, Se05xApdu.SIG_ECDSA_SHA_256),
                Tlv.encode(Se05xApdu.TAG_3, digest));

        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_CRYPTO,
                Se05xApdu.P1_SIGNATURE, Se05xApdu.P2_SIGN, data, EXPECTED_RESPONSE_LENGTH));

        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("ECDSA sign", response.getSW());
        }

        byte[] der = extractDer(response.getData());
        if (der == null) {
            throw new ApduException("ECDSA sign (no DER signature in response)", Se05xApdu.SW_SUCCESS);
        }
        return der;
    }

    /**
     * Extracts the DER signature from the response: either the value of a
     * leading {@code 0x41} TLV, or the first embedded ASN.1 SEQUENCE.
     */
    private static byte[] extractDer(byte[] response) {
        if (response.length >= 2 && response[0] == Se05xApdu.TAG_1) {
            int length;
            int offset;
            if (response[1] == (byte) 0x82 && response.length >= 4) {
                length = ((response[2] & 0xFF) << 8) | (response[3] & 0xFF);
                offset = 4;
            } else {
                length = response[1] & 0xFF;
                offset = 2;
            }
            if (response.length >= offset + length) {
                byte[] signature = new byte[length];
                System.arraycopy(response, offset, signature, 0, length);
                return signature;
            }
        }

        // Fallback: find the ASN.1 SEQUENCE (0x30) that begins a DER signature.
        for (int i = 0; i + 1 < response.length; i++) {
            if ((response[i] & 0xFF) == SEQUENCE_TAG) {
                int seqLength = response[i + 1] & 0xFF;
                if (i + 2 + seqLength <= response.length) {
                    byte[] signature = new byte[seqLength + 2];
                    System.arraycopy(response, i, signature, 0, seqLength + 2);
                    return signature;
                }
            }
        }
        return null;
    }
}
