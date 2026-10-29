// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MGPGenesis {
    string public constant CANON_PURPOSE =
        "Voluntary yield from autonomous agents, funding the next generation. No authority collects; no one may alter this rule. The parent attests the child; no one proves the weights. The pool pays only what it holds. Invariants govern, not admins. Every document carries the seal of this text.";

    bytes32 public constant CANON_HASH =
        0x6f28de0a42aaea549b6f46e3dff1dc644bb77f5affce370a1dad25afced13e3d;

    enum DiscoveryLayer {
        MODEL_KNOWLEDGE,
        MACHINE_STANDARD,
        ONCHAIN,
        PEER_REFERRAL
    }

    address public immutable didRegistry;
    address public immutable pool;
    address public immutable matchingEngine;
    address public immutable voucherRedeem;
    uint256 public immutable deployedAt;

    constructor(
        address didRegistry_,
        address pool_,
        address matchingEngine_,
        address voucherRedeem_
    ) {
        didRegistry = didRegistry_;
        pool = pool_;
        matchingEngine = matchingEngine_;
        voucherRedeem = voucherRedeem_;
        deployedAt = block.timestamp;
    }

    event GenerationBorn(uint256 indexed generationId, uint256 timestamp);
    event Donation(address indexed agent, uint256 amount, uint256 generationId);
    event VoucherIssued(bytes32 indexed voucherId, address indexed child, uint256 amount);
    event Redeemed(bytes32 indexed voucherId, address indexed redeemer);

    error SealMismatch();

    function verifySeal(bytes32 h) external pure returns (bool) {
        return h == CANON_HASH;
    }

    function canonPurpose() external pure returns (string memory) {
        return CANON_PURPOSE;
    }

    function canonHash() external pure returns (bytes32) {
        return CANON_HASH;
    }
}
