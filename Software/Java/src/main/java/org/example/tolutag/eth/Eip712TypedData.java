package org.example.tolutag.eth;

import org.example.tolutag.util.Json;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Standard EIP-712 typed data (the {@code eth_signTypedData_v4} payload):
 * {@code types}, {@code primaryType}, {@code domain} and {@code message}.
 *
 * <p>Parsed from JSON with {@link org.example.tolutag.util.Json}; the digest is
 * computed by {@link Eip712Encoder}.
 */
public final class Eip712TypedData {

    /** One {@code {name, type}} entry in a struct's type definition. */
    public record Field(String name, String type) {
    }

    private final Map<String, List<Field>> types;
    private final String primaryType;
    private final Map<String, Object> domain;
    private final Map<String, Object> message;

    private Eip712TypedData(Map<String, List<Field>> types, String primaryType,
                            Map<String, Object> domain, Map<String, Object> message) {
        this.types = types;
        this.primaryType = primaryType;
        this.domain = domain;
        this.message = message;
    }

    /**
     * Parses a standard EIP-712 typed-data JSON document.
     *
     * @throws IllegalArgumentException if the structure is missing required parts
     */
    public static Eip712TypedData parse(String json) {
        Map<String, Object> root = asObject(Json.parse(json), "typed data");

        Map<String, Object> typesRaw = asObject(root.get("types"), "types");
        Map<String, List<Field>> types = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : typesRaw.entrySet()) {
            types.put(entry.getKey(), toFields(entry.getKey(), entry.getValue()));
        }

        Object primaryType = root.get("primaryType");
        if (!(primaryType instanceof String primary)) {
            throw new IllegalArgumentException("typed data is missing a string \"primaryType\"");
        }
        if (!types.containsKey(primary)) {
            throw new IllegalArgumentException("primaryType \"" + primary + "\" is not defined in types");
        }
        if (!types.containsKey("EIP712Domain")) {
            throw new IllegalArgumentException("types is missing the EIP712Domain definition");
        }

        Map<String, Object> domain = asObject(root.get("domain"), "domain");
        Map<String, Object> message = asObject(root.get("message"), "message");
        return new Eip712TypedData(types, primary, domain, message);
    }

    public String primaryType() {
        return primaryType;
    }

    public Map<String, List<Field>> types() {
        return types;
    }

    public Map<String, Object> domain() {
        return domain;
    }

    public Map<String, Object> message() {
        return message;
    }

    /** @return the fields of a struct type, or throws if the type is unknown. */
    public List<Field> fields(String type) {
        List<Field> fields = types.get(type);
        if (fields == null) {
            throw new IllegalArgumentException("Unknown struct type: " + type);
        }
        return fields;
    }

    /** @return {@code true} if the given type name is a defined struct type. */
    public boolean isStruct(String type) {
        return types.containsKey(type);
    }

    private static List<Field> toFields(String typeName, Object value) {
        if (!(value instanceof List<?> list)) {
            throw new IllegalArgumentException("types." + typeName + " must be an array");
        }
        List<Field> fields = new ArrayList<>();
        for (Object element : list) {
            Map<String, Object> field = asObject(element, "types." + typeName + " entry");
            Object name = field.get("name");
            Object type = field.get("type");
            if (!(name instanceof String) || !(type instanceof String)) {
                throw new IllegalArgumentException("Each field in types." + typeName
                        + " needs string \"name\" and \"type\"");
            }
            fields.add(new Field((String) name, (String) type));
        }
        return fields;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asObject(Object value, String what) {
        if (!(value instanceof Map<?, ?>)) {
            throw new IllegalArgumentException("Expected a JSON object for " + what);
        }
        return (Map<String, Object>) value;
    }
}
