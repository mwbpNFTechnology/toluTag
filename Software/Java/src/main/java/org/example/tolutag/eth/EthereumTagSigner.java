package org.example.tolutag.eth;

import org.example.tolutag.crypto.DerEcdsaSignature;
import org.example.tolutag.se05x.EcdsaSignService;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xReader;
import org.example.tolutag.se05x.curve.CurveParameter;
import org.example.tolutag.se05x.curve.Secp256k1;
import org.example.tolutag.smartcard.Se05xChannel;
import org.example.tolutag.util.Hex;

import javax.smartcardio.CardException;
import java.math.BigInteger;

/**
 * High-level Ethereum operations backed by a secp256k1 key on the SE05x:
 * deriving the chip's address, reading its unique id, and producing EIP-191
 * {@code personal_sign} signatures.
 *
 * <p>All operations reuse the single {@link Se05xChannel} passed to the
 * constructor.
 */
public final class EthereumTagSigner {

    /**
     * Recovery id used for the signature. The SE05x returns only {@code r} and
     * {@code s}; Ethereum needs {@code v} to recover the signer. This is fixed
     * to 28, matching the toluTag reference pipeline. (A future improvement is
     * to recover {@code v} by trying 27/28 and comparing against the chip's
     * known address.)
     */
    private static final int RECOVERY_ID = 28;

    private static final int UNIQUE_ID_HEX_LENGTH = 40;

    private final Se05xReader reader;
    private final EcdsaSignService signService;
    private final BigInteger curveOrder;

    public EthereumTagSigner(Se05xChannel channel) {
        this.reader = new Se05xReader(channel);
        this.signService = new EcdsaSignService(channel);
        this.curveOrder = new BigInteger(1, Secp256k1.INSTANCE.parameter(CurveParameter.N));
    }

    /**
     * @return the Ethereum address derived from the key pair's public point.
     */
    public EthereumAddress address(ObjectId objectId) throws CardException {
        return EthereumAddress.fromPublicKey(reader.readPublicKeyPoint(objectId));
    }

    /**
     * @return the chip's factory unique id as a {@code 0x}-prefixed, 40-hex-char
     *         string (left-padded with zeros).
     */
    public String uniqueId() throws CardException {
        String hex = Hex.toHex(reader.readUniqueId());
        if (hex.length() < UNIQUE_ID_HEX_LENGTH) {
            hex = "0".repeat(UNIQUE_ID_HEX_LENGTH - hex.length()) + hex;
        }
        return "0x" + hex;
    }

    /**
     * Signs {@code message} as an EIP-191 personal-sign message.
     *
     * @param objectId the key to sign with
     * @param message  the message text
     * @return the Ethereum-format signature
     */
    public EthereumSignature signPersonalMessage(ObjectId objectId, String message) throws CardException {
        byte[] hash = Eip191.personalMessageHash(message);
        byte[] der = signService.signDigest(objectId, hash);
        DerEcdsaSignature signature = DerEcdsaSignature.parse(der);
        return EthereumSignature.from(signature, curveOrder, hash, RECOVERY_ID);
    }
}
