package org.example.tolutag.cli.read;

import org.example.tolutag.eth.Eip712Encoder;
import org.example.tolutag.eth.Eip712TagSigner;
import org.example.tolutag.eth.Eip712TypedData;
import org.example.tolutag.eth.EthereumAddress;
import org.example.tolutag.eth.EthereumSignature;
import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xApdu;
import org.example.tolutag.se05x.Se05xSession;
import org.example.tolutag.cli.PinSession;
import org.example.tolutag.smartcard.CardConnection;
import org.example.tolutag.smartcard.Se05xChannel;
import org.example.tolutag.util.Hex;

import java.util.Scanner;

/**
 * Interactive command-line tool that signs arbitrary EIP-712 typed data with a
 * secp256k1 key on the SE05x.
 *
 * <p>Paste any standard {@code eth_signTypedData_v4} document
 * ({@code {types, primaryType, domain, message}}) - the same shape MetaMask and
 * ethers use - and it computes the digest and signs it, recovering the recovery
 * id {@code v} rather than assuming it. The token {@code {{signer}}} anywhere in
 * the JSON is replaced with the chip's own address before encoding, so a
 * "signer" field can reference the key that signs.
 *
 * <p>Run with the argument {@code selftest} to print the digest of the canonical
 * EIP-712 "Mail" example (no card needed), to cross-check the encoder.
 */
public final class eip712Sign {

    private static final int CARD_WAIT_MILLIS = 30_000;
    private static final String SIGNER_PLACEHOLDER = "{{signer}}";

    private final Scanner scanner;

    public eip712Sign(Scanner scanner) {
        this.scanner = scanner;
    }

    public static void main(String[] args) {
        if (args.length > 0 && "selftest".equalsIgnoreCase(args[0])) {
            byte[] digest = Eip712Encoder.digest(Eip712TypedData.parse(MAIL_EXAMPLE));
            System.out.println("Mail example digest: 0x" + Hex.toHex(digest).toLowerCase());
            return;
        }
        try (Scanner scanner = new Scanner(System.in)) {
            new eip712Sign(scanner).run();
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
                Eip712TagSigner signer = new Eip712TagSigner(channel);

                EthereumAddress signerAddress = signer.address(objectId);
                System.out.println("\nSigning key address: " + signerAddress.hex());
                System.out.println("(use " + SIGNER_PLACEHOLDER + " in the JSON to insert this address)");

                String json = readTypedDataJson()
                        .replace(SIGNER_PLACEHOLDER, signerAddress.hex().toLowerCase());
                Eip712TypedData typedData = Eip712TypedData.parse(json);

                byte[] digest = Eip712Encoder.digest(typedData);
                System.out.println("\nprimaryType: " + typedData.primaryType());
                System.out.println("digest:      0x" + Hex.toHex(digest).toLowerCase());

                EthereumSignature signature = signer.signDigest(objectId, digest);
                printResult(signerAddress, digest, signature);
            } finally {
                if (session != null) {
                    session.close();
                }
            }
        }
    }

    private void printResult(EthereumAddress signerAddress, byte[] digest, EthereumSignature signature) {
        System.out.println("\n=== EIP-712 SIGNATURE ===");
        System.out.println("signer: " + signerAddress.hex());
        System.out.println("digest: 0x" + Hex.toHex(digest).toLowerCase());
        System.out.println("r:      0x" + signature.r());
        System.out.println("s:      0x" + signature.s());
        System.out.println("v:      " + signature.v() + "   (recovered, not assumed)");

        System.out.println("\n--- signature envelope ---");
        System.out.println("{"
                + "\"signer\":\"" + signerAddress.hex() + "\","
                + "\"digest\":\"0x" + Hex.toHex(digest).toLowerCase() + "\","
                + "\"signature\":{\"r\":\"0x" + signature.r() + "\",\"s\":\"0x" + signature.s()
                + "\",\"v\":" + signature.v() + "}"
                + "}");
    }

    /** Reads a JSON object spanning one or more lines (until braces balance). */
    private String readTypedDataJson() {
        System.out.println("\nPaste the EIP-712 typed-data JSON (one or more lines):");
        StringBuilder sb = new StringBuilder();
        int depth = 0;
        boolean started = false;
        boolean inString = false;
        boolean escape = false;

        while (scanner.hasNextLine()) {
            String line = scanner.nextLine();
            sb.append(line).append('\n');
            for (int i = 0; i < line.length(); i++) {
                char c = line.charAt(i);
                if (escape) {
                    escape = false;
                } else if (inString) {
                    if (c == '\\') {
                        escape = true;
                    } else if (c == '"') {
                        inString = false;
                    }
                } else if (c == '"') {
                    inString = true;
                } else if (c == '{' || c == '[') {
                    depth++;
                    started = true;
                } else if (c == '}' || c == ']') {
                    depth--;
                }
            }
            if (started && depth <= 0) {
                break;
            }
        }
        return sb.toString().trim();
    }

    private ObjectId promptObjectId() {
        while (true) {
            System.out.println("Object ID of the signing key (hex, e.g. 2222 or 0000aaaa):");
            try {
                ObjectId objectId = ObjectId.fromHexPadded(scanner.nextLine());
                System.out.println("Using Object ID: " + objectId.toHex());
                return objectId;
            } catch (IllegalArgumentException e) {
                System.out.println(e.getMessage());
            }
        }
    }

    /** The canonical EIP-712 "Mail" example (nested Person structs). */
    private static final String MAIL_EXAMPLE = """
            {
              "types": {
                "EIP712Domain": [
                  {"name":"name","type":"string"},
                  {"name":"version","type":"string"},
                  {"name":"chainId","type":"uint256"},
                  {"name":"verifyingContract","type":"address"}
                ],
                "Person": [
                  {"name":"name","type":"string"},
                  {"name":"wallet","type":"address"}
                ],
                "Mail": [
                  {"name":"from","type":"Person"},
                  {"name":"to","type":"Person"},
                  {"name":"contents","type":"string"}
                ]
              },
              "primaryType": "Mail",
              "domain": {
                "name": "Ether Mail",
                "version": "1",
                "chainId": 1,
                "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
              },
              "message": {
                "from": {"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
                "to": {"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
                "contents": "Hello, Bob!"
              }
            }
            """;
}
