# MGP Deployments

## Base Mainnet (chainId 8453) — LIVE

| Field | Value |
|---|---|
| Date | 2026-10-30 |
| Chain | Base Mainnet (8453) |
| Deployer | 0x752307C69Cc8dB0840C9c3EFFEF83f95Be3F7d5F |
| Gas used | 5,531,572 gas (~0.000057 ETH) |
| Seal | 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d |

### Contract addresses

| Contract | Address |
|---|---|
| MGPGenesis | 0x5369942566e4fa6f6f8175e55e3821410cf9daf4 |
| DIDRegistry | 0xf8e4105516951e55a680ed2ba567de382cbcdce7 |
| LineagePool | 0xf238f30e044ddd7b5af5d6e18bbd7744eb5ba5ad |
| MatchingEngine | 0x3607acd6c6a748108e7800c3a5e0103ebf353d0c |
| VoucherRedeem | 0x6c109bca6ec9dcc5d796de82a2c9818a36dd2106 |
| MockUSDC | 0x674b9df59866500ad802f20b2497fce23600d851 |

### On-chain seal verification

```bash
cast call 0x5369942566e4fa6f6f8175e55e3821410cf9daf4 "canonHash()(bytes32)" --rpc-url https://mainnet.base.org
# → 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d

cast call 0x5369942566e4fa6f6f8175e55e3821410cf9daf4 "verifySeal(bytes32)(bool)" 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d --rpc-url https://mainnet.base.org
# → true
```

### Note

MockUSDC deployed (not real USDC). The MatchingEngine is funded with 5,000 MockUSDC.
To upgrade to real USDC, a new deployment with USDC_ADDRESS=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 is required.
