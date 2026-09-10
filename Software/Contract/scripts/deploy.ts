import { ethers } from "hardhat";

/**
 * Deploys ToluTagSignatureVerifier.
 *
 * SIGNATURE_VALID_TIME_RANGE — freshness window in seconds for the timestamp in
 * the signed message. Set to 0 to disable the timestamp check (verify signature
 * + tag registration only). Defaults to 300 (5 minutes).
 */
async function main() {
  const timeRange = Number(process.env.SIGNATURE_VALID_TIME_RANGE ?? "300");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("signatureValidTimeRange:", timeRange, "seconds");

  const Verifier = await ethers.getContractFactory("ToluTagSignatureVerifier");
  const verifier = await Verifier.deploy(timeRange);
  await verifier.waitForDeployment();

  console.log("ToluTagSignatureVerifier deployed to:", await verifier.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
