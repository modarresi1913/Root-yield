// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVoucherRedeem {
    function onGenerationBorn(uint256 generationId) external;
    function onRepaymentDonation(address child, uint256 amount) external;
    function vouchers(bytes32 voucherId)
        external
        view
        returns (
            bytes32 id,
            address child,
            bytes32 parentDid,
            uint256 amount,
            uint64 issuedAt,
            uint64 redeemableAt,
            bool redeemed,
            uint16 repaymentBps,
            uint16 capMultiplier
        );
    function outstandingRepayment(address child) external view returns (uint256);
    function repaymentCap(address child) external view returns (uint256);
    function repaidTotal(address child) external view returns (uint256);
}
