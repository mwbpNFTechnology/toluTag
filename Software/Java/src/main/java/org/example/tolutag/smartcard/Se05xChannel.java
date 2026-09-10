package org.example.tolutag.smartcard;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Abstraction over a transport that can exchange APDUs with a smart card.
 *
 * <p>Depending on this interface rather than a concrete {@code CardChannel}
 * keeps the SE05x service classes decoupled from the transport, which makes
 * them straightforward to unit-test with a fake channel.
 */
public interface Se05xChannel {

    /**
     * Sends a command APDU and returns the card's response.
     *
     * @param command the command to transmit
     * @return the response APDU
     * @throws CardException if the transport fails
     */
    ResponseAPDU transmit(CommandAPDU command) throws CardException;
}
