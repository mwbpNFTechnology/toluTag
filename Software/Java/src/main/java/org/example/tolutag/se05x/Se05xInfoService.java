package org.example.tolutag.se05x;

import org.example.tolutag.smartcard.ApduException;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import javax.smartcardio.CommandAPDU;
import javax.smartcardio.ResponseAPDU;

/**
 * Chip-level information commands: applet version and free memory.
 */
public final class Se05xInfoService {

    private static final int EXPECTED_RESPONSE_LENGTH = 256;

    private final Se05xChannel channel;

    public Se05xInfoService(Se05xChannel channel) {
        this.channel = channel;
    }

    /**
     * Reads the applet version information (GetVersion).
     */
    public VersionInfo getVersion() throws CardException {
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_MGMT,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_VERSION, EXPECTED_RESPONSE_LENGTH));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("Get version", response.getSW());
        }
        byte[] value = Tlv.findValue(response.getData(), Se05xApdu.TAG_1);
        return new VersionInfo(value != null ? value : response.getData());
    }

    /**
     * Reads the amount of free memory of the given type, in bytes.
     *
     * @param memoryType one of {@link Se05xApdu#MEM_PERSISTENT},
     *                   {@link Se05xApdu#MEM_TRANSIENT_RESET},
     *                   {@link Se05xApdu#MEM_TRANSIENT_DESELECT}
     */
    public int getFreeMemory(byte memoryType) throws CardException {
        ResponseAPDU response = channel.transmit(new CommandAPDU(
                Se05xApdu.CLA_NO_SM, Se05xApdu.INS_MGMT,
                Se05xApdu.P1_DEFAULT, Se05xApdu.P2_MEMORY,
                Tlv.encode(Se05xApdu.TAG_1, memoryType), EXPECTED_RESPONSE_LENGTH));
        if (response.getSW() != Se05xApdu.SW_SUCCESS) {
            throw new ApduException("Get free memory", response.getSW());
        }
        byte[] value = Tlv.findValue(response.getData(), Se05xApdu.TAG_1);
        if (value == null) {
            throw new ApduException("Get free memory (missing value in response)", Se05xApdu.SW_SUCCESS);
        }
        int free = 0;
        for (byte b : value) {
            free = (free << 8) | (b & 0xFF);
        }
        return free;
    }
}
