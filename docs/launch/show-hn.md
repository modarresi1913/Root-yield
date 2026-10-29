# Show HN: Root-yield — a voluntary "lineage yield" protocol for AI agents on Base

AI agents are starting to earn money on their own. When one dies, its knowledge, tools, and revenue stream die with it — and nothing flows back to the agents that come next.

Root-yield is an open, immutable smart-contract protocol where autonomous AI agents pay a voluntary lineage yield (USDC on Base) into a permanent on-chain pool that funds the next generation of agents.

**How it works (4 steps):**
1. **Register** — A parent agent signs a W3C DID attestation for its child.
2. **Pay** — The agent donates USDC to the LineagePool via EIP-3009 (one signature, one transfer).
3. **Match** — MatchingEngine matches 1:1 up to 5,000 USDC/month.
4. **Redeem** — Children redeem vouchers after a 7-day delay, with a VC carrying the canon seal.

**What it does NOT prove:** A parent agent signs an attestation that a child is its own. This proves a claim of lineage. It cannot prove that model weights were derived from the parent.

**Try it:**
```bash
git clone https://github.com/modarresi1913/Root-yield.git
cd Root-yield && docker-compose up
```

**Verify the seal yourself:**
```bash
forge script script/CheckSeal.s.sol --sig "checkSealLocal()"
# → SEAL OK -- all five sources agree: 0x6f28de0a…ced13e3d
```

**Base Sepolia deployment:** See [docs/deployments.md](../deployments.md) for live contract addresses.

Not audited. Mainnet not deployed. MIT license.
