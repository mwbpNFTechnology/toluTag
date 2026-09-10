package org.example.tolutag.se05x;

import org.example.tolutag.util.Hex;

import java.util.Arrays;

/**
 * The parsed attributes buffer of a Secure Object, as returned by
 * ReadObjectAttributes (spec Table 4 for non-authentication objects).
 *
 * <p>The spec lists the fields and their sizes but not the exact serialization,
 * so this parser assumes the documented field order and reads the fixed-size
 * header from the front and {@code origin}/{@code version} from the back (the
 * variable-length policy sits between them). Callers can cross-check
 * {@link #objectIdentifier()} and {@link #typeByte()} against an independent
 * ReadType to confirm the layout was interpreted correctly; {@link #rawHex()}
 * exposes the untouched buffer.
 *
 * <p>Field order: object id (4), type (1), auth indicator (1), min AEAD tag
 * length (2), session owner (4), min output length (2), policy (variable),
 * origin (1), version (4).
 */
public final class ObjectAttributes {

    private static final int HEADER_LENGTH = 14; // up to and including min output length
    private static final int TRAILER_LENGTH = 5; // origin (1) + version (4)
    private static final int MINIMUM_LENGTH = HEADER_LENGTH + TRAILER_LENGTH;

    private final byte[] raw;
    private final byte[] objectIdentifier;
    private final int typeByte;
    private final int authIndicatorByte;
    private final byte[] policy;
    private final Origin origin;
    private final long version;

    private ObjectAttributes(byte[] raw, byte[] objectIdentifier, int typeByte, int authIndicatorByte,
                             byte[] policy, Origin origin, long version) {
        this.raw = raw;
        this.objectIdentifier = objectIdentifier;
        this.typeByte = typeByte;
        this.authIndicatorByte = authIndicatorByte;
        this.policy = policy;
        this.origin = origin;
        this.version = version;
    }

    /**
     * Parses an attributes buffer.
     *
     * @throws IllegalArgumentException if the buffer is too short to be valid
     */
    public static ObjectAttributes parse(byte[] buffer) {
        if (buffer.length < MINIMUM_LENGTH) {
            throw new IllegalArgumentException("Attributes buffer too short: " + buffer.length + " bytes");
        }
        byte[] identifier = Arrays.copyOfRange(buffer, 0, 4);
        int type = buffer[4] & 0xFF;
        int authIndicator = buffer[5] & 0xFF;

        int originIndex = buffer.length - TRAILER_LENGTH;
        byte[] policy = Arrays.copyOfRange(buffer, HEADER_LENGTH, originIndex);
        Origin origin = Origin.fromByte(buffer[originIndex]);

        long version = 0;
        for (int i = originIndex + 1; i < buffer.length; i++) {
            version = (version << 8) | (buffer[i] & 0xFF);
        }

        return new ObjectAttributes(buffer.clone(), identifier, type, authIndicator, policy, origin, version);
    }

    /** @return the 4-byte object identifier as stored in the attributes. */
    public byte[] objectIdentifier() {
        return objectIdentifier.clone();
    }

    /** @return the object type byte (decode with {@link SecureObjectType}). */
    public int typeByte() {
        return typeByte;
    }

    private static final int SET_INDICATOR_SET = 0x02; // SetIndicator: SET (0x02) vs NOT_SET (0x01)

    /** @return {@code true} if the object is an authentication object (SetIndicator SET). */
    public boolean isAuthenticationObject() {
        return authIndicatorByte == SET_INDICATOR_SET;
    }

    /** @return the raw policy bytes (variable length). */
    public byte[] policy() {
        return policy.clone();
    }

    /** @return the object origin (generated / imported / provisioned). */
    public Origin origin() {
        return origin;
    }

    /** @return the object version attribute. */
    public long version() {
        return version;
    }

    /** @return the full attributes buffer as hex, for manual inspection. */
    public String rawHex() {
        return Hex.toHex(raw);
    }
}
