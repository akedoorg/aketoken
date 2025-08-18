// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./library/withdraw.sol";


contract CommunityPool is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    using SafeERC20 for IERC20;

    event WithdrawEvent(address indexed from, address indexed token, uint256 value, bytes payload);
    event SetSignerCheckerEvent(address indexed checker);
    event TransferTokenEvent(address indexed to, uint256 amount);
    
    address private _signerChecker;
    mapping(uint256 => bool) private _nonceChecker;
    mapping(string => bool) public codeChecker;
   
    function initialize() public initializer {
        __Ownable_init(msg.sender); 
        __UUPSUpgradeable_init(); 
    }

    receive() external payable {
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function userWithdraw(Withdraw.WithdrawInfo calldata info) external {
       if(Withdraw._withdrawInfoCheck(info, _signerChecker, _nonceChecker, codeChecker)){
            if(info.token == address(0)){
                require(address(this).balance >= info.amount, "CommunityPool: insufficient balance for withdrawal");
                (bool success, ) = msg.sender.call{value: info.amount}("");
                require(success, "Transfer failed");
                
            }else if( info.token != address(0)){
                IERC20 token = IERC20(info.token); 
                require(token.balanceOf(address(this)) >= info.amount, "CommunityPool: insufficient balance for withdrawal");
                token.safeTransfer(msg.sender, info.amount); 
            } 
            emit WithdrawEvent(msg.sender, info.token, info.amount, bytes(info.payload));
       }  
    }

    function setSignerChecker(address checker) external onlyOwner {
        require(checker != address(0), "CommunityPool: checker is zero address");
        _signerChecker = checker;
        emit SetSignerCheckerEvent(checker);
    }


    /// @notice 
    function withdraw( address t) external onlyOwner {
        if(t == address(0)){
            (bool success, ) = payable(owner()).call{value: address(this).balance}("");
            require(success, "Transfer failed.");
        }else{
            IERC20 token = IERC20(t); 
            token.safeTransfer(owner(), token.balanceOf(address(this))); 
        }
    }
}