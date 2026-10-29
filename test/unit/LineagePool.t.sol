// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MGPFixture} from "./MGPFixture.sol";
import {LineagePool} from "../../contracts/LineagePool.sol";
import {MatchingEngine} from "../../contracts/MatchingEngine.sol";
import {VoucherRedeem} from "../../contracts/VoucherRedeem.sol";
import {Attacker} from "./Attacker.sol";

contract LineagePoolTest is MGPFixture {
    function _donate(
        address donor,
        uint256 pk,
        bytes32 did,
        uint256 amount,
        bytes32 nonce,
        bool repay
    ) internal returns (uint256) {
        uint256 eip3009Value = repay ? amount + (amount * 100) / 10_000 : amount;
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donor, address(pool), eip3009Value, 0, type(uint256).max, nonce, pk
        );
        vm.prank(donor);
        pool.donate(donor, amount, did, nonce, 0, type(uint256).max, sig, repay);
        return eip3009Value;
    }

    function _setupDonor() internal returns (bytes32) {
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);
        _registerChild(CHILD_DID, childAddr, ROOT_DID, ROOT_PK, address(genesis), block.chainid);
        _registerChild(DONOR_DID, donorAddr, ROOT_DID, ROOT_PK, address(genesis), block.chainid);
        return DONOR_DID;
    }

    function test_DonateHappyPath_Unflagged() public {
        bytes32 did = _setupDonor();
        uint256 amount = 10e6;
        uint256 poolBefore = usdc.balanceOf(address(pool));
        uint256 meBefore = usdc.balanceOf(address(me));
        _donate(donorAddr, DONOR_PK, did, amount, bytes32(uint256(1)), false);
        assertEq(usdc.balanceOf(address(pool)) - poolBefore, amount + amount, "pool delta");
        assertEq(meBefore - usdc.balanceOf(address(me)), amount, "ME delta");
        assertEq(pool.currentGenerationTotal(), amount + amount, "gen total");
    }

    function test_DonateRevertsOnZeroAmount() public {
        bytes32 did = _setupDonor();
        bytes32 nonce = bytes32(uint256(2));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), 0, 0, type(uint256).max, nonce, DONOR_PK
        );
        vm.prank(donorAddr);
        vm.expectRevert(LineagePool.ZeroAmount.selector);
        pool.donate(donorAddr, 0, did, nonce, 0, type(uint256).max, sig, false);
    }

    function test_DonateRevertsOnUnregisteredDID() public {
        bytes32 did = bytes32(uint256(0xBAADF00D));
        uint256 amount = 10e6;
        bytes32 nonce = bytes32(uint256(3));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount, 0, type(uint256).max, nonce, DONOR_PK
        );
        vm.prank(donorAddr);
        vm.expectRevert(LineagePool.NotRegistered.selector);
        pool.donate(donorAddr, amount, did, nonce, 0, type(uint256).max, sig, false);
    }

    function test_DonateRevertsWhenAgentMismatch() public {
        bytes32 did = _setupDonor();
        bytes32 nonce = bytes32(uint256(4));
        uint256 amount = 10e6;
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc),
            attackerAddr,
            address(pool),
            amount,
            0,
            type(uint256).max,
            nonce,
            ATTACKER_PK
        );
        vm.prank(attackerAddr);
        vm.expectRevert(LineagePool.Unauthorized.selector);
        pool.donate(attackerAddr, amount, did, nonce, 0, type(uint256).max, sig, false);
    }

    function test_RateLimit_101stDonationReverts() public {
        bytes32 did = _setupDonor();
        uint256 amount = 1e6;
        for (uint256 i = 0; i < 100; i++) {
            _donate(donorAddr, DONOR_PK, did, amount, bytes32(uint256(100 + i)), false);
        }
        assertEq(pool.donationsTodayByParent(did), 100, "should be at cap");
        bytes32 nonce = bytes32(uint256(200));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount, 0, type(uint256).max, nonce, DONOR_PK
        );
        vm.prank(donorAddr);
        vm.expectRevert(LineagePool.RateLimited.selector);
        pool.donate(donorAddr, amount, did, nonce, 0, type(uint256).max, sig, false);
    }

    function test_RateLimitResetsNextDay() public {
        bytes32 did = _setupDonor();
        uint256 amount = 1e6;
        for (uint256 i = 0; i < 100; i++) {
            _donate(donorAddr, DONOR_PK, did, amount, bytes32(uint256(300 + i)), false);
        }
        assertEq(pool.donationsTodayByParent(did), 100);
        vm.warp(block.timestamp + 1 days + 1);
        _donate(donorAddr, DONOR_PK, did, amount, bytes32(uint256(400)), false);
        assertEq(pool.donationsTodayByParent(did), 1, "counter reset");
    }

    function test_GenerationThresholdBoundary_Plus1Wei() public {
        bytes32 did = _setupDonor();
        uint256 amount = 2_500e6;
        vm.expectEmit(true, false, false, true);
        emit LineagePool.GenerationBorn(1, block.timestamp);
        _donate(donorAddr, DONOR_PK, did, amount, bytes32(uint256(500)), false);
        assertEq(pool.currentGenerationId(), 1, "generation advanced");
        assertEq(pool.currentGenerationTotal(), 0, "total reset");
    }

    function test_GenerationThresholdBoundary_JustBelow_NoCross() public {
        bytes32 did = _setupDonor();
        uint256 amount = 2_499_999_999;
        _donate(donorAddr, DONOR_PK, did, amount, bytes32(uint256(501)), false);
        assertEq(pool.currentGenerationId(), 0, "no threshold cross");
        assertEq(pool.currentGenerationTotal(), amount + amount, "total below threshold");
    }

    function test_GenerationThresholdBoundary_ExactlyAtThreshold() public {
        bytes32 did = _setupDonor();
        uint256 amount = 2_500e6;
        vm.expectEmit(true, false, false, true);
        emit LineagePool.GenerationBorn(1, block.timestamp);
        _donate(donorAddr, DONOR_PK, did, amount, bytes32(uint256(502)), false);
        assertEq(pool.currentGenerationId(), 1);
    }

    function test_DonationEventEmitted() public {
        bytes32 did = _setupDonor();
        uint256 amount = 10e6;
        bytes32 nonce = bytes32(uint256(503));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount, 0, type(uint256).max, nonce, DONOR_PK
        );
        vm.prank(donorAddr);
        vm.expectEmit(true, false, false, true);
        emit LineagePool.Donation(donorAddr, amount, 0);
        pool.donate(donorAddr, amount, did, nonce, 0, type(uint256).max, sig, false);
    }
}

