// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interface/Base.sol";


contract KOLPool is Initializable, UUPSUpgradeable, OwnableUpgradeable, IBase {

    using SafeERC20 for IERC20;
    using Math for uint256;

    struct KOL {
        uint256 totalAmount;
        uint256 receivedAmount;
        uint256 unlockTime;
    }

    event WithdrawEvent(address indexed from, address indexed token, uint256 value);
    event SetKOLEvent(address[] accounts, uint256[] amounts, uint256[] unlockTimes);
    event AdminWithdrawEvent(address indexed to, address indexed token, uint256 value);

    address public tokenAddress;
    
    mapping(address => KOL) public kol;  

   
    function initialize(address token) public initializer {
        __Ownable_init(msg.sender); 
        __UUPSUpgradeable_init(); 
        tokenAddress = token;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setKOL(address[] memory accounts, uint256[] memory amounts, uint256[] memory unlockTimes) external onlyOwner {
        require(accounts.length == amounts.length, "Accounts and amounts length mismatch");
        require(accounts.length == unlockTimes.length, "Accounts and unlockTimes length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            kol[accounts[i]] = KOL(amounts[i], 0, unlockTimes[i]);
        }
        emit SetKOLEvent(accounts, amounts, unlockTimes);
    }

   //20% of initial holdings, unlocking 1/6 each month
    function _calculateUnlockAmount(uint256 totalAmout, uint256 unlockTime) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 unlockAmount = 0;
        require(totalAmout > 0, "Total amount is 0");
        require(unlockTime > 0, "Unlock time is 0");
        if(currentTime < unlockTime){
            return 0;
        }
        unlockAmount = totalAmout * 20 / 100;    
        uint256 deltaTime = currentTime - unlockTime;
        // uint256 monthsPassed = deltaTime / (30 days); // Calculate the number of months passed
        uint256 monthsPassed = deltaTime / (30 minutes); // Calculate the number of months passed
        
        // Unlock starts from the 1st month (no unlock in the first 5 months)
        if(monthsPassed >= 1) {
        
            // Calculate the number of unlock months starting from the 1st month, 
            uint256 unlockMonths = monthsPassed;
            
            // Maximum unlock period is 6 months
            if(unlockMonths > 6) {
                unlockMonths = 6;
            }
            
            // Use safe integer calculation to avoid precision loss: (totalAmout * unlockMonths) / 42
            unlockAmount += (totalAmout - unlockAmount) * unlockMonths / 6;
        }
        return unlockAmount;
    }

    function memberWithdraw() external {
        uint256 unlockAmount = _calculateUnlockAmount(kol[msg.sender].totalAmount, kol[msg.sender].unlockTime);
         uint256 amount = unlockAmount - kol[msg.sender].receivedAmount;
        require(amount > 0, "No amount");
        kol[msg.sender].receivedAmount += amount;
        IERC20 token = IERC20(tokenAddress); 
        token.safeTransfer(msg.sender, amount); 
        emit WithdrawEvent(msg.sender, tokenAddress, amount);
    }

    function getRemainingAmount() public view returns (uint256) {
        uint256 unlockAmount = _calculateUnlockAmount(kol[msg.sender].totalAmount, kol[msg.sender].unlockTime);
        return unlockAmount - kol[msg.sender].receivedAmount;
    }

    function getReceivedAmount() external view returns (uint256) {
        return kol[msg.sender].receivedAmount;
    }

    function getTotalAmount() external view returns (uint256) {
        return kol[msg.sender].totalAmount;
    }

    function getUnlockTime() external view returns (uint256) {
        return kol[msg.sender].unlockTime;
    }

    function getLockedAmount() external view returns (uint256) {
        uint256 unlockAmount = _calculateUnlockAmount(kol[msg.sender].totalAmount, kol[msg.sender].unlockTime);
        return kol[msg.sender].totalAmount - unlockAmount;
    }
    /// @notice 
    function adminWithdraw() external onlyOwner {
        require(block.timestamp > 30 * 43 days, "Unlock time not reached");
        IERC20 token = IERC20(tokenAddress); 
        token.safeTransfer(owner(), token.balanceOf(address(this))); 
        emit AdminWithdrawEvent(owner(), tokenAddress, token.balanceOf(address(this)));
    }
}