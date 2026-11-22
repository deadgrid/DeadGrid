// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeadGridScores.sol";

contract DeadGridScoresTest is Test {
    receive() external payable {}

    DeadGridScores s;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA901);

    function setUp() public {
        s = new DeadGridScores();
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(carol, 1 ether);
    }

    function testSubmitAndTop() public {
        vm.prank(alice);
        s.submitScore{value: 0.0001 ether}("ALICE", 100, 5);
        vm.prank(bob);
        s.submitScore{value: 0.0001 ether}("BOB", 250, 12);
        (DeadGridScores.Entry[10] memory board, uint256 count) = s.getTop(s.currentDay());
        assertEq(count, 2);
        assertEq(board[0].player, bob);
        assertEq(board[0].score, 250);
        assertEq(board[1].player, alice);
        assertEq(board[0].bnbMicro, 12);
    }

    function testImproveOwnScore() public {
        vm.prank(alice);
        s.submitScore{value: 0.0001 ether}("ALICE", 100, 1);
        vm.prank(alice);
        s.submitScore{value: 0.0001 ether}("ALICE", 300, 9);
        (DeadGridScores.Entry[10] memory board, uint256 count) = s.getTop(s.currentDay());
        assertEq(count, 1);
        assertEq(board[0].score, 300);
        assertEq(board[0].bnbMicro, 9);
    }

    function testLowerScoreReverts() public {
        vm.prank(alice);
        s.submitScore{value: 0.0001 ether}("ALICE", 100, 1);
        vm.prank(alice);
        vm.expectRevert("beat your best first");
        s.submitScore{value: 0.0001 ether}("ALICE", 50, 1);
    }

    function testFeeRequired() public {
        vm.prank(alice);
        vm.expectRevert("fee 0.0001 BNB");
        s.submitScore{value: 0.00001 ether}("ALICE", 100, 1);
    }

    function testNameLength() public {
        vm.prank(alice);
        vm.expectRevert("name 1-16 chars");
        s.submitScore{value: 0.0001 ether}("THISNAMEISTOOLONG123", 100, 1);
    }

    function testNewDayResetsBoard() public {
        vm.prank(alice);
        s.submitScore{value: 0.0001 ether}("ALICE", 100, 1);
        vm.warp(block.timestamp + 1 days + 1);
        (DeadGridScores.Entry[10] memory board, uint256 count) = s.getTop(s.currentDay());
        assertEq(count, 0);
        assertEq(board[0].score, 0);
        vm.prank(bob);
        s.submitScore{value: 0.0001 ether}("BOB", 10, 0);
        (board, count) = s.getTop(s.currentDay());
        assertEq(count, 1);
        assertEq(board[0].player, bob);
    }

    function testTop10Cap() public {
        for (uint256 i = 0; i < 12; i++) {
            address p = address(uint160(0x1000 + i));
            vm.deal(p, 1 ether);
            vm.prank(p);
            s.submitScore{value: 0.0001 ether}("P", (i + 1) * 10, 0);
        }
        (, uint256 count) = s.getTop(s.currentDay());
        assertEq(count, 10);
    }

    function testWithdrawFees() public {
        vm.prank(alice);
        s.submitScore{value: 0.0001 ether}("ALICE", 100, 1);
        uint256 before = address(this).balance;
        s.withdrawFees();
        assertEq(address(this).balance, before + 0.0001 ether);
    }
}
