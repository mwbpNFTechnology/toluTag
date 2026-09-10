package org.example.tolutag.se05x;

import org.example.tolutag.util.Hex;

import java.util.ArrayList;
import java.util.List;

/**
 * The applet version information returned by GetVersion (spec §4.20.1).
 *
 * <p>The spec documents that the 7-byte {@code VersionInfo} carries the applet
 * major/minor/patch, the supported applet features (AppletConfig, Table 48) and
 * the secure-box version, but does <em>not</em> tabulate the exact byte offsets.
 * This class therefore exposes the raw bytes via {@link #rawHex()} and offers a
 * best-effort interpretation using the conventional layout
 * {@code [major, minor, patch, config(2), secureBox(2)]}.
 */
public final class VersionInfo {

    // AppletConfig feature bits (spec Table 48); aggregates (ALL) are omitted.
    private static final int[] FEATURE_BITS = {
            0x0002, 0x0004, 0x0008, 0x0010, 0x0020, 0x0040,
            0x0080, 0x0100, 0x0200, 0x0400, 0x0800, 0x2000
    };
    private static final String[] FEATURE_NAMES = {
            "ECDSA/ECDH/ECDHE", "EdDSA", "DH-Montgomery", "HMAC", "RSA-plain", "RSA-CRT",
            "AES", "DES", "PBKDF", "TLS", "MIFARE", "I2CM"
    };

    private final byte[] raw;

    public VersionInfo(byte[] raw) {
        this.raw = raw.clone();
    }

    /** @return the untouched version bytes as hex. */
    public String rawHex() {
        return Hex.toHex(raw);
    }

    /** @return the number of raw bytes (7 for the base form, more when extended). */
    public int length() {
        return raw.length;
    }

    private int at(int index) {
        return index < raw.length ? raw[index] & 0xFF : 0;
    }

    /** @return best-effort "major.minor.patch" from the first three bytes. */
    public String versionString() {
        return at(0) + "." + at(1) + "." + at(2);
    }

    /** @return the applet feature configuration word (best-effort, bytes 3-4). */
    public int appletConfig() {
        return (at(3) << 8) | at(4);
    }

    /** @return the secure-box version (best-effort, bytes 5-6). */
    public int secureBoxVersion() {
        return (at(5) << 8) | at(6);
    }

    /** @return the enabled feature names decoded from {@link #appletConfig()}. */
    public List<String> features() {
        int config = appletConfig();
        List<String> enabled = new ArrayList<>();
        for (int i = 0; i < FEATURE_BITS.length; i++) {
            if ((config & FEATURE_BITS[i]) != 0) {
                enabled.add(FEATURE_NAMES[i]);
            }
        }
        return enabled;
    }
}
