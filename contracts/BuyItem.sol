// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BuyItem is Ownable {
    /// @notice Thrown when the passedclear in signature is not a valid length
    error InvalidValue();

    event BuyItemEvent(address indexed from, uint256 value, bytes payload);

    constructor() Ownable(msg.sender){}

    function buy(bytes calldata payload) external payable {
        require(msg.value > 0, "must send eth");
        emit BuyItemEvent(msg.sender, msg.value, payload);
    }

    /// @notice 
    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}