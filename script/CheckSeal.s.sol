// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MGPGenesis} from "../contracts/MGPGenesis.sol";

contract CheckSeal is Script {
    error SealMismatch(string source, bytes32 expected, bytes32 actual);

    bytes32 internal EXPECTED;

    function checkSealLocal() public {
        string memory canonPath = "canon/canon.txt";
        bytes memory canonBytes = vm.readFileBinary(canonPath);
        EXPECTED = keccak256(canonBytes);
        console2.log("[1/5] canon/canon.txt         -> seal ==");
        console2.logBytes32(EXPECTED);

        MGPGenesis probe = new MGPGenesis(address(0), address(0), address(0), address(0));
        bytes32 genesisHash = probe.canonHash();
        console2.log("[2/5] MGPGenesis.CANON_HASH   -> ");
        console2.logBytes32(genesisHash);
        _check("MGPGenesis.CANON_HASH", EXPECTED, genesisHash);

        bytes32 wellKnownHash = vm.parseBytes32(
            vm.parseJsonString(vm.readFile("wellknown/agent-giving.json"), ".canonHash")
        );
        console2.log("[3/5] wellknown/.canonHash    -> ");
        console2.logBytes32(wellKnownHash);
        _check("wellknown/agent-giving.json", EXPECTED, wellKnownHash);

        bytes32 llmsSeal = _extractLlmsSeal(vm.readFile("llms.txt"));
        console2.log("[4/5] llms.txt canon_seal     -> ");
        console2.logBytes32(llmsSeal);
        _check("llms.txt", EXPECTED, llmsSeal);

        bytes32 schemaHash = vm.parseBytes32(
            vm.parseJsonString(
                vm.readFile("schemas/lineage-referral-v1.json"), ".$metadata.canonHash"
            )
        );
        console2.log("[5/5] schemas/...canonHash    -> ");
        console2.logBytes32(schemaHash);
        _check("schemas/lineage-referral-v1.json", EXPECTED, schemaHash);

        bytes32 recomputedFromConstant = keccak256(bytes(probe.canonPurpose()));
        _check("MGPGenesis.CANON_PURPOSE (recomputed)", EXPECTED, recomputedFromConstant);

        console2.log("SEAL OK -- all five sources agree:");
        console2.logBytes32(EXPECTED);
    }

    function checkSealOnChain() public view {
        address genesisAddr = vm.envAddress("MGP_GENESIS_ADDRESS");
        bytes32 onChainHash = MGPGenesis(genesisAddr).canonHash();
        bytes32 local = keccak256(vm.readFileBinary("canon/canon.txt"));
        _check("on-chain MGPGenesis.CANON_HASH()", local, onChainHash);
        console2.log("SEAL OK (on-chain) -- genesis.CANON_HASH == canon.txt");
        console2.logBytes32(onChainHash);
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

    function _check(string memory source, bytes32 expected, bytes32 actual) internal pure {
        if (expected != actual) {
            revert SealMismatch(source, expected, actual);
        }
    }
}
