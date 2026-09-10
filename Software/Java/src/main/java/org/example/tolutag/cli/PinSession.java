package org.example.tolutag.cli;

import org.example.tolutag.se05x.ObjectId;
import org.example.tolutag.se05x.Se05xSession;
import org.example.tolutag.smartcard.Se05xChannel;

import javax.smartcardio.CardException;
import java.nio.charset.StandardCharsets;
import java.util.Scanner;

/**
 * Shared CLI helper: asks whether the object being used is PIN-protected and, if
 * so, opens an authenticated UserID session.
 *
 * <p>Returns {@code null} when the user leaves the prompt blank (object not
 * protected), so callers use the raw channel in that case.
 */
public final class PinSession {

    private PinSession() {
    }

    /**
     * Prompts for an optional protecting user id + PIN and opens a session.
     *
     * @param scanner the CLI scanner
     * @param raw     the raw channel to the applet (already selected)
     * @return an open session, or {@code null} if the object is not protected
     * @throws CardException if the session cannot be opened (e.g. wrong PIN)
     */
    public static Se05xSession promptAndOpen(Scanner scanner, Se05xChannel raw) throws CardException {
        System.out.println("\nIf this object is PIN-protected, enter the protecting user Object ID "
                + "(blank if not protected):");
        String line = scanner.nextLine().trim();
        if (line.isEmpty()) {
            return null;
        }
        ObjectId userId = ObjectId.fromHexPadded(line);

        System.out.println("Enter the PIN:");
        byte[] pin = scanner.nextLine().getBytes(StandardCharsets.UTF_8);

        Se05xSession session = Se05xSession.openUserId(raw, userId, pin);
        System.out.println("PIN session opened with user " + userId.toHex() + ".");
        return session;
    }
}
