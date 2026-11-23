// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MockAgentId {
    mapping(address => uint256) public balanceOf;

    function mintTo(address to) external {
        balanceOf[to] = 1;
    }
}
