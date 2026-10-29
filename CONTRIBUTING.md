# Contributing to Machine Giving Protocol (MGP)

PRs welcome. Before submitting:

1. `forge fmt --check` must be clean
2. `forge build` must be warning-free
3. `forge test` must be green at 10k fuzz + 10k invariant runs (CI override)
4. Any new dependency must be added to `DECISIONS.md` and reviewed (§11 stop condition)
5. Immutability is non-negotiable — no PRs adding proxies, admin keys, or upgrade paths
6. The honesty section in README is verbatim-mandatory — do not paraphrase

## What a contributor should never do

1. **Never import from `@openzeppelin/contracts-upgradeable/`** — the repo is anti-upgrade by design
2. **Never add an admin key or setter** for canon, seal, match ratio, monthly cap, generation threshold, or redemption rules
3. **Never mark a phase complete with red tests**
4. **Never add a new third-party dependency** without halting for human review (§11)
5. **Never paraphrase the honesty section** in README — it's verbatim per spec §8

## What a contributor should do

1. **Read `DECISIONS.md`** for every silent-spec decision + rationale before making new ones
2. **Run `forge fmt --check && forge build && forge test`** before declaring done
3. **Use `deal()` (forge-std cheatcode) instead of `usdc.mint()`** in tests — mint consumes a deployer nonce
4. **Use `import type` for type-only imports** in TS (strip-types compatibility)
5. **Use `encodeAbiParameters`** for `abi.encode` matches (not `encodePacked`)
