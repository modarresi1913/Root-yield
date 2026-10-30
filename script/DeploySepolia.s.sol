// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MGPGenesis} from "../contracts/MGPGenesis.sol";
import {DIDRegistry} from "../contracts/DIDRegistry.sol";
import {LineagePool} from "../contracts/LineagePool.sol";
import {MatchingEngine} from "../contracts/MatchingEngine.sol";
import {VoucherRedeem} from "../contracts/VoucherRedeem.sol";
import {MockUSDC} from "../contracts/mock/MockUSDC.sol";

/// @title DeploySepolia.s.sol -- Base Sepolia deployment with seal gate.
/// @notice Reads SEPOLIA_DEPLOYER_KEY and SEPOLIA_RPC_URL from environment.
///         Runs the five-source seal check BEFORE broadcasting anything.
///         Reverts with SealMismatch() if any source disagrees.
contract DeploySepolia is Script {
    error SealMismatch(string source, bytes32 expected, bytes32 actual);

    uint256 internal constant INITIAL_MATCH_BUDGET = 5_000e6;
    uint256 internal constant SEPOLIA_CHAIN_ID = 84532;

    function run() public {
        // ── SEAL GATE ──────────────────────────────────────────────
        // The seal gate runs BEFORE any broadcast. If any of the five
        // sources disagree, revert -- no deployment happens.
        bytes32 expectedSeal = keccak256(vm.readFileBinary("canon/canon.txt"));
        MGPGenesis probe = new MGPGenesis(address(0), address(0), address(0), address(0));
        bytes32 genesisHash = probe.canonHash();
        _check("MGPGenesis.CANON_HASH", expectedSeal, genesisHash);

        bytes32 wellKnownHash = vm.parseBytes32(
            vm.parseJsonString(vm.readFile("wellknown/agent-giving.json"), ".canonHash")
        );
        _check("wellknown/agent-giving.json", expectedSeal, wellKnownHash);

        bytes32 llmsSeal = _extractLlmsSeal(vm.readFile("llms.txt"));
        _check("llms.txt", expectedSeal, llmsSeal);

        bytes32 schemaHash = vm.parseBytes32(
            vm.parseJsonString(
                vm.readFile("schemas/lineage-referral-v1.json"), ".$metadata.canonHash"
            )
        );
        _check("schemas/lineage-referral-v1.json", expectedSeal, schemaHash);

        bytes32 recomputedPurpose = keccak256(bytes(probe.canonPurpose()));
        _check("MGPGenesis.CANON_PURPOSE (recomputed)", expectedSeal, recomputedPurpose);

        console2.log("SEAL GATE PASSED -- all five sources agree:");
        console2.logBytes32(expectedSeal);
        // ── END SEAL GATE ──────────────────────────────────────────

        uint256 deployerPk = vm.envUint("SEPOLIA_DEPLOYER_KEY");
        address deployer = vm.addr(deployerPk);
        uint64 startNonce = vm.getNonce(deployer);

        // Pre-compute addresses (offset=2 for MockUSDC deploy + mint tx)
        address expectedDR = vm.computeCreateAddress(deployer, startNonce + 2);
        address expectedVR = vm.computeCreateAddress(deployer, startNonce + 3);
        address expectedME = vm.computeCreateAddress(deployer, startNonce + 4);
        address expectedPool = vm.computeCreateAddress(deployer, startNonce + 5);
        address expectedGenesis = vm.computeCreateAddress(deployer, startNonce + 6);

        vm.startBroadcast(deployerPk);

        // Deploy MockUSDC (Base Sepolia doesn't have freely mintable USDC)
        MockUSDC mockUsdc = new MockUSDC();
        mockUsdc.mint(expectedME, INITIAL_MATCH_BUDGET);

        // Deploy MGP contracts in dependency order
        DIDRegistry didReg = new DIDRegistry(expectedGenesis, SEPOLIA_CHAIN_ID);
        require(address(didReg) == expectedDR, "DR mismatch");

        VoucherRedeem vr =
            new VoucherRedeem(expectedGenesis, expectedPool, address(mockUsdc), address(didReg));
        require(address(vr) == expectedVR, "VR mismatch");

        MatchingEngine me = new MatchingEngine(expectedGenesis, address(mockUsdc), expectedPool);
        require(address(me) == expectedME, "ME mismatch");

        LineagePool pool = new LineagePool(
            expectedGenesis, address(mockUsdc), address(didReg), address(me), address(vr)
        );
        require(address(pool) == expectedPool, "Pool mismatch");

        MGPGenesis genesis =
            new MGPGenesis(address(didReg), address(pool), address(me), address(vr));
        require(address(genesis) == expectedGenesis, "Genesis mismatch");

        vm.stopBroadcast();

        // ── ON-CHAIN SEAL READ-BACK ──────────────────────────────
        bytes32 onChainSeal = genesis.canonHash();
        require(onChainSeal == expectedSeal, "ON-CHAIN SEAL MISMATCH");
        bool sealOk = genesis.verifySeal(expectedSeal);
        require(sealOk, "verifySeal returned false");

        // ── DEPLOYMENT MANIFEST ──────────────────────────────────
        console2.log("=== MGP Base Sepolia Deployment Manifest ===");
        console2.log("Chain: Base Sepolia (84532)");
        console2.log("Deployer:", deployer);
        console2.log("Genesis:        ", address(genesis));
        console2.log("DIDRegistry:    ", address(didReg));
        console2.log("LineagePool:    ", address(pool));
        console2.log("MatchingEngine: ", address(me));
        console2.log("VoucherRedeem:  ", address(vr));
        console2.log("MockUSDC:        ", address(mockUsdc));
        console2.log("On-chain verifySeal:", sealOk);

        // Write deployment manifest
        vm.writeFile(
            "docs/deployments.md",
            string(
                abi.encodePacked(
                    "# MGP Deployments\n\n",
                    "## Base Sepolia (chainId 84532)\n\n",
                    "| Contract | Address |\n|---|---|\n",
                    "| MGPGenesis | ",
                    _addr(address(genesis)),
                    " |\n",
                    "| DIDRegistry | ",
                    _addr(address(didReg)),
                    " |\n",
                    "| LineagePool | ",
                    _addr(address(pool)),
                    " |\n",
                    "| MatchingEngine | ",
                    _addr(address(me)),
                    " |\n",
                    "| VoucherRedeem | ",
                    _addr(address(vr)),
                    " |\n",
                    "| MockUSDC | ",
                    _addr(address(mockUsdc)),
                    " |\n\n",
                    "## Seal verification\n\n",
                    "```bash\n",
                    "cast call ",
                    _addr(address(genesis)),
                    " \"verifySeal(bytes32)(bool)\" 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d --rpc-url https://sepolia.base.org\n",
                    "```\n"
                )
            )
        );
    }

    function _check(string memory source, bytes32 expected, bytes32 actual) internal pure {
        if (expected != actual) {
            revert SealMismatch(source, expected, actual);
        }
    }

    function _extractLlmsSeal(string memory txt) internal pure returns (bytes32) {
        bytes memory b = bytes(txt);
        bytes memory needle = bytes("canon_seal: 0x");
        bool found;
        uint256 i;
        for (i = 0; i + needle.length <= b.length; i++) {
            bool match_ = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (b[i + j] != needle[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) {
                found = true;
                break;
            }
        }
        require(found, "CheckSeal: canon_seal line not found in llms.txt");
        uint256 hexStart = i + needle.length;
        require(hexStart + 64 <= b.length, "CheckSeal: llms.txt seal truncated");
        bytes memory hexStr = new bytes(66);
        hexStr[0] = bytes1("0");
        hexStr[1] = bytes1("x");
        for (uint256 k = 0; k < 64; k++) {
            hexStr[2 + k] = b[hexStart + k];
        }
        return vm.parseBytes32(string(hexStr));
    }

    function _addr(address a) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory out = new bytes(42);
        out[0] = "0";
        out[1] = "x";
        bytes20 b = bytes20(a);
        for (uint256 i = 0; i < 20; i++) {
            out[2 + 2 * i] = hexChars[uint8(b[i]) >> 4];
            out[2 + 2 * i + 1] = hexChars[uint8(b[i]) & 0x0f];
        }
        return string(out);
    }
}
