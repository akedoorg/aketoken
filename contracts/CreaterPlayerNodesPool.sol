// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "./library/withdraw.sol";


contract CreaterPlayerNodesPool is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    using SafeERC20 for IERC20;
    using Math for uint256;


    event WithdrawEvent(address indexed from, address indexed token, uint256 value);
    event AdminWithdrawEvent(address indexed to, address indexed token, uint256 value);
    event SetSignerCheckerEvent(address indexed signerChecker);
    event SetUnlockTimeEvent(uint256 indexed unlockTime);

    address public tokenAddress;
    uint256 public totalAmount;
    uint256 public alreadyReceivedAmount;
    uint256 public unlockTime;

    address public signerChecker;
    mapping(uint256 => bool) public nonceChecker;
    mapping(string => bool) public codeChecker;

    function initialize(address token, uint256 _totalAmount) public initializer {
        __Ownable_init(msg.sender); 
        __UUPSUpgradeable_init(); 
        tokenAddress = token;
        totalAmount = _totalAmount;
        alreadyReceivedAmount = 0;
    }

    function setSignerChecker(address _signerChecker) external onlyOwner {
        require(_signerChecker != address(0), "CreaterPlayerNodesPool: checker is zero address");
        signerChecker = _signerChecker;
        emit SetSignerCheckerEvent(_signerChecker);
    }

    function setUnlockTime(uint256 _unlockTime) external onlyOwner {
        require(unlockTime == 0, "Unlock time already set");
        unlockTime = _unlockTime;
        emit SetUnlockTimeEvent(_unlockTime);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

   //2.08% of initial unlock, unlocking 1/48 each month
    function _calculateUnlockAmount() internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        require(totalAmount > 0, "Total amount is 0");
        require(unlockTime > 0, "Unlock time is 0");
        require(currentTime > unlockTime, "Unlock time not reached");
        
        uint256 initialUnlockAmount = totalAmount * 208 / 10000;
        
        uint256 deltaTime = currentTime - unlockTime;
        uint256 monthsPassed = deltaTime / (30 days); // Calculate the number of months passed

        uint256 unlockAmount = initialUnlockAmount;
        
        // Unlock starts from the 1st month (no unlock in the first 5 months)
        if(monthsPassed >= 1) {
        
            // Calculate the number of unlock months starting from the 1st month, 
            uint256 unlockMonths = monthsPassed;
            
            // Maximum unlock period is 6 months
            if(unlockMonths > 6) {
                unlockMonths = 6;
            }
            
            // Use safe integer calculation to avoid precision loss: (totalAmout * unlockMonths) / 6
            unlockAmount = ((totalAmount - initialUnlockAmount) * unlockMonths) / 6;
        }
        return unlockAmount;
    }

    function memberWithdraw(Withdraw.WithdrawInfo calldata info) external {
        if(Withdraw._withdrawInfoCheck(info, signerChecker, nonceChecker, codeChecker)){
            uint256 amount = _calculateUnlockAmount();
            require(amount > 0, "No amount");
            require(info.amount <= alreadyReceivedAmount, "No enough amount");
            alreadyReceivedAmount += amount;
            IERC20 token = IERC20(tokenAddress); 
            token.safeTransfer(msg.sender, amount); 
            emit WithdrawEvent(msg.sender, tokenAddress, amount);
        }
    }

    /// @notice 
    function adminWithdraw() external onlyOwner {
        require(block.timestamp > 30 * 43 days, "Unlock time not reached");
        IERC20 token = IERC20(tokenAddress); 
        token.safeTransfer(owner(), token.balanceOf(address(this))); 
        emit AdminWithdrawEvent(owner(), tokenAddress, token.balanceOf(address(this)));
    }
}