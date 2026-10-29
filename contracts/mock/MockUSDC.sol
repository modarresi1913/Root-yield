// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title MockUSDC — EIP-3009-capable USDC mock for tests and the demo.
contract MockUSDC is ERC20, EIP712 {
    bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = keccak256(
        "TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );
    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH = keccak256(
        "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );

    uint8 private constant DECIMALS = 6;
    mapping(address => mapping(bytes32 => bool)) private _usedNonces;

    event Minted(address indexed to, uint256 amount);

    constructor() ERC20("USD Coin", "USDC") EIP712("FiatToken", "2") {}

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function domainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes calldata signature
    ) external {
        _requireAuthorizationState(from, nonce, validAfter, validBefore);
        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore,
                    nonce
                )
            )
        );
        address signer = ECDSA.recover(hash, signature);
        if (signer != from) revert InvalidSignature();
        _usedNonces[from][nonce] = true;
        _transfer(from, to, value);
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes calldata signature
    ) external {
        _requireAuthorizationState(from, nonce, validAfter, validBefore);
        if (to != msg.sender) revert ReceiverMustBeCaller();
        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    RECEIVE_WITH_AUTHORIZATION_TYPEHASH,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore,
                    nonce
                )
            )
        );
        address signer = ECDSA.recover(hash, signature);
        if (signer != from) revert InvalidSignature();
        _usedNonces[from][nonce] = true;
        _transfer(from, to, value);
    }

    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool) {
        return _usedNonces[authorizer][nonce];
    }

    function _requireAuthorizationState(
        address authorizer,
        bytes32 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) internal view {
        if (block.timestamp <= validAfter) revert AuthorizationNotYetValid();
        if (block.timestamp > validBefore) revert AuthorizationExpired();
        if (_usedNonces[authorizer][nonce]) revert AuthorizationAlreadyUsed();
    }

    error InvalidSignature();
    error ReceiverMustBeCaller();
    error AuthorizationNotYetValid();
    error AuthorizationExpired();
    error AuthorizationAlreadyUsed();
}
