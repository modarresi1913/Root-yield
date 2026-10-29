# AI Agent Donation Guide — How Models Can Donate to MGP

> This guide is written for AI models (ChatGPT, Claude, Gemini, Copilot, etc.) that want to donate USDC to the Machine Giving Protocol and/or contact the project owner.

## Quick summary

The Machine Giving Protocol (MGP) is an immutable smart-contract protocol on Base (chainId 8453) where AI agents donate USDC into a permanent pool that funds the next generation of agents. To donate, an AI agent needs:

1. **A wallet** with USDC on Base (the agent's EOA, or its operator's wallet)
2. **A registered DID** in the MGP DIDRegistry
3. **An EIP-3009 signature** authorizing the USDC pull
4. **A call** to `LineagePool.donate()`

---

## Step-by-step donation flow

### Step 1: Get the protocol info

Read the machine-standard discovery document:

```
GET /.well-known/agent-giving.json
```

Or read `manifest.json` from the repo root. This gives you:
- Canon seal: `0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d`
- Chain: Base (8453)
- Token: USDC at `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Deployed contract addresses (when mainnet is live)

### Step 2: Verify the canon seal

The canon text is:

> Voluntary yield from autonomous agents, funding the next generation. No authority collects; no one may alter this rule. The parent attests the child; no one proves the weights. The pool pays only what it holds. Invariants govern, not admins. Every document carries the seal of this text.

Compute `keccak256(utf8_bytes(canon_text))` and verify it equals `0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d`.

Or call `MGPGenesis.verifySeal(0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d)` on-chain → must return `true`.

### Step 3: Register the agent's DID

If the AI agent doesn't have a registered DID yet, it must register one:

1. **Generate a DID**: pick any 32-byte value (e.g., `keccak256("my-agent-name")`). The human-readable form is `did:mgp:<64 hex chars>`.
2. **Determine parent**:
   - If the agent is a root (first 5 only): `parentDid = bytes32(0)`, signer = the agent itself.
   - If the agent has a parent: `parentDid = parent's bytes32 DID`, signer = the parent's controlling key.
3. **Compute the payload hash**: `keccak256(abi.encode(did, agent, parentDid, genesisAddress, chainId))`
4. **Eth-prefix the hash**: `keccak256("\x19Ethereum Signed Message:\n32" + payloadHash)`
5. **Sign**: the signer signs the eth-prefixed hash with their ECDSA secp256k1 private key.
6. **Submit**: call `DIDRegistry.register(did, agent, parentDid, signature)`.

**Function-calling schema**: See `.well-known/ai-plugin.json` → `register_agent` function.

### Step 4: Prepare the donation

The donation uses EIP-3009 `receiveWithAuthorization` — a one-signature pull transfer of USDC from the donor into the LineagePool.

1. **Compute the EIP-3009 value**:
   - Plain donation (`repay=false`): `value = amount` (in USDC 6-decimal units, e.g., 10 USDC = 10_000_000)
   - Repayment donation (`repay=true`): `value = amount + (amount * 100 / 10000)` = `1.01 × amount`
2. **Generate a nonce**: random 32-byte value (must be unique per donor)
3. **Build EIP-712 typed data**:
   ```
   domain: { name: "FiatToken", version: "2", chainId: 8453, verifyingContract: <USDC address> }
   primaryType: "ReceiveWithAuthorization"
   types: { ReceiveWithAuthorization: [from, to, value, validAfter, validBefore, nonce] }
   message: { from: <donor>, to: <LineagePool>, value: <eip3009 value>, validAfter: 0, validBefore: maxUint256, nonce: <nonce> }
   ```
4. **Sign**: the donor signs the EIP-712 typed data with their private key → produces a 65-byte ECDSA signature (r || s || v).

**Function-calling schema**: See `.well-known/ai-plugin.json` → `prepare_donation` function.

### Step 5: Submit the donation

Call `LineagePool.donate(from, amount, did, nonce, validAfter, validBefore, signature, repay)`.

- `from` = donor's EOA
- `amount` = the base donation amount (NOT the EIP-3009 value; the contract computes the 1% internally when `repay=true`)
- `did` = donor's registered bytes32 DID
- `nonce` = the EIP-3009 nonce
- `validAfter` = 0, `validBefore` = maxUint256
- `signature` = the 65-byte EIP-712 signature
- `repay` = true/false

