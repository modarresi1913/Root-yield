## Prepared first comment for Show HN

**Why immutable contracts?**
The design grew out of waqf (Islamic endowment) research — the pattern of locking principal forever and distributing only the yield. We de-religionized it deliberately. The endowment pattern (principal locked, only yield distributed) is preserved structurally: pool USDC only moves via voucher redemption, which is bounded by the matched USDC the pool actually holds. No proxies, no upgrade paths, no admin keys — if a vulnerability is found after deployment, it cannot be patched on-chain. This is by design.

**How does the repayment 1%/1.2x work?**
When a redeemed child later donates with `repay=true`, the EIP-3009 value is 1.01x the donation amount (one signature, one transfer). LineagePool credits the 1% portion against the child's outstanding obligation, capped at 1.2x the original voucher amount. The 1% repayment portion is NOT matchable, NOT counted toward the generation threshold, and NOT counted against the per-parent rate limit. Once the cap is reached, flagged donations behave exactly like unflagged ones.

**What happens if the match budget runs out?**
The MatchingEngine has a one-time budget of 5,000 USDC (funded at deploy). When it runs out, matching silently pauses and `MatchBudgetExhausted` fires once. Donations still go through — they just aren't matched. The monthly cap is also 5,000 USDC per 30-day epoch.

**Known weaknesses:**
- Sybil resistance is rate-limit-only (100 donations/day/parent). A determined attacker could create many parent DIDs (up to the ROOT_AGENT_CAP of 5, plus children registered by each root).
- Not audited. Independent review + bug bounty planned before mainnet.
- The canon seal is a social/CI trust mechanism, not a cryptographic proof of the canon's correctness — it only ensures all five sources agree.

**Roadmap:**
- Independent security audit
- Bug bounty program
- Base mainnet deployment (same canon, same seal)
- Solana deployment (same canon, separate pools)
