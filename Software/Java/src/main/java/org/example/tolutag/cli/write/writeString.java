package org.example.tolutag.cli.write;

import org.example.tolutag.se05x.BinaryFileService;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.se05x.Se05xReader;
import org.example.tolutag.se05x.policy.EcKeyPolicy;
import org.example.tolutag.smartcard.CardConnection;

import java.nio.charset.StandardCharsets;
import java.util.Scanner;

/**
 * Interactive command-line tool that stores a plain string in an SE05x
 * BinaryFile object under a chosen object id, optionally protected from deletion.
 *
 * <p>Read it back with {@code readString}.
 */
public final class writeString {

    private static final int CARD_WAIT_MILLIS = 30_000;

    private final Scanner scanner;

    public writeString(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new writeString(scanner).run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void run() throws Exception {
        ObjectId objectId = promptObjectId();

        System.out.println("Enter the string to store:");
        byte[] data = scanner.nextLine().getBytes(StandardCharsets.UTF_8);
        if (data.length == 0) {
            System.out.println("Nothing to write - empty string.");
            return;
        }
        if (data.length > BinaryFileService.MAX_SINGLE_WRITE) {
            System.out.println("String is too long (" + data.length + " bytes, max "
                    + BinaryFileService.MAX_SINGLE_WRITE + ").");
            return;
        }

        boolean protect = promptYesNo("Protect this object from deletion? (y/n):");

        try (CardConnection connection = CardConnection.openFirstTerminal(CARD_WAIT_MILLIS)) {
            connection.selectApplet(Se05xApdu.aid());

            BinaryFileService files = new BinaryFileService(connection);
            boolean exists = new Se05xReader(connection).exists(objectId);

            if (exists) {
                System.out.println("Object " + objectId.toHex()
                        + " already exists - updating its contents (deletion protection is fixed at creation).");
                files.update(objectId, data);
            } else {
                files.create(objectId, data, policyFor(protect));
                System.out.println("Created " + objectId.toHex()
                        + (protect ? " (deletion-protected)." : " (deletable)."));
            }
            System.out.println("✓ Wrote " + data.length + " bytes.");
        }
    }

    private static EcKeyPolicy policyFor(boolean protect) {
        EcKeyPolicy.Builder builder = EcKeyPolicy.builder()
                .allow(EcKeyPolicy.Permission.READ, EcKeyPolicy.Permission.WRITE);
        if (!protect) {
            builder.allow(EcKeyPolicy.Permission.DELETE);
        }
        return builder.build();
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Enter the Object ID (hex, e.g. 2222 or 58588381):");
            try {
                ObjectId objectId = ObjectId.fromHexPadded(scanner.nextLine());
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
