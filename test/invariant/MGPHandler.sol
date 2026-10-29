// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, Vm} from "forge-std/Test.sol";
import {MGPGenesis} from "../../contracts/MGPGenesis.sol";
import {DIDRegistry} from "../../contracts/DIDRegistry.sol";
import {LineagePool} from "../../contracts/LineagePool.sol";
import {MatchingEngine} from "../../contracts/MatchingEngine.sol";
import {VoucherRedeem} from "../../contracts/VoucherRedeem.sol";
import {MockUSDC} from "../../contracts/mock/MockUSDC.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MGPHandler is Test {
    MGPGenesis public genesis;
    DIDRegistry public didReg;
    LineagePool public pool;
    MatchingEngine public me;
    VoucherRedeem public vr;
    MockUSDC public usdc;

    address[] public agents;
    bytes32[] public dids;
    mapping(address => uint256) public pks;
    mapping(address => bytes32) public didOf;
    mapping(address => uint256) public nonceCounter;

    bytes32[] public allVoucherIds;
    uint256 public totalMatchEvents;

    constructor(
        MGPGenesis genesis_,
        DIDRegistry didReg_,
        LineagePool pool_,
        MatchingEngine me_,
        VoucherRedeem vr_,
        MockUSDC usdc_
    ) {
        genesis = genesis_;
        didReg = didReg_;
        pool = pool_;
        me = me_;
        vr = vr_;
        usdc = usdc_;

        for (uint256 i = 0; i < 5; i++) {
            uint256 pk = 0xA11CE_0000 + i;
            address a = vm.addr(pk);
            pks[a] = pk;
            agents.push(a);
            bytes32 did = bytes32(uint256(0xCAFE_0000 + i));
            didOf[a] = did;
            dids.push(did);
            deal(address(usdc), a, 1_000_000e6);
            _registerAsRoot(did, a, pk);
        }
        for (uint256 i = 0; i < 5; i++) {
            uint256 pk = 0xB0B_0000 + i;
            address a = vm.addr(pk);
            pks[a] = pk;
            agents.push(a);
            bytes32 did = bytes32(uint256(0xC41D_0000 + i));
            didOf[a] = did;
            dids.push(did);
            deal(address(usdc), a, 1_000_000e6);
            _registerAsChild(did, a, dids[0], pks[agents[0]]);
        }
    }

    function donate(uint256 agentIdx, uint256 amount, bool repay) external {
        amount = bound(amount, 1e6, 50_000e6);
        address agent = agents[agentIdx % agents.length];
        bytes32 did = didOf[agent];
        bytes32 nonce = bytes32(uint256(0x0BADF00D) | nonceCounter[agent]);
        nonceCounter[agent]++;

        uint256 eip3009Value = repay ? amount + (amount * 100) / 10_000 : amount;
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc),
            agent,
            address(pool),
            eip3009Value,
            0,
            type(uint256).max,
            nonce,
            pks[agent]
        );
        vm.prank(agent);
        vm.recordLogs();
        try pool.donate(agent, amount, did, nonce, 0, type(uint256).max, sig, repay) {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            for (uint256 i = 0; i < logs.length; i++) {
                if (
                    logs[i].emitter == address(me)
                        && logs[i].topics[0] == keccak256("Match(bytes32,uint256)")
                ) {
                    totalMatchEvents++;
                }
            }
        } catch {}
    }

    function advanceTime(uint256 secs) external {
        secs = bound(secs, 0, 30 days);
        vm.warp(block.timestamp + secs);
    }

    function repayViaFlaggedDonation(uint256 agentIdx, uint256 amount) external {
        amount = bound(amount, 1e6, 100_000e6);
        address agent = agents[agentIdx % agents.length];
        bytes32 did = didOf[agent];
        bytes32 nonce = bytes32(uint256(0x0BADCAFE) | nonceCounter[agent]);
        nonceCounter[agent]++;
        uint256 eip3009Value = amount + (amount * 100) / 10_000;
        bytes memory sig = _signReceiveWithAuthorization(
            address(usdc),
            agent,
            address(pool),
            eip3009Value,
            0,
            type(uint256).max,
            nonce,
            pks[agent]
        );
        vm.prank(agent);
        try pool.donate(agent, amount, did, nonce, 0, type(uint256).max, sig, true) {} catch {}
    }

    function redeem(uint256 voucherIdx) external {
        if (allVoucherIds.length == 0) return;
        bytes32 voucherId = allVoucherIds[voucherIdx % allVoucherIds.length];
        (, address child,,,, uint64 redeemableAt, bool redeemed,,) = vr.vouchers(voucherId);
        if (redeemed) return;
        if (block.timestamp < redeemableAt) return;
        bytes memory vc = _validLineageReferralVC();
        vm.prank(child);
        try vr.redeem(voucherId, vc) {} catch {}
    }

    function verifySeal(bytes32 h) external view returns (bool) {
        return genesis.verifySeal(h);
    }

    function outstandingVoucherTotal() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < allVoucherIds.length; i++) {
            (,,, uint256 amount,,, bool redeemed,,) = vr.vouchers(allVoucherIds[i]);
            if (!redeemed) total += amount;
        }
        return total;
    }

    function totalRepaymentCap() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < agents.length; i++) {
            total += vr.repaymentCap(agents[i]);
        }
        return total;
    }

    function totalRepaid() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < agents.length; i++) {
            total += vr.repaidTotal(agents[i]);
        }
        return total;
    }

    function _registerAsRoot(bytes32 did, address agent, uint256 pk) internal {
        bytes memory sig =
            _signParentAttestation(did, agent, bytes32(0), address(genesis), block.chainid, pk);
        vm.prank(agent);
        didReg.register(did, agent, bytes32(0), sig);
    }

    function _registerAsChild(bytes32 did, address agent, bytes32 parentDid, uint256 parentPk)
        internal
    {
        bytes memory sig = _signParentAttestation(
            did, agent, parentDid, address(genesis), block.chainid, parentPk
        );
        vm.prank(agent);
        didReg.register(did, agent, parentDid, sig);
    }

    function _signParentAttestation(
        bytes32 did,
        address agent,
        bytes32 parentDid,
        address genesisAddr,
        uint256 chainId,
        uint256 pk
    ) internal pure returns (bytes memory) {
        bytes32 payloadHash = keccak256(abi.encode(did, agent, parentDid, genesisAddr, chainId));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(payloadHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function _signReceiveWithAuthorization(
        address token,
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint256 pk
    ) internal view returns (bytes memory) {
        bytes32 typehash = keccak256(
            "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
        );
        bytes32 domainSep = MockUSDC(token).domainSeparator();
        bytes32 structHash =
            keccak256(abi.encode(typehash, from, to, value, validAfter, validBefore, nonce));
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(r, s, v);
    }

    function _validLineageReferralVC() internal view returns (bytes memory) {
        bytes32 canonHash = genesis.canonHash();
        return
            abi.encodePacked(
                '{"credentialSubject":{"canonHash":"0x', _toHexBytes32(canonHash), '"}}'
            );
    }

    function _toHexBytes32(bytes32 b) internal pure returns (bytes memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory out = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            out[2 * i] = hexChars[uint8(b[i]) >> 4];
            out[2 * i + 1] = hexChars[uint8(b[i]) & 0x0f];
        }
        return out;
    }

    function refreshVoucherList() external {}
}
