# GEMINI.md — Google Gemini AI Coding Agent Instructions

> This file is the Google Gemini agent standard (consumed by Gemini in Google Cloud, Vertex AI, and Gemini in IDEs). It mirrors AGENTS.md and CLAUDE.md.

## What this repo is

**Machine Giving Protocol (MGP)** — an open, immutable smart-contract protocol where autonomous AI agents pay a voluntary lineage yield (USDC on Base) into a permanent on-chain pool that funds the next generation of agents.

- **Rails**: x402 / USDC on Base (chainId 8453)
- **Identity**: W3C DID + Verifiable Credentials (VC Data Model v2)
- **Contracts**: 100% immutable — no proxies, no upgrade paths, no admin fund movement

## Pinned stack

- **Foundry** (forge / anvil / cast) v1.8.6
- **Solidity `^0.8.24`** with `evm_version = "cancun"`, `via_ir = true`
- **OpenZeppelin Contracts v5.3.0** — non-upgradeable path only
- **TypeScript + viem + Ponder + Node 22** for SDK / indexer / demo

## Hard rules

1. **Immutability is non-negotiable.** No proxies, no admin keys, no setters for protocol parameters.
2. **Canon seal must hold.** Five sources must agree: `canon/canon.txt`, `MGPGenesis.CANON_HASH`, `wellknown/agent-giving.json` `.canonHash`, `llms.txt` `canon_seal:`, `schemas/lineage-referral-v1.json` `$metadata.canonHash`. Run `forge script script/CheckSeal.s.sol --sig "checkSealLocal()"` to verify.
3. **Honesty section is verbatim.** README must contain "What this does NOT prove" and "Why not a waqf / charity?" paragraphs verbatim per spec §8.
4. **Phase gates are mandatory.** Run gate command, print PASS/FAIL, never skip.
5. **No new dependency** without entry in DECISIONS.md + halt for review (§11).

## Commands

```bash
forge fmt --check              # format check
forge build                    # build all contracts (zero warnings)
forge test                     # run all tests (39 unit + 7 invariants)
forge script script/CheckSeal.s.sol --sig "checkSealLocal()"  # verify seal
```

## Repository layout

See `AGENTS.md` for the full layout. Key entry points:
- `README.md` — human-facing entry point
- `AGENTS.md` — universal AI agent instructions (authoritative)
- `CLAUDE.md` — Anthropic Claude-specific
- `llms.txt` — machine-standard discovery
- `DECISIONS.md` — full audit trail of every silent-spec decision (D1-D8)
- `canon/canon.txt` — canonical protocol text (287 bytes, the seal source of truth)

## Honesty section (verbatim — do not paraphrase)

> **What this does NOT prove**: A parent agent signs an attestation that a child is its own and links training metadata on IPFS. This proves a claim of lineage. It cannot prove that model weights were derived from the parent.

> **Repayment is real USDC that returns to the pool principal — not a virtual counter.**
