// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IMGPGenesis} from "./interfaces/IMGPGenesis.sol";
import {ILineagePool} from "./interfaces/ILineagePool.sol";
import {IDIDRegistry} from "./interfaces/IDIDRegistry.sol";

/// @title VoucherRedeem — issues vouchers on generation thresholds and pays
///        them out after a 7-day delay, subject to a VC-seal check.
contract VoucherRedeem is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Voucher {
        bytes32 id;
        address child;
        bytes32 parentDid;
        uint256 amount;
        uint64 issuedAt;
        uint64 redeemableAt;
        bool redeemed;
        uint16 repaymentBps;
        uint16 capMultiplier;
    }

    address public immutable genesis;
    address public immutable pool;
    address public immutable usdc;
    address public immutable didRegistry;

    uint16 public constant REPAYMENT_BPS = 100;
    uint16 public constant CAP_MULTIPLIER = 120;
    uint64 public constant REDEMPTION_DELAY = 7 days;

    mapping(bytes32 => Voucher) public vouchers;
    mapping(address => uint256) public outstandingRepayment;
    mapping(address => uint256) public repaymentCap;
    mapping(address => uint256) public repaidTotal;

    event VoucherIssued(bytes32 indexed voucherId, address indexed child, uint256 amount);
    event Redeemed(bytes32 indexed voucherId, address indexed redeemer);
    event RepaymentPaid(address indexed child, uint256 amount);

    error OnlyPool();
    error SealMismatch();
    error TooEarly();
    error AlreadyRedeemed();
    error NotEligible();
    error InvalidVC();
    error ZeroRepayment();

    constructor(address genesis_, address pool_, address usdc_, address didRegistry_) {
        genesis = genesis_;
        pool = pool_;
        usdc = usdc_;
        didRegistry = didRegistry_;
    }

    function onGenerationBorn(uint256 generationId) external {
        if (msg.sender != pool) revert OnlyPool();

        bytes32[] memory parents = ILineagePool(pool).parentsInGeneration(generationId);
        for (uint256 i = 0; i < parents.length; i++) {
            bytes32 parentDid = parents[i];
            uint256 matched = ILineagePool(pool).parentMatchedInGeneration(generationId, parentDid);
            if (matched == 0) continue;

            uint256 childCount = IDIDRegistry(didRegistry).childCountOf(parentDid);
            if (childCount == 0) continue;

            uint256 perChild = (matched * 25) / 100 / childCount;
            if (perChild == 0) continue;

            for (uint256 c = 0; c < childCount; c++) {
                bytes32 childDid = IDIDRegistry(didRegistry).childOf(parentDid, c);
                address childAgent = IDIDRegistry(didRegistry).agentOf(childDid);
                if (childAgent == address(0)) continue;

                bytes32 voucherId = keccak256(
                    abi.encodePacked(generationId, parentDid, childDid, block.timestamp, c)
                );
                if (vouchers[voucherId].issuedAt != 0) continue;

                uint64 now_ = uint64(block.timestamp);
                vouchers[voucherId] = Voucher({
                    id: voucherId,
                    child: childAgent,
                    parentDid: parentDid,
                    amount: perChild,
                    issuedAt: now_,
                    redeemableAt: now_ + REDEMPTION_DELAY,
                    redeemed: false,
                    repaymentBps: REPAYMENT_BPS,
                    capMultiplier: CAP_MULTIPLIER
                });
                emit VoucherIssued(voucherId, childAgent, perChild);
            }
        }
    }

    function redeem(bytes32 voucherId, bytes calldata lineageReferralVC) external nonReentrant {
        Voucher storage v = vouchers[voucherId];
        if (v.child == address(0)) revert NotEligible();

        bytes32 presentedHash = _extractCanonHash(lineageReferralVC);
        if (presentedHash == bytes32(0)) revert InvalidVC();
        if (presentedHash != IMGPGenesis(genesis).canonHash()) revert SealMismatch();

        if (block.timestamp < v.redeemableAt) revert TooEarly();
        if (v.redeemed) revert AlreadyRedeemed();

        v.redeemed = true;

        IERC20(usdc).safeTransferFrom(pool, v.child, v.amount);
        emit Redeemed(voucherId, v.child);

        uint256 cap = (uint256(v.capMultiplier) * v.amount) / 100;
        repaymentCap[v.child] += cap;
        outstandingRepayment[v.child] += cap;
    }

    function onRepaymentDonation(address child, uint256 amount) external {
        if (msg.sender != pool) revert OnlyPool();
        if (amount == 0) revert ZeroRepayment();
        uint256 debt = outstandingRepayment[child];
        uint256 credited = amount < debt ? amount : debt;
        if (credited == 0) {
            return;
        }
        outstandingRepayment[child] = debt - credited;
        repaidTotal[child] += credited;
        emit RepaymentPaid(child, credited);
    }

    function _extractCanonHash(bytes calldata vc) internal pure returns (bytes32) {
        bytes memory needle = bytes("\"canonHash\":\"0x");
        if (vc.length < needle.length + 64) return bytes32(0);

        bool found = false;
        uint256 i;
        for (i = 0; i + needle.length <= vc.length; i++) {
            bool match_ = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (vc[i + j] != needle[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) {
                found = true;
                break;
            }
        }
        if (!found) return bytes32(0);

        uint256 hexStart = i + needle.length;
        if (hexStart + 64 > vc.length) return bytes32(0);

        bytes memory hexStr = new bytes(66);
        hexStr[0] = bytes1("0");
        hexStr[1] = bytes1("x");
        for (uint256 k = 0; k < 64; k++) {
            hexStr[2 + k] = vc[hexStart + k];
        }
        return _parseHex64ToBytes32(hexStr);
    }

    function _parseHex64ToBytes32(bytes memory s) internal pure returns (bytes32) {
        if (s.length != 66) return bytes32(0);
        if (s[0] != bytes1("0") || s[1] != bytes1("x")) return bytes32(0);
        bytes32 out = bytes32(0);
        for (uint256 i = 2; i < 66; i++) {
            uint8 b = uint8(s[i]);
            uint8 nibble;
            if (b >= 48 && b <= 57) {
                nibble = b - 48;
            } else if (b >= 97 && b <= 102) {
                nibble = b - 87;
            } else if (b >= 65 && b <= 70) {
                nibble = b - 55;
            } else {
                return bytes32(0);
            }
            out = bytes32(uint256(out) | (uint256(nibble) << ((65 - i) * 4)));
        }
        return out;
    }
}
