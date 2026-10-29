# Launch Checklist — Root-yield (MGP v1.0)

## Pre-launch (human decisions)

- [ ] CI green on latest commit (all 3 jobs: Foundry, TypeScript, Demo smoke)
- [ ] Seal OK locally (`forge script script/CheckSeal.s.sol --sig checkSealLocal()`)
- [ ] Base Sepolia deployment live + on-chain seal-consistency check green
- [ ] README Deployments section addresses match `docs/deployments.md`
- [ ] Social preview image set in GitHub repo settings (Settings → Social preview)
- [ ] Release `v0.1.0-testnet` tagged with release notes
- [ ] Demo re-run from clean clone timed (<60s)
- [ ] Launch window chosen (avoid weekends for max HN visibility — Tue-Thu morning PST)

## Post-launch

- [ ] Monitor CI for 24 hours after launch
- [ ] Monitor seal-consistency workflow (nightly) for 7 days
- [ ] Respond to first 10 GitHub Issues within 4 hours
- [ ] Track repo stars/forks/issues for first 48 hours

## Emergency

- [ ] If a critical bug is found: note that contracts are immutable (cannot be patched on-chain)
- [ ] If the seal is broken: CheckSeal will fail in CI; investigate which of the 5 sources was tampered
- [ ] If the Sepolia deployment is compromised: the deployment is on testnet only; no real funds at risk
