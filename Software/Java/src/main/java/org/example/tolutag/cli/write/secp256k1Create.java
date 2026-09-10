package org.example.tolutag.cli.write;

import org.example.tolutag.se05x.CurveInitializer;
import org.example.tolutag.se05x.EcKeyPairService;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.se05x.curve.EcCurve;
import org.example.tolutag.se05x.curve.Secp256k1;
import org.example.tolutag.se05x.policy.EcKeyPolicy;
import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.CardConnection;
import org.example.tolutag.util.Hex;

import java.util.Scanner;

/**
 * Interactive command-line tool that provisions a protected secp256k1 key pair
 * on an NXP SE05x secure element for the toluTag project.
 *
 * <p>This is an application entry point; the domain logic lives in the
 * {@code smartcard} and {@code se05x} packages.
 */
public final class secp256k1Create {

    private static final int CARD_WAIT_MILLIS = 30_000;
    private static final EcCurve CURVE = Secp256k1.INSTANCE;

    private final Scanner scanner;

    public secp256k1Create(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new secp256k1Create(scanner).run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /** Runs the full interactive provisioning flow. */
    public void run() throws Exception {
        ObjectId objectId = promptObjectId();
        boolean protect = promptYesNo("\nCreate deletion-protected key? (y/n):");

        try (CardConnection connection = CardConnection.openFirstTerminal(CARD_WAIT_MILLIS)) {
            connection.selectApplet(Se05xApdu.aid());
            System.out.println("Applet selected");

            provisionKey(connection, objectId, protect);
            readAndPrintPublicKey(connection, objectId);
        }
    }

    private void provisionKey(CardConnection connection, ObjectId objectId, boolean protect) throws Exception {
        System.out.println("Initializing " + CURVE.name() + " curve...");
        if (new CurveInitializer(connection).initialize(CURVE)) {
            System.out.println("✓ " + CURVE.name() + " curve initialized");
        } else {
            System.out.println("⚠️ Some curve parameters failed to set, but proceeding...");
        }

        EcKeyPairService keyService = new EcKeyPairService(connection);
        boolean created = false;
        if (protect) {
            System.out.println("Creating protected key...");
            try {
                keyService.createProtected(objectId, CURVE, EcKeyPolicy.deletionProtected());
                System.out.println("✓ Protected key created");
                created = true;
            } catch (ApduException e) {
                System.err.println(e.getMessage() + " - falling back to a standard key");
            }
        }

        if (!created) {
            System.out.println("Creating standard key...");
            keyService.createStandard(objectId, CURVE);
            System.out.println("✓ Key created");
        }
    }

    private void readAndPrintPublicKey(CardConnection connection, ObjectId objectId) throws Exception {
        byte[] publicKey = new EcKeyPairService(connection).readPublicKey(objectId);
        System.out.println("Pub: " + Hex.toHex(publicKey));
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Enter Object ID (8 hex chars, e.g. 58588381):");
            try {
                ObjectId objectId = ObjectId.fromHex(scanner.nextLine());
                System.out.println("Using Object ID: " + objectId.toHex());
                return objectId;
            } catch (IllegalArgumentException e) {
                System.out.println(e.getMessage());
            }
        }
    }

    private boolean promptYesNo(String prompt) {
        System.out.println(prompt);
        return scanner.nextLine().trim().equalsIgnoreCase("y");
    }
}
