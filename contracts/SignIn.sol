// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


contract SignIn {
    event SignInEvent(address indexed from);
    function signIn() external {
        emit SignInEvent(msg.sender);
    }
}