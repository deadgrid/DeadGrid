// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/DeadGridNFT.sol";
import "../src/DeadGridMarketplace.sol";

contract MockAgentIdMarket {
    mapping(address => uint256) public balanceOf;

    function mintTo(address to) external {
        balanceOf[to] = 1;
    }
}

contract DeadGridMarketplaceTest is Test {
    receive() external payable {}

    DeadGridNFT nft;
    DeadGridMarketplace market;
    MockAgentIdMarket agent;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address stranger = address(0x57A6);

    function _isActive(uint256 id) internal view returns (bool) {
        (,,,, bool active) = market.listings(id);
        return active;
    }

    function setUp() public {
        agent = new MockAgentIdMarket();
        nft = new DeadGridNFT(address(agent));
        agent.mintTo(alice);
        agent.mintTo(bob);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(stranger, 10 ether);
        nft.setMintOpen(true);
        // alice: free mint (token 1) + paid mint (token 2)
        vm.prank(alice);
        nft.mint();
        vm.prank(alice);
        nft.mint{value: 0.001 ether}();
        // bob: public mint (token 3)
        vm.prank(bob);
        nft.mintPublic{value: 0.001 ether}();
        market = new DeadGridMarketplace(address(nft));
        // sellers must approve the marketplace to escrow their NFT on list
        vm.prank(alice);
        nft.setApprovalForAll(address(market), true);
        vm.prank(bob);
        nft.setApprovalForAll(address(market), true);
    }

    function testListAndBuy() public {
        vm.prank(alice);
        uint256 id = market.list(1, 0.1 ether);
        assertEq(nft.ownerOf(1), address(market));
        assertTrue(_isActive(id));

        uint256 sellerBefore = alice.balance;
        uint256 ownerBefore = address(this).balance;
        vm.prank(bob);
        market.buy{value: 0.1 ether}(id);

        assertEq(nft.ownerOf(1), bob);
        assertFalse(_isActive(id));
        // seller gets 97.5%, marketplace owner gets 2.5%
        assertEq(alice.balance, sellerBefore + 0.0975 ether);
        assertEq(address(this).balance, ownerBefore + 0.0025 ether);
    }

    function testCancelReturnsNFT() public {
        vm.prank(alice);
        uint256 id = market.list(1, 0.1 ether);
        vm.prank(alice);
        market.cancel(id);
        assertEq(nft.ownerOf(1), alice);
        assertFalse(_isActive(id));
    }

    function testBuyWrongPaymentReverts() public {
        vm.prank(alice);
        uint256 id = market.list(1, 0.1 ether);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(DeadGridMarketplace.WrongPayment.selector, 0.1 ether, 0.09 ether));
        market.buy{value: 0.09 ether}(id);
    }

    function testBuySoldListingReverts() public {
        vm.prank(alice);
        uint256 id = market.list(1, 0.1 ether);
        vm.prank(bob);
        market.buy{value: 0.1 ether}(id);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DeadGridMarketplace.NotListed.selector, id));
        market.buy{value: 0.1 ether}(id);
    }

    function testBuyCancelledListingReverts() public {
        vm.prank(alice);
        uint256 id = market.list(1, 0.1 ether);
        vm.prank(alice);
        market.cancel(id);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(DeadGridMarketplace.NotListed.selector, id));
        market.buy{value: 0.1 ether}(id);
    }

    function testCancelByNonSellerReverts() public {
        vm.prank(alice);
        uint256 id = market.list(1, 0.1 ether);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(DeadGridMarketplace.NotSeller.selector, bob));
        market.cancel(id);
    }

    function testDoubleListReverts() public {
        vm.prank(alice);
        market.list(1, 0.1 ether);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(DeadGridMarketplace.AlreadyListed.selector, 1));
        market.list(1, 0.2 ether);
    }

    function testListNonOwnedReverts() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DeadGridMarketplace.NotOwner.selector, stranger));
        market.list(1, 0.1 ether);
    }

    function testListZeroPriceReverts() public {
        vm.prank(alice);
        vm.expectRevert(DeadGridMarketplace.ZeroPrice.selector);
        market.list(1, 0);
    }

    function testSetFeeOnlyOwnerAndCap() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        market.setFee(500);
        market.setFee(500);
        assertEq(market.feeBps(), 500);
        vm.expectRevert(abi.encodeWithSelector(DeadGridMarketplace.FeeTooHigh.selector, 1001));
        market.setFee(1001);
        market.setFee(1000);
        assertEq(market.feeBps(), 1000);
    }

    function testRelistAfterCancel() public {
        vm.prank(alice);
        uint256 id1 = market.list(1, 0.1 ether);
        vm.prank(alice);
        market.cancel(id1);
        vm.prank(alice);
        uint256 id2 = market.list(1, 0.2 ether);
        assertTrue(_isActive(id2));
        assertEq(market.listingByToken(1), id2);
    }

    function testFeeSplitAtCustomFee() public {
        market.setFee(1000); // 10%
        vm.prank(alice);
        uint256 id = market.list(1, 1 ether);
        uint256 sellerBefore = alice.balance;
        uint256 ownerBefore = address(this).balance;
        vm.prank(bob);
        market.buy{value: 1 ether}(id);
        assertEq(alice.balance, sellerBefore + 0.9 ether);
        assertEq(address(this).balance, ownerBefore + 0.1 ether);
    }
}
