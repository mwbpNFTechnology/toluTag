import { expect } from "chai";
import { ethers } from "hardhat";
import { ToluTagSignatureVerifier } from "../typechain-types";
import { HDNodeWallet } from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

/**
 * Exercises the full toluTag method on-chain:
 *   1. add a tag (register public key + UID)
 *   2. verify a signature over the "0xAddress_0xUID_timestamp" template
 *
 * Signatures are produced with ethers' personal_sign (EIP-191), the same
 * envelope the SE05x EthereumTagSigner uses, so the contract's ecrecover path
 * is tested against real signatures rather than mocks.
 */
describe("ToluTagSignatureVerifier", function () {
  const TIME_RANGE = 300; // 5 minutes

  // The contract parses part 2 as a 0x-prefixed, 40-hex-char (address-shaped)
  // value — exactly how the tag's factory unique id is formatted. It comes back
  // from the contract EIP-55 checksummed, so store it that way for comparisons.
  const UID = ethers.getAddress("0x00000000000000000000000000000000deadbeef");

  async function deploy(timeRange = TIME_RANGE) {
    const [owner, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("ToluTagSignatureVerifier");
    const verifier = (await Factory.deploy(timeRange)) as unknown as ToluTagSignatureVerifier;
    await verifier.waitForDeployment();
    return { verifier, owner, other };
  }

  // Build "addr_uid_timestamp", sign it with `tag`, and split into r/s.
  async function signTemplate(tag: HDNodeWallet, addr: string, uid: string, ts: number) {
    const message = `${addr}_${uid}_${ts}`;
    const sig = await tag.signMessage(message);
    const { r, s } = ethers.Signature.from(sig);
    return { message, r, s };
  }

  async function now() {
    return await time.latest();
  }

  describe("addTag", function () {
    it("registers a tag and exposes it", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();

      await expect(verifier.addTag(tag.address, UID))
        .to.emit(verifier, "TagAdded")
        .withArgs(tag.address, UID);

      expect(await verifier.tagCount()).to.equal(1);
      expect(await verifier.tagUid(tag.address)).to.equal(UID);

      const [registered, uid] = await verifier.isTagRegistered(tag.address);
      expect(registered).to.equal(true);
      expect(uid).to.equal(UID);
    });

    it("reverts on duplicate registration", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);
      await expect(verifier.addTag(tag.address, UID)).to.be.revertedWithCustomError(
        verifier,
        "TagAlreadyRegistered"
      );
    });

    it("reverts on zero address", async function () {
      const { verifier } = await deploy();
      await expect(verifier.addTag(ethers.ZeroAddress, UID)).to.be.revertedWithCustomError(
        verifier,
        "ZeroAddress"
      );
    });

    it("is owner-only", async function () {
      const { verifier, other } = await deploy();
      const tag = ethers.Wallet.createRandom();
      await expect(verifier.connect(other).addTag(tag.address, UID)).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("batchAddTags registers several at once (with and without trailing _0)", async function () {
      const { verifier } = await deploy();
      const a = ethers.Wallet.createRandom();
      const b = ethers.Wallet.createRandom();
      await verifier.batchAddTags([`${a.address}_${UID}`, `${b.address}_${UID}_0`]);
      expect(await verifier.tagCount()).to.equal(2);
      expect(await verifier.tagUid(a.address)).to.equal(UID);
      expect(await verifier.tagUid(b.address)).to.equal(UID);
    });

    it("removeTag clears a registration", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);
      await expect(verifier.removeTag(tag.address)).to.emit(verifier, "TagRemoved").withArgs(tag.address);
      expect(await verifier.tagCount()).to.equal(0);
      expect(await verifier.tagUid(tag.address)).to.equal(ethers.ZeroAddress);
    });
  });

  describe("verify", function () {
    it("accepts a valid signature from the tag's own key (Tag source)", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);

      const { message, r, s } = await signTemplate(tag, tag.address, UID, await now());
      const res = await verifier.verify(r, s, tag.address, message);

      expect(res.isValid).to.equal(true);
      expect(res.reason).to.equal("");
      expect(res.signatureAddress).to.equal(tag.address);
      expect(res.verificationSource).to.equal(1); // Tag
    });

    it("accepts a valid signature on behalf of a wallet (Sender source)", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      const wallet = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);

      // Part 1 is the wallet address, but the tag key produces the signature.
      const { message, r, s } = await signTemplate(tag, wallet.address, UID, await now());
      const res = await verifier.verify(r, s, tag.address, message);

      expect(res.isValid).to.equal(true);
      expect(res.signatureAddress).to.equal(wallet.address);
      expect(res.verificationSource).to.equal(0); // Sender
    });

    it("rejects an unregistered key", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      const { message, r, s } = await signTemplate(tag, tag.address, UID, await now());
      const res = await verifier.verify(r, s, tag.address, message);
      expect(res.isValid).to.equal(false);
      expect(res.reason).to.equal("Invalid key or uid");
    });

    it("rejects a mismatched UID", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);

      const wrongUid = "0x000000000000000000000000000000000000c0de";
      const { message, r, s } = await signTemplate(tag, tag.address, wrongUid, await now());
      const res = await verifier.verify(r, s, tag.address, message);
      expect(res.isValid).to.equal(false);
      expect(res.reason).to.equal("Invalid key or uid");
    });

    it("rejects a signature that does not recover to the claimed key", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      const imposter = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);

      // Signed by imposter, but we claim it is the tag's key.
      const { message, r, s } = await signTemplate(imposter, tag.address, UID, await now());
      const res = await verifier.verify(r, s, tag.address, message);
      expect(res.isValid).to.equal(false);
      expect(res.reason).to.equal("Invalid sig: recovery failed");
    });

    it("rejects an expired timestamp", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);

      const oldTs = (await now()) - TIME_RANGE - 60;
      const { message, r, s } = await signTemplate(tag, tag.address, UID, oldTs);
      const res = await verifier.verify(r, s, tag.address, message);
      expect(res.isValid).to.equal(false);
      expect(res.reason).to.equal("Invalid time: expired");
    });

    it("rejects a future timestamp", async function () {
      const { verifier } = await deploy();
      const tag = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);

      const futureTs = (await now()) + 10_000;
      const { message, r, s } = await signTemplate(tag, tag.address, UID, futureTs);
      const res = await verifier.verify(r, s, tag.address, message);
      expect(res.isValid).to.equal(false);
      expect(res.reason).to.equal("Invalid time: future");
    });

    it("skips the timestamp check when the window is 0", async function () {
      const { verifier } = await deploy(0);
      const tag = ethers.Wallet.createRandom();
      await verifier.addTag(tag.address, UID);

      const oldTs = (await now()) - 1_000_000;
      const { message, r, s } = await signTemplate(tag, tag.address, UID, oldTs);
      const res = await verifier.verify(r, s, tag.address, message);
      expect(res.isValid).to.equal(true);
    });
  });
});
