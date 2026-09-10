package org.example.tolutag.eth;

import org.example.tolutag.crypto.Keccak256;

import java.nio.charset.StandardCharsets;

/**
 * Computes the EIP-191 {@code personal_sign} hash of a message:
 * {@code keccak256(0x19 || "Ethereum Signed Message:\n" || len(message) || message)}.
 *
 * <p>The leading {@code 0x19} byte and the fixed prefix text are mandated by
 * EIP-191; {@code len(message)} is the message's UTF-8 byte length rendered as
 * decimal ASCII.
 */
public final class Eip191 {

    private static final byte VERSION_BYTE = 0x19;
    private static final byte[] PREFIX_TEXT =
            "Ethereum Signed Message:\n".getBytes(StandardCharsets.UTF_8);

    private Eip191() {
        // Utility class - no instances.
    }

    /**
     * @param message the message to sign
     * @return the 32-byte Keccak-256 hash of the prefixed message
     */
    public static byte[] personalMessageHash(String message) {
        byte[] body = message.getBytes(StandardCharsets.UTF_8);
        byte[] length = Integer.toString(body.length).getBytes(StandardCharsets.UTF_8);

        byte[] prefixed = new byte[1 + PREFIX_TEXT.length + length.length + body.length];
        int offset = 0;
        prefixed[offset++] = VERSION_BYTE;
        System.arraycopy(PREFIX_TEXT, 0, prefixed, offset, PREFIX_TEXT.length);
        offset += PREFIX_TEXT.length;
        System.arraycopy(length, 0, prefixed, offset, length.length);
        offset += length.length;
        System.arraycopy(body, 0, prefixed, offset, body.length);

        return Keccak256.digest(prefixed);
    }
}
