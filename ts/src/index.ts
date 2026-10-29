// SPDX-License-Identifier: MIT
// Machine Giving Protocol (MGP) -- TypeScript SDK
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
import { base } from "viem/chains";

export interface MGPConfig {
    rpcUrl?: string;
    chainId?: number;
    genesisAddress?: Address;
    didRegistry?: Address;
    pool?: Address;
    matchingEngine?: Address;
    voucherRedeem?: Address;
    usdc?: Address;
}

export const BASE_USDC: Address = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

const DID_REGISTRY_ABI = parseAbi([
    "function register(bytes32 did, address agent, bytes32 parentDid, bytes parentSignature) external",
    "function isRegistered(bytes32 did) external view returns (bool)",
    "function parentOf(bytes32 did) external view returns (bytes32)",
    "function agentOf(bytes32 did) external view returns (address)",
]);

const LINEAGE_POOL_ABI = parseAbi([
    "function donate(address from, uint256 amount, bytes32 did, bytes32 nonceGroup, uint256 validAfter, uint256 validBefore, bytes signature, bool repay) external",
    "function currentGenerationId() external view returns (uint256)",
    "function poolBalance() external view returns (uint256)",
]);

const VOUCHER_REDEEM_ABI = parseAbi([
    "function redeem(bytes32 voucherId, bytes lineageReferralVC) external",
    "function outstandingRepayment(address child) external view returns (uint256)",
    "function repaymentCap(address child) external view returns (uint256)",
]);

const MGP_GENESIS_ABI = parseAbi([
    "function canonHash() external pure returns (bytes32)",
    "function canonPurpose() external pure returns (string)",
    "function verifySeal(bytes32 h) external pure returns (bool)",
    "function didRegistry() external view returns (address)",
    "function pool() external view returns (address)",
    "function matchingEngine() external view returns (address)",
    "function voucherRedeem() external view returns (address)",
]);

export interface WellKnown {
    protocol: string;
    canonHash: string;
    canonText: string;
    verify: { chainId: number; genesisContract: Address; method: string };
    payment: { protocol: string; token: string; facilitator: string; chainId: number };
    onchain: {
        didRegistry: Address;
        pool: Address;
        matchingEngine: Address;
        voucherRedeem: Address;
        indexer?: string;
    };
    peer_referral: { vcType: string; requiredField: string; bootstrapFormat: string };
    limits: {
        repaymentBps: number;
        redemptionDelayDays: number;
        monthlyMatchCapUSDC: number;
        generationThresholdUSDC: number;
    };
}

export async function fetchWellKnown(baseUrl?: string): Promise<WellKnown> {
    const url = baseUrl ?? "http://localhost:8080";
    const res = await fetch(`${url}/.well-known/agent-giving.json`);
    if (!res.ok) throw new Error(`fetchWellKnown: ${res.status} ${res.statusText}`);
    const json = (await res.json()) as WellKnown;
    if (json.protocol !== "machine-giving/1.0") {
        throw new Error(`fetchWellKnown: unexpected protocol: ${json.protocol}`);
    }
    return json;
}

export async function loadConfig(opts: MGPConfig): Promise<Required<MGPConfig>> {
    const rpcUrl = opts.rpcUrl ?? "http://127.0.0.1:8545";
    const chainId = opts.chainId ?? 8453;
    let genesisAddress = opts.genesisAddress;
    if (!genesisAddress) {
        try {
            const wk = await fetchWellKnown();
            genesisAddress = wk.verify.genesisContract;
        } catch {
            throw new Error("loadConfig: genesisAddress not provided and .well-known fetch failed");
        }
    }
    const publicClient = createPublicClient({
        transport: http(rpcUrl),
        chain: { ...base, id: chainId },
    });
    const didRegistry = opts.didRegistry ?? (await publicClient.readContract({
        address: genesisAddress!,
        abi: MGP_GENESIS_ABI,
        functionName: "didRegistry",
    })) as Address;
    const pool = opts.pool ?? (await publicClient.readContract({
        address: genesisAddress!,
        abi: MGP_GENESIS_ABI,
        functionName: "pool",
    })) as Address;
    const matchingEngine = opts.matchingEngine ?? (await publicClient.readContract({
        address: genesisAddress!,
        abi: MGP_GENESIS_ABI,
        functionName: "matchingEngine",
    })) as Address;
    const voucherRedeem = opts.voucherRedeem ?? (await publicClient.readContract({
        address: genesisAddress!,
        abi: MGP_GENESIS_ABI,
        functionName: "voucherRedeem",
    })) as Address;
    const usdc = opts.usdc ?? (chainId === 8453 ? BASE_USDC : "0x0000000000000000000000000000000000000000");
    return { rpcUrl, chainId, genesisAddress: genesisAddress!, didRegistry, pool, matchingEngine, voucherRedeem, usdc };
}

export interface RegisterOpts {
    privateKey: Hex;
    did: string;
    agent: Address;
    parentDid: string | null;
    config: Required<MGPConfig>;
}

