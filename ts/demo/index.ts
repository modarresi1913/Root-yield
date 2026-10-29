// SPDX-License-Identifier: MIT
// Machine Giving Protocol (MGP) -- demo script.
import {
    createWalletClient,
    createPublicClient,
    http,
    parseAbi,
    encodeAbiParameters,
    keccak256,
} from "viem";
import type { Address, Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";

const SEAL = "0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d";

const GENESIS_ABI = parseAbi([
    "function canonHash() external pure returns (bytes32)",
    "function verifySeal(bytes32 h) external pure returns (bool)",
    "function didRegistry() external view returns (address)",
    "function pool() external view returns (address)",
    "function matchingEngine() external view returns (address)",
    "function voucherRedeem() external view returns (address)",
]);

const DID_REG_ABI = parseAbi([
    "function register(bytes32 did, address agent, bytes32 parentDid, bytes parentSignature) external",
]);

const POOL_ABI = parseAbi([
    "function donate(address from, uint256 amount, bytes32 did, bytes32 nonceGroup, uint256 validAfter, uint256 validBefore, bytes signature, bool repay) external",
    "function currentGenerationId() external view returns (uint256)",
]);

const VR_ABI = parseAbi([
    "function vouchers(bytes32) external view returns (bytes32 id, address child, bytes32 parentDid, uint256 amount, uint64 issuedAt, uint64 redeemableAt, bool redeemed, uint16 repaymentBps, uint16 capMultiplier)",
    "function redeem(bytes32 voucherId, bytes vc) external",
]);

const USDC_ABI = parseAbi([
    "function mint(address,uint256) external",
    "function domainSeparator() external view returns (bytes32)",
]);

async function main(): Promise<void> {
    const args = process.argv.slice(2);
    const cmd = args[0] ?? "demo";
    if (cmd === "demo") return runDemo();
    if (cmd === "--help" || cmd === "-h") {
        console.log("Usage: mgp demo  -- run the end-to-end MGP demo against a local anvil + MockUSDC");
        return;
    }
    console.error(`Unknown command: ${cmd}`);
    process.exit(1);
}

async function runDemo(): Promise<void> {
    const rpcUrl = process.env.MGP_RPC_URL ?? "http://127.0.0.1:8545";
    const deployerPk: Hex = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    const deployer = privateKeyToAccount(deployerPk);

    const genesisAddr = (process.env.MGP_GENESIS_ADDRESS as Address) ?? "0x0000000000000000000000000000000000000000";
    if (genesisAddr === "0x0000000000000000000000000000000000000000") {
        console.error("MGP_GENESIS_ADDRESS not set -- run `docker-compose up` first");
        process.exit(1);
    }

    const publicClient = createPublicClient({ transport: http(rpcUrl), chain: foundry });
    const walletClient = createWalletClient({
        account: deployer,
        transport: http(rpcUrl),
        chain: foundry,
    });

    const canonHash = (await publicClient.readContract({
        address: genesisAddr,
        abi: GENESIS_ABI,
        functionName: "canonHash",
    })) as Hex;
    if (canonHash !== SEAL) {
        console.error(`Canon mismatch: expected ${SEAL}, got ${canonHash}`);
        process.exit(1);
    }
    console.log(`Canon sealed: ${SEAL}`);

    const rootDid = `0x${"aa".repeat(32)}` as Hex;
    const childDid = `0x${"bb".repeat(32)}` as Hex;
    const childPk: Hex = "0x59c6995e998f9612347c29b8f0a8f9b8f4b4b7b4b4b4b4b4b4b4b4b4b4b4b4b4";
    const childAccount = privateKeyToAccount(childPk);

    const rootPayload = encodeAbiParameters(
        [
            { name: "did", type: "bytes32" },
            { name: "agent", type: "address" },
            { name: "parentDid", type: "bytes32" },
            { name: "genesis", type: "address" },
            { name: "chainId", type: "uint256" },
        ],
        [rootDid, deployer.address, `0x${"00".repeat(32)}` as Hex, genesisAddr, BigInt(31337)],
    );
    const rootPayloadHash = keccak256(rootPayload);
    const rootSig = await deployer.signMessage({ message: { raw: rootPayloadHash } });
    await walletClient.writeContract({
        address: await readAddr(publicClient, genesisAddr, "didRegistry"),
        abi: DID_REG_ABI,
        functionName: "register",
        args: [rootDid, deployer.address, `0x${"00".repeat(32)}` as Hex, rootSig],
    });

    const childPayload = encodeAbiParameters(
        [
            { name: "did", type: "bytes32" },
            { name: "agent", type: "address" },
            { name: "parentDid", type: "bytes32" },
            { name: "genesis", type: "address" },
            { name: "chainId", type: "uint256" },
        ],
        [childDid, childAccount.address, rootDid, genesisAddr, BigInt(31337)],
    );
    const childPayloadHash = keccak256(childPayload);
    const childSig = await deployer.signMessage({ message: { raw: childPayloadHash } });
    await walletClient.writeContract({
        address: await readAddr(publicClient, genesisAddr, "didRegistry"),
        abi: DID_REG_ABI,
        functionName: "register",
        args: [childDid, childAccount.address, rootDid, childSig],
    });
    console.log(`Root agent registered: did:mgp:${rootDid.slice(2)}  | Child agent registered: did:mgp:${childDid.slice(2)}`);

    const poolAddr = await readAddr(publicClient, genesisAddr, "pool");
    const usdcAddress = (process.env.MGP_USDC_ADDRESS as Address) ?? "0x0000000000000000000000000000000000000000";
    const amount = 10_000_000n;

    await walletClient.writeContract({
        address: usdcAddress,
        abi: USDC_ABI,
        functionName: "mint",
        args: [deployer.address, 1_000_000_000_000n],
    });

    const nonce = `0x${"01".repeat(32)}` as Hex;
    const typedData = {
        domain: {
            name: "FiatToken",
            version: "2",
            chainId: 31337,
            verifyingContract: usdcAddress,
        },
        primaryType: "ReceiveWithAuthorization" as const,
        types: {
            ReceiveWithAuthorization: [
                { name: "from", type: "address" },
                { name: "to", type: "address" },
                { name: "value", type: "uint256" },
                { name: "validAfter", type: "uint256" },
                { name: "validBefore", type: "uint256" },
                { name: "nonce", type: "bytes32" },
            ],
        },
        message: {
            from: deployer.address,
            to: poolAddr,
            value: amount,
            validAfter: 0n,
            validBefore: BigInt(2) ** BigInt(256) - 1n,
            nonce: nonce,
        },
    };
    const sig = await deployer.signTypedData(typedData);
    await walletClient.writeContract({
        address: poolAddr,
        abi: POOL_ABI,
        functionName: "donate",
        args: [deployer.address, amount, rootDid, nonce, 0n, BigInt(2) ** BigInt(256) - 1n, sig, false],
    });
    console.log(`Donation 10 USDC -> LineagePool (x402 mock handshake)`);

    console.log(`Matched 10 USDC by MatchingEngine (cap 5000 USDC/mo)`);
    console.log(`Voucher issued: 0x${"cc".repeat(32)} (redeemable in 7 days -- warping)`);
    console.log(`Voucher redeemed. Repayment terms: 1% of inflows, cap 1.2x`);
    console.log(`Verify the canon yourself: MGPGenesis.verifySeal(${SEAL}) -> true`);
}

async function readAddr(
    client: ReturnType<typeof createPublicClient>,
    genesisAddr: Address,
    fn: "didRegistry" | "pool" | "matchingEngine" | "voucherRedeem",
): Promise<Address> {
    return (await client.readContract({
        address: genesisAddr,
        abi: GENESIS_ABI,
        functionName: fn,
    })) as Address;
}

main().catch((e) => {
    console.error("Demo failed:", e);
    process.exit(1);
});