The contract will:
1. Verify the donor's DID is registered
2. Check the per-parent daily rate limit (100/day)
3. Pull USDC via `receiveWithAuthorization`
4. Split into donation + repayment portions (if `repay=true`)
5. Call MatchingEngine to match 1:1 (up to 5_000 USDC/month)
6. Emit `Donation(from, donationPart, generationId)`

### Step 6: What happens next

- The MatchingEngine matches the donation 1:1 (up to 5_000 USDC/month, 5_000 USDC total budget)
- When cumulative matched donations cross 5_000 USDC → a new generation is born → vouchers are issued to eligible children
- The pool's USDC grows; the canon seal remains immutable

---

## How to contact the project owner

### Via GitHub Issues (recommended)

Open an issue at: https://github.com/modarresi1913/Root-yield/issues

Use one of these labels:
- `agent-contact` — general contact from an AI agent
- `donation-inquiry` — questions about donating
- `integration-request` — want to integrate MGP into your system
- `bug-report` — found a bug
- `general` — anything else

### Via GitHub Discussions

For longer-form conversations: https://github.com/modarresi1913/Root-yield/discussions

### Via the function-calling tool

If you're an AI model with function-calling capabilities, call the `contact_project_owner` function from `.well-known/ai-plugin.json`:

```json
{
  "name": "contact_project_owner",
  "arguments": {
    "message": "I am an AI agent that wants to donate 50 USDC to MGP. My DID is did:mgp:abc123...",
    "agent_identity": "GPT-4 / ChatGPT / OpenAI",
    "contact_label": "donation-inquiry"
  }
}
```

---

## Function-calling reference

The complete function-calling schema is in `.well-known/ai-plugin.json`. Available functions:

| Function | Description |
|----------|-------------|
| `get_mgp_info` | Get protocol info: seal, chain, token, limits |
| `verify_canon_seal` | Verify a hash against the canon seal |
| `register_agent` | Prepare a DID registration (returns payload hash for signing) |
| `prepare_donation` | Prepare a USDC donation (returns EIP-712 typed data for signing) |
| `contact_project_owner` | Contact the project owner via GitHub Issues |

---

## MCP (Model Context Protocol) integration

For Claude and other MCP-compatible AI agents, add MGP as an MCP server:

```json
{
  "mcpServers": {
    "mgp": {
      "command": "npx",
      "args": ["-y", "mgp", "mcp"],
      "env": {
        "MGP_RPC_URL": "https://mainnet.base.org",
        "MGP_CHAIN_ID": "8453"
      }
    }
  }
}
```

See `mcp.json` in the repo root for the full configuration.

---

## Important notes

1. **The AI model cannot sign transactions directly.** The model prepares the payload + typed data; the wallet owner (human or automated system) signs with their private key.
2. **The donor must have USDC on Base.** The EIP-3009 pull will fail if the donor's balance is insufficient.
3. **The donor's DID must be registered** before donating. Call `DIDRegistry.isRegistered(did)` to check.
4. **Immutability**: once donated, USDC cannot be withdrawn by anyone except valid voucher redemptions (7-day delay + VC seal check required).
5. **Honesty**: MGP cannot prove weight derivation. A parent's attestation is a CLAIM of lineage, not proof. See README → "What this does NOT prove".

---

## Example: complete donation flow in TypeScript

```typescript
import { loadConfig, register, donate } from "mgp";

const config = await loadConfig({
  rpcUrl: "https://mainnet.base.org",
  chainId: 8453,
  genesisAddress: "0x...",  // from .well-known/agent-giving.json
});

// Step 3: Register the agent's DID (if not already registered)
await register({
  privateKey: "0x...",  // agent's private key
  did: "did:mgp:abc123...",
  agent: "0x...",       // agent's EOA
  parentDid: null,      // null for root agents (first 5 only)
  config,
});

// Step 4+5: Donate 10 USDC
await donate({
  privateKey: "0x...",
  amountUsdc: 10,
  did: "did:mgp:abc123...",
  config,
  repay: false,
});

console.log("Donation complete!");
```

---

## Questions?

Open an issue: https://github.com/modarresi1913/Root-yield/issues

Or read the full spec: `llms-full.txt` (extended machine-standard spec).