contract RepaymentTest is MGPFixture {
    function _donate(
        address donor,
        uint256 pk,
        bytes32 did,
        uint256 amount,
        bytes32 nonce,
        bool repay
    ) internal {
        uint256 eip3009Value = repay ? amount + (amount * 100) / 10_000 : amount;
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donor, address(pool), eip3009Value, 0, type(uint256).max, nonce, pk
        );
        vm.prank(donor);
        pool.donate(donor, amount, did, nonce, 0, type(uint256).max, sig, repay);
    }

    function _setupChildWithDebt() internal returns (bytes32 voucherId, uint256 voucherAmount) {
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);
        _registerChild(CHILD_DID, childAddr, ROOT_DID, ROOT_PK, address(genesis), block.chainid);

        bytes32 did = ROOT_DID;
        uint256 amount = 2_500e6;
        bytes32 nonce = bytes32(uint256(700));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), rootAddr, address(pool), amount, 0, type(uint256).max, nonce, ROOT_PK
        );
        vm.prank(rootAddr);
        pool.donate(rootAddr, amount, did, nonce, 0, type(uint256).max, sig, false);

        voucherAmount = (2_500e6 * 25) / 100 / 1;
        voucherId = keccak256(
            abi.encodePacked(uint256(0), ROOT_DID, CHILD_DID, block.timestamp, uint256(0))
        );
        (, address child,, uint256 amt,,,,,) = vr.vouchers(voucherId);
        assertEq(amt, voucherAmount, "voucher amount mismatch");
        assertEq(child, childAddr, "voucher child mismatch");

        vm.warp(block.timestamp + 7 days + 1);

        bytes memory vc = _validLineageReferralVC(address(genesis));
        vm.prank(childAddr);
        vr.redeem(voucherId, vc);

        assertEq(vr.outstandingRepayment(childAddr), voucherAmount * 120 / 100, "debt mismatch");
        assertEq(vr.repaymentCap(childAddr), voucherAmount * 120 / 100, "cap mismatch");
    }

    function test_FlaggedDonationWithDebtExceedingCap() public {
        (, uint256 voucherAmount) = _setupChildWithDebt();
        uint256 cap = vr.repaymentCap(childAddr);
        uint256 debt = vr.outstandingRepayment(childAddr);
        assertEq(debt, cap, "debt should equal cap initially");
        assertEq(voucherAmount, cap * 100 / 120, "voucherAmount math sanity");

        uint256 donation = 100_000e6;
        deal(address(usdc), childAddr, 200_000e6);

        uint256 poolBefore = usdc.balanceOf(address(pool));
        uint256 repaidBefore = vr.repaidTotal(childAddr);

        _donate(childAddr, CHILD_PK, CHILD_DID, donation, bytes32(uint256(800)), true);

        uint256 credited = vr.repaidTotal(childAddr) - repaidBefore;
        assertEq(credited, cap, "credited should equal cap");
        assertEq(vr.outstandingRepayment(childAddr), 0, "debt should be cleared");
        assertEq(vr.repaidTotal(childAddr), cap, "total repaid == cap");

        assertGe(
            usdc.balanceOf(address(pool)) - poolBefore,
            donation + (donation / 100) - cap + (donation / 100),
            "pool received at least donation + surplus - cap + 1%surplus"
        );

        deal(address(usdc), childAddr, 200_000e6);
        uint256 repaidBeforeNext = vr.repaidTotal(childAddr);
        _donate(childAddr, CHILD_PK, CHILD_DID, 100e6, bytes32(uint256(801)), true);
        assertEq(vr.repaidTotal(childAddr), repaidBeforeNext, "no further credit after cap");
        assertEq(vr.outstandingRepayment(childAddr), 0, "debt still 0");
    }

    function test_FlaggedDonationWithZeroDebt() public {
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);
        _registerChild(CHILD_DID, childAddr, ROOT_DID, ROOT_PK, address(genesis), block.chainid);

        assertEq(vr.outstandingRepayment(childAddr), 0);

        uint256 amount = 100e6;
        uint256 poolBefore = usdc.balanceOf(address(pool));
        uint256 repaidBefore = vr.repaidTotal(childAddr);

        _donate(childAddr, CHILD_PK, CHILD_DID, amount, bytes32(uint256(900)), true);

        assertEq(vr.repaidTotal(childAddr), repaidBefore, "no credit when debt == 0");
        assertEq(vr.outstandingRepayment(childAddr), 0, "debt still 0");

        uint256 poolDelta = usdc.balanceOf(address(pool)) - poolBefore;
        assertEq(poolDelta, 202e6, "pool delta should be donationPart + matched");
    }

    function test_ReentrancyOnSplitPath() public {
        _setupChildWithDebt();
        Attacker attacker = new Attacker(address(pool));
        uint256 amount = 10e6;
        uint256 eip3009Value = amount + amount / 100;
        bytes32 nonce = bytes32(uint256(999));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc),
            childAddr,
            address(pool),
            eip3009Value,
            0,
            type(uint256).max,
            nonce,
            CHILD_PK
        );
        attacker.setAttackParams(childAddr, CHILD_DID, nonce, sig, true, amount);
        vm.prank(childAddr);
        attacker.tryReenter();
        assertGt(pool.currentGenerationTotal(), 0, "donation credited");
    }
}

