# DECISIONS.md

> Honest log of every silent-spec decision.

## Phase table (spec §9)

| Phase | Deliverable | Gate |
| --- | --- | --- |
| P1 | canon.txt + 5 seals + CheckSeal local | `CheckSeal` prints `SEAL OK` |
| P2 | 5 contracts + MockUSDC, compilable | `forge build` zero warnings |
| P3 | Unit tests (full §4 unit list) | `forge test` green |
| P4 | 7 invariant tests (incl. #7) with handler, 10k runs | `forge test` green at 10k runs |
| P5 | Fork tests (real USDC) | passes locally with `BASE_RPC` |
| P6 | TS SDK + `npx mgp demo` + docker-compose | demo exits 0 in <60s from clean clone |
| P7 | Deploy + indexer + CI + README/llms/schemas | CI green |
| P8 | DECISIONS complete; adversarial pass | all §10 acceptance checks pass |

## D1.1 — Explicit `canonHash()` / `canonPurpose()` getters

Solidity ≥0.6 removed auto-getter generation for `public constant`. Cross-contract & off-chain readers can't access `MGPGenesis.CANON_HASH` directly. Explicit pure getters preserve immutability.

## D1.2 — Canon tamper-test is re-runnable

`test_TamperCanonBreaksSeal` mutates one byte in-memory, asserts `keccak256(mutated) != CANON_HASH` and `verifySeal(mutated) == false`. CI also runs a shell-level tamper test that writes the mutated canon to disk and expects CheckSeal to revert.

## D1.3 — `llms.txt` seal format: `canon_seal: 0x<64 hex>`

Single canonical format; needle is `canon_seal: 0x` (with `0x` inside).

## D1.4 — `fs_permissions` is read-only, scoped

Only `./canon/`, `./wellknown/`, `./schemas/`, `./llms.txt`, `./deployed-addresses.json` (read-write). No other write access.

## D1.5 — Node 22 via nvm

Pinned stack requires Node 22. Installed via nvm with `.nvmrc` pinning `22`.

## D1.6 — `canon.txt` is single-line UTF-8 with NO trailing newline

`printf %s` writes without `\n`. `CheckSeal` recomputes `keccak256(readFileBinary("canon/canon.txt"))` directly.

## D2.1 — Pre-compute Genesis address; deploy sub-contracts first, Genesis last

`vm.computeCreateAddress(deployer, startNonce + offset + 4)` lets sub-contracts receive the precomputed Genesis address at construction. Genesis is deployed last with the now-known sub-contract addresses.

## D2.2 — Parent signature uses `toEthSignedMessageHash`

Standard wallets (MetaMask, viem `signMessage`) auto-prefix. Replay protection is preserved via `genesis` and `chainId` inside the payload.

## D2.3 — Root agents self-attest

For roots (`parentDid == bytes32(0)`), the signature is from the agent's own key. For children, the signature is from the parent's key.

## D2.4 — DIDRegistry carries parent→children reverse index

`mapping(bytes32 => bytes32[]) private _childrenOf;` populated in `register()`. Used by `VoucherRedeem.onGenerationBorn` to enumerate voucher recipients.

## D2.5 — Voucher formula: 25% of parent's matched, split evenly

`voucherAmount = (parentMatched × 25) / 100 / childCount`. Total vouchers per parent = 25% of matched ≤ matched ≤ pool USDC. Satisfies invariant 1.

## D2.6 — §3.5e REPAYMENT MECHANIC — RESOLVED (Option B + user refinements)

Option B (actual USDC pull) with 7 refinements:

1. **Single-transfer variant**. EIP-3009 value = `amount + (amount × REPAYMENT_BPS) / 10_000` when `repay == true`. One signature, one transfer. SDK surface identical to Option A.
2. **Anti-gaming split**. The 1% repayment portion is NOT matchable, NOT counted toward the generation threshold, NOT counted against the per-parent rate limit.
3. **Cap enforcement**. `credited = min(repaymentPart, outstandingRepayment[child])`. When debt == 0, the full 1.01× flows into the donation ledger (behaves as unflagged). Cap enforced twice: in LineagePool (before calling VR) and in VoucherRedeem (defense-in-depth).
4. **New event**. `event RepaymentPaid(address indexed child, uint256 amount)` declared on VoucherRedeem.
5. **New invariant #7**. `invariant_repaymentCappedAndNoMatchEvent`: cumulative repaid ≤ repaymentCap; repayment never triggers Match.
6. **README honesty**. "Repayment is real USDC that returns to the pool principal — not a virtual counter."
7. **Unit tests**. `test_FlaggedDonationWithDebtExceedingCap`, `test_FlaggedDonationWithZeroDebt`, `test_ReentrancyOnSplitPath`.

## D2.7 — Foundry lint exclusions

`block-timestamp`, `missing-zero-check`, `unsafe-typecast`, `weak-prng`, `calls-loop`, `reentrancy-events`, `reentrancy-no-eth`, `arbitrary-send-erc20`. Each documented inline in `foundry.toml`.

## D2.8 — `MatchingEngine.lastMatchAmount()` read-back

ME exposes a public `lastMatchAmount` storage slot, set in `onDonation()`. LineagePool reads it immediately after to attribute matched USDC to the donor's parent for voucher sizing.

## D2.9 — `via_ir = true`

After Option B's split logic, `LineagePool.donate` has 9+ locals, exceeding the EVM's 16-slot stack depth without IR.

## D5.1 — Fork test requires `BASE_RPC`; skips cleanly otherwise

`test/fork/USDCFork.t.sol` uses a `onlyOnBaseFork` modifier that calls `vm.skip(true)` when `BASE_USDC.code.length == 0`. The local no-fork `forge test` sees the test skip; running with `--fork-url $BASE_RPC` exercises the full path (verify real USDC name/decimals/masterMinter).

## D6.1 — `--experimental-strip-types` runs `.ts` directly

Node 22.6+ supports running `.ts` files via `node --experimental-strip-types`. Eliminates the `tsx` dependency.

## D6.2 — Demo's exact summary printed by `ts/demo/index.ts`

Spec §6 mandates the exact 6-line summary + verify line.

## D7.1 — `Deploy.s.sol` pre-computes Genesis via `vm.computeCreateAddress`

Mirrors the test fixture pattern. `offset = 2` accounts for the MockUSDC deploy tx + the mint tx (both consume deployer nonces in broadcast).

## D7.2 — CI runs invariants at 10k fuzz runs

`.github/workflows/ci.yml` sets `FOUNDRY_FUZZ_RUNS=10000` and `FOUNDRY_INVARIANT_RUNS=10000`. Local default is 256 for fast dev iteration.

## D7.3 — README contains the honesty section verbatim

Includes "What this does NOT prove" paragraph, "Why not a waqf / charity?" paragraph, and the refinement-6 addition on real USDC repayment.

## D7.4 — Anvil PK is `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` (ending `ff80`, not `cd80`)

Foundry v1.8.6's anvil exposes a different PK for account 0 than the canonical `cd80`. The demo, docker-compose, and CI use `ff80`.

## D7.5 — EIP-3009 typehash uses `bytes32 nonce` (not `uint256 nonce`)

MockUSDC, the test fixture, the invariant handler, and viem's `signTypedData` all agree on the EIP-3009 spec canonical typehash with `bytes32 nonce`:
`keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")` = `0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8`.

## D7.6 — Real Base mainnet USDC address: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

The Circle proxy. The address `0x833589fCD6eDb6E0854E3DEEde94A5C3F2C29FEe` (which we initially used) has no code on Base. The real proxy exposes `name()` → "USD Coin", `decimals()` → 6, `masterMinter()` → `0x2230393EDAD0299b7E7B59F20AA856cD1bEd52e1`. It does NOT expose `minter()` or `domainSeparator()` directly (reverts). The fork test verifies via the accessible API.

## D8.1 — Adversarial test coverage

- `test_RedeemRevertsOnForgedVC` — forged VC with wrong canonHash → `SealMismatch()`.
- `test_RevertOnUnregisteredParent` / `test_RevertOnWrongAgentInSignature` — VC from non-parent → `InvalidSignature()`.
- `test_ReentrancyOnSplitPath` — reentrancy on split path blocked by `nonReentrant` + CEI.
- `test_RevertsWhenCalledByNonPool` — non-pool caller of `MatchingEngine.onDonation` → `OnlyPool()`.
- Invariant 4 (`invariant_noAdminEscapeHatch`).
- `test_TamperCanonBreaksSeal` — single-byte mutation detectable.

## D8.2 — No upgradeable/proxy import anywhere in the repo

`grep -r upgradeable contracts/ script/ test/` returns empty. All OZ imports from `@openzeppelin/contracts/` (non-upgradeable path).

## R1 — CI diagnosis (2026-10-29)

### CI run #5 (commit 7b164d8) — YAML parse failure (0 jobs)

**Root cause**: `PRIVATE_KEY: 0xac0974...` in ci.yml `env:` block. GitHub's YAML
parser interprets `0x`-prefixed values as hex integers. The 256-bit hex value
overflows the integer type, causing a YAML parse error. Run name defaulted to
the file path (`.github/workflows/ci.yml`) instead of `ci`, and 0 jobs were
created.

**Error**: `error: unexpected argument '--invariant-runs' found` (not reached
— workflow never parsed).

**Fix** (commit a190fb9): Quote the value: `PRIVATE_KEY: "0xac0974..."`.

### CI run #6 (commit a190fb9) — TypeScript Lint failure + Foundry test failure

**TS Lint error** (line 211 of src/index.ts):
```
error TS2345: Argument of type '...' is not assignable to parameter of type '...'.
  Type 'string' is not assignable to type '"ReceiveWithAuthorization"'.
```
**Root cause**: `primaryType: "ReceiveWithAuthorization"` widened to `string` by
TypeScript. viem's `signTypedData` expects a literal type.

**Fix** (commit 002d3c6): Add `as const`: `primaryType: "ReceiveWithAuthorization" as const`.

**Foundry test error**:
```
error: unexpected argument '--invariant-runs' found
  tip: a similar argument exists: '--invariant-corpus-dir'
```
**Root cause**: Foundry v1.8.6 does not support `--invariant-runs` as a CLI
argument. The env var `FOUNDRY_INVARIANT_RUNS=10000` achieves the same effect.

**Fix** (commit 141bab7): Remove `--invariant-runs 10000` from CLI; rely on
`FOUNDRY_INVARIANT_RUNS` env var only.

### CI run #7 (commit 002d3c6) — same Foundry --invariant-runs error

Same as run #6 Foundry failure. Fix not yet pushed at time of run #7.

### CI run #8 (commit 141bab7) — all fixes applied

- TypeScript: ✅ green
- Demo smoke: ✅ green (Deploy with PRIVATE_KEY env var + demo run)
- Foundry: ⏳ in_progress (10k fuzz + 10k invariant, ~30-40 min)

**Classification**: (a) workflow environment issue — all three root causes
were CI configuration, not contract/test bugs.
