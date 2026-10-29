// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MGPFixture} from "./MGPFixture.sol";
import {MGPGenesis} from "../../contracts/MGPGenesis.sol";

contract MGPGenesisTest is MGPFixture {
    function test_CanonHashMatchesSeal() public view {
        bytes32 expected = 0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d;
        assertEq(genesis.canonHash(), expected, "canonHash mismatch");
    }

    function test_VerifySealAcceptsCanonHash() public view {
        bytes32 h = genesis.canonHash();
        assertTrue(genesis.verifySeal(h));
    }

    function test_VerifySealRejectsMutatedHash() public view {
        bytes32 h = genesis.canonHash();
        bytes32 mutated = bytes32(uint256(h) ^ 1);
        assertFalse(genesis.verifySeal(mutated));
    }

    function test_CanonPurposeMatchesCanonFile() public view {
        bytes memory canonBytes = vm.readFileBinary("canon/canon.txt");
        bytes32 fromFile = keccak256(canonBytes);
        bytes32 fromContract = keccak256(bytes(genesis.canonPurpose()));
        assertEq(fromFile, fromContract, "CANON_PURPOSE != canon.txt");
    }

    function test_TamperCanonBreaksSeal() public view {
        bytes memory original = vm.readFileBinary("canon/canon.txt");
        bytes32 fromFile = keccak256(original);
        assertEq(fromFile, genesis.canonHash(), "canon.txt != CANON_HASH at start");

        bytes memory tampered = new bytes(original.length);
        for (uint256 i = 0; i < original.length; i++) {
            tampered[i] = original[i];
        }
        tampered[0] = bytes1(uint8(tampered[0]) ^ 0x01);
        bytes32 mutatedSeal = keccak256(tampered);

        assertNotEq(mutatedSeal, genesis.canonHash(), "tamper did not change seal");
        assertFalse(genesis.verifySeal(mutatedSeal), "verifySeal accepted tampered seal");
    }

    function test_ImmutableAddresses() public view {
        assertEq(address(genesis.didRegistry()), address(didReg));
        assertEq(address(genesis.pool()), address(pool));
        assertEq(address(genesis.matchingEngine()), address(me));
        assertEq(address(genesis.voucherRedeem()), address(vr));
    }

    function test_DeployedAtSet() public view {
        assertGt(genesis.deployedAt(), 0);
    }
}
