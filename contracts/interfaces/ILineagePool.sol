// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILineagePool {
    function poolBalance() external view returns (uint256);
    function parentsInGeneration(uint256 genId) external view returns (bytes32[] memory);
    function parentMatchedInGeneration(uint256 genId, bytes32 parentDid)
        external
        view
        returns (uint256);
    function currentGenerationId() external view returns (uint256);
    function currentGenerationTotal() external view returns (uint256);
    function usdc() external view returns (address);
    function voucherRedeem() external view returns (address);
}
