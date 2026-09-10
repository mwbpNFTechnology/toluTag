package org.example.tolutag.eth;

import org.example.tolutag.crypto.Keccak256;
import org.example.tolutag.eth.Eip712TypedData.Field;
import org.example.tolutag.util.Hex;

import java.io.ByteArrayOutputStream;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

/**
 * General EIP-712 encoder: computes the signing digest of any
 * {@link Eip712TypedData} per the spec's {@code encodeType} / {@code hashStruct}
 * rules, including nested struct references and arrays.
 *
 * <p>{@code digest = keccak256(0x19 || 0x01 || hashStruct(EIP712Domain, domain)
 * || hashStruct(primaryType, message))}.
 */
public final class Eip712Encoder {

    private static final int WORD = 32;
    private static final byte[] PREFIX = {0x19, 0x01};

    private Eip712Encoder() {
        // Utility class - no instances.
    }

    /** @return the 32-byte EIP-712 signing digest for the given typed data. */
    public static byte[] digest(Eip712TypedData typedData) {
        byte[] domainSeparator = hashStruct("EIP712Domain", typedData.domain(), typedData);
        byte[] messageHash = hashStruct(typedData.primaryType(), typedData.message(), typedData);
        return Keccak256.digest(concat(PREFIX, domainSeparator, messageHash));
    }

    /** @return {@code keccak256(typeHash || encodeData)} for one struct value. */
    public static byte[] hashStruct(String type, Map<String, Object> data, Eip712TypedData typedData) {
        return Keccak256.digest(concat(typeHash(type, typedData), encodeData(type, data, typedData)));
    }

    /** @return {@code keccak256(encodeType(type))}. */
    public static byte[] typeHash(String type, Eip712TypedData typedData) {
        return Keccak256.digest(encodeType(type, typedData).getBytes(StandardCharsets.UTF_8));
    }

    /** Builds the canonical type string: primary type first, then deps sorted. */
    public static String encodeType(String primaryType, Eip712TypedData typedData) {
        TreeSet<String> dependencies = new TreeSet<>();
        collectDependencies(primaryType, typedData, dependencies);
        dependencies.remove(primaryType);

        StringBuilder sb = new StringBuilder(encodeOneType(primaryType, typedData));
        for (String dependency : dependencies) {
            sb.append(encodeOneType(dependency, typedData));
        }
        return sb.toString();
    }

    private static void collectDependencies(String type, Eip712TypedData typedData, TreeSet<String> found) {
        if (found.contains(type) || !typedData.isStruct(type)) {
            return;
        }
        found.add(type);
        for (Field field : typedData.fields(type)) {
            collectDependencies(structBaseType(field.type()), typedData, found);
        }
    }

    private static String encodeOneType(String type, Eip712TypedData typedData) {
        StringBuilder sb = new StringBuilder(type).append('(');
        List<Field> fields = typedData.fields(type);
        for (int i = 0; i < fields.size(); i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(fields.get(i).type()).append(' ').append(fields.get(i).name());
        }
        return sb.append(')').toString();
    }

