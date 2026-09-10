package org.example.tolutag.se05x;

import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * An {@link Se05xChannel} that runs every command inside an SE05x session by
 * wrapping it in a ProcessSessionCmd (spec §4.5.1.3).
 *
 * <p>Because ProcessSessionCmd returns the inner command's response body and
 * status word verbatim, the existing services (signer, reader, ...) work through
 * an authenticated session without any change - construct them with this channel
 * instead of the raw {@link org.example.tolutag.smartcard.CardConnection}.
 */
public final class Se05xSessionChannel implements Se05xChannel {

    private static final int EXPECTED_RESPONSE_LENGTH = 256;

    private final Se05xChannel raw;
    private final byte[] sessionId;

    Se05xSessionChannel(Se05xChannel raw, byte[] sessionId) {
        this.raw = raw;
        this.sessionId = sessionId;
    }

    @Override
    public ResponseAPDU transmit(CommandAPDU command) throws CardException {
        return raw.transmit(wrap(sessionId, command.getBytes()));
    }

    /** Wraps a full inner APDU as a ProcessSessionCmd for the given session. */
    static CommandAPDU wrap(byte[] sessionId, byte[] innerApdu) {
        byte[] payload = Tlv.concat(
                Tlv.encode(Se05xApdu.TAG_SESSION_ID, sessionId),
                Tlv.encode(Se05xApdu.TAG_1, innerApdu));
        return new CommandAPDU(Se05xApdu.CLA_NO_SM, Se05xApdu.INS_PROCESS,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_DEFAULT, payload, EXPECTED_RESPONSE_LENGTH);
    }
}
