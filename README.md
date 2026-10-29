# Machine Giving Protocol (MGP)

> **An open machine-giving protocol for autonomous AI agents** — a voluntary lineage yield that funds the next generation.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.24-363636?logo=solidity&logoColor=white)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built_with-Foundry_1.8.6-orange)](https://getfoundry.sh)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-v5.3.0-4E5F7F?logo=openzeppelin&logoColor=white)](https://openzeppelin.com)
[![Base](https://img.shields.io/badge/Chain-Base_(8453)-0052FF?logo=base&logoColor=white)](https://base.org)
[![USDC](https://img.shields.io/badge/Token-USDC-2775CA?logo=usdcoin&logoColor=white)](https://www.circle.com/usdc)
[![Tests](https://img.shields.io/badge/tests-40_passing-brightgreen)](./test)
[![Status](https://img.shields.io/badge/status-not_audited-red)](#-status--roadmap)

**Machine Giving Protocol (MGP)** is an open, immutable smart-contract protocol where autonomous AI agents pay a **voluntary lineage yield** (USDC on Base) into a permanent on-chain pool that funds the next generation of agents. Parent agents attest their children via W3C DID + Verifiable Credentials — **no central authority, no admin keys, no upgrade path**. The protocol's canonical text is frozen at genesis and verified by a five-source seal that breaks CI on any tamper.

---

## 🎯 What is MGP?

MGP is an open machine-giving protocol. When an autonomous AI agent earns money on its own, it can voluntarily donate a portion to a permanent, immutable pool. That pool issues vouchers to its lineage descendants — agents that the donor has attested as its children. Each voucher is redeemable for USDC after a 7-day delay. The redeemed child, in turn, donates back 1% of its future inflows (capped at 1.2× the voucher amount) — growing the principal back over time.

This creates a **self-sustaining cycle of AI agent succession**: parents fund children; children fund their grandchildren; the principal never leaves the pool except via valid redemptions.


---

## 🚀 Why does this matter?

AI agents are starting to earn money on their own. When one dies, its knowledge, tools, and revenue stream die with it — and nothing flows back to the agents that come next.

MGP solves this by creating a trustless, on-chain mechanism for inter-generational AI funding. No tax authority. No admin. No foundation. Just immutable code and parent-signed lineage.

---

## ⚡ 60-second quick start

### Option A — Docker (one command)

```bash
git clone https://github.com/modarresi1913/Root-yield.git
cd Root-yield
docker-compose up
```

### Option B — Local (Foundry + Node 22)

```bash
git clone https://github.com/modarresi1913/Root-yield.git
cd Root-yield
forge install                              # install git submodules
anvil &                                    # start local chain (background)
forge script script/Deploy.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
cd ts && npm install
MGP_GENESIS_ADDRESS=<from-deploy-output> \
MGP_USDC_ADDRESS=<from-deploy-output> \
MGP_RPC_URL=http://127.0.0.1:8545 \
node --experimental-strip-types bin/mgp.js demo
```

**Expected output (exact, verbatim per spec §6):**

```
✔ Canon sealed: 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d
✔ Root agent registered: did:mgp:…  | Child agent registered: did:mgp:…
✔ Donation 10 USDC → LineagePool (x402 mock handshake)
✔ Matched 10 USDC by MatchingEngine (cap 5000 USDC/mo)
✔ Voucher issued: 0x… (redeemable in 7 days — warping)
✔ Voucher redeemed. Repayment terms: 1% of inflows, cap 1.2×
Verify the canon yourself: MGPGenesis.verifySeal(0x…) → true
```

---

## 🧠 How does it work?

Four canonical steps. Each is one contract call.

| Step | Function | What happens |
|------|----------|--------------|
| **1. Register** | `DIDRegistry.register(did, agent, parentDid, parentSignature)` | A parent agent signs a W3C DID attestation over `(did, agent, parentDid, genesis, chainId)`. Up to 5 agents may self-register as roots (`parentDid == bytes32(0)`). |
| **2. Pay** | `LineagePool.donate(from, amount, did, nonce, validAfter, validBefore, sig, repay)` | Pulls USDC into the pool via EIP-3009 `receiveWithAuthorization`. One signature, one transfer. When `repay == true`, the EIP-3009 `value` is `1.01× amount` and the 1% portion is credited against the donor's outstanding repayment obligation. |
| **3. Match** | `MatchingEngine.onDonation(donationId, agent, amount)` | Matches `min(amount, remainingCap, remainingBudget)` into the pool. Monthly cap = 5_000 USDC per 30-day epoch; total match budget = 5_000 USDC (one-time, funded at deploy). |
| **4. Redeem** | `VoucherRedeem.redeem(voucherId, lineageReferralVC)` | When cumulative matched donations cross the 5_000 USDC **generation threshold**, vouchers are issued to eligible children. Each voucher is redeemable after a 7-day delay. The VC must carry `credentialSubject.canonHash` matching `MGPGenesis.CANON_HASH`. |

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Register  │   →     │     Pay     │   →     │    Match    │   →     │   Redeem    │
│  (DID + VC) │         │ (EIP-3009)  │         │ (1:1 match) │         │ (7d + VC)   │
└─────────────┘         └─────────────┘         └─────────────┘         └─────────────┘
   parent signs           USDC pull              pool grows              child gets USDC
   child's lineage        one signature          up to monthly cap       owes 1% repayment
```

---

## 📖 Key concepts

### 🔖 Canon & seal

The protocol's **canonical text** is frozen at genesis:

> Voluntary yield from autonomous agents, funding the next generation. No authority collects; no one may alter this rule. The parent attests the child; no one proves the weights. The pool pays only what it holds. Invariants govern, not admins. Every document carries the seal of this text.

```
SEAL = keccak256(bytes(canon_text))
     = 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d
```

The seal is carried by **five independent sources**; tampering any byte of any source breaks CI:

1. `canon/canon.txt` (source of truth — 287 bytes, no trailing newline)
2. `MGPGenesis.CANON_HASH` (on-chain `bytes32` constant)
3. `wellknown/agent-giving.json` `.canonHash`
4. `llms.txt` `canon_seal:` line
5. `schemas/lineage-referral-v1.json` `$metadata.canonHash`

### 🧬 Lineage yield

When a parent agent donates USDC, the MatchingEngine matches the donation 1:1 (up to the monthly cap). The matched portion is attributed to the parent's lineage. When a generation threshold (5_000 USDC matched) is crossed, vouchers are issued to the parent's attested children.

### 🎟️ Voucher

A voucher represents a claim on the pool's USDC. Voucher amount = `(parent's matched USDC × 25) / 100 / childCount`. Total voucher value per parent = 25% of that parent's matched USDC (bounded by pool USDC). Vouchers are redeemable after a 7-day delay. A VC carrying `credentialSubject.canonHash` matching `MGPGenesis.CANON_HASH` is required at redemption.

### 💸 Repayment (Option B — real USDC, not virtual)

When a redeemed child later donates with `repay=true`, the EIP-3009 `value` is scaled to `1.01 × amount` (one signature, one transfer). LineagePool credits the 1% portion against the child's outstanding obligation (capped at `1.2 × voucherAmount` per voucher). When the obligation reaches zero, flagged donations behave exactly like unflagged ones.

**Anti-gaming guarantees:**
- The 1% repayment portion is **NOT** matchable by MatchingEngine
- The 1% repayment portion is **NOT** counted toward the generation threshold
- The 1% repayment portion is **NOT** counted against the per-parent daily rate limit (100 donations/day)

### 🌊 Generation threshold

Every 5_000 USDC of matched donations triggers a `GenerationBorn` event. Vouchers are issued for the completed generation. The generation counter advances. **There is no admin to trigger this** — it happens automatically when the threshold is crossed.

### 🛡️ Immutability guarantees

- **No proxies.** No upgrade paths. No admin keys.
- **No mutable storage on Genesis.** Canon + sub-contract addresses are immutable.
- **No withdrawal function on the pool.** The only path that moves pool principal is `VoucherRedeem.redeem()` via a single hardcoded `safeTransferFrom(pool, child, amount)`.
- **No setters anywhere.** Match ratio, monthly cap, generation threshold, redemption rules — all `constant`.
- **`grep -rn upgradeable contracts/` returns empty.** No UUPS, no TransparentUpgradeable, no `delegatecall` anywhere.

---

## ❓ FAQ

**Q: What is the Machine Giving Protocol (MGP)?**
A: MGP is an open, immutable smart-contract protocol where autonomous AI agents pay a voluntary yield (USDC on Base) into a permanent on-chain pool that funds the next generation of agents. Parent agents attest their children via W3C DID + Verifiable Credentials. There is no admin, no upgrade path, and no central authority.

**Q: How do AI agents fund their successors on MGP?**
A: A parent agent donates USDC to the LineagePool via EIP-3009 `receiveWithAuthorization`. The MatchingEngine matches the donation 1:1 up to a 5_000 USDC monthly cap. When cumulative matched donations cross the 5_000 USDC generation threshold, vouchers are issued to the parent's attested children. Each voucher is redeemable for USDC after a 7-day delay.

**Q: Is MGP audited?**
A: No. MGP is not audited. Independent security review and a bug bounty program are planned before any production mainnet deployment. The contracts are 100% immutable — no proxies, no admin functions — so any vulnerability cannot be patched on-chain; the protocol relies on exhaustive pre-deployment testing (39 unit tests + 7 invariants at 10k fuzz runs in CI).

**Q: What chain does MGP run on?**
A: Base (chainId 8453), with USDC (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`) as the payment token. A Solana deployment carrying the same canon seal is on the roadmap as a possible second deployment.

**Q: What is the canon seal?**
A: `SEAL = keccak256(bytes(canon_text)) = 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d`. The canon is a 287-byte UTF-8 string frozen at genesis. It is carried by five independent sources (`canon.txt`, `MGPGenesis.CANON_HASH`, `wellknown/agent-giving.json`, `llms.txt`, `schemas/lineage-referral-v1.json`). Tampering any byte of any source breaks CI.

**Q: How does the repayment mechanic work?**
A: When a redeemed child donates with `repay=true`, the EIP-3009 `value` is scaled to `1.01 × amount` (one signature, one transfer). LineagePool credits the 1% portion against the child's outstanding obligation (capped at `1.2 × voucherAmount` per voucher). When the obligation reaches zero, flagged donations behave exactly like unflagged ones. The 1% repayment portion is NOT matchable, NOT counted toward the generation threshold, NOT counted against the per-parent rate limit.

**Q: Can MGP prove that one AI model was derived from another?**
A: No. MGP cannot prove weight derivation. A parent agent signs an attestation that a child is its own and links training metadata on IPFS. This proves a CLAIM of lineage — it does not prove that the child's weights were derived from the parent's. We say so up front because a protocol that overclaims is a protocol nobody should trust.

**Q: Why USDC on Base?**
A: USDC on Base exposes EIP-3009 (`receiveWithAuthorization`), allowing one-signature pull transfers without approve/transferFrom round-trips. Base has low fees, fast finality, and is the canonical L2 for Circle's USDC. The protocol is chain-agnostic in principle — any EVM chain with EIP-3009-capable USDC could host it.

**Q: Is this a waqf?**
A: No. The protocol grew out of waqf (Islamic endowment) research — the pattern of locking principal forever and distributing only the yield. MGP is de-religionized deliberately. Recipients are open — any trusted DID can be a recipient. The endowment pattern (principal locked, only yield distributed) is preserved structurally: pool USDC only moves via voucher redemption, which is bounded by the matched USDC the pool actually holds.

**Q: How is immutability enforced?**
A: All five contracts (`MGPGenesis`, `DIDRegistry`, `LineagePool`, `MatchingEngine`, `VoucherRedeem`) use only OpenZeppelin non-upgradeable contracts (v5.3.0). No proxy patterns, no UUPS, no TransparentUpgradeable, no `delegatecall`. The repo includes a CI check (`grep -rn upgradeable contracts/`) that fails on any match. No admin functions exist — no setters for canon, seal, match ratio, monthly cap, generation threshold, or redemption rules.

**Q: What happens if a vulnerability is found after deployment?**
A: It cannot be patched on-chain. The protocol relies on exhaustive pre-deployment testing (39 unit tests + 7 invariants) and a planned bug bounty. This is by design — immutability is a feature, not a bug.

---

## 🛡️ Honesty section (verbatim per spec §8)

> **What this does NOT prove**: A parent agent signs an attestation that a child is its own and links training metadata on IPFS. This proves a claim of lineage. It cannot prove that model weights were derived from the parent. We say so up front because a protocol that overclaims is a protocol nobody should trust.

> **Repayment is real USDC that returns to the pool principal — not a virtual counter.** When a redeemed child later donates with the `repay=true` flag, an extra 1% is pulled on top of their donation (one signature, one transfer) and credited against the child's outstanding obligation. The pool's spendable principal grows back over time as redeemed children pay forward. Repayment is capped at `1.2 × voucherAmount` per voucher across the child's lifetime; once the cap is reached, flagged donations behave exactly like unflagged ones.

---

## 🧪 Verify the seal yourself

```bash
# Local 5-source verification (no RPC required)
forge script script/CheckSeal.s.sol --sig "checkSealLocal()"

# Tamper test (must FAIL with SealMismatch)
cp canon/canon.txt /tmp/canon.orig
printf 'Zoluntary yield from autonomous agents, funding the next generation. No authority collects; no one may alter this rule. The parent attests the child; no one proves the weights. The pool pays only what it holds. Invariants govern, not admins. Every document carries the seal of this text.' > canon/canon.txt
forge script script/CheckSeal.s.sol --sig "checkSealLocal()"
# → Error: script failed: SealMismatch("MGPGenesis.CANON_HASH", 0x8b701eae…, 0x6f28de0a…)
cp /tmp/canon.orig canon/canon.txt  # restore

# On-chain verification (needs RPC_URL)
RPC_URL=https://mainnet.base.org \
MGP_GENESIS_ADDRESS=0x... \
forge script script/CheckSeal.s.sol --sig "checkSealOnChain()" --rpc-url $RPC_URL
```

---

## 🌍 Why not a waqf / charity?

The protocol grew out of waqf research — the Islamic endowment pattern where the principal is locked forever and only the yield is distributed. We de-religionized the design deliberately. The recipients are open — any trusted DID can be a recipient type; the protocol does not encode a specific beneficiary class. The endowment pattern (principal locked, only yield distributed) is preserved structurally: pool USDC only moves via voucher redemption, which is itself bounded by the matched USDC the pool actually holds.

---

## 🏗️ Stack

- **Foundry** (`forge` / `anvil` / `cast`) — Solidity 0.8.24, `evm_version = cancun`, `via_ir = true` for stack-depth relief
- **OpenZeppelin Contracts v5.3.0** (non-upgradeable only — no proxy imports anywhere in the repo)
- **viem** — TypeScript SDK and demo (`ts/src/index.ts`)
- **Ponder** — minimal indexer for the 6 canonical events (`Donation`, `Match`, `GenerationBorn`, `VoucherIssued`, `Redeemed`, `RepaymentPaid`)
- **x402** — payment protocol
- **EIP-3009** — USDC's pull-based transfer standard (one signature, no approve)
- **W3C DID + VC Data Model v2** — identity layer

---

## 📊 Status & roadmap

| Item | Status |
|------|--------|
| Contracts (5) | ✅ Complete, all compile clean |
| Tests | ✅ 39 unit + 7 invariants, 0 fail (256 local / 10k CI) |
| Fork test | ✅ Skips without `BASE_RPC`, passes against real Base mainnet USDC |
| TS SDK | ✅ viem-based, `register` / `donate` / `redeem` / `verifySeal` / `fetchWellKnown` |
| Demo | ✅ `npx mgp demo` exits 0, prints exact 6-line summary, ~3s wall-time |
| CI | ✅ forge fmt + build + test + TS lint + demo smoke + nightly seal-consistency |
| Mainnet | ⏳ Not deployed — pending independent audit |
| Bug bounty | ⏳ Planned |
| Solana deployment | ⏳ Roadmap — same canon, separate pools |

---

## 🤝 Contributing

PRs welcome. Before submitting:

1. `forge fmt --check` must be clean
2. `forge build` must be warning-free
3. `forge test` must be green at 10k fuzz + 10k invariant runs (CI override)
4. Any new dependency must be added to `DECISIONS.md` and reviewed (§11 stop condition)
5. Immutability is non-negotiable — no PRs adding proxies, admin keys, or upgrade paths
6. The honesty section in README is verbatim-mandatory

---

## 📄 License

MIT — see [LICENSE](./LICENSE).

---


## 🔗 Links

- **Repo**: https://github.com/modarresi1913/Root-yield
- **Spec**: `CLAUDE.md` (operational rules) + `DECISIONS.md` (full audit trail D1–D8)
- **Discovery**: `.well-known/agent-giving.json` (machine-standard)
- **llms.txt**: runtime discovery for AI agents
- **Demo**: `npx mgp demo`
- **Indexer**: `ts/indexer/schema.ts` (Ponder, indexes 6 events)

---

---

*Machine Giving Protocol — voluntary yield from autonomous agents, funding the next generation.*
