# toluTag Signature Verifier

A minimal Hardhat project that verifies **toluTag secp256k1 signatures on-chain**.

It is the same verification method used by the 0xLimited collection contracts,
reduced to its two essentials so it can stand on its own:

1. **Add a tag** — register a tag's public-key address together with its UID.
2. **Verify it** — check a signature over the unified toluTag message template.

## Message template

Identical to the one the toluTag hardware signer (`EthereumTagSigner` on the
SE05x) and the 0xLimited validation logic use:

```
0xAddress_0xUID_timestamp
```

| Part        | Meaning                                                                                  |
| ----------- | ---------------------------------------------------------------------------------------- |
| `0xAddress` | The tag's own public-key address, **or** a separate wallet / `msg.sender` it signs for.  |
| `0xUID`     | The tag's factory unique id, as a `0x`-prefixed, 40-hex-char (address-shaped) value.     |
| `timestamp` | Unix timestamp in seconds.                                                               |

The payload is signed as an EIP-191 personal message
(`"\x19Ethereum Signed Message:\n"` prefix), so it matches the chip's output
exactly. Because the recovery id is not part of the tag's raw secp256k1 output,
`verify` recovers with `v = 27` then `v = 28`.

## Contract API — `ToluTagSignatureVerifier`

```solidity
// 1. Add a tag (owner only)
function addTag(address tagPublicKey, address uid) external;
function batchAddTags(string[] calldata entries) external;   // "0xKey_0xUID" (or "0xKey_0xUID_0")
function removeTag(address tagPublicKey) external;

// 2. Verify a signature (view, no state written)
function verify(
    bytes32 r,
    bytes32 s,
    address tagPublicKey,
    string calldata signedMessage          // "0xAddress_0xUID_timestamp"
) external view returns (VerificationResult memory);

// Config / views
function setSignatureValidTimeRange(uint256 timeRange) external;  // 0 disables the timestamp check
function isTagRegistered(address tagPublicKey) external view returns (bool registered, address uid);
function tagUid(address) external view returns (address);
function tagCount() external view returns (uint256);
```

`VerificationResult` reports the verdict, a human-readable `reason` on failure,
the parsed timestamp and part-1 address, and a `verificationSource`
(`Tag` when part 1 is the tag's own key, `Sender` when it signed for a wallet).

## Usage

```bash
cd Software/Contract
npm install
cp .env.example .env        # fill in only to deploy to Sepolia

npm run compile
npm test
```

Deploy:

```bash
# Local
npx hardhat node                       # in one terminal
npm run deploy:local                   # in another

# Sepolia (requires .env)
npm run deploy:sepolia
```

`SIGNATURE_VALID_TIME_RANGE` (seconds, default `300`) sets the freshness window
passed to the constructor; `0` disables the timestamp check.

## Layout

```
Contract/
├── contracts/ToluTagSignatureVerifier.sol   # add a tag + verify a signature
├── scripts/deploy.ts
├── test/ToluTagSignatureVerifier.ts          # signs real EIP-191 messages and verifies on-chain
└── hardhat.config.ts
```
