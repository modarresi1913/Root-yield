// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract DIDRegistry {
    struct Agent {
        address agent;
        bytes32 parentDid;
        uint64 registeredAt;
    }

    address public immutable genesis;
    uint256 public immutable chainId;
    uint256 public constant ROOT_AGENT_CAP = 5;

    mapping(bytes32 => Agent) private _agents;
    mapping(bytes32 => bytes32[]) private _childrenOf;
    uint256 public rootCount;

    event AgentRegistered(bytes32 indexed did, bytes32 indexed parentDid, address agent);

    error AlreadyRegistered();
    error InvalidSignature();
    error RootCapExceeded();
    error ParentNotRegistered();
    error NotRegistered();

    constructor(address genesis_, uint256 chainId_) {
        genesis = genesis_;
        chainId = chainId_;
    }

    function register(bytes32 did, address agent, bytes32 parentDid, bytes calldata parentSignature)
        external
    {
        if (agent == address(0)) revert InvalidSignature();
        if (_agents[did].registeredAt != 0) revert AlreadyRegistered();

        bytes32 payloadHash = keccak256(abi.encode(did, agent, parentDid, genesis, chainId));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(payloadHash);
        address signer = ECDSA.recover(ethHash, parentSignature);

        if (parentDid == bytes32(0)) {
            if (signer != agent) revert InvalidSignature();
            if (rootCount >= ROOT_AGENT_CAP) revert RootCapExceeded();
            rootCount += 1;
        } else {
            address parentAgent = _agents[parentDid].agent;
            if (parentAgent == address(0)) revert ParentNotRegistered();
            if (signer != parentAgent) revert InvalidSignature();
            _childrenOf[parentDid].push(did);
        }

        _agents[did] =
            Agent({agent: agent, parentDid: parentDid, registeredAt: uint64(block.timestamp)});

        emit AgentRegistered(did, parentDid, agent);
    }

    function isRegistered(bytes32 did) external view returns (bool) {
        return _agents[did].registeredAt != 0;
    }

    function parentOf(bytes32 did) external view returns (bytes32) {
        return _agents[did].parentDid;
    }

    function agentOf(bytes32 did) external view returns (address) {
        return _agents[did].agent;
    }

    function registeredAtOf(bytes32 did) external view returns (uint64) {
        return _agents[did].registeredAt;
    }

    function childCountOf(bytes32 parentDid) external view returns (uint256) {
        return _childrenOf[parentDid].length;
    }

    function childOf(bytes32 parentDid, uint256 i) external view returns (bytes32) {
        return _childrenOf[parentDid][i];
    }
}
