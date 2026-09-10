package org.example.tolutag.cli.read;

import org.example.tolutag.eth.EthereumAddress;
import org.example.tolutag.se05x.ObjectAttributes;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Origin;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.se05x.Se05xInfoService;
import org.example.tolutag.se05x.Se05xReader;
import org.example.tolutag.se05x.SecureObjectType;
import org.example.tolutag.se05x.Se05xSession;
import org.example.tolutag.se05x.VersionInfo;
import org.example.tolutag.cli.PinSession;
import org.example.tolutag.smartcard.CardConnection;
import org.example.tolutag.smartcard.Se05xChannel;
import org.example.tolutag.util.Hex;

import java.util.Arrays;
import java.util.List;
import java.util.Scanner;

/**
 * Interactive command-line tool that scans an SE05x chip and a specific object,
 * reporting as many parameters as the applet exposes: chip unique id / version /
 * free memory, and per-object existence, type, size, origin (generated on-chip
 * vs imported), policy and - for EC keys - the public point and Ethereum address.
 *
 * <p>Every read is independent and best-effort: if one command is rejected (for
 * example the object lacks {@code ALLOW_READ}), the tool notes it and continues.
 */
public final class scanDetails {

    private static final int CARD_WAIT_MILLIS = 30_000;
    private static final int FREE_MEMORY_SATURATED = 0x7FFF;

    private final Scanner scanner;

    public scanDetails(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new scanDetails(scanner).run();
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
                printChipDetails(channel);
                printObjectDetails(channel, objectId);
            } finally {
                if (session != null) {
                    session.close();
                }
            }
        }
    }

    private void printChipDetails(Se05xChannel channel) {
        System.out.println("\n=== CHIP DETAILS ===");
        Se05xReader reader = new Se05xReader(channel);
        Se05xInfoService info = new Se05xInfoService(channel);

        try {
            System.out.println("Unique ID: 0x" + Hex.toHex(reader.readUniqueId()));
        } catch (Exception e) {
            System.out.println("Unique ID: unavailable (" + e.getMessage() + ")");
        }

        try {
            VersionInfo version = info.getVersion();
            System.out.println("Applet version (raw): 0x" + version.rawHex());
            System.out.println("Applet version (best-effort): " + version.versionString());
            System.out.println("Secure box version (best-effort): " + version.secureBoxVersion());
            List<String> features = version.features();
            System.out.println("Features: " + (features.isEmpty() ? "-" : String.join(", ", features)));
        } catch (Exception e) {
            System.out.println("Applet version: unavailable (" + e.getMessage() + ")");
        }

        printFreeMemory(info, "Persistent free memory", Se05xApdu.MEM_PERSISTENT);
        printFreeMemory(info, "Transient reset free memory", Se05xApdu.MEM_TRANSIENT_RESET);
        printFreeMemory(info, "Transient deselect free memory", Se05xApdu.MEM_TRANSIENT_DESELECT);
    }

    private void printFreeMemory(Se05xInfoService info, String label, byte memoryType) {
        try {
            int free = info.getFreeMemory(memoryType);
            String suffix = (free == FREE_MEMORY_SATURATED) ? " (>= 32768)" : "";
            System.out.println(label + ": " + free + " bytes" + suffix);
        } catch (Exception e) {
            System.out.println(label + ": unavailable (" + e.getMessage() + ")");
        }
    }

    private void printObjectDetails(Se05xChannel channel, ObjectId objectId) {
        System.out.println("\n=== OBJECT DETAILS (" + objectId.toHex() + ") ===");
        Se05xReader reader = new Se05xReader(channel);

        try {
            System.out.println("Exists: " + reader.exists(objectId));
        } catch (Exception e) {
            System.out.println("Exists: unknown (" + e.getMessage() + ")");
        }

        Integer typeByte = null;
        try {
            typeByte = reader.readType(objectId);
            System.out.printf("Type: %s (0x%02X)%n", SecureObjectType.describe(typeByte), typeByte);
        } catch (Exception e) {
            System.out.println("Type: unavailable (" + e.getMessage() + ")");
        }

        try {
            System.out.println("Size: " + reader.readSize(objectId) + " bytes");
        } catch (Exception e) {
            System.out.println("Size: unavailable (" + e.getMessage() + ")");
        }

        printAttributes(reader, objectId, typeByte);
        printPublicKey(reader, objectId);
    }

    private void printAttributes(Se05xReader reader, ObjectId objectId, Integer typeByte) {
        try {
            ObjectAttributes attributes = reader.readAttributes(objectId);
            Origin origin = attributes.origin();
            System.out.println("Origin: " + origin + " - " + origin.description());
            System.out.println("Authentication object: " + attributes.isAuthenticationObject());
            System.out.println("Version attribute: " + attributes.version());
            System.out.println("Policy (raw): 0x" + Hex.toHex(attributes.policy()));
            System.out.println("Attributes (raw): 0x" + attributes.rawHex());

            // Validate the assumed attribute layout against independent reads.
            if (!Arrays.equals(attributes.objectIdentifier(), objectId.bytes())) {
                System.out.println("  ⚠️ attributes object id does not match - origin may be unreliable");
            }
            if (typeByte != null && attributes.typeByte() != typeByte) {
                System.out.println("  ⚠️ attributes type byte differs from ReadType - layout may be misread");
            }
        } catch (Exception e) {
            System.out.println("Origin/attributes: unavailable (" + e.getMessage() + ")");
        }
    }

    private void printPublicKey(Se05xReader reader, ObjectId objectId) {
        try {
            byte[] point = reader.readPublicKeyPoint(objectId);
            System.out.println("Public key: 0x" + Hex.toHex(point));
            System.out.println("Ethereum address: " + EthereumAddress.fromPublicKey(point).hex());
        } catch (Exception e) {
            System.out.println("Public key: unavailable (" + e.getMessage() + ")");
        }
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Enter the Object ID to scan (in hex format, e.g. 2222 or 58588381):");
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
