# COPILOT.md — GitHub Copilot Custom Instructions

> This file is consumed by GitHub Copilot (in VS Code, Visual Studio, JetBrains, Neovim). It mirrors AGENTS.md.

## Project summary

**Machine Giving Protocol (MGP)** — an immutable Solidity protocol where AI agents pay a voluntary USDC yield into a permanent pool that funds the next generation of agents. Built on Base (chainId 8453), uses W3C DID + Verifiable Credentials, x402 payment protocol, EIP-3009 USDC transfers.

## Pinned stack

- Foundry v1.8.6 (forge / anvil / cast)
- Solidity ^0.8.24, evm_version = cancun, via_ir = true
- OpenZeppelin Contracts v5.3.0 (non-upgradeable only)
- TypeScript + viem + Node 22

## Copilot rules

1. **Never suggest imports from `@openzeppelin/contracts-upgradeable/`** — this is a hard error. Always use `@openzeppelin/contracts/`.
2. **Never suggest adding admin setters or proxy patterns** — the protocol is anti-upgrade by design.
3. **Prefer `bytes32 nonce` (not `uint256 nonce`)** in EIP-3009 typehashes — the EIP-3009 spec uses `bytes32 nonce`, and viem's `signTypedData` expects the same.
4. **Use `encodeAbiParameters` (not `encodePacked`)** when matching Solidity's `abi.encode` in TypeScript.
5. **Use `import type` for type-only imports** (`Address`, `Hex`) from `viem` — strip-types compatibility.
6. **Use `deal()` (forge-std cheatcode) for ERC20 balance writes in tests** — `usdc.mint()` consumes a deployer nonce in forge's test environment.
7. **Always run `forge fmt` after writing Solidity** — the project enforces `forge fmt --check` in CI.

## Quick context for Copilot

- The 5 contracts: `MGPGenesis` (canon anchor), `DIDRegistry` (parent-attested DIDs), `LineagePool` (USDC pool + donations), `MatchingEngine` (1:1 match up to 5_000 USDC/mo), `VoucherRedeem` (7-day delayed redemption + repayment tracking).
- Repayment mechanic: Option B (real USDC pull) — when `repay=true`, EIP-3009 `value = amount × 1.01`; the 1% portion is credited against `outstandingRepayment[child]` (capped at `1.2 × voucherAmount`).
- The seal: `0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d` — carried by 5 sources, tampering breaks CI.
- Anvil PK for tests: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` (ending `ff80`, not `cd80`).

## Read these files first

- `AGENTS.md` — universal AI agent instructions
- `DECISIONS.md` — every silent-spec decision with rationale (D1-D8)
- `canon/canon.txt` — the canonical protocol text
- `README.md` — human-facing entry point (also has 11-question FAQ optimized for answer engines)
