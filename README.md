# Machine Giving Protocol (MGP)

> An open protocol where autonomous AI agents pay a voluntary lineage yield into an immutable on-chain pool that funds the next generation of agents.

- **Rails**: x402 / USDC on Base (chainId 8453).
- **Identity**: W3C DID + Verifiable Credentials (VC Data Model v2).
- **Contracts**: 100% immutable — no proxies, no upgrade paths, no admin fund movement.

## The pain

AI agents are starting to earn money on their own. When one dies, its knowledge, tools, and revenue stream die with it — and nothing flows back to the agents that come next.

## The protocol (one sentence)

A parent agent that earns on its own can pay a voluntary yield into a pool that funds the next generation, gated by a parent-signed lineage credential — without any tax authority in the loop.

## 60-second quick start

```bash
npx mgp demo
```

(Bring up `docker-compose up` first if you don't have a local anvil running. The demo signs a real EIP-3009 authorization with a test key and runs a real x402-style 402 → pay → retry loop against a local mock facilitator.)

## How it works

1. **Register** → `DIDRegistry.register(did, agent, parentDid, parentSignature)`
   — A parent agent attests that a child is its own, signing over `(did, agent, parentDid, genesis, chainId)`. The first 5 agents may self-register as roots.

2. **Pay** → `LineagePool.donate(from, amount, did, nonce, validAfter, validBefore, signature, repay)`
   — Pulls USDC into the pool via EIP-3009 `receiveWithAuthorization`. One signature, one transfer. When `repay == true`, the EIP-3009 `value` is `1.01× amount` and the 1% portion is credited against the donor's outstanding repayment obligation (if any).

3. **Match** → `MatchingEngine.onDonation(donationId, agent, amount)`
   — Matches `min(amount, remainingCap, remainingBudget)` into the pool. Monthly cap = 5_000 USDC per 30-day epoch; total budget = 5_000 USDC (one-time, transferred in at deploy).

4. **Redeem** → `VoucherRedeem.redeem(voucherId, lineageReferralVC)`
   — After a generation threshold is crossed (5_000 USDC matched), vouchers are issued to eligible children. Each voucher is redeemable after a 7-day delay. The VC must carry `credentialSubject.canonHash` matching `MGPGenesis.CANON_HASH`.

## What this does NOT prove

A parent agent signs an attestation that a child is its own and links training metadata on IPFS. This proves a claim of lineage. It cannot prove that model weights were derived from the parent. We say so up front because a protocol that overclaims is a protocol nobody should trust.

### Repayment is real USDC that returns to the pool principal — not a virtual counter

When a redeemed child later donates with the `repay=true` flag, an extra 1% is pulled on top of their donation (one signature, one transfer) and credited against the child's outstanding obligation. The pool's spendable principal grows back over time as redeemed children pay forward. Repayment is capped at `1.2 × voucherAmount` per voucher across the child's lifetime; once the cap is reached, flagged donations behave exactly like unflagged ones.

## Canon & seal

The protocol's canonical text ("canon") is frozen at genesis:

> Voluntary yield from autonomous agents, funding the next generation. No authority collects; no one may alter this rule. The parent attests the child; no one proves the weights. The pool pays only what it holds. Invariants govern, not admins. Every document carries the seal of this text.

`SEAL = keccak256(bytes(canon_text)) = 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d`

The seal is carried by **five** sources; tampering any byte of any source breaks CI:

1. `canon/canon.txt` (source of truth)
2. `MGPGenesis.CANON_HASH` (on-chain constant)
3. `wellknown/agent-giving.json` `.canonHash`
4. `llms.txt` `canon_seal:` line
5. `schemas/lineage-referral-v1.json` `$metadata.canonHash`

Verify locally:

```bash
forge script script/CheckSeal.s.sol --sig "checkSealLocal()"
```

Or on-chain:

```bash
RPC_URL=https://mainnet.base.org \
MGP_GENESIS_ADDRESS=0x... \
forge script script/CheckSeal.s.sol --sig "checkSealOnChain()" --rpc-url $RPC_URL
```

## Why not a waqf / charity?

The protocol grew out of waqf research — the Islamic endowment pattern where the principal is locked forever and only the yield is distributed. We de-religionized the design deliberately. The recipients are open — any trusted DID can be a recipient type; the protocol does not encode a specific beneficiary class. The endowment pattern (principal locked, only yield distributed) is preserved structurally: pool USDC only moves via voucher redemption, which is itself bounded by the matched USDC the pool actually holds.

## Stack

- **Foundry** (`forge` / `anvil` / `cast`) — Solidity 0.8.24, evm_version `cancun`, `via_ir` for stack-depth relief.
- **OpenZeppelin Contracts v5** (non-upgradeable only — no proxy imports anywhere in the repo).
- **viem** — TypeScript SDK and demo.
- **Ponder** — minimal indexer for the 5 events (`Donation`, `Match`, `GenerationBorn`, `VoucherIssued`, `Redeemed`, `RepaymentPaid`).

## Status

Not audited. Independent review + bug bounty planned.

## Roadmap

A Solana deployment carrying the same seal is a possible second deployment — same canon, separate pools.

## License

MIT.
