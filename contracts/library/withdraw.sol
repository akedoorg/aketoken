// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library Withdraw {
    struct WithdrawInfo {
        address token;
        uint256 amount;
        uint256 expire;
        string  payload;
        uint256 nonce;
        bytes  signature;
    }

     function splitSignature(bytes memory sig)
        public
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return (r, s, v);
    }

     function  _withdrawInfoCheck(WithdrawInfo calldata info, address _signerChecker, mapping(uint256 => bool) storage _nonceChecker, mapping(string => bool) storage codeChecker) internal returns(bool){
        require(_signerChecker != address(0), "error 4");
        //check signature
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, info.token, info.amount, info.expire, info.payload, info.nonce, block.chainid, address(this)));
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(info.signature);
        address signer = ecrecover(messageHash, v, r, s);
        require(signer == _signerChecker, "error 0");
        require(!_nonceChecker[info.nonce], "error 1");
        _nonceChecker[info.nonce] = true;
        require(block.timestamp <= info.expire, "error 2");
        require(!codeChecker[info.payload], "error 3");
        codeChecker[info.payload] = true;
        return true;
    }
}