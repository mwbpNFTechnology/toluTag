// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ToluTagSignatureVerifier
 * @notice Minimal, standalone on-chain verifier for toluTag secp256k1 signatures.
 * @dev This is the same verification method used by the 0xLimited collection
 *      contracts, reduced to its two essentials so it can stand on its own:
 *
 *        1. `addTag`  — register a tag's public-key address together with its UID.
 *        2. `verify`  — check a signature over the unified toluTag message template.
 *
 *      Message template (identical to the one the toluTag hardware signer and the
 *      0xLimited validation logic use):
 *
 *          "0xAddress_0xUID_timestamp"
 *
 *      where:
 *        - Part 1 (0xAddress)  is either the tag's own public-key address, or a
 *          separate wallet / `msg.sender` address the tag signed on behalf of.
 *        - Part 2 (0xUID)      is the tag's factory unique id, formatted as a
 *          0x-prefixed, 40-hex-char (address-shaped) value.
 *        - Part 3 (timestamp)  is a Unix timestamp in seconds.
 *
 *      The signed payload is an EIP-191 ("\x19Ethereum Signed Message:\n") personal
 *      message, so it matches what EthereumTagSigner produces on the SE05x chip.
 */
contract ToluTagSignatureVerifier is Ownable {
    // ── Errors ────────────────────────────────────────────────────────────────
    error TagAlreadyRegistered();
    error ZeroAddress();
    error InvalidMessageFormat();
    error InvalidNumberChar();
    error InvalidHexAddress();
    error InvalidHexChar();

    // ── Storage ───────────────────────────────────────────────────────────────

    /// @notice Did the signature come from the tag's own public key
    ///         (0xtagPublicKeyAddress_0xtagUID_timestamp), or from a separate
    ///         "sender" key (0xwalletAddress_0xtagUID_timestamp)?
    enum VerificationSource { Sender, Tag }

    struct VerificationResult {
        address tagPublicKey;       // the key the signature was checked against
        bool    isValid;            // overall verdict
        string  reason;             // empty when valid, else why it failed
        uint256 signatureTimestamp; // timestamp parsed from the message
        address signatureAddress;   // part-1 address parsed from the message
        VerificationSource verificationSource;
    }

    /// @notice Registered tag public key => its UID. address(0) means "not registered".
    mapping(address => address) public tagUid;

    /// @notice Number of registered tags.
    uint256 public tagCount;

    /// @notice Signature freshness window, in seconds. Set to 0 to disable the
    ///         timestamp check entirely (verify signature + registration only).
    uint256 public signatureValidTimeRange;

    // ── Events ──────────────────────────────────────────────────────────────--
    event TagAdded(address indexed tagPublicKey, address uid);
    event TagRemoved(address indexed tagPublicKey);
    event SignatureValidTimeRangeUpdated(uint256 timeRange);

    /**
     * @param _signatureValidTimeRange Initial freshness window in seconds
     *        (0 disables the timestamp check).
     */
    constructor(uint256 _signatureValidTimeRange) Ownable() {
        signatureValidTimeRange = _signatureValidTimeRange;
    }

    // ── 1. Add a tag ────────────────────────────────────────────────────────--

    /**
     * @notice Register a single toluTag.
     * @param tagPublicKey The tag's Ethereum (public-key) address.
     * @param uid          The tag's UID, as a 0x-prefixed address-shaped value.
     */
    function addTag(address tagPublicKey, address uid) external onlyOwner {
        _addTag(tagPublicKey, uid);
    }

    /**
     * @notice Register many toluTags at once, each encoded as "0xPublicKey_0xUID".
     * @dev Mirrors the 0xLimited `batchSetToluTagPublicKeys` string encoding, minus
     *      the token-id third field. A trailing "_0" is tolerated so the exact
     *      registration strings used elsewhere can be reused unchanged.
     * @param entries Array of "0xPublicKey_0xUID" (optionally "0xPublicKey_0xUID_0").
     */
    function batchAddTags(string[] calldata entries) external onlyOwner {
        for (uint256 i = 0; i < entries.length; i++) {
            (address tagPublicKey, address uid, ) = _parseMessage(entries[i]);
            _addTag(tagPublicKey, uid);
        }
    }

    /**
     * @notice Remove a previously registered tag.
     * @param tagPublicKey The tag's public-key address.
     */
    function removeTag(address tagPublicKey) external onlyOwner {
        if (tagUid[tagPublicKey] == address(0)) return;
        delete tagUid[tagPublicKey];
        tagCount--;
        emit TagRemoved(tagPublicKey);
    }

    /**
     * @notice Update the signature freshness window (0 disables the check).
     */
    function setSignatureValidTimeRange(uint256 _timeRange) external onlyOwner {
        signatureValidTimeRange = _timeRange;
        emit SignatureValidTimeRangeUpdated(_timeRange);
    }

    /**
     * @notice Whether a tag public key is registered, and the UID it maps to.
     */
    function isTagRegistered(address tagPublicKey) external view returns (bool registered, address uid) {
        uid = tagUid[tagPublicKey];
        registered = uid != address(0);
    }

    // ── 2. Verify a signature ─────────────────────────────────────────────────

    /**
     * @notice Verify a toluTag signature over the "0xAddress_0xUID_timestamp" template.
     * @dev Recovers the signer with v = 27 then 28 (the recovery id is not part of the
     *      tag's raw secp256k1 output, so both parities are tried), checks it against a
     *      registered tag + matching UID, then checks timestamp freshness when a window
     *      is configured. Pure `view`: no state is written.
     * @param r             r component of the signature.
     * @param s             s component of the signature.
     * @param tagPublicKey  The tag public key the signature should recover to.
     * @param signedMessage The signed message, format "0xAddress_0xUID_timestamp".
     * @return result       The verification result.
     */
    function verify(
        bytes32 r,
        bytes32 s,
        address tagPublicKey,
        string calldata signedMessage
    ) external view returns (VerificationResult memory result) {
        // Recreate the EIP-191 personal-message hash.
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n",
                Strings.toString(bytes(signedMessage).length),
                signedMessage
            )
        );

        // Recovery id is not stored on the tag, so try v = 27 then v = 28.
        address recovered = ecrecover(messageHash, 27, r, s);
        if (recovered != tagPublicKey) {
            recovered = ecrecover(messageHash, 28, r, s);
            if (recovered != tagPublicKey) {
                return VerificationResult(
                    tagPublicKey, false, "Invalid sig: recovery failed", 0, address(0), VerificationSource.Sender
                );
            }
        }

        // Parse "0xAddress_0xUID_timestamp".
        (address signatureAddress, address extractedUid, uint256 timestamp) = _parseMessage(signedMessage);

        VerificationSource source = signatureAddress == tagPublicKey
            ? VerificationSource.Tag
            : VerificationSource.Sender;

        // The recovered key must be a registered tag, and the UID in the message
        // must match the one registered for it.
        if (tagUid[tagPublicKey] == address(0) || extractedUid != tagUid[tagPublicKey]) {
            return VerificationResult(
                tagPublicKey, false, "Invalid key or uid", timestamp, signatureAddress, source
            );
        }

        // Optional freshness check.
        if (signatureValidTimeRange != 0) {
            if (timestamp > block.timestamp) {
                return VerificationResult(tagPublicKey, false, "Invalid time: future", timestamp, signatureAddress, source);
            }
            if (block.timestamp - timestamp > signatureValidTimeRange) {
                return VerificationResult(tagPublicKey, false, "Invalid time: expired", timestamp, signatureAddress, source);
            }
        }

        return VerificationResult(tagPublicKey, true, "", timestamp, signatureAddress, source);
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    function _addTag(address tagPublicKey, address uid) private {
        if (tagPublicKey == address(0) || uid == address(0)) revert ZeroAddress();
        if (tagUid[tagPublicKey] != address(0)) revert TagAlreadyRegistered();
        tagUid[tagPublicKey] = uid;
        tagCount++;
        emit TagAdded(tagPublicKey, uid);
    }

    /**
     * @notice Parse a message in the unified 3-part format "0xAddress_0xAddress_uint256".
     * @dev When parsing a 2-part registration string ("0xKey_0xUID"), `thirdParam`
     *      returns 0. Identical parsing to the 0xLimited validation logic.
     */
    function _parseMessage(string calldata signedMsg)
        internal
        pure
        returns (address addr, address uid, uint256 thirdParam)
    {
        bytes calldata msgBytes = bytes(signedMsg);
        uint256 msgLen = msgBytes.length;

        uint256 first = type(uint256).max;
        uint256 second = type(uint256).max;

        for (uint256 i = 0; i < msgLen; i++) {
            if (msgBytes[i] == 0x5F) { // underscore
                if (first == type(uint256).max) {
                    first = i;
                } else {
                    second = i;
                    break;
                }
            }
        }

        // At least one underscore (two parts) is required.
        if (first == type(uint256).max) revert InvalidMessageFormat();

        // Part 1: 0xAddress
        addr = _parseHexAddress(msgBytes, 0, first);

        // Part 2: 0xUID — ends at the second underscore, or end-of-string if absent.
        uint256 uidEnd = second == type(uint256).max ? msgLen : second;
        uid = _parseHexAddress(msgBytes, first + 1, uidEnd);

        // Part 3: uint256 (timestamp). Absent => 0 (registration string).
        if (second != type(uint256).max) {
            for (uint256 i = second + 1; i < msgLen; i++) {
                uint8 char = uint8(msgBytes[i]);
                if (char < 0x30 || char > 0x39) revert InvalidNumberChar();
                thirdParam = thirdParam * 10 + (char - 0x30);
            }
        }
    }

    /**
     * @notice Parse a 0x-prefixed, 40-hex-char address from a byte slice.
     */
    function _parseHexAddress(bytes calldata msgBytes, uint256 startPos, uint256 endPos)
        internal
        pure
        returns (address)
    {
        uint256 len = endPos - startPos;
        if (!(len == 42 && msgBytes[startPos] == 0x30 && msgBytes[startPos + 1] == 0x78)) revert InvalidHexAddress();

        uint160 parsed = 0;
        for (uint256 i = startPos + 2; i < endPos; i++) {
            parsed <<= 4;
            uint8 char = uint8(msgBytes[i]);

            if (char >= 0x30 && char <= 0x39) {
                parsed |= uint160(char - 0x30);
            } else if (char >= 0x41 && char <= 0x46) {
                parsed |= uint160(char - 0x37);
            } else if (char >= 0x61 && char <= 0x66) {
                parsed |= uint160(char - 0x57);
            } else {
                revert InvalidHexChar();
            }
        }

        return address(parsed);
    }
}
