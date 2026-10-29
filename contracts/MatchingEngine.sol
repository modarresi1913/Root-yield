// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MatchingEngine — matches donations into the LineagePool up to a
///        monthly cap, funded by a one-time budget transferred in at deploy.
contract MatchingEngine {
    using SafeERC20 for IERC20;

    address public immutable genesis;
    address public immutable usdc;
    address public immutable pool;
    uint256 public constant MONTHLY_CAP = 5_000e6;
    uint256 public constant EPOCH = 30 days;

    uint256 public matchBudgetRemaining;
    uint256 public lastMatchAmount;
    bool public budgetExhaustedEventEmitted;
    mapping(uint256 => uint256) public monthlyMatchedTotal;

    event Match(bytes32 indexed donationId, uint256 amount);
    event MatchBudgetExhausted();

    error OnlyPool();
    error ZeroDonation();

    constructor(address genesis_, address usdc_, address pool_) {
        genesis = genesis_;
        usdc = usdc_;
        pool = pool_;
        matchBudgetRemaining = IERC20(usdc_).balanceOf(address(this));
    }

    function onDonation(
        bytes32 donationId,
        address,
        /* agent */
        uint256 amount
    )
        external
    {
        if (msg.sender != pool) revert OnlyPool();
        if (amount == 0) revert ZeroDonation();

        uint256 epoch = block.timestamp / EPOCH;
        uint256 remainingCap = MONTHLY_CAP - monthlyMatchedTotal[epoch];
        uint256 remainingBudget = matchBudgetRemaining;

        uint256 matchAmount = amount;
        if (matchAmount > remainingCap) matchAmount = remainingCap;
        if (matchAmount > remainingBudget) matchAmount = remainingBudget;

        if (matchAmount > 0) {
            matchBudgetRemaining = remainingBudget - matchAmount;
            monthlyMatchedTotal[epoch] += matchAmount;
            IERC20(usdc).safeTransfer(pool, matchAmount);
        } else if (!budgetExhaustedEventEmitted) {
            budgetExhaustedEventEmitted = true;
            emit MatchBudgetExhausted();
        }

        lastMatchAmount = matchAmount;
        emit Match(donationId, matchAmount);
    }

    function remainingMonthlyCap() external view returns (uint256) {
        uint256 epoch = block.timestamp / EPOCH;
        return MONTHLY_CAP - monthlyMatchedTotal[epoch];
    }
}
