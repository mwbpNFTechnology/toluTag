package org.example.tolutag.se05x.policy;

import org.example.tolutag.se05x.Se05xApdu;

import java.util.EnumSet;
import java.util.Set;

/**
 * An SE05x object policy for an EC key: the set of operations that will be
 * allowed on the key, bound to an authentication object.
 *
 * <p>Build one with the {@link Builder}, or use {@link #deletionProtected()}
 * for the common "allow everything except DELETE and KDF" preset, which yields
 * a key that cannot be removed from the secure element.
 */
public final class EcKeyPolicy {

    /**
     * The individual permission bits of an EC-key policy, with their positions
     * in the 32-bit access-rule mask.
     */
    public enum Permission {
        SIGN(0x10000000),
        VERIFY(0x08000000),
        KEY_AGREEMENT(0x04000000),
        ENCRYPT(0x02000000),
        DECRYPT(0x01000000),
        READ(0x00200000),
        WRITE(0x00100000),
        GENERATE(0x00080000),
        DELETE(0x00040000),
        KDF(0x00800000);

        private final int bit;

        Permission(int bit) {
            this.bit = bit;
        }

        int bit() {
            return bit;
        }
    }

    private final int authId;
    private final Set<Permission> permissions;

    private EcKeyPolicy(int authId, Set<Permission> permissions) {
        this.authId = authId;
        this.permissions = EnumSet.copyOf(permissions);
    }

    /**
     * Preset policy that allows every operation except {@link Permission#DELETE}
     * and {@link Permission#KDF}, producing a deletion-protected key.
     */
    public static EcKeyPolicy deletionProtected() {
        return builder()
                .allow(Permission.SIGN, Permission.VERIFY, Permission.KEY_AGREEMENT,
                        Permission.ENCRYPT, Permission.DECRYPT, Permission.GENERATE,
                        Permission.WRITE, Permission.READ)
                .build();
    }

    /** @return a new builder for a policy bound to auth object 0. */
    public static Builder builder() {
        return new Builder();
    }

    /** @return the 32-bit access-rule mask for the granted permissions. */
    public int mask() {
        int mask = 0;
        for (Permission permission : permissions) {
            mask |= permission.bit();
        }
        return mask;
    }

    /**
     * Encodes this policy as the SE05x policy TLV:
     * {@code [TAG_POLICY, 0x09, 0x08, authId(4 bytes), mask(4 bytes)]}.
     */
    public byte[] toTlv() {
        int mask = mask();
        byte[] tlv = new byte[11];
        tlv[0] = Se05xApdu.TAG_POLICY;
        tlv[1] = 0x09; // length of the policy set
        tlv[2] = 0x08; // length of the single policy entry
        tlv[3] = (byte) (authId >>> 24);
        tlv[4] = (byte) (authId >>> 16);
        tlv[5] = (byte) (authId >>> 8);
        tlv[6] = (byte) authId;
        tlv[7] = (byte) (mask >>> 24);
        tlv[8] = (byte) (mask >>> 16);
        tlv[9] = (byte) (mask >>> 8);
        tlv[10] = (byte) mask;
        return tlv;
    }

    /** Fluent builder for {@link EcKeyPolicy}. */
    public static final class Builder {
        private int authId = 0;
        private final Set<Permission> permissions = EnumSet.noneOf(Permission.class);

        /** Binds the policy to the given authentication object id (default 0). */
        public Builder authId(int authId) {
            this.authId = authId;
            return this;
        }

        /** Grants one or more permissions. */
        public Builder allow(Permission... granted) {
            for (Permission permission : granted) {
                permissions.add(permission);
            }
            return this;
        }

        public EcKeyPolicy build() {
            return new EcKeyPolicy(authId, permissions);
        }
    }
}