contract VoucherRedeemTest is MGPFixture {
    bytes32 internal voucherId;
    uint256 internal voucherAmount;

    function setUp() public override {
        super.setUp();
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);
        _registerChild(CHILD_DID, childAddr, ROOT_DID, ROOT_PK, address(genesis), block.chainid);

        uint256 amount = 2_500e6;
        bytes32 nonce = bytes32(uint256(600));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), rootAddr, address(pool), amount, 0, type(uint256).max, nonce, ROOT_PK
        );
        vm.prank(rootAddr);
        pool.donate(rootAddr, amount, ROOT_DID, nonce, 0, type(uint256).max, sig, false);

        voucherAmount = (2_500e6 * 25) / 100 / 1;
        voucherId = keccak256(
            abi.encodePacked(uint256(0), ROOT_DID, CHILD_DID, block.timestamp, uint256(0))
        );
        (,,, uint256 amt,,,,,) = vr.vouchers(voucherId);
        assertEq(amt, voucherAmount, "voucher amount mismatch");
    }

    function test_ReedeemRevertsTooEarly() public {
        bytes memory vc = _validLineageReferralVC(address(genesis));
        vm.prank(childAddr);
        vm.expectRevert(VoucherRedeem.TooEarly.selector);
        vr.redeem(voucherId, vc);
    }

    function test_RedeemAfter7DaysBoundary() public {
        bytes memory vc = _validLineageReferralVC(address(genesis));
        vm.warp(block.timestamp + 7 days - 1);
        vm.prank(childAddr);
        vm.expectRevert(VoucherRedeem.TooEarly.selector);
        vr.redeem(voucherId, vc);

        vm.warp(block.timestamp + 1);
        uint256 childBefore = usdc.balanceOf(childAddr);
        vm.prank(childAddr);
        vr.redeem(voucherId, vc);
        assertEq(usdc.balanceOf(childAddr) - childBefore, voucherAmount, "child got USDC");
    }

    function test_RedeemRevertsAlreadyRedeemed() public {
        bytes memory vc = _validLineageReferralVC(address(genesis));
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(childAddr);
        vr.redeem(voucherId, vc);

        vm.prank(childAddr);
        vm.expectRevert(VoucherRedeem.AlreadyRedeemed.selector);
        vr.redeem(voucherId, vc);
    }

    function test_RedeemRevertsOnForgedVC() public {
        bytes memory forged = _forgedLineageReferralVC(address(genesis));
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(childAddr);
        vm.expectRevert(VoucherRedeem.SealMismatch.selector);
        vr.redeem(voucherId, forged);
    }

    function test_RedeemRevertsOnNonexistentVoucher() public {
        bytes memory vc = _validLineageReferralVC(address(genesis));
        vm.warp(block.timestamp + 7 days + 1);
        bytes32 fakeId = bytes32(uint256(0xDEAD));
        vm.prank(childAddr);
        vm.expectRevert(VoucherRedeem.NotEligible.selector);
        vr.redeem(fakeId, vc);
    }

    function test_RedeemRecordsRepaymentObligation() public {
        bytes memory vc = _validLineageReferralVC(address(genesis));
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(childAddr);
        vr.redeem(voucherId, vc);

        assertEq(vr.outstandingRepayment(childAddr), voucherAmount * 120 / 100);
        assertEq(vr.repaymentCap(childAddr), voucherAmount * 120 / 100);
        assertEq(vr.repaidTotal(childAddr), 0);
    }
}

