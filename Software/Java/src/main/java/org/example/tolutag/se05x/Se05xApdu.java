package org.example.tolutag.se05x;

import org.example.tolutag.util.Hex;

/**
 * Constants from the NXP SE05x APDU specification: class/instruction bytes,
 * P1/P2 parameters, TLV tags, and the applet AID.
 *
 * <p>Grouped here so the individual service classes read as intent
 * ({@code INS_WRITE}, {@code P1_CURVE}) rather than magic numbers.
 */
public final class Se05xApdu {

    private Se05xApdu() {
        // Constants holder - no instances.
    }

    /** Class byte for commands sent without secure messaging. */
    public static final byte CLA_NO_SM = (byte) 0x80;

    // --- Instruction bytes -------------------------------------------------
    public static final byte INS_WRITE = 0x01;
    public static final byte INS_READ = 0x02;
    public static final byte INS_CRYPTO = 0x03; // crypto operations (e.g. sign)
    public static final byte INS_MGMT = 0x04; // create/delete object / session management
    public static final byte INS_PROCESS = 0x05; // process a command within a session

    /** OR-ed into INS_WRITE to create an Authentication Object (e.g. a UserID). */
    public static final byte INS_AUTH_OBJECT = 0x40;

    // --- P1 parameters -----------------------------------------------------
    public static final byte P1_DEFAULT = 0x00;
    public static final byte P1_EC = 0x01;
    public static final byte P1_BINARY = 0x06;
    public static final byte P1_USERID = 0x07;
    public static final byte P1_CURVE = 0x0B;
    public static final byte P1_SIGNATURE = 0x0C;
    public static final byte P1_KEY_PAIR = 0x60;

    // --- P2 parameters -----------------------------------------------------
    public static final byte P2_DEFAULT = 0x00;
    public static final byte P2_SIZE = 0x07;
    public static final byte P2_SIGN = 0x09;
    public static final byte P2_SESSION_CREATE = 0x1B;
    public static final byte P2_SESSION_CLOSE = 0x1C;
    public static final byte P2_SESSION_USERID = 0x2C;
    public static final byte P2_VERSION = 0x20;
    public static final byte P2_VERSION_EXT = 0x21;
    public static final byte P2_MEMORY = 0x22;
    public static final byte P2_LIST = 0x25;
    public static final byte P2_TYPE = 0x26;
    public static final byte P2_EXIST = 0x27;
    public static final byte P2_DELETE_OBJECT = 0x28;
    public static final byte P2_ATTRIBUTES = 0x3B;
    public static final byte P2_CREATE = 0x04;
    public static final byte P2_PARAM = 0x40;

    // --- TLV tags ----------------------------------------------------------
    public static final byte TAG_SESSION_ID = 0x10; // session identifier
    public static final byte TAG_1 = 0x41; // object ID
    public static final byte TAG_2 = 0x42; // curve ID / parameter / signature algorithm / file offset
    public static final byte TAG_3 = 0x43; // parameter value / message hash / attributes / file length
    public static final byte TAG_4 = 0x44; // binary file data
    public static final byte TAG_POLICY = 0x11; // object policy

    /** ECDSA signature algorithm with a SHA-256-sized (32-byte) digest. */
    public static final byte SIG_ECDSA_SHA_256 = 0x21;

    // --- Memory types (GetFreeMemory) --------------------------------------
    public static final byte MEM_PERSISTENT = 0x01;
    public static final byte MEM_TRANSIENT_RESET = 0x02;
    public static final byte MEM_TRANSIENT_DESELECT = 0x03;

    // --- Result / indicator values -----------------------------------------
    public static final byte RESULT_SUCCESS = 0x01;
    public static final byte PERSISTENT = 0x01;
    public static final byte TRANSIENT = 0x02;

    /** Status word indicating success. */
    public static final int SW_SUCCESS = 0x9000;

    /** Reserved object id that returns the chip's factory unique identifier. */
    public static final byte[] RESERVED_ID_UNIQUE_ID = {(byte) 0x7F, (byte) 0xFF, 0x02, 0x06};

    /** AID of the SE05x IoT applet. */
    public static byte[] aid() {
        return Hex.toBytes("A0000003965453000000010300000000");
    }
}
