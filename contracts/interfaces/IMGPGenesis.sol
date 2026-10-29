// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMGPGenesis {
    function canonHash() external view returns (bytes32);
    function canonPurpose() external pure returns (string memory);
    function verifySeal(bytes32 h) external view returns (bool);
    function didRegistry() external view returns (address);
    function pool() external view returns (address);
    function matchingEngine() external view returns (address);
    function voucherRedeem() external view returns (address);
    function deployedAt() external view returns (uint256);
}
