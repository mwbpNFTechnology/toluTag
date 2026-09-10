package org.example.tolutag.eth;

import org.example.tolutag.crypto.DerEcdsaSignature;
import org.example.tolutag.crypto.Secp256k1Recovery;
import org.example.tolutag.se05x.EcdsaSignService;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xReader;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import java.math.BigInteger;
import java.util.Arrays;

/**
 * Signs a 32-byte digest with a secp256k1 key on the SE05x and returns a
 * complete Ethereum signature whose recovery id {@code v} is <em>recovered</em>,
 * not assumed: the chip returns only {@code r}/{@code s}, so each candidate
 * {@code v} is tried and the one that recovers to the chip's own public key wins.
 *
 * <p>Suitable for any pre-computed digest - EIP-712 typed data, EIP-191, or a
 * raw hash.
 */
public final class Eip712TagSigner {

    private static final BigInteger CURVE_ORDER = Secp256k1Recovery.CURVE_ORDER;

    private final Se05xReader reader;
    private final EcdsaSignService signService;

    public Eip712TagSigner(Se05xChannel channel) {
        this.reader = new Se05xReader(channel);
        this.signService = new EcdsaSignService(channel);
    }

    /** @return the chip's uncompressed public point ({@code 0x04||X||Y}). */
    public byte[] publicKeyPoint(ObjectId objectId) throws CardException {
        return reader.readPublicKeyPoint(objectId);
    }

    /** @return the chip's Ethereum address. */
    public EthereumAddress address(ObjectId objectId) throws CardException {
        return EthereumAddress.fromPublicKey(publicKeyPoint(objectId));
    }

    /**
     * Signs {@code digest} and returns an Ethereum signature with a recovered
     * {@code v}.
     *
     * @param objectId the signing key
     * @param digest   the 32-byte digest to sign
     * @return the Ethereum signature (r, s low form, recovered v, digest)
     * @throws IllegalStateException if neither recovery id reproduces the key
     */
    public EthereumSignature signDigest(ObjectId objectId, byte[] digest) throws CardException {
        byte[] chipPoint = publicKeyPoint(objectId);
        byte[] der = signService.signDigest(objectId, digest);

        DerEcdsaSignature parsed = DerEcdsaSignature.parse(der);
        DerEcdsaSignature low = parsed.normalizeLowS(CURVE_ORDER);
        int v = recoverV(low.r(), low.s(), digest, chipPoint);

        return EthereumSignature.from(parsed, CURVE_ORDER, digest, v);
    }

    private static int recoverV(BigInteger r, BigInteger s, byte[] digest, byte[] chipPoint) {
        for (int recId = 0; recId < 2; recId++) {
            byte[] recovered = Secp256k1Recovery.recoverPublicKey(recId, r, s, digest);
            if (recovered != null && Arrays.equals(recovered, chipPoint)) {
                return recId + 27;
            }
        }
        throw new IllegalStateException(
                "Neither recovery id reproduces the chip's public key - signature does not match this key");
    }
}
