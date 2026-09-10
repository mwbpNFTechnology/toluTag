package org.example.tolutag.cli.write;

import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.ObjectManagementService;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.se05x.Se05xReader;
import org.example.tolutag.smartcard.CardConnection;

import java.util.Scanner;

/**
 * Interactive command-line tool that deletes a Secure Object by its identifier.
 *
 * <p>Deletion is irreversible, so the tool confirms first. Objects created with
 * deletion protection (no {@code ALLOW_DELETE} in their policy) cannot be
 * removed; the card refuses and the tool reports it.
 */
public final class deleteObject {

    private static final int CARD_WAIT_MILLIS = 30_000;

    private final Scanner scanner;

    public deleteObject(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new deleteObject(scanner).run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void run() throws Exception {
        ObjectId objectId = promptObjectId();

        try (CardConnection connection = CardConnection.openFirstTerminal(CARD_WAIT_MILLIS)) {
            connection.selectApplet(Se05xApdu.aid());

            if (!new Se05xReader(connection).exists(objectId)) {
                System.out.println("No object with id " + objectId.toHex() + " - nothing to delete.");
                return;
            }

            if (!promptYesNo("Delete object " + objectId.toHex() + "? This is irreversible. (y/n):")) {
                System.out.println("Cancelled.");
                return;
            }

            boolean deleted = new ObjectManagementService(connection).delete(objectId);
            System.out.println(deleted
                    ? "✓ Deleted " + objectId.toHex()
                    : "✗ Delete refused - object is deletion-protected.");
        }
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Enter the Object ID to delete (hex, e.g. 2222 or 58588381):");
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
