// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDIDRegistry {
    function isRegistered(bytes32 did) external view returns (bool);
    function parentOf(bytes32 did) external view returns (bytes32);
    function agentOf(bytes32 did) external view returns (address);
    function registeredAtOf(bytes32 did) external view returns (uint64);
    function childCountOf(bytes32 parentDid) external view returns (uint256);
    function childOf(bytes32 parentDid, uint256 i) external view returns (bytes32);
}
