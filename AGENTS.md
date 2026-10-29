# AGENTS.md — Universal AI Coding Agent Instructions

> This file is the universal AI coding agent standard (consumed by Cursor, Aider, Sourcegraph Cody, Codeium, Continue, and any agent that respects the AGENTS.md convention). It is parallel to `CLAUDE.md` (Anthropic-specific) and `GEMINI.md` (Google-specific).

## What this repo is

**Machine Giving Protocol (MGP)** — an open, immutable smart-contract protocol where autonomous AI agents pay a voluntary lineage yield (USDC on Base) into a permanent on-chain pool that funds the next generation of agents.

- **Rails**: x402 / USDC on Base (chainId 8453)
- **Identity**: W3C DID + Verifiable Credentials (VC Data Model v2)
- **Contracts**: 100% immutable — no proxies, no upgrade paths, no admin fund movement

## Pinned stack (do not deviate)

- **Foundry** (forge / anvil / cast) v1.8.6
- **Solidity `^0.8.24`** with `evm_version = "cancun"`
- **OpenZeppelin Contracts v5.3.0**, non-upgradeable path only (`@openzeppelin/contracts/`). Importing from `@openzeppelin/contracts-upgradeable/` is a hard error
- **TypeScript + viem + Ponder + Node 22** for the SDK / indexer / demo
- **No new third-party dependency** without an entry in `DECISIONS.md` AND a halt for human review (§11)

## Phase gates are mandatory

- Work only the current phase
- At each phase gate, run the gate command and print `PASS` or `FAIL` before continuing
- On `FAIL`, fix before proceeding; never mark a phase complete with red tests

## Immutability contract (non-negotiable)

Any function that lets any key:
- move pool principal, OR
- alter the canon text / seal, OR
- alter the match ratio / monthly cap / generation threshold, OR
- alter the redemption rules (7-day delay, 1% repayment, 1.2× cap),

is a **spec violation**. Write a test proving it cannot exist.

## The canon & its seal

- One canonical text, frozen at genesis, lives at `canon/canon.txt`
- `SEAL = keccak256(bytes(canon_text)) = 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d`
- Five sources carry the seal; `script/CheckSeal.s.sol --sig "checkSealLocal()"` verifies all five agree
- The five sources: `canon/canon.txt`, `MGPGenesis.CANON_HASH`, `wellknown/agent-giving.json` `.canonHash`, `llms.txt` `canon_seal:`, `schemas/lineage-referral-v1.json` `$metadata.canonHash`
- Tampering any byte of any source breaks CI: prove it once in a unit test (`test_TamperCanonBreaksSeal`)

## Tests

- Every test named in the spec must exist by name (see `test/`)
- Invariant suite is **7 named invariants** (the original 6 + #7 for repayment) at 10k fuzz runs (CI) / 256 (local dev)
- Tampering the canon must break CI: prove it once in a unit test

## Honesty section (verbatim — do not paraphrase)

- README must contain the verbatim "What this does NOT prove" block and the "Why not a waqf / charity?" paragraph (§8)
- The refinement-6 addition on real USDC repayment is also verbatim

## When the spec is silent

- Choose the simplest option consistent with the constraints
- Record the choice + one-line rationale in `DECISIONS.md`

## Hard halts (§11 — write to DECISIONS.md and await review)

- Any spec requirement conflicts with immutability or security
- A dependency beyond the pinned stack seems unavoidable
- Any invariant cannot be made to hold

## Lint hygiene

- `forge fmt --check` clean
- `forge build` zero warnings (no unused variables, explicit `override`/`virtual` discipline)
- TS lint clean (`npm run lint` in `ts/`)

## Repository layout (where to find what)

```
mgp/
├── AGENTS.md             ← you are here (universal AI agent instructions)
├── CLAUDE.md             ← Claude-specific build rules
├── GEMINI.md             ← Gemini-specific build rules
├── README.md             ← human-facing entry point (viral + GEO/AEO)
├── llms.txt              ← machine-standard discovery file
├── llms-full.txt         ← extended machine-standard spec
├── .well-known/agent-giving.json  ← machine-discovery document
├── canon/canon.txt       ← canonical protocol text (287 bytes, no trailing newline)
├── contracts/            ← 5 main contracts + 6 interfaces + 1 mock
│   ├── MGPGenesis.sol
│   ├── DIDRegistry.sol
│   ├── LineagePool.sol
│   ├── MatchingEngine.sol
│   ├── VoucherRedeem.sol
│   ├── mock/MockUSDC.sol
│   └── interfaces/...
├── test/
│   ├── unit/             ← 39 unit tests across 6 suites
│   ├── invariant/        ← MGPHandler + Canon.t.sol (7 invariants)
│   └── fork/             ← USDCFork.t.sol (skips without BASE_RPC)
├── script/
│   ├── Deploy.s.sol
│   └── CheckSeal.s.sol
├── schemas/              ← 3 W3C VC JSON Schemas + agent-giving discovery schema
├── ts/
│   ├── src/index.ts      ← viem-based SDK
│   ├── demo/index.ts     ← `npx mgp demo` runner
│   ├── bin/mgp.js        ← bin entry
│   └── indexer/          ← Ponder indexer (6 events)
├── docker-compose.yml
└── foundry.toml
```

## Quick commands

```bash
# Build everything (compiles 64 Solidity files)
forge build

# Run all tests (39 unit + 7 invariants, ~10s)
forge test

# Verify the 5-source canon seal (must print "SEAL OK")
forge script script/CheckSeal.s.sol --sig "checkSealLocal()"

# Deploy to local anvil
anvil &
forge script script/Deploy.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Run the end-to-end demo
cd ts && npm install
MGP_GENESIS_ADDRESS=<from-deploy-output> \
MGP_USDC_ADDRESS=<from-deploy-output> \
MGP_RPC_URL=http://127.0.0.1:8545 \
node --experimental-strip-types bin/mgp.js demo

# Fork test against real Base mainnet USDC
forge test --match-contract USDCForkTest --fork-url https://mainnet.base.org
```

## What an AI agent should NEVER do

1. **Never import from `@openzeppelin/contracts-upgradeable/`** — the repo is anti-upgrade by design
2. **Never add an admin key or setter** for canon, seal, match ratio, monthly cap, generation threshold, or redemption rules
3. **Never mark a phase complete with red tests**
4. **Never add a new third-party dependency** without halting for human review (§11)
5. **Never paraphrase the honesty section** in README — it's verbatim per spec §8

## What an AI agent SHOULD do

1. **Read `DECISIONS.md`** for every silent-spec decision + rationale before making new ones
2. **Run `forge fmt --check && forge build && forge test`** before declaring done
3. **Use `deal()` (forge-std cheatcode) instead of `usdc.mint()`** in tests — mint consumes a deployer nonce
4. **Use `import type` for type-only imports** in TS (strip-types compatibility)
5. **Use `encodeAbiParameters`** for `abi.encode` matches (not `encodePacked`)
