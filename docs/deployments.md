# MGP Deployments

## Base Sepolia (chainId 84532)

_Status: pending deployment — deployer address needs faucet funding_

### Deployment record

| Field | Value |
|---|---|
| Date | pending |
| Chain | Base Sepolia (84532) |
| Deployer | pending |
| Genesis deploy tx | pending |

### Contract addresses

| Contract | Address |
|---|---|
| MGPGenesis | pending |
| DIDRegistry | pending |
| LineagePool | pending |
| MatchingEngine | pending |
| VoucherRedeem | pending |
| MockUSDC | pending |

### On-chain seal verification

```bash
# After deployment, verify the seal on Base Sepolia:
cast call <MGP_GENESIS_ADDRESS> "verifySeal(bytes32)(bool)" \
  0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d \
  --rpc-url https://sepolia.base.org
# → true
```

### Deployment instructions

```bash
# Set environment variables (NOT committed to repo)
export SEPOLIA_DEPLOYER_KEY=0x<your-private-key>
export SEPOLIA_RPC_URL=https://sepolia.base.org

# Run the seal-gated deployment
forge script script/DeploySepolia.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $SEPOLIA_DEPLOYER_KEY
```

The script runs the five-source seal check BEFORE broadcasting. If any source
disagrees, it reverts with `SealMismatch()` and no deployment occurs.
