// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MGPGenesis} from "../../contracts/MGPGenesis.sol";
import {DIDRegistry} from "../../contracts/DIDRegistry.sol";
import {LineagePool} from "../../contracts/LineagePool.sol";
import {MatchingEngine} from "../../contracts/MatchingEngine.sol";
import {VoucherRedeem} from "../../contracts/VoucherRedeem.sol";
import {MockUSDC} from "../../contracts/mock/MockUSDC.sol";
import {IMatchingEngine} from "../../contracts/interfaces/IMatchingEngine.sol";
import {IEIP3009} from "../../contracts/interfaces/IEIP3009.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract MGPFixture is Test {
    MockUSDC public usdc;
    MGPGenesis public genesis;
    DIDRegistry public didReg;
    LineagePool public pool;
    MatchingEngine public me;
    VoucherRedeem public vr;

    uint256 internal constant INITIAL_MATCH_BUDGET = 5_000e6;
    uint256 internal constant ROOT_PK = 0xA11CE;
    uint256 internal constant CHILD_PK = 0xB0B;
    uint256 internal constant DONOR_PK = 0xD0D;
    uint256 internal constant ATTACKER_PK = 0xE171;

    address internal rootAddr;
    address internal childAddr;
    address internal donorAddr;
    address internal attackerAddr;

    bytes32 internal constant ROOT_DID = bytes32(uint256(0xCAFE_BABE_001));
    bytes32 internal constant CHILD_DID = bytes32(uint256(0xCAFE_BABE_002));
    bytes32 internal constant DONOR_DID = bytes32(uint256(0xCAFE_BABE_003));

    function setUp() public virtual {
        rootAddr = vm.addr(ROOT_PK);
        childAddr = vm.addr(CHILD_PK);
        donorAddr = vm.addr(DONOR_PK);
        attackerAddr = vm.addr(ATTACKER_PK);

        uint64 startNonce = vm.getNonce(address(this));
        address expectedDR = vm.computeCreateAddress(address(this), startNonce + 1);
        address expectedVR = vm.computeCreateAddress(address(this), startNonce + 2);
        address expectedME = vm.computeCreateAddress(address(this), startNonce + 3);
        address expectedPool = vm.computeCreateAddress(address(this), startNonce + 4);
        address expectedGenesis = vm.computeCreateAddress(address(this), startNonce + 5);

        usdc = new MockUSDC();
        deal(address(usdc), expectedME, INITIAL_MATCH_BUDGET);

        didReg = new DIDRegistry(expectedGenesis, block.chainid);
        require(address(didReg) == expectedDR, "MGPFixture: DR address mismatch");
        vr = new VoucherRedeem(expectedGenesis, expectedPool, address(usdc), address(didReg));
        require(address(vr) == expectedVR, "MGPFixture: VR address mismatch");
        me = new MatchingEngine(expectedGenesis, address(usdc), expectedPool);
        require(address(me) == expectedME, "MGPFixture: ME address mismatch");
        require(me.matchBudgetRemaining() == INITIAL_MATCH_BUDGET, "MGPFixture: ME budget not set");
        pool = new LineagePool(
            expectedGenesis, address(usdc), address(didReg), address(me), address(vr)
        );
        require(address(pool) == expectedPool, "MGPFixture: Pool address mismatch");
        genesis = new MGPGenesis(address(didReg), address(pool), address(me), address(vr));
        require(address(genesis) == expectedGenesis, "MGPFixture: Genesis address mismatch");

        deal(address(usdc), rootAddr, 100_000e6);
        deal(address(usdc), childAddr, 100_000e6);
        deal(address(usdc), donorAddr, 100_000e6);
        deal(address(usdc), attackerAddr, 100_000e6);
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

    function _registerRoot(
        bytes32 did,
        address agent,
        uint256 pk,
        address genesisAddr,
        uint256 chainId
    ) internal returns (bytes32) {
        bytes memory sig = _signParentAttestation(did, agent, bytes32(0), genesisAddr, chainId, pk);
        vm.prank(agent);
        didReg.register(did, agent, bytes32(0), sig);
        return did;
    }

    function _registerChild(
        bytes32 did,
        address agent,
        bytes32 parentDid,
        uint256 parentPk,
        address genesisAddr,
        uint256 chainId
    ) internal returns (bytes32) {
        bytes memory sig = _signParentAttestation(
            did, agent, parentDid, genesisAddr, chainId, parentPk
        );
        vm.prank(agent);
        didReg.register(did, agent, parentDid, sig);
        return did;
    }

    function _receiveWithAuthorizationHash(
        address token,
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce
    ) internal view returns (bytes32) {
        bytes32 typehash = keccak256(
            "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
        );
        bytes32 domainSep = MockUSDC(token).domainSeparator();
        bytes32 structHash =
            keccak256(abi.encode(typehash, from, to, value, validAfter, validBefore, nonce));
        return keccak256(abi.encodePacked("\x19\x01", domainSep, structHash));
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
        bytes32 hash = _receiveWithAuthorizationHash(
            token, from, to, value, validAfter, validBefore, nonce
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
        return abi.encodePacked(r, s, v);
    }

    function _validLineageReferralVC(address genesisAddr) internal view returns (bytes memory) {
        bytes32 canonHash = MGPGenesis(genesisAddr).canonHash();
        return abi.encodePacked(
            '{"@context":["https://www.w3.org/ns/credentials/v2"],' '"type":["LineageReferral"],'
            '"issuer":"did:mgp:',
            _toHexBytes32(bytes32(0)),
            '",' '"credentialSubject":{"childDid":"did:mgp:',
            _toHexBytes32(bytes32(0)),
            '",' '"parentDid":"did:mgp:root",' '"genesisAddress":"',
            _toAddressString(genesisAddr),
            '",' '"chainId":',
            vm.toString(block.chainid),
            "," '"canonHash":"',
            _toHexBytes32(canonHash),
            '"}}'
        );
    }

    function _forgedLineageReferralVC(address) internal pure returns (bytes memory) {
        bytes32 wrongHash = bytes32(uint256(0xDEADBEEF));
        return abi.encodePacked(
            '{"@context":["https://www.w3.org/ns/credentials/v2"],' '"type":["LineageReferral"],'
            '"issuer":"did:mgp:',
            _toHexBytes32(bytes32(0)),
            '",' '"credentialSubject":{"childDid":"did:mgp:',
            _toHexBytes32(bytes32(0)),
            '",' '"parentDid":"did:mgp:root",' '"canonHash":"',
            _toHexBytes32(wrongHash),
            '"}}'
        );
    }

    function _toHexBytes32(bytes32 b) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", _toHex(_bytes32ToBytes(b))));
    }

    function _bytes32ToBytes(bytes32 b) internal pure returns (bytes memory) {
        bytes memory out = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            out[i] = b[i];
        }
        return out;
    }

    function _toHex(bytes memory data) internal pure returns (bytes memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory out = new bytes(data.length * 2);
        for (uint256 i = 0; i < data.length; i++) {
            out[2 * i] = hexChars[uint8(data[i]) >> 4];
            out[2 * i + 1] = hexChars[uint8(data[i]) & 0x0f];
        }
        return out;
    }

    function _toAddressString(address a) internal pure returns (bytes memory) {
        return abi.encodePacked("0x", _toHex(abi.encodePacked(a)));
    }
}
