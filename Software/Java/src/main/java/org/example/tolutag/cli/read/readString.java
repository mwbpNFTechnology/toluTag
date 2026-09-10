package org.example.tolutag.cli.read;

import org.example.tolutag.se05x.BinaryFileService;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.smartcard.CardConnection;
import org.example.tolutag.util.Hex;

import java.nio.charset.StandardCharsets;
import java.util.Scanner;

/**
 * Interactive command-line tool that reads back the string stored in an SE05x
 * BinaryFile object (written with {@code writeString}).
 */
public final class readString {

    private static final int CARD_WAIT_MILLIS = 30_000;

    private final Scanner scanner;

    public readString(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new readString(scanner).run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void run() throws Exception {
        ObjectId objectId = promptObjectId();

        try (CardConnection connection = CardConnection.openFirstTerminal(CARD_WAIT_MILLIS)) {
            connection.selectApplet(Se05xApdu.aid());

            byte[] data = new BinaryFileService(connection).read(objectId);
            System.out.println("Length: " + data.length + " bytes");
            System.out.println("Hex:    0x" + Hex.toHex(data));
            System.out.println("String: " + new String(data, StandardCharsets.UTF_8));
        }
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Enter the Object ID to read (hex, e.g. 2222 or 58588381):");
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
