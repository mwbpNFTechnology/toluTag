package org.example.tolutag.se05x;

import java.io.ByteArrayOutputStream;
import java.util.Arrays;

/**
 * Minimal builder and reader for the TLV (tag-length-value) structures used by
 * the SE05x APDU payloads in this project.
 *
 * <p>Encoding always uses a single-byte length (all values written here are
 * &le; 255 bytes); decoding also understands the ISO 7816 {@code 0x81}/{@code 0x82}
 * extended-length forms that responses may use.
 */
public final class Tlv {

    private Tlv() {
        // Utility class - no instances.
    }

    /**
     * Encodes a TLV with a single-byte value.
     */
    public static byte[] encode(byte tag, byte value) {
        return new byte[] {tag, 0x01, value};
    }

    /**
     * Encodes a TLV with an arbitrary-length value.
     *
     * @throws IllegalArgumentException if {@code value} is longer than 255 bytes
     */
    public static byte[] encode(byte tag, byte[] value) {
        if (value.length > 0xFF) {
            throw new IllegalArgumentException("TLV value too long: " + value.length);
        }
        byte[] out = new byte[value.length + 2];
        out[0] = tag;
        out[1] = (byte) value.length;
        System.arraycopy(value, 0, out, 2, value.length);
        return out;
    }

    /**
     * Concatenates several byte arrays (e.g. a sequence of TLVs) into one.
     */
    public static byte[] concat(byte[]... parts) {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        for (byte[] part : parts) {
            buffer.writeBytes(part);
        }
        return buffer.toByteArray();
    }

    /**
     * Returns the value of the first top-level TLV with the given tag, walking a
     * sequence of TLVs (as found in an SE05x R-APDU body). Understands the ISO
     * 7816 short form and the {@code 0x81}/{@code 0x82} extended-length forms.
     *
     * @param data a concatenation of TLVs
     * @param tag  the tag to search for
     * @return the value bytes, or {@code null} if the tag is not present
     */
    public static byte[] findValue(byte[] data, byte tag) {
        int i = 0;
        while (i + 2 <= data.length) {
            byte currentTag = data[i++];
            int length = data[i++] & 0xFF;
            if (length == 0x81) {
                if (i >= data.length) {
                    break;
                }
                length = data[i++] & 0xFF;
            } else if (length == 0x82) {
                if (i + 1 >= data.length) {
                    break;
                }
                length = ((data[i] & 0xFF) << 8) | (data[i + 1] & 0xFF);
                i += 2;
            }
            if (i + length > data.length) {
                break;
            }
            if (currentTag == tag) {
                return Arrays.copyOfRange(data, i, i + length);
            }
            i += length;
        }
        return null;
    }
}
