package org.example.tolutag.se05x;

import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * An authenticated SE05x session (spec §4.5). Opening a session against a UserID
 * Authentication Object and verifying its PIN lets you use objects whose policy
 * is bound to that user.
 *
 * <p>Use {@link #channel()} to obtain an {@link Se05xChannel} that runs commands
 * inside the session; {@link #close()} closes it. Implements {@link AutoCloseable}.
 */
public final class Se05xSession implements AutoCloseable {

    private static final int SESSION_ID_LENGTH = 8;

    private final Se05xChannel raw;
    private final byte[] sessionId;
    private final Se05xSessionChannel channel;

    private Se05xSession(Se05xChannel raw, byte[] sessionId) {
        this.raw = raw;
        this.sessionId = sessionId;
        this.channel = new Se05xSessionChannel(raw, sessionId);
    }

    /**
     * Opens a session for a UserID Authentication Object and verifies its PIN.
     *
     * @param raw    the raw (unwrapped) channel to the applet
     * @param userId the UserID object identifier
     * @param pin    the UserID secret
     * @return an open, authenticated session
     * @throws ApduException if the session cannot be created or the PIN is wrong
     * @throws CardException if the transport fails
     */
    public static Se05xSession openUserId(Se05xChannel raw, ObjectId userId, byte[] pin) throws CardException {
        byte[] sessionId = createSession(raw, userId);
        Se05xSession session = new Se05xSession(raw, sessionId);
        session.verifyUserId(pin);
        return session;
    }

    /** @return a channel that runs commands inside this session. */
    public Se05xChannel channel() {
        return channel;
    }

    private static byte[] createSession(Se05xChannel raw, ObjectId userId) throws CardException {
        ResponseAPDU response = raw.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_MGMT,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_SESSION_CREATE,
                Tlv.encode(Se05xApdu.TAG_1, userId.bytes()), SESSION_ID_LENGTH + 4));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("Create session", response.getSW());
        }
        byte[] sessionId = Tlv.findValue(response.getData(), Se05xApdu.TAG_1);
        if (sessionId == null || sessionId.length != SESSION_ID_LENGTH) {
            throw new ApduException("Create session (no session id in response)", Se05xApdu.SW_SUCCESS);
        }
        return sessionId;
    }

    private void verifyUserId(byte[] pin) throws CardException {
        byte[] inner = new CommandAPDU(Se05xApdu.CLA_NO_SM, Se05xApdu.INS_MGMT,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_SESSION_USERID,
                Tlv.encode(Se05xApdu.TAG_1, pin)).getBytes();
        ResponseAPDU response = raw.transmit(Se05xSessionChannel.wrap(sessionId, inner));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("Verify UserID (wrong PIN?)", response.getSW());
        }
    }

    @Override
    public void close() throws CardException {
        byte[] inner = new CommandAPDU(Se05xApdu.CLA_NO_SM, Se05xApdu.INS_MGMT,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_SESSION_CLOSE).getBytes();
        raw.transmit(Se05xSessionChannel.wrap(sessionId, inner));
    }
}
