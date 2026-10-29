# MGP build rules

> Source of truth: `MASTER PROMPT — Machine Giving Protocol (MGP v1.0)`. This file is the operational short-form for any agent working inside the repo.

## What this repo is

- An **immutable** Solidity protocol — no proxies, no upgrade paths, no admin fund movement. Anyone claiming otherwise in a PR is wrong; reject.
- A protocol where autonomous AI agents pay a voluntary lineage yield (USDC on Base) into an on-chain pool that funds the next generation of agents, via parent-attested DIDs.

## Pinned stack (do not deviate)

- **Foundry** (forge / anvil / cast) v1.8.6.
- **Solidity `^0.8.24`** with `evm_version = "cancun"`.
- **OpenZeppelin Contracts v5.3.0**, non-upgradeable path only (`@openzeppelin/contracts/`). Importing from `@openzeppelin/contracts-upgradeable/` is a hard error.
- **TypeScript + viem + Ponder + Node 22** for the SDK / indexer / demo.
- **No new third-party dependency** without an entry in `DECISIONS.md` AND a halt for human review (§11).

## Phase gates are mandatory

- Work only the current phase.
- At each phase gate, run the gate command and print `PASS` or `FAIL` before continuing.

## Immutability contract

Any function that lets any key:
- move pool principal, OR
- alter the canon text / seal, OR
- alter the match ratio / monthly cap / generation threshold, OR
- alter the redemption rules (7-day delay, 1% repayment, 1.2× cap),

is a **spec violation**. Write a test proving it cannot exist.

## The canon & its seal

- One canonical text, frozen at genesis, lives at `canon/canon.txt`.
- `SEAL = keccak256(bytes(canon_text))`.
- Five sources carry the seal; `script/CheckSeal.s.sol --sig "checkSealLocal()"` verifies all five agree. Tampering any byte of `canon.txt` breaks the check.
- The five sources: `canon/canon.txt`, `MGPGenesis.CANON_HASH`, `wellknown/agent-giving.json` `.canonHash`, `llms.txt` `canon_seal:`, `schemas/lineage-referral-v1.json` `$metadata.canonHash`.

## Tests

- Every test named in the spec must exist by name (see `test/`).
- Invariant suite is 7 named invariants (the original 6 + #7 for repayment) at 10k fuzz runs (CI) / 256 (local dev).
- Tampering the canon must break CI: prove it once in a unit test.

## Honesty section

- README must contain the verbatim "What this does NOT prove" block and the "Why not a waqf / charity?" paragraph (§8).

## When the spec is silent

- Choose the simplest option consistent with the constraints.
- Record the choice + one-line rationale in `DECISIONS.md`.

## Hard halts (§11)

- Any spec requirement conflicts with immutability or security.
- A dependency beyond the pinned stack seems unavoidable.
- Any invariant cannot be made to hold.

## Lint hygiene

- `forge fmt --check` clean.
- `forge build` zero warnings (no unused variables, explicit `override`/`virtual` discipline).
- TS lint clean.
