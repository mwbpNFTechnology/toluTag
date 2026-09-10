package org.example.tolutag.smartcard;

import javax.smartcardio.Card;
import javax.smartcardio.CardChannel;
import javax.smartcardio.CardException;
import javax.smartcardio.CardTerminal;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;
import javax.smartcardio.TerminalFactory;
import java.util.List;

/**
 * A PC/SC connection to a single smart card, exposed as an {@link Se05xChannel}.
 *
 * <p>Handles terminal discovery, waiting for card insertion, and applet
 * selection. Implements {@link AutoCloseable} so it can be used in a
 * try-with-resources block.
 */
public final class CardConnection implements Se05xChannel, AutoCloseable {

    private static final int STATUS_OK = 0x9000;

    private final Card card;
    private final CardChannel channel;

    private CardConnection(Card card, CardChannel channel) {
        this.card = card;
        this.channel = channel;
    }

    /**
     * Opens a connection to the first available terminal, waiting up to
     * {@code waitMillis} for a card to be inserted if none is present.
     *
     * @param waitMillis how long to wait for a card, in milliseconds
     * @return an open connection
     * @throws CardException if no terminal is available or the connection fails
     */
    public static CardConnection openFirstTerminal(int waitMillis) throws CardException {
        TerminalFactory factory = TerminalFactory.getDefault();
        List<CardTerminal> terminals = factory.terminals().list();
        if (terminals.isEmpty()) {
            throw new CardException("No smart-card terminal found");
        }
        CardTerminal terminal = terminals.get(0);
        if (!terminal.isCardPresent()) {
            if (!terminal.waitForCardPresent(waitMillis)) {
                throw new CardException("Timed out waiting for a card in " + terminal.getName());
            }
        }
        Card card = terminal.connect("*");
        return new CardConnection(card, card.getBasicChannel());
    }

    /**
     * Selects an applet by its AID.
     *
     * @param aid the application identifier
     * @throws ApduException if the card rejects the selection
     * @throws CardException if the transport fails
     */
    public void selectApplet(byte[] aid) throws CardException {
        ResponseAPDU response = transmit(new CommandAPDU(0x00, 0xA4, 0x04, 0x00, aid));
        if (response.getSW() != STATUS_OK) {
            throw new ApduException("Select applet", response.getSW());
        }
    }

    @Override
    public ResponseAPDU transmit(CommandAPDU command) throws CardException {
        return channel.transmit(command);
    }

    @Override
    public void close() throws CardException {
        card.disconnect(false);
    }
}
