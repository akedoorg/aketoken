// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interface/Base.sol";


contract InvestorsPool is Initializable, UUPSUpgradeable, OwnableUpgradeable, IBase {

    using SafeERC20 for IERC20;
    using Math for uint256;

    event WithdrawEvent(address indexed from, address indexed token, uint256 value);
    event SetUnlockTimeEvent(uint256 unlockTime);
    event SetInvestorsEvent(address[] accounts, uint256[] amounts);
    event AdminWithdrawEvent(address indexed to, address indexed token, uint256 value);
    address public tokenAddress;
    
    mapping(address => uint256) public investors;//total amount
    mapping(address => uint256) public investorsReceivedAmount;//already received amount

    uint256 public unlockTime;
    uint256 public constant investorLockTimeOffset = 24;
   
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

    function setInvestors(address[] memory accounts, uint256[] memory amounts) external onlyOwner {
        require(accounts.length == amounts.length, "Accounts and amounts length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            investors[accounts[i]] = amounts[i];
        }
        emit SetInvestorsEvent(accounts, amounts);
    }

    //5% of initial holdings, linear unlock starting from month 4, unlocking 1/45 each month
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
        // Start unlocking from month 4 (no additional unlock in first 3 months)
        if(monthsPassed >= 4) {
            // Calculate unlock months starting from month 4
            uint256 linearUnlockMonths = monthsPassed - 3; // Starting from month 4, so subtract 3
            
            // Maximum unlock period is 45 months (remaining 95% distributed over 45 months)
            if(linearUnlockMonths > investorLockTimeOffset) {
                linearUnlockMonths = investorLockTimeOffset;
            }
            
            uint256 linearUnlock = (totalAmout  * linearUnlockMonths) / investorLockTimeOffset;
            unlockAmount += linearUnlock;
        }
        
        return unlockAmount;
    }

    function memberWithdraw() external {
        uint256 amount = getRemainingAmount();
        require(amount > 0, "No unlock amount");
        investorsReceivedAmount[msg.sender] += amount;
        IERC20 token = IERC20(tokenAddress);    
        token.safeTransfer(msg.sender, amount); 
        emit WithdrawEvent(msg.sender, tokenAddress, amount);
    }

    function getRemainingAmount() public view returns (uint256) {
        uint256 unlockAmount = _calculateUnlockAmount(investors[msg.sender]);
        return unlockAmount - investorsReceivedAmount[msg.sender];
    }

    function getReceivedAmount() external view returns (uint256) {
        return investorsReceivedAmount[msg.sender];
    }

    function getTotalAmount() external view returns (uint256) {
        return investors[msg.sender];
    }

    function getUnlockTime() external view returns (uint256) {
        return unlockTime;
    }

    function getLockedAmount() external view returns (uint256) {
        uint256 unlockAmount = _calculateUnlockAmount(investors[msg.sender]);
        return investors[msg.sender] - unlockAmount;
    }
    function adminWithdraw() external onlyOwner {
        require(block.timestamp > unlockTime + 46*43 days, "Unlock time not reached");
        IERC20 token = IERC20(tokenAddress); 
        token.safeTransfer(owner(), token.balanceOf(address(this))); 
        emit AdminWithdrawEvent(owner(), tokenAddress, token.balanceOf(address(this)));
    }
}