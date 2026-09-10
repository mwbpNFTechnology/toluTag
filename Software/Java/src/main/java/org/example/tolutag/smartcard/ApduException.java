package org.example.tolutag.smartcard;

import javax.smartcardio.CardException;

/**
 * Thrown when a smart-card command returns a status word other than the one
 * expected (typically {@code 0x9000} for success).
 *
 * <p>Extends {@link CardException} so that it flows naturally through the same
 * {@code throws} clauses as the underlying {@code javax.smartcardio} API.
 */
public class ApduException extends CardException {

    private static final long serialVersionUID = 1L;

    private final int statusWord;

    /**
     * @param operation  human-readable description of the failed operation
     * @param statusWord the status word (SW1||SW2) returned by the card
     */
    public ApduException(String operation, int statusWord) {
        super(String.format("%s failed, SW=0x%04X", operation, statusWord & 0xFFFF));
        this.statusWord = statusWord & 0xFFFF;
    }

    /** @return the raw status word returned by the card. */
    public int statusWord() {
        return statusWord;
    }
}
