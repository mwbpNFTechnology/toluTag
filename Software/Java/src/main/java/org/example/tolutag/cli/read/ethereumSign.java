package org.example.tolutag.cli.read;

import org.example.tolutag.eth.EthereumAddress;
import org.example.tolutag.eth.EthereumSignature;
import org.example.tolutag.eth.EthereumTagSigner;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.se05x.Se05xSession;
import org.example.tolutag.cli.PinSession;
import org.example.tolutag.smartcard.CardConnection;
import org.example.tolutag.smartcard.Se05xChannel;

import java.util.Scanner;

/**
 * Interactive command-line tool that signs an EIP-191 message with a
 * secp256k1 key on the SE05x, producing the {@code r}/{@code s}/{@code v} values
 * and message hash needed for on-chain Ethereum verification.
 *
 * <p>Two modes are offered:
 * <ul>
 *   <li><b>toluTag template</b> — signs {@code <address>_<uniqueId>_<timestamp>},
 *       where {@code <address>} is the chip's own address or a caller-supplied
 *       {@code msg.sender}.</li>
 *   <li><b>Custom message</b> — signs any text the user enters verbatim.</li>
 * </ul>
 */
public final class ethereumSign {

    private static final int CARD_WAIT_MILLIS = 30_000;

    private final Scanner scanner;

    public ethereumSign(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new ethereumSign(scanner).run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void run() throws Exception {
        ObjectId objectId = promptObjectId();

        try (CardConnection connection = CardConnection.openFirstTerminal(CARD_WAIT_MILLIS)) {
            connection.selectApplet(Se05xApdu.aid());

            Se05xSession session = PinSession.promptAndOpen(scanner, connection);
            Se05xChannel channel = (session != null) ? session.channel() : connection;
            try {
                EthereumTagSigner signer = new EthereumTagSigner(channel);
                EthereumAddress chipAddress = signer.address(objectId);

                if (promptYesNo("\nSign a custom message instead of the toluTag template? (y/n):")) {
                    signCustomMessage(signer, objectId, chipAddress);
                } else {
                    signTemplateMessage(signer, objectId, chipAddress);
                }
            } finally {
                if (session != null) {
                    session.close();
                }
            }
        }
    }

    private void signCustomMessage(EthereumTagSigner signer, ObjectId objectId, EthereumAddress chipAddress)
            throws Exception {
        String message = promptMessage();
        EthereumSignature signature = signer.signPersonalMessage(objectId, message);

        System.out.println("\n=== ETHEREUM VERIFICATION DATA ===");
        System.out.println("Chip's Ethereum Address: " + chipAddress.hex());
        System.out.println("Message: " + message);
        printSignature(signature);
    }

    private void signTemplateMessage(EthereumTagSigner signer, ObjectId objectId, EthereumAddress chipAddress)
            throws Exception {
        String uniqueId = signer.uniqueId();
        String timestamp = String.valueOf(System.currentTimeMillis() / 1000);
        System.out.println("Current timestamp: " + timestamp);

        System.out.println("Should need a msg.sender? "
                + "(leave empty to use chip's public key address, or enter custom address):");
        String msgSender = scanner.nextLine().trim();

        String addressUsed;
        if (msgSender.isEmpty()) {
            addressUsed = chipAddress.hex();
            System.out.println("Using chip's public key address: " + addressUsed);
        } else {
            addressUsed = msgSender;
            System.out.println("Using custom msg.sender: " + msgSender);
        }

        String message = addressUsed + "_" + uniqueId + "_" + timestamp;
        EthereumSignature signature = signer.signPersonalMessage(objectId, message);

        System.out.println("\n=== ETHEREUM VERIFICATION DATA ===");
        System.out.println("Chip's Ethereum Address: " + chipAddress.hex());
        if (!msgSender.isEmpty()) {
            System.out.println("Custom msg.sender used: " + msgSender);
        }
        System.out.println("Address used in message: " + addressUsed);
        System.out.println("Message: " + message);
        System.out.println("Timestamp: " + timestamp);
        System.out.println("Unique ID: " + uniqueId);
        printSignature(signature);
    }

    private void printSignature(EthereumSignature signature) {
        System.out.println("r: 0x" + signature.r());
        System.out.println("s: 0x" + signature.s());
        System.out.println("v: " + signature.v());
        System.out.println("messageHash: 0x" + signature.messageHash());
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Enter the Object ID for the secp256k1 key "
                    + "(in hex format, e.g. 2222 or 58588381):");
            try {
                ObjectId objectId = ObjectId.fromHexPadded(scanner.nextLine());
                System.out.println("Using Object ID: " + objectId.toHex());
                return objectId;
            } catch (IllegalArgumentException e) {
                System.out.println(e.getMessage());
            }
        }
    }

    private String promptMessage() {
        while (true) {
            System.out.println("Enter the message to sign:");
            String message = scanner.nextLine();
            if (!message.isEmpty()) {
                return message;
            }
            System.out.println("Message cannot be empty.");
        }
    }

    private boolean promptYesNo(String prompt) {
        System.out.println(prompt);
        return scanner.nextLine().trim().equalsIgnoreCase("y");
    }
}
