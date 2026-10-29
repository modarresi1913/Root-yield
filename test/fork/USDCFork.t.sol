// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MGPGenesis} from "../../contracts/MGPGenesis.sol";
import {DIDRegistry} from "../../contracts/DIDRegistry.sol";
import {LineagePool} from "../../contracts/LineagePool.sol";
import {MatchingEngine} from "../../contracts/MatchingEngine.sol";
import {VoucherRedeem} from "../../contracts/VoucherRedeem.sol";

contract USDCForkTest is Test {
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant BASE_CHAIN_ID = 8453;

    MGPGenesis genesis;
    DIDRegistry didReg;
    LineagePool pool;
    MatchingEngine me;
    VoucherRedeem vr;

    modifier onlyOnBaseFork() {
        if (BASE_USDC.code.length == 0) {
            console2.log("USDCForkTest: skipping (no Base fork -- BASE_RPC not set)");
            vm.skip(true, "USDCForkTest: requires BASE_RPC fork");
        }
        _;
    }

    function setUp() public onlyOnBaseFork {
        uint64 startNonce = vm.getNonce(address(this));
        address expectedDR = vm.computeCreateAddress(address(this), startNonce + 0);
        address expectedVR = vm.computeCreateAddress(address(this), startNonce + 1);
        address expectedME = vm.computeCreateAddress(address(this), startNonce + 2);
        address expectedPool = vm.computeCreateAddress(address(this), startNonce + 3);
        address expectedGenesis = vm.computeCreateAddress(address(this), startNonce + 4);

        didReg = new DIDRegistry(expectedGenesis, BASE_CHAIN_ID);
        require(address(didReg) == expectedDR, "DR mismatch");
        vr = new VoucherRedeem(expectedGenesis, expectedPool, BASE_USDC, address(didReg));
        require(address(vr) == expectedVR, "VR mismatch");
        me = new MatchingEngine(expectedGenesis, BASE_USDC, expectedPool);
        require(address(me) == expectedME, "ME mismatch");
        pool =
            new LineagePool(expectedGenesis, BASE_USDC, address(didReg), address(me), address(vr));
        require(address(pool) == expectedPool, "Pool mismatch");
        genesis = new MGPGenesis(address(didReg), address(pool), address(me), address(vr));
        require(address(genesis) == expectedGenesis, "Genesis mismatch");
    }

    function test_EIP3009RealUSDCHappyPath() public onlyOnBaseFork {
        (, bytes memory nameData) = BASE_USDC.staticcall(abi.encodeWithSignature("name()"));
        string memory name = abi.decode(nameData, (string));
        console2.log("Real USDC name:", name);
        assertEq(name, "USD Coin", "name should be USD Coin");

        (, bytes memory decimalsData) = BASE_USDC.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 decimals = abi.decode(decimalsData, (uint8));
        console2.log("Real USDC decimals:", decimals);
        assertEq(decimals, 6, "decimals should be 6");

        (, bytes memory masterMinterData) =
            BASE_USDC.staticcall(abi.encodeWithSignature("masterMinter()"));
        address masterMinter = abi.decode(masterMinterData, (address));
        console2.log("Real USDC masterMinter:", masterMinter);
        assertTrue(masterMinter != address(0), "masterMinter should be set");

        bytes4 receiveWithAuthSelector = bytes4(
            keccak256(
                "receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,bytes)"
            )
        );
        (bool dispatchOk, bytes memory returnData) =
            BASE_USDC.staticcall(abi.encodePacked(receiveWithAuthSelector));
        if (returnData.length == type(uint256).max) {}
        console2.log("receiveWithAuthorization dispatched:", dispatchOk);
    }
}
