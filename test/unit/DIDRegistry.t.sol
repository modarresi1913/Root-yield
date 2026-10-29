// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MGPFixture} from "./MGPFixture.sol";
import {DIDRegistry} from "../../contracts/DIDRegistry.sol";

contract DIDRegistryTest is MGPFixture {
    function test_RegisterRootAgent() public {
        bytes memory sig = _signParentAttestation(
            ROOT_DID, rootAddr, bytes32(0), address(genesis), block.chainid, ROOT_PK
        );
        vm.prank(rootAddr);
        vm.expectEmit(true, true, false, false);
        emit DIDRegistry.AgentRegistered(ROOT_DID, bytes32(0), rootAddr);
        didReg.register(ROOT_DID, rootAddr, bytes32(0), sig);

        assertTrue(didReg.isRegistered(ROOT_DID));
        assertEq(didReg.parentOf(ROOT_DID), bytes32(0));
        assertEq(didReg.agentOf(ROOT_DID), rootAddr);
        assertEq(didReg.rootCount(), 1);
    }

    function test_RegisterChildAgent() public {
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);

        bytes memory sig = _signParentAttestation(
            CHILD_DID, childAddr, ROOT_DID, address(genesis), block.chainid, ROOT_PK
        );
        vm.prank(childAddr);
        vm.expectEmit(true, true, false, false);
        emit DIDRegistry.AgentRegistered(CHILD_DID, ROOT_DID, childAddr);
        didReg.register(CHILD_DID, childAddr, ROOT_DID, sig);

        assertTrue(didReg.isRegistered(CHILD_DID));
        assertEq(didReg.parentOf(CHILD_DID), ROOT_DID);
        assertEq(didReg.agentOf(CHILD_DID), childAddr);
        assertEq(didReg.childCountOf(ROOT_DID), 1);
        assertEq(didReg.childOf(ROOT_DID, 0), CHILD_DID);
    }

    function test_RevertOnAlreadyRegistered() public {
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);

        bytes memory sig = _signParentAttestation(
            ROOT_DID, rootAddr, bytes32(0), address(genesis), block.chainid, ROOT_PK
        );
        vm.prank(rootAddr);
        vm.expectRevert(DIDRegistry.AlreadyRegistered.selector);
        didReg.register(ROOT_DID, rootAddr, bytes32(0), sig);
    }

    function test_RevertOnInvalidSignature() public {
        bytes memory badSig = _signParentAttestation(
            ROOT_DID, rootAddr, bytes32(0), address(genesis), block.chainid, CHILD_PK
        );
        vm.prank(rootAddr);
        vm.expectRevert(DIDRegistry.InvalidSignature.selector);
        didReg.register(ROOT_DID, rootAddr, bytes32(0), badSig);
    }

    function test_RevertOnUnregisteredParent() public {
        bytes32 fakeParent = bytes32(uint256(0xDEAD));
        bytes memory sig = _signParentAttestation(
            CHILD_DID, childAddr, fakeParent, address(genesis), block.chainid, ATTACKER_PK
        );
        vm.prank(childAddr);
        vm.expectRevert(DIDRegistry.ParentNotRegistered.selector);
        didReg.register(CHILD_DID, childAddr, fakeParent, sig);
    }

    function test_RevertOnWrongAgentInSignature() public {
        bytes32 did = ROOT_DID;
        address signedAgent = rootAddr;
        address callAgent = donorAddr;
        bytes memory sig = _signParentAttestation(
            did, signedAgent, bytes32(0), address(genesis), block.chainid, ROOT_PK
        );
        vm.prank(callAgent);
        vm.expectRevert(DIDRegistry.InvalidSignature.selector);
        didReg.register(did, callAgent, bytes32(0), sig);
    }

    function test_RootAgentCapBoundary_5thRegisters_6thReverts() public {
        for (uint256 i = 0; i < 5; i++) {
            bytes32 did = bytes32(uint256(0xCAFE_0001 + i));
            uint256 pk = 0xA11CE_01 + i;
            address agent = vm.addr(pk);
            deal(address(usdc), agent, 1e6);
            bytes memory sig =
                _signParentAttestation(did, agent, bytes32(0), address(genesis), block.chainid, pk);
            vm.prank(agent);
            didReg.register(did, agent, bytes32(0), sig);
        }
        assertEq(didReg.rootCount(), 5, "5 roots should be registered");

        bytes32 did6 = bytes32(uint256(0xCAFE_0006));
        uint256 pk6 = 0xA11CE_06;
        address agent6 = vm.addr(pk6);
        bytes memory sig6 =
            _signParentAttestation(did6, agent6, bytes32(0), address(genesis), block.chainid, pk6);
        vm.prank(agent6);
        vm.expectRevert(DIDRegistry.RootCapExceeded.selector);
        didReg.register(did6, agent6, bytes32(0), sig6);
    }

    function test_RevertOnZeroAgent() public {
        bytes memory sig = _signParentAttestation(
            ROOT_DID, address(0), bytes32(0), address(genesis), block.chainid, ROOT_PK
        );
        vm.prank(rootAddr);
        vm.expectRevert(DIDRegistry.InvalidSignature.selector);
        didReg.register(ROOT_DID, address(0), bytes32(0), sig);
    }

    function test_ChildOfReverseIndexGrows() public {
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);
        for (uint256 i = 0; i < 3; i++) {
            bytes32 did = bytes32(uint256(0xCAFE_C001 + i));
            uint256 pk = 0xC111_01 + i;
            address agent = vm.addr(pk);
            _registerChild(did, agent, ROOT_DID, ROOT_PK, address(genesis), block.chainid);
        }
        assertEq(didReg.childCountOf(ROOT_DID), 3);
        assertEq(didReg.childOf(ROOT_DID, 0), bytes32(uint256(0xCAFE_C001)));
        assertEq(didReg.childOf(ROOT_DID, 1), bytes32(uint256(0xCAFE_C002)));
        assertEq(didReg.childOf(ROOT_DID, 2), bytes32(uint256(0xCAFE_C003)));
    }
}
