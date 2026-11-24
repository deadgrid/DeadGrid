// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DeadGrid Marketplace
/// @notice Fixed-price marketplace for the DeadGrid NFT (DGRID), v1.
///  Escrow model: on list(), the NFT moves into this contract. On buy(),
///  the buyer pays the exact listed price; the seller gets the price
///  minus the fee and the buyer gets the NFT. On cancel(), the NFT goes
///  back to the seller. The marketplace takes a fee of 2.5% of the sale
///  price, paid to the contract owner. No offers, no auctions, no other
///  fees. The fee can be changed by the owner, capped at 10%.
contract DeadGridMarketplace is Ownable, ReentrancyGuard, IERC721Receiver {
    uint256 public constant MAX_FEE_BPS = 1000; // 10%

    /// @notice The DeadGrid NFT contract traded here.
    IERC721 public immutable nft;

    /// @notice Marketplace fee in basis points (250 = 2.5%).
    uint256 public feeBps = 250;

    /// @notice Number of listings ever created (listing ids start at 0).
    uint256 public nextListingId;

    struct Listing {
        uint256 id;
        address seller;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    /// @notice All listings by id (including sold/cancelled ones).
    mapping(uint256 => Listing) public listings;
    /// @notice Active listing id for a token, if any. 0 means none — the
    ///  check uses listings[id].active, so a stale id is harmless.
    mapping(uint256 => uint256) public listingByToken;

    error NotOwner(address caller);
    error NotSeller(address caller);
    error NotListed(uint256 listingId);
    error AlreadyListed(uint256 tokenId);
    error ZeroPrice();
    error WrongPayment(uint256 expected, uint256 got);
    error FeeTooHigh(uint256 bps);
    error PaymentFailed();

    event Listed(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId, uint256 price);
    event Sold(uint256 indexed listingId, address indexed seller, address indexed buyer, uint256 tokenId, uint256 price, uint256 fee);
    event Cancelled(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId);
    event FeeChanged(uint256 oldFeeBps, uint256 newFeeBps);

    constructor(address nft_) Ownable(msg.sender) {
        require(nft_ != address(0), "nft is zero address");
        nft = IERC721(nft_);
    }

    /// @notice Change the marketplace fee (basis points, max 10%).
    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps);
        uint256 old = feeBps;
        feeBps = newFeeBps;
        emit FeeChanged(old, newFeeBps);
    }

    /// @notice List an NFT for sale at a fixed price. The NFT is moved
    ///  into escrow in this contract. Caller must own the token.
    function list(uint256 tokenId, uint256 price) external nonReentrant returns (uint256 listingId) {
        if (price == 0) revert ZeroPrice();
        if (listings[listingByToken[tokenId]].active) revert AlreadyListed(tokenId);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner(msg.sender);

        listingId = nextListingId++;
        listings[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            tokenId: tokenId,
            price: price,
            active: true
        });
        listingByToken[tokenId] = listingId;

        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        emit Listed(listingId, msg.sender, tokenId, price);
    }

    /// @notice Buy a listed NFT at its exact listed price.
    function buy(uint256 listingId) external payable nonReentrant {
        Listing storage l = listings[listingId];
        if (!l.active) revert NotListed(listingId);
        if (msg.value != l.price) revert WrongPayment(l.price, msg.value);

        uint256 fee = (l.price * feeBps) / 10000;
        uint256 sellerProceeds = l.price - fee;
        address seller = l.seller;
        uint256 tokenId = l.tokenId;

        l.active = false;
        listingByToken[tokenId] = 0;

        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        if (sellerProceeds > 0) {
            (bool okSeller, ) = seller.call{value: sellerProceeds}("");
            if (!okSeller) revert PaymentFailed();
        }
        if (fee > 0) {
            (bool okFee, ) = owner().call{value: fee}("");
            if (!okFee) revert PaymentFailed();
        }

        emit Sold(listingId, seller, msg.sender, tokenId, l.price, fee);
    }

    /// @notice Cancel a listing and take the NFT back. Seller only.
    function cancel(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        if (!l.active) revert NotListed(listingId);
        if (l.seller != msg.sender) revert NotSeller(msg.sender);

        l.active = false;
        listingByToken[l.tokenId] = 0;

        nft.safeTransferFrom(address(this), msg.sender, l.tokenId);
        emit Cancelled(listingId, msg.sender, l.tokenId);
    }

    /// @notice The marketplace accepts NFTs sent to it (escrow on list).
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
