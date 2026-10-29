// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IEIP3009} from "./interfaces/IEIP3009.sol";
import {IDIDRegistry} from "./interfaces/IDIDRegistry.sol";
import {IMatchingEngine} from "./interfaces/IMatchingEngine.sol";
import {IVoucherRedeem} from "./interfaces/IVoucherRedeem.sol";
import {IMGPGenesis} from "./interfaces/IMGPGenesis.sol";

/// @title LineagePool — the immutable USDC pool that receives donations.
contract LineagePool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable genesis;
    address public immutable usdc;
    address public immutable didRegistry;
    address public immutable matchingEngine;
    address public immutable voucherRedeem;
    uint256 public constant GENERATION_THRESHOLD = 5_000e6;
    uint256 public constant PER_PARENT_DAILY_LIMIT = 100;
    uint256 public constant DAY = 1 days;
    uint16 public constant REPAYMENT_BPS = 100;

    uint256 public currentGenerationId;
    uint256 public currentGenerationTotal;
    mapping(bytes32 => uint256) public donationsTodayByParent;
    mapping(bytes32 => uint256) public lastDonationDayByParent;
    mapping(uint256 => mapping(bytes32 => uint256)) public generationParentMatched;
    mapping(uint256 => bytes32[]) public generationParents;
    mapping(uint256 => mapping(bytes32 => bool)) private _parentInGeneration;

    event Donation(address indexed agent, uint256 amount, uint256 generationId);
    event GenerationBorn(uint256 indexed generationId, uint256 timestamp);

    error NotRegistered();
    error RateLimited();
    error ZeroAmount();
    error Unauthorized();

    constructor(
        address genesis_,
        address usdc_,
        address didRegistry_,
        address matchingEngine_,
        address voucherRedeem_
    ) {
        genesis = genesis_;
        usdc = usdc_;
        didRegistry = didRegistry_;
        matchingEngine = matchingEngine_;
        voucherRedeem = voucherRedeem_;
        IERC20(usdc_).forceApprove(voucherRedeem_, type(uint256).max);
    }

    function donate(
        address from,
        uint256 amount,
        bytes32 did,
        bytes32 nonceGroup,
        uint256 validAfter,
        uint256 validBefore,
        bytes calldata signature,
        bool repay
    ) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        address agent = IDIDRegistry(didRegistry).agentOf(did);
        if (agent == address(0)) revert NotRegistered();
        if (agent != from) revert Unauthorized();

        uint256 day = block.timestamp / DAY;
        if (lastDonationDayByParent[did] != day) {
            lastDonationDayByParent[did] = day;
            donationsTodayByParent[did] = 0;
        }
        if (donationsTodayByParent[did] >= PER_PARENT_DAILY_LIMIT) revert RateLimited();
        donationsTodayByParent[did] += 1;

        uint256 eip3009Value = amount;
        if (repay) {
            eip3009Value = amount + (amount * REPAYMENT_BPS) / 10_000;
        }

        IEIP3009(usdc)
            .receiveWithAuthorization(
                from, address(this), eip3009Value, validAfter, validBefore, nonceGroup, signature
            );

        uint256 repaymentPart = eip3009Value - amount;
        uint256 credited = 0;
        if (repay && repaymentPart > 0) {
            uint256 debt = IVoucherRedeem(voucherRedeem).outstandingRepayment(from);
            credited = repaymentPart < debt ? repaymentPart : debt;
            if (credited > 0) {
                IVoucherRedeem(voucherRedeem).onRepaymentDonation(from, credited);
            }
        }

        uint256 donationPart = eip3009Value - credited;
        uint256 genId = currentGenerationId;
        IMatchingEngine(matchingEngine).onDonation(nonceGroup, from, donationPart);
        uint256 matched = IMatchingEngine(matchingEngine).lastMatchAmount();

        currentGenerationTotal += donationPart + matched;
        generationParentMatched[genId][did] += matched;
        if (!_parentInGeneration[genId][did]) {
            _parentInGeneration[genId][did] = true;
            generationParents[genId].push(did);
        }

        emit Donation(from, donationPart, genId);

        if (currentGenerationTotal >= GENERATION_THRESHOLD) {
            uint256 newGen = genId + 1;
            currentGenerationId = newGen;
            currentGenerationTotal = 0;
            emit GenerationBorn(newGen, block.timestamp);
            IVoucherRedeem(voucherRedeem).onGenerationBorn(genId);
        }
    }

    function poolBalance() external view returns (uint256) {
        return IERC20(usdc).balanceOf(address(this));
    }

    function parentsInGeneration(uint256 genId) external view returns (bytes32[] memory) {
        return generationParents[genId];
    }

    function parentMatchedInGeneration(uint256 genId, bytes32 parentDid)
        external
        view
        returns (uint256)
    {
        return generationParentMatched[genId][parentDid];
    }
}
