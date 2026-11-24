// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/DeadGridNFT.sol";

contract MockAgentId {
    mapping(address => uint256) public balanceOf;

    function mintTo(address to) external {
        balanceOf[to] = 1;
    }
}

contract DeadGridNFTTest is Test {
    receive() external payable {}

    DeadGridNFT nft;
    MockAgentId agent;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address stranger = address(0x57A6);

    function setUp() public {
        agent = new MockAgentId();
        nft = new DeadGridNFT(address(agent));
        agent.mintTo(alice);
        agent.mintTo(bob);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(stranger, 10 ether);
    }

    function testMintClosedByDefault() public {
        vm.prank(alice);
        vm.expectRevert(DeadGridNFT.MintClosed.selector);
        nft.mint();
    }

    function testNoAgentIdRevertsOnAgentLane() public {
        nft.setMintOpen(true);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DeadGridNFT.NoAgentId.selector, stranger));
        nft.mint();
    }

    function testFirstMintFreeAgentLane() public {
        nft.setMintOpen(true);
        vm.prank(alice);
        uint256 id = nft.mint();
        assertEq(nft.ownerOf(id), alice);
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.mintedByWallet(alice), 1);
        assertEq(address(nft).balance, 0);
    }

    function testSecondMintCosts0001AgentLane() public {
        nft.setMintOpen(true);
        vm.prank(alice);
        nft.mint();
        uint256 ownerBefore = address(this).balance;
        vm.prank(alice);
        nft.mint{value: 0.001 ether}();
        assertEq(nft.totalMinted(), 2);
        assertEq(address(this).balance, ownerBefore + 0.001 ether);
    }

    function testWrongPaymentReverts() public {
        nft.setMintOpen(true);
        vm.prank(alice);
        nft.mint();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(DeadGridNFT.WrongPayment.selector, 0.001 ether, 0));
        nft.mint();
    }

    function testPublicLaneNoAgentId() public {
        nft.setMintOpen(true);
        vm.prank(stranger);
        uint256 id = nft.mintPublic{value: 0.001 ether}();
        assertEq(nft.ownerOf(id), stranger);
        assertEq(nft.totalMinted(), 1);
    }

    function testPublicLaneAlwaysPaid() public {
        nft.setMintOpen(true);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DeadGridNFT.WrongPayment.selector, 0.001 ether, 0));
        nft.mintPublic();
    }

    function testPublicLaneClosedByDefault() public {
        vm.prank(stranger);
        vm.expectRevert(DeadGridNFT.MintClosed.selector);
        nft.mintPublic{value: 0.001 ether}();
    }

    function testPublicLaneCap10() public {
        nft.setMintOpen(true);
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(stranger);
            nft.mintPublic{value: 0.001 ether}();
        }
        assertEq(nft.mintedPublicByWallet(stranger), 10);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DeadGridNFT.PublicMintCapReached.selector, stranger));
        nft.mintPublic{value: 0.001 ether}();
    }

    function testPublicCapIsPerWallet() public {
        nft.setMintOpen(true);
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(stranger);
            nft.mintPublic{value: 0.001 ether}();
        }
        // another wallet can still mint on the public lane
        vm.prank(bob);
        uint256 id = nft.mintPublic{value: 0.001 ether}();
        assertEq(nft.ownerOf(id), bob);
    }

    function testTokenURIUsesTypeSlug() public {
        nft.setMintOpen(true);
        vm.prank(alice);
        uint256 id = nft.mint();
        string memory uri = nft.tokenURI(id);
        assertEq(uri, string(abi.encodePacked("https://deadgrid.github.io/DeadGrid/metadata/", nft.typeSlugs(nft.tokenType(id)), ".json")));
    }

    function testPerTypeCap() public {
        nft.setMintOpen(true);
        // mint 3000 across many agent wallets: every type must stop at 100
        for (uint256 i = 0; i < 300; i++) {
            address w = address(uint160(0x1000 + i));
            agent.mintTo(w);
            vm.deal(w, 10 ether);
            for (uint256 j = 0; j < 10; j++) {
                vm.prank(w);
                if (j == 0) nft.mint();
                else nft.mint{value: 0.001 ether}();
            }
        }
        assertEq(nft.totalMinted(), 3000);
        for (uint8 t = 0; t < 30; t++) {
            assertEq(nft.mintedPerType(t), 100);
        }
        address w2 = address(0x9999);
        agent.mintTo(w2);
        vm.deal(w2, 1 ether);
        vm.prank(w2);
        vm.expectRevert(DeadGridNFT.SoldOut.selector);
        nft.mint();
    }
}
