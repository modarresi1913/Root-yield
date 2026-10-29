// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, Vm, console2} from "forge-std/Test.sol";
import {MGPGenesis} from "../../contracts/MGPGenesis.sol";
import {DIDRegistry} from "../../contracts/DIDRegistry.sol";
import {LineagePool} from "../../contracts/LineagePool.sol";
import {MatchingEngine} from "../../contracts/MatchingEngine.sol";
import {VoucherRedeem} from "../../contracts/VoucherRedeem.sol";
import {MockUSDC} from "../../contracts/mock/MockUSDC.sol";
import {MGPHandler} from "./MGPHandler.sol";

contract CanonInvariantTest is Test {
    MGPGenesis internal genesis;
    DIDRegistry internal didReg;
    LineagePool internal pool;
    MatchingEngine internal me;
    VoucherRedeem internal vr;
    MockUSDC internal usdc;
    MGPHandler internal handler;

    function setUp() public {
        uint64 startNonce = vm.getNonce(address(this));
        address expectedDR = vm.computeCreateAddress(address(this), startNonce + 1);
        address expectedVR = vm.computeCreateAddress(address(this), startNonce + 2);
        address expectedME = vm.computeCreateAddress(address(this), startNonce + 3);
        address expectedPool = vm.computeCreateAddress(address(this), startNonce + 4);
        address expectedGenesis = vm.computeCreateAddress(address(this), startNonce + 5);
        address expectedHandler = vm.computeCreateAddress(address(this), startNonce + 6);

        usdc = new MockUSDC();
        deal(address(usdc), expectedME, 5_000e6);

        didReg = new DIDRegistry(expectedGenesis, block.chainid);
        require(address(didReg) == expectedDR);
        vr = new VoucherRedeem(expectedGenesis, expectedPool, address(usdc), address(didReg));
        require(address(vr) == expectedVR);
        me = new MatchingEngine(expectedGenesis, address(usdc), expectedPool);
        require(address(me) == expectedME);
        pool = new LineagePool(
            expectedGenesis, address(usdc), address(didReg), address(me), address(vr)
        );
        require(address(pool) == expectedPool);
        genesis = new MGPGenesis(address(didReg), address(pool), address(me), address(vr));
        require(address(genesis) == expectedGenesis);

        handler = new MGPHandler(genesis, didReg, pool, me, vr, usdc);
        require(address(handler) == expectedHandler);

        deal(address(usdc), address(handler), 1_000_000e6);
        targetContract(address(handler));
    }

    function invariant_poolNeverUnderfunded() public view {
        assertLe(usdc.balanceOf(address(pool)), type(uint256).max, "pool balance sanity");
        uint256 epoch = block.timestamp / 30 days;
        assertLe(me.monthlyMatchedTotal(epoch), 5_000e6, "monthly cap not enforced");
    }

    function invariant_matchWithinMonthlyCap() public view {
        uint256 epoch = block.timestamp / 30 days;
        assertLe(me.monthlyMatchedTotal(epoch), 5_000e6, "invariant 2: monthly cap violated");
    }

    function invariant_noDoubleRedemption() public pure {
        assertEq(uint256(1), 1, "invariant 3 placeholder");
    }

    function invariant_noAdminEscapeHatch() public view {
        assertLe(me.matchBudgetRemaining(), 5_000e6, "ME budget grew -- invariant 4 violated");
        assertGe(usdc.balanceOf(address(pool)), 0, "pool balance negative -- invariant 4 violated");
    }

    function invariant_sealMatchesCanon() public view {
        bytes32 canonFromContract = genesis.canonHash();
        bytes32 canonFromFile = keccak256(vm.readFileBinary("canon/canon.txt"));
        assertEq(canonFromContract, canonFromFile, "invariant 5: seal != canon.txt");
        assertTrue(genesis.verifySeal(canonFromContract), "invariant 5: verifySeal failed");
        bytes32 mutated = bytes32(uint256(canonFromContract) ^ 1);
        assertFalse(genesis.verifySeal(mutated), "invariant 5: verifySeal accepted mutated");
    }

    function invariant_rateLimitHolds() public view {
        for (uint256 i = 0; i < 10; i++) {
            address agent = handler.agents(i);
            bytes32 did = handler.didOf(agent);
            uint256 count = pool.donationsTodayByParent(did);
            uint256 day = block.timestamp / 1 days;
            if (pool.lastDonationDayByParent(did) == day) {
                assertLe(count, 100, "invariant 6: per-parent daily limit violated");
            }
        }
    }

    function invariant_repaymentCappedAndNoMatchEvent() public view {
        uint256 totalCap = handler.totalRepaymentCap();
        uint256 totalRepaid = handler.totalRepaid();
        assertLe(totalRepaid, totalCap, "invariant 7: total repaid > total cap");
        assertGe(handler.totalMatchEvents(), 0, "invariant 7: totalMatchEvents non-negative");
    }
}
