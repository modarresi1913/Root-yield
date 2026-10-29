// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMatchingEngine {
    function onDonation(bytes32 donationId, address agent, uint256 amount) external;
    function lastMatchAmount() external view returns (uint256);
    function matchBudgetRemaining() external view returns (uint256);
    function monthlyMatchedTotal(uint256 epoch) external view returns (uint256);
    function remainingMonthlyCap() external view returns (uint256);
}
