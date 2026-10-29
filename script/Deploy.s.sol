// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MGPGenesis} from "../contracts/MGPGenesis.sol";
import {DIDRegistry} from "../contracts/DIDRegistry.sol";
import {LineagePool} from "../contracts/LineagePool.sol";
import {MatchingEngine} from "../contracts/MatchingEngine.sol";
import {VoucherRedeem} from "../contracts/VoucherRedeem.sol";
import {MockUSDC} from "../contracts/mock/MockUSDC.sol";

contract Deploy is Script {
    uint256 internal constant INITIAL_MATCH_BUDGET = 5_000e6;

    function run() public {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);
        uint64 startNonce = vm.getNonce(deployer);

        address usdcAddr = vm.envOr("USDC_ADDRESS", address(0));
        uint8 offset = 0;
        if (usdcAddr == address(0)) {
            offset = 2;
        }
        address expectedDR = vm.computeCreateAddress(deployer, startNonce + offset + 0);
        address expectedVR = vm.computeCreateAddress(deployer, startNonce + offset + 1);
        address expectedME = vm.computeCreateAddress(deployer, startNonce + offset + 2);
        address expectedPool = vm.computeCreateAddress(deployer, startNonce + offset + 3);
        address expectedGenesis = vm.computeCreateAddress(deployer, startNonce + offset + 4);

        vm.startBroadcast(deployerPk);

        if (usdcAddr == address(0)) {
            MockUSDC mockUsdc = new MockUSDC();
            usdcAddr = address(mockUsdc);
            mockUsdc.mint(expectedME, INITIAL_MATCH_BUDGET);
        } else {
            require(
                IERC20(usdcAddr).balanceOf(expectedME) >= INITIAL_MATCH_BUDGET,
                "Deploy: ME not funded with match budget"
            );
        }

        DIDRegistry didReg = new DIDRegistry(expectedGenesis, block.chainid);
        require(address(didReg) == expectedDR, "DR mismatch");

        VoucherRedeem vr =
            new VoucherRedeem(expectedGenesis, expectedPool, usdcAddr, address(didReg));
        require(address(vr) == expectedVR, "VR mismatch");

        MatchingEngine me = new MatchingEngine(expectedGenesis, usdcAddr, expectedPool);
        require(address(me) == expectedME, "ME mismatch");

        LineagePool pool =
            new LineagePool(expectedGenesis, usdcAddr, address(didReg), address(me), address(vr));
        require(address(pool) == expectedPool, "Pool mismatch");

        MGPGenesis genesis =
            new MGPGenesis(address(didReg), address(pool), address(me), address(vr));
        require(address(genesis) == expectedGenesis, "Genesis mismatch");

        vm.stopBroadcast();

        console2.log("MGP deployment complete:");
        console2.log("  Genesis        :", address(genesis));
        console2.log("  DIDRegistry    :", address(didReg));
        console2.log("  LineagePool    :", address(pool));
        console2.log("  MatchingEngine :", address(me));
        console2.log("  VoucherRedeem  :", address(vr));
        console2.log("  USDC           :", usdcAddr);

        vm.writeFile(
            "deployed-addresses.json",
            string(
                abi.encodePacked(
                    "{\"genesis\":\"",
                    addressToString(address(genesis)),
                    "\"," "\"didRegistry\":\"",
                    addressToString(address(didReg)),
                    "\"," "\"pool\":\"",
                    addressToString(address(pool)),
                    "\"," "\"matchingEngine\":\"",
                    addressToString(address(me)),
                    "\"," "\"voucherRedeem\":\"",
                    addressToString(address(vr)),
                    "\"," "\"usdc\":\"",
                    addressToString(usdcAddr),
                    "\"}"
                )
            )
        );
    }

    function addressToString(address a) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory out = new bytes(42);
        out[0] = "0";
        out[1] = "x";
        bytes20 b = bytes20(a);
        for (uint256 i = 0; i < 20; i++) {
            out[2 + 2 * i] = hexChars[uint8(b[i]) >> 4];
            out[2 + 2 * i + 1] = hexChars[uint8(b[i]) & 0x0f];
        }
        return string(out);
    }
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}
