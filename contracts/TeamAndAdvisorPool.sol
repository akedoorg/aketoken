// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";


import "./interface/Base.sol";


contract TeamAndAdvisorPool is Initializable, UUPSUpgradeable, OwnableUpgradeable, IBase {

    using SafeERC20 for IERC20;
    using Math for uint256;

    event WithdrawEvent(address indexed from, address indexed token, uint256 value);
    event SetUnlockTimeEvent(uint256 unlockTime);
    event SetTeamAndAdvisorEvent(address[] accounts, uint256[] amounts);
    event AdminWithdrawEvent(address indexed to, address indexed token, uint256 value);

    address public tokenAddress;
    
    mapping(address => uint256) public teamAndAdvisor;//total amount
    mapping(address => uint256) public teamAndAdvisorReceivedAmount;//already received amount

    uint256 public unlockTime;

    uint256 public constant teamAndAdvisorLockTimeOffset = 42;
   
    function initialize(address token) public initializer {
        __Ownable_init(msg.sender); 
        __UUPSUpgradeable_init(); 
        tokenAddress = token;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setUnlockTime(uint256 _unlockTime) external onlyOwner {
        require(unlockTime == 0, "Unlock time already set");
        unlockTime = _unlockTime;
        emit SetUnlockTimeEvent(_unlockTime);
    }

    function setTeamAndAdvisor(address[] memory accounts, uint256[] memory amounts) external onlyOwner {
        require(accounts.length == amounts.length, "Accounts and amounts length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            teamAndAdvisor[accounts[i]] = amounts[i];
        }
        emit SetTeamAndAdvisorEvent(accounts, amounts);
    }

    //Unlock starts from the 7th month, unlocking 1/42 each month
    function _calculateUnlockAmount(uint256 totalAmout) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 unlockAmount = 0;
        require(unlockTime > 0, "Unlock time is 0");
        if(currentTime < unlockTime){
            return unlockAmount;
        }
        require(totalAmout > 0, "Total amount is 0");
        
        uint256 deltaTime = currentTime - unlockTime;
        uint256 monthsPassed = deltaTime / (30 days); // Calculate the number of months passed
   
        // Unlock starts from the 7th month (no unlock in the first 6 months)
        if(monthsPassed >= 7) {
        
            // Calculate the number of unlock months starting from the 7th month
            uint256 unlockMonths = monthsPassed - 6; // Start calculating from the 7th month, so subtract 6
            
            // Maximum unlock period is 42 months
            if(unlockMonths > teamAndAdvisorLockTimeOffset) {
                unlockMonths = teamAndAdvisorLockTimeOffset;
            }
            
            // Use safe integer calculation to avoid precision loss: (totalAmout * unlockMonths) / 42
            unlockAmount = (totalAmout * unlockMonths) / teamAndAdvisorLockTimeOffset;
        }
        return unlockAmount;
    }

    function memberWithdraw() external {
        uint256 unlockAmount =  _calculateUnlockAmount(teamAndAdvisor[msg.sender]);
        uint256 amount = unlockAmount - teamAndAdvisorReceivedAmount[msg.sender];
        require(amount > 0, "No unlock amount");
        teamAndAdvisorReceivedAmount[msg.sender] += amount;
        IERC20 token = IERC20(tokenAddress); 
        token.safeTransfer(msg.sender, amount); 
        emit WithdrawEvent(msg.sender, tokenAddress, amount);
    }

    function getRemainingAmount() public view returns (uint256) {
        uint256 unlockAmount = _calculateUnlockAmount(teamAndAdvisor[msg.sender]);
        return unlockAmount - teamAndAdvisorReceivedAmount[msg.sender];
    }

    function getReceivedAmount() external view returns (uint256) {
        return teamAndAdvisorReceivedAmount[msg.sender];
    }

    function getTotalAmount() external view returns (uint256) {
        return teamAndAdvisor[msg.sender];
    }

    function getUnlockTime() external view returns (uint256) {
        return unlockTime;
    }

    function getLockedAmount() external view returns (uint256) {
        uint256 unlockAmount = _calculateUnlockAmount(teamAndAdvisor[msg.sender]);
        return teamAndAdvisor[msg.sender] - unlockAmount;
    }
    /// @notice 
    function adminWithdraw() external onlyOwner {
        require(block.timestamp > unlockTime + 30 * 43 days, "Unlock time not reached");
        IERC20 token = IERC20(tokenAddress); 
        token.safeTransfer(owner(), token.balanceOf(address(this))); 
        emit AdminWithdrawEvent(owner(), tokenAddress, token.balanceOf(address(this)));
    }
}