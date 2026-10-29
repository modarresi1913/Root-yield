// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LineagePool} from "../../contracts/LineagePool.sol";

contract Attacker {
    LineagePool public pool;
    address public donor;
    bytes32 public did;
    bytes32 public nonce;
    bytes public sig;
    bool public repay;
    uint256 public amount;

    constructor(address pool_) {
        pool = LineagePool(pool_);
    }

    function setAttackParams(
        address donor_,
        bytes32 did_,
        bytes32 nonce_,
        bytes calldata sig_,
        bool repay_,
        uint256 amount_
    ) external {
        donor = donor_;
        did = did_;
        nonce = nonce_;
        sig = sig_;
        repay = repay_;
        amount = amount_;
    }

    function tryReenter() external {
        pool.donate(donor, amount, did, nonce, 0, type(uint256).max, sig, repay);
    }
}