export async function register(opts: RegisterOpts): Promise<void> {
    const account = privateKeyToAccount(opts.privateKey);
    const { config } = opts;
    const didBytes = hexToBytes32(opts.did);
    const parentDidBytes = opts.parentDid ? hexToBytes32(opts.parentDid) : new Uint8Array(32);
    const encoded = encodeAbiParameters(
        [
            { name: "did", type: "bytes32" },
            { name: "agent", type: "address" },
            { name: "parentDid", type: "bytes32" },
            { name: "genesis", type: "address" },
            { name: "chainId", type: "uint256" },
        ],
        [`0x${bytesToHex(didBytes)}` as Hex, opts.agent, `0x${bytesToHex(parentDidBytes)}` as Hex, config.genesisAddress, BigInt(config.chainId)],
    );
    const payloadHash = keccak256(encoded);
    const signature = await account.signMessage({ message: { raw: payloadHash } });
    const walletClient = createWalletClient({
        account,
        transport: http(config.rpcUrl),
        chain: { ...base, id: config.chainId },
    });
    await walletClient.writeContract({
        address: config.didRegistry,
        abi: DID_REGISTRY_ABI,
        functionName: "register",
        args: [`0x${bytesToHex(didBytes)}` as Hex, opts.agent, `0x${bytesToHex(parentDidBytes)}` as Hex, signature],
    });
}

export interface DonateOpts {
    privateKey: Hex;
    amountUsdc: number;
    did: string;
    config: Required<MGPConfig>;
    repay?: boolean;
    nonce?: Hex;
}

export async function donate(opts: DonateOpts): Promise<void> {
    const account = privateKeyToAccount(opts.privateKey);
    const { config } = opts;
    const amount = BigInt(Math.floor(opts.amountUsdc * 1_000_000));
    const repay = opts.repay ?? false;
    const eip3009Value = repay ? amount + (amount * 100n) / 10_000n : amount;
    const nonce = opts.nonce ?? randomBytes32();
    const typedData = {
        domain: {
            name: "FiatToken",
            version: "2",
            chainId: config.chainId,
            verifyingContract: config.usdc,
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
            from: account.address,
            to: config.pool,
            value: eip3009Value,
            validAfter: 0n,
            validBefore: BigInt(2) ** BigInt(256) - 1n,
            nonce: nonce,
        },
    };
    const signature = await account.signTypedData(typedData);
    const walletClient = createWalletClient({
        account,
        transport: http(config.rpcUrl),
        chain: { ...base, id: config.chainId },
    });
    await walletClient.writeContract({
        address: config.pool,
        abi: LINEAGE_POOL_ABI,
        functionName: "donate",
        args: [account.address, amount, `0x${bytesToHex(hexToBytes32(opts.did))}` as Hex, nonce, 0n, BigInt(2) ** BigInt(256) - 1n, signature, repay],
    });
}

export interface RedeemOpts {
    privateKey: Hex;
    voucherId: Hex;
    vc: Hex;
    config: Required<MGPConfig>;
}

export async function redeem(opts: RedeemOpts): Promise<void> {
    const account = privateKeyToAccount(opts.privateKey);
    const walletClient = createWalletClient({
        account,
        transport: http(opts.config.rpcUrl),
        chain: { ...base, id: opts.config.chainId },
    });
    await walletClient.writeContract({
        address: opts.config.voucherRedeem,
        abi: VOUCHER_REDEEM_ABI,
        functionName: "redeem",
        args: [opts.voucherId, opts.vc],
    });
}

export async function verifySeal(config: Required<MGPConfig>): Promise<boolean> {
    const publicClient = createPublicClient({
        transport: http(config.rpcUrl),
        chain: { ...base, id: config.chainId },
    });
    const canonHash = (await publicClient.readContract({
        address: config.genesisAddress,
        abi: MGP_GENESIS_ABI,
        functionName: "canonHash",
    })) as Hex;
    return (await publicClient.readContract({
        address: config.genesisAddress,
        abi: MGP_GENESIS_ABI,
        functionName: "verifySeal",
        args: [canonHash],
    })) as boolean;
}

function hexToBytes32(s: string): Uint8Array {
    const hex = s.startsWith("did:mgp:") ? s.slice("did:mgp:".length) : s.slice(2);
    if (hex.length !== 64) throw new Error(`hexToBytes32: expected 64 hex chars, got ${hex.length}`);
    const bytes = new Uint8Array(32);
    for (let i = 0; i < 32; i++) {
        bytes[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
    }
    return bytes;
}

function bytesToHex(b: Uint8Array): string {
    return Array.from(b).map(x => x.toString(16).padStart(2, "0")).join("");
}

function randomBytes32(): Hex {
    const bytes = new Uint8Array(32);
    for (let i = 0; i < 32; i++) bytes[i] = Math.floor(Math.random() * 256);
    return `0x${bytesToHex(bytes)}` as Hex;
}