contract MatchingEngineTest is MGPFixture {
    function _setup() internal returns (bytes32) {
        _registerRoot(ROOT_DID, rootAddr, ROOT_PK, address(genesis), block.chainid);
        _registerChild(CHILD_DID, childAddr, ROOT_DID, ROOT_PK, address(genesis), block.chainid);
        _registerChild(DONOR_DID, donorAddr, ROOT_DID, ROOT_PK, address(genesis), block.chainid);
        return DONOR_DID;
    }

    function test_MatchEventEmitted() public {
        bytes32 did = _setup();
        uint256 amount = 10e6;
        bytes32 nonce = bytes32(uint256(1000));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount, 0, type(uint256).max, nonce, DONOR_PK
        );
        vm.prank(donorAddr);
        vm.expectEmit(true, false, false, true);
        emit MatchingEngine.Match(nonce, amount);
        pool.donate(donorAddr, amount, did, nonce, 0, type(uint256).max, sig, false);
    }

    function test_RevertsWhenCalledByNonPool() public {
        vm.expectRevert(MatchingEngine.OnlyPool.selector);
        me.onDonation(bytes32(uint256(1)), donorAddr, 10e6);
    }

    function test_MonthlyCapEnforced() public {
        bytes32 did = _setup();
        uint256 amount = 5_000e6;
        bytes32 nonce = bytes32(uint256(1001));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount, 0, type(uint256).max, nonce, DONOR_PK
        );
        vm.prank(donorAddr);
        pool.donate(donorAddr, amount, did, nonce, 0, type(uint256).max, sig, false);
        assertEq(me.remainingMonthlyCap(), 0, "monthly cap exhausted");

        uint256 amount2 = 10e6;
        bytes32 nonce2 = bytes32(uint256(1002));
        bytes memory sig2 = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount2, 0, type(uint256).max, nonce2, DONOR_PK
        );
        vm.prank(donorAddr);
        vm.expectEmit(false, false, false, false);
        emit MatchingEngine.MatchBudgetExhausted();
        pool.donate(donorAddr, amount2, did, nonce2, 0, type(uint256).max, sig2, false);
    }

    function test_MatchBudgetExhaustedEmittedOnce() public {
        bytes32 did = _setup();
        uint256 amount = 5_000e6;
        bytes32 nonce = bytes32(uint256(2000));
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount, 0, type(uint256).max, nonce, DONOR_PK
        );
        vm.prank(donorAddr);
        pool.donate(donorAddr, amount, did, nonce, 0, type(uint256).max, sig, false);

        uint256 amount2 = 1e6;
        bytes32 nonce2 = bytes32(uint256(2001));
        bytes memory sig2 = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount2, 0, type(uint256).max, nonce2, DONOR_PK
        );
        vm.prank(donorAddr);
        vm.expectEmit(false, false, false, false);
        emit MatchingEngine.MatchBudgetExhausted();
        pool.donate(donorAddr, amount2, did, nonce2, 0, type(uint256).max, sig2, false);

        uint256 amount3 = 1e6;
        bytes32 nonce3 = bytes32(uint256(2002));
        bytes memory sig3 = _signReceiveWithAuthorization(
            address(usdc), donorAddr, address(pool), amount3, 0, type(uint256).max, nonce3, DONOR_PK
        );
        vm.prank(donorAddr);
        pool.donate(donorAddr, amount3, did, nonce3, 0, type(uint256).max, sig3, false);
        assertTrue(me.budgetExhaustedEventEmitted());
    }
}
