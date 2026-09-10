package org.example.tolutag.cli.write;

import org.example.tolutag.se05x.CurveInitializer;
import org.example.tolutag.se05x.EcKeyPairService;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.se05x.Se05xReader;
import org.example.tolutag.se05x.UserIdService;
import org.example.tolutag.se05x.curve.EcCurve;
import org.example.tolutag.se05x.curve.Secp256k1;
import org.example.tolutag.se05x.policy.EcKeyPolicy;
import org.example.tolutag.smartcard.CardConnection;

import java.nio.charset.StandardCharsets;
import java.util.Scanner;

/**
 * Interactive command-line tool that creates a secp256k1 key pair on the SE05x
 * protected by a PIN.
 *
 * <p>The PIN is held in a UserID Authentication Object; the key's policy is bound
 * to that UserID, so using the key requires a session authenticated with the PIN.
 *
 * <p>Two object ids are supplied: one for the key, one for the user. If the user
 * object already exists, it is reused to protect the key and no PIN is asked -
 * the existing user (and its PIN) is applied.
 */
public final class secp256k1PinProtectCreate {

    private static final int CARD_WAIT_MILLIS = 30_000;
    private static final EcCurve CURVE = Secp256k1.INSTANCE;

    private final Scanner scanner;

    public secp256k1PinProtectCreate(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new secp256k1PinProtectCreate(scanner).run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void run() throws Exception {
        ObjectId keyId = promptObjectId("Object ID to store the secp256k1 key:");
        ObjectId userId = promptObjectId("Object ID to store the user (PIN):");
        if (keyId.equals(userId)) {
            System.out.println("The key and user object ids must be different.");
            return;
        }

        try (CardConnection connection = CardConnection.openFirstTerminal(CARD_WAIT_MILLIS)) {
            connection.selectApplet(Se05xApdu.aid());
            Se05xReader reader = new Se05xReader(connection);

            if (reader.exists(keyId)) {
                System.out.println("Key object " + keyId.toHex()
                        + " already exists - delete it first (deleteObject) or choose another id.");
                return;
            }

            if (reader.exists(userId)) {
                System.out.println("User already exists at " + userId.toHex()
                        + " - reusing it to protect the key (no PIN needed).");
            } else {
                byte[] pin = promptPin();
                new UserIdService(connection).create(userId, pin);
                System.out.println("Created user " + userId.toHex() + " with the given PIN.");
            }

            System.out.println("Initializing " + CURVE.name() + " curve...");
            new CurveInitializer(connection).initialize(CURVE);

            EcKeyPolicy policy = pinBoundPolicy(userId);
            new EcKeyPairService(connection).createProtected(keyId, CURVE, policy);

            System.out.println("\n✓ Created secp256k1 key " + keyId.toHex()
                    + ", protected by user " + userId.toHex() + ".");
            System.out.println("Using this key (sign, read public key) now requires a session "
                    + "authenticated with the PIN.");
        }
    }

    /** Key policy granting the usual EC operations, bound to the UserID's auth id. */
    private static EcKeyPolicy pinBoundPolicy(ObjectId userId) {
        return EcKeyPolicy.builder()
                .authId(userId.toInt())
                .allow(EcKeyPolicy.Permission.SIGN, EcKeyPolicy.Permission.VERIFY,
                        EcKeyPolicy.Permission.KEY_AGREEMENT, EcKeyPolicy.Permission.ENCRYPT,
                        EcKeyPolicy.Permission.DECRYPT, EcKeyPolicy.Permission.GENERATE,
                        EcKeyPolicy.Permission.WRITE, EcKeyPolicy.Permission.READ)
                .build();
    }

    private byte[] promptPin() {
        while (true) {
            System.out.println("Enter a PIN (" + UserIdService.MIN_PIN_LENGTH + " to "
                    + UserIdService.MAX_PIN_LENGTH + " characters):");
            byte[] pin = scanner.nextLine().getBytes(StandardCharsets.UTF_8);
            if (pin.length >= UserIdService.MIN_PIN_LENGTH && pin.length <= UserIdService.MAX_PIN_LENGTH) {
                return pin;
            }
            System.out.println("PIN must be " + UserIdService.MIN_PIN_LENGTH + " to "
                    + UserIdService.MAX_PIN_LENGTH + " bytes.");
        }
    }

    private ObjectId promptObjectId(String prompt) {
        while (true) {
            System.out.println(prompt + " (hex, e.g. 2222 or 58588381):");
            try {
                ObjectId objectId = ObjectId.fromHexPadded(scanner.nextLine());
                System.out.println("Using Object ID: " + objectId.toHex());
                return objectId;
            } catch (IllegalArgumentException e) {
                System.out.println(e.getMessage());
            }
        }
    }
}
