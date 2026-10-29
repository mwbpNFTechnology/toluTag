//
//  SessionApdu.swift
//  toluTag
//
//  A command as it rides inside ProcessSessionCmd before the session is
//  authenticated — how ECKeySessionInternalAuthenticate travels. As NXP's
//  middleware builds it (se05x_Transform): the header, a 1-byte Lc (three
//  bytes only past 254), the data, and no Le. The applet answers a 3-byte
//  Lc on InternalAuthenticate with 6A80.
//

import Foundation

enum SessionApdu {
    static func unprotected(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: [UInt8]) -> [UInt8] {
        var apdu = [cla, ins, p1, p2]
        guard !data.isEmpty else { return apdu }
        if data.count < 0xFF {
            apdu.append(UInt8(data.count))
        } else {
            apdu += [0x00, UInt8(truncatingIfNeeded: data.count >> 8), UInt8(truncatingIfNeeded: data.count)]
        }
        return apdu + data
    }
}
