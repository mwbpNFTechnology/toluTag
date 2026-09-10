package org.example.tolutag.cli.read;

import org.example.tolutag.eth.EthereumAddress;
import org.example.tolutag.eth.EthereumTagSigner;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.smartcard.CardConnection;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Scanner;
import java.util.Set;

/**
 * Interactive command-line tool that builds a list of Ethereum addresses across
 * many tags. For each tag placed on the reader it reads the key at a chosen
 * object id, derives the address, reads the chip unique id, and records an entry
 * in a chosen phrase format. Duplicate tags (same unique id) are rejected, and
 * the whole list is written out as JSON.
 */
public final class collectTags {

    private static final int CARD_WAIT_MILLIS = 30_000;
    private static final String DEFAULT_OUTPUT = "tags.json";

    /** The third component of each phrase. */
    private enum PhraseFormat {
        TIMESTAMP("address_tagId_timestamp"),
        ZERO("address_tagId_0"),
        COUNT("address_tagId_count");

        private final String label;

        PhraseFormat(String label) {
            this.label = label;
        }
    }

    private record TagEntry(int index, String tagId, String address, String value, String phrase) {
    }

    private final Scanner scanner;

    public collectTags(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            new collectTags(scanner).run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void run() throws Exception {
        ObjectId objectId = promptObjectId();
        PhraseFormat format = promptFormat();
        String outputFile = promptOutputFile();

        List<TagEntry> entries = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();

        System.out.println("\nScan tags one by one. Place a tag, then press Enter. Type 'done' to finish.\n");
        while (true) {
            System.out.print("Place a tag and press Enter (or 'done'): ");
            if (scanner.nextLine().trim().equalsIgnoreCase("done")) {
                break;
            }
            collectOne(objectId, format, entries, seen);
        }

        String json = toJson(objectId, format, entries);
        Path path = Path.of(outputFile).toAbsolutePath();
        Files.writeString(path, json);
        System.out.println("\nSaved " + entries.size() + " tag(s) to " + path);
    }

    private void collectOne(ObjectId objectId, PhraseFormat format, List<TagEntry> entries, Set<String> seen) {
        try (CardConnection connection = CardConnection.openFirstTerminal(CARD_WAIT_MILLIS)) {
            connection.selectApplet(Se05xApdu.aid());
            EthereumTagSigner tag = new EthereumTagSigner(connection);

            String address = tag.address(objectId).hex().toLowerCase();
            String tagId = tag.uniqueId();

            if (!seen.add(tagId)) {
                System.out.println("  ! Tag " + tagId + " is already in the list - place a different tag.");
                return;
            }

            int index = entries.size();
            String value = thirdValue(format, index);
            String phrase = address + "_" + tagId + "_" + value;
            entries.add(new TagEntry(index, tagId, address, value, phrase));
            System.out.println("  + [" + index + "] " + phrase);
        } catch (Exception e) {
            System.out.println("  ! Could not read tag: " + e.getMessage());
        }
    }

    private static String thirdValue(PhraseFormat format, int index) {
        return switch (format) {
            case TIMESTAMP -> String.valueOf(System.currentTimeMillis() / 1000L);
            case ZERO -> "0";
            case COUNT -> String.valueOf(index);
        };
    }

    private static String toJson(ObjectId objectId, PhraseFormat format, List<TagEntry> entries) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\n");
        sb.append("  \"objectId\": \"").append(objectId.toHex()).append("\",\n");
        sb.append("  \"format\": \"").append(format.label).append("\",\n");
        sb.append("  \"count\": ").append(entries.size()).append(",\n");
        sb.append("  \"tags\": [");
        for (int i = 0; i < entries.size(); i++) {
            TagEntry e = entries.get(i);
            sb.append(i == 0 ? "\n" : ",\n");
            sb.append("    {")
                    .append("\"index\": ").append(e.index()).append(", ")
                    .append("\"tagId\": \"").append(e.tagId()).append("\", ")
                    .append("\"address\": \"").append(e.address()).append("\", ")
                    .append("\"value\": \"").append(e.value()).append("\", ")
                    .append("\"phrase\": \"").append(e.phrase()).append("\"}");
        }
        sb.append(entries.isEmpty() ? "]\n" : "\n  ]\n");
        sb.append("}\n");
        return sb.toString();
    }

    private PhraseFormat promptFormat() {
        while (true) {
            System.out.println("Choose the phrase format:");
            System.out.println("  1) {address}_{tagId}_{timestamp}");
            System.out.println("  2) {address}_{tagId}_0");
            System.out.println("  3) {address}_{tagId}_{count}   (running index, 0-based)");
            switch (scanner.nextLine().trim()) {
                case "1" -> {
                    return PhraseFormat.TIMESTAMP;
                }
                case "2" -> {
                    return PhraseFormat.ZERO;
                }
                case "3" -> {
                    return PhraseFormat.COUNT;
                }
                default -> System.out.println("Enter 1, 2 or 3.");
            }
        }
    }

    private String promptOutputFile() {
        System.out.println("Output JSON file [" + DEFAULT_OUTPUT + "]:");
        String input = scanner.nextLine().trim();
        return input.isEmpty() ? DEFAULT_OUTPUT : input;
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Object ID of the secp256k1 key on each tag (hex, e.g. 2222 or 58588381):");
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