    private static byte[] encodeData(String type, Map<String, Object> data, Eip712TypedData typedData) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        for (Field field : typedData.fields(type)) {
            out.writeBytes(encodeValue(field.type(), data.get(field.name()), typedData));
        }
        return out.toByteArray();
    }

    private static byte[] encodeValue(String type, Object value, Eip712TypedData typedData) {
        if (type.endsWith("]")) {
            String elementType = type.substring(0, type.lastIndexOf('['));
            if (!(value instanceof List<?> items)) {
                throw new IllegalArgumentException("Expected an array for type " + type);
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            for (Object item : items) {
                out.writeBytes(encodeValue(elementType, item, typedData));
            }
            return Keccak256.digest(out.toByteArray());
        }
        if (typedData.isStruct(type)) {
            return hashStruct(type, asObject(value, type), typedData);
        }
        return encodeAtomic(type, value);
    }

    private static byte[] encodeAtomic(String type, Object value) {
        if (type.equals("string")) {
            return Keccak256.digest(asString(value).getBytes(StandardCharsets.UTF_8));
        }
        if (type.equals("bytes")) {
            return Keccak256.digest(Hex.toBytes(strip0x(asString(value))));
        }
        if (type.startsWith("bytes")) {
            return fixedBytes(type, value);
        }
        if (type.equals("address")) {
            return leftPadded(addressToBytes(value));
        }
        if (type.equals("bool")) {
            byte[] word = new byte[WORD];
            word[WORD - 1] = (byte) (asBoolean(value) ? 1 : 0);
            return word;
        }
        if (type.startsWith("uint")) {
            BigInteger v = toBigInteger(value);
            if (v.signum() < 0) {
                throw new IllegalArgumentException("Negative value for " + type + ": " + v);
            }
            return leftPadded(v.toByteArray());
        }
        if (type.startsWith("int")) {
            return twosComplement(toBigInteger(value));
        }
        throw new IllegalArgumentException("Unsupported EIP-712 type: " + type);
    }

    private static byte[] fixedBytes(String type, Object value) {
        int n = Integer.parseInt(type.substring("bytes".length()));
        byte[] bytes = Hex.toBytes(strip0x(asString(value)));
        if (bytes.length != n) {
            throw new IllegalArgumentException(type + " expects " + n + " bytes, got " + bytes.length);
        }
        byte[] word = new byte[WORD];
        System.arraycopy(bytes, 0, word, 0, n); // left-aligned, right zero-padded
        return word;
    }

    /** Left-pads an unsigned big-endian magnitude to a 32-byte word. */
    private static byte[] leftPadded(byte[] magnitude) {
        byte[] trimmed = magnitude;
        // Drop a leading sign byte from BigInteger.toByteArray if present.
        if (trimmed.length > WORD && trimmed[0] == 0) {
            int start = trimmed.length - WORD;
            byte[] cut = new byte[WORD];
            System.arraycopy(trimmed, start, cut, 0, WORD);
            trimmed = cut;
        }
        if (trimmed.length > WORD) {
            throw new IllegalArgumentException("Value exceeds 32 bytes");
        }
        byte[] word = new byte[WORD];
        System.arraycopy(trimmed, 0, word, WORD - trimmed.length, trimmed.length);
        return word;
    }

    private static byte[] twosComplement(BigInteger value) {
        byte[] word = new byte[WORD];
        if (value.signum() < 0) {
            java.util.Arrays.fill(word, (byte) 0xFF); // sign-extend
        }
        byte[] bytes = value.toByteArray();
        int length = Math.min(bytes.length, WORD);
        System.arraycopy(bytes, bytes.length - length, word, WORD - length, length);
        return word;
    }

    private static byte[] addressToBytes(Object value) {
        byte[] bytes = Hex.toBytes(strip0x(asString(value)));
        if (bytes.length != 20) {
            throw new IllegalArgumentException("address must be 20 bytes, got " + bytes.length);
        }
        return bytes;
    }

    private static BigInteger toBigInteger(Object value) {
        if (value instanceof BigInteger big) {
            return big;
        }
        String text = asString(value).trim();
        if (text.startsWith("0x") || text.startsWith("0X")) {
            return new BigInteger(text.substring(2), 16);
        }
        return new BigInteger(text);
    }

    private static boolean asBoolean(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        return Boolean.parseBoolean(asString(value));
    }

    private static String asString(Object value) {
        if (value == null) {
            throw new IllegalArgumentException("Missing value");
        }
        return value.toString();
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asObject(Object value, String type) {
        if (!(value instanceof Map<?, ?>)) {
            throw new IllegalArgumentException("Expected an object for struct " + type);
        }
        return (Map<String, Object>) value;
    }

    private static String structBaseType(String type) {
        int bracket = type.indexOf('[');
        return bracket < 0 ? type : type.substring(0, bracket);
    }

    private static String strip0x(String value) {
        return (value.startsWith("0x") || value.startsWith("0X")) ? value.substring(2) : value;
    }

    private static byte[] concat(byte[]... parts) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        for (byte[] part : parts) {
            out.writeBytes(part);
        }
        return out.toByteArray();
    }
}
