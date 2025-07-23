// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBase {
    function memberWithdraw() external;
    function getRemainingAmount() external view returns (uint256);
    function getReceivedAmount() external view returns (uint256);
    function getTotalAmount() external view returns (uint256);
    function getUnlockTime() external view returns (uint256);
    function getLockedAmount() external view returns (uint256);
}