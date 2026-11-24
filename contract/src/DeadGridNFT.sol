// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Binance Agent ID registry interface — same pattern as
/// RiferaFirstTake / RiferaCursorPieces: only `balanceOf` is used, and a
/// wallet must hold >= 1 Agent ID to use the gated lane. No other registry
/// function is called.
interface IAgentId {
    function balanceOf(address account) external view returns (uint256);
}

/// @title DeadGrid NFT
/// @notice ERC721 collection of the DeadGrid game: 30 types — 10 Survivors,
///  10 Zombies, 10 Items — 100 of each, 3,000 total. Mint is random: the
///  type is picked from the mint hash, skipping types that are sold out.
///  Two lanes:
///   - mint() — AGENT lane: requires holding a Binance Agent ID.
///     First mint per wallet is FREE (gas only); further mints cost
///     0.001 BNB each, exact payment.
///   - mintPublic() — OPEN lane: anyone can mint, no Agent ID needed,
///     but EVERY mint costs 0.001 BNB exact (no free mint).
///  100% of paid mint BNB goes straight to the owner (project wallet) in
///  the same transaction — nothing is kept in this contract. Mint starts
///  CLOSED; the owner opens it separately.
///  Artwork is hosted on the game site: tokenURI is baseURI + type
///  slug + ".json" (30 metadata files, one per type).
contract DeadGridNFT is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant MAX_SUPPLY = 3000;
    uint256 public constant MAX_PER_TYPE = 100;
    uint256 public constant TYPE_COUNT = 30;

    /// @notice Binance Agent ID NFT contract (BNB Chain mainnet).
    IAgentId public immutable agentId;

    /// @notice Mint starts CLOSED. Nobody can mint until the owner opens
    ///  it with setMintOpen(true). The owner can close it again.
    bool public mintOpen;

    /// @notice Metadata base URI, e.g. https://deadgrid.github.io/DeadGrid/metadata/
    string public baseURI;

    uint256 public nextTokenId = 1;
    uint256 public totalMinted;

    /// @notice Type index per token (0-9 Survivors, 10-19 Zombies, 20-29 Items).
    mapping(uint256 => uint8) public tokenType;
    /// @notice Minted count per type (0-29). Public getter: mintedPerType(type).
    mapping(uint8 => uint256) public mintedPerType;
    /// @notice Mints per wallet (first one via the agent lane is free).
    mapping(address => uint256) public mintedByWallet;

    string[30] public typeSlugs = [
        "survivor-vex", "survivor-nova", "survivor-bulwark", "survivor-ghost", "survivor-medix",
        "survivor-blaze", "survivor-frost", "survivor-volt", "survivor-oracle", "survivor-reaper",
        "zombie-walker", "zombie-crawler", "zombie-runner", "zombie-spitter", "zombie-stalker",
        "zombie-brute", "zombie-screamer", "zombie-boomer", "zombie-juggernaut", "zombie-wraith",
        "item-rifle", "item-heavygun", "item-shield", "item-flamethrower", "item-scythe",
        "item-staff", "item-medkit", "item-crystal", "item-coil", "item-dagger"
    ];

    error MintClosed();
    error NoAgentId(address wallet);
    error SoldOut();
    error WrongPayment(uint256 expected, uint256 got);
    error PaymentFailed();

    event Minted(address indexed minter, uint256 indexed tokenId, uint8 indexed typeIndex, bool freeMint);

    constructor(address agentId_) ERC721("DeadGrid", "DGRID") Ownable(msg.sender) {
        require(agentId_ != address(0), "agent id is zero address");
        agentId = IAgentId(agentId_);
        baseURI = "https://deadgrid.github.io/DeadGrid/metadata/";
    }

    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    /// @notice Pick a type with remaining supply, starting from a hash of
    ///  the mint. Deterministic per mint, unpredictable before it.
    function _pickType(uint256 tokenId, address minter) internal view returns (uint8) {
        uint256 start = uint256(keccak256(abi.encodePacked(block.prevrandao, minter, tokenId))) % TYPE_COUNT;
        for (uint256 i = 0; i < TYPE_COUNT; i++) {
            uint8 t = uint8((start + i) % TYPE_COUNT);
            if (mintedPerType[t] < MAX_PER_TYPE) return t;
        }
        revert SoldOut();
    }

    function _doMint(uint256 expected, bool freeMint) internal returns (uint256 tokenId) {
        if (msg.value != expected) revert WrongPayment(expected, msg.value);

        tokenId = nextTokenId++;
        uint8 t = _pickType(tokenId, msg.sender);
        tokenType[tokenId] = t;
        mintedPerType[t] += 1;
        mintedByWallet[msg.sender] += 1;
        totalMinted += 1;

        if (msg.value > 0) {
            (bool ok, ) = owner().call{value: msg.value}("");
            if (!ok) revert PaymentFailed();
        }

        _safeMint(msg.sender, tokenId);
        emit Minted(msg.sender, tokenId, t, freeMint);
    }

    /// @notice AGENT lane: requires a Binance Agent ID. First mint per
    ///  wallet FREE, further mints 0.001 BNB exact.
    function mint() external payable nonReentrant returns (uint256 tokenId) {
        if (!mintOpen) revert MintClosed();
        if (agentId.balanceOf(msg.sender) < 1) revert NoAgentId(msg.sender);
        if (totalMinted >= MAX_SUPPLY) revert SoldOut();

        bool freeMint = mintedByWallet[msg.sender] == 0;
        uint256 expected = freeMint ? 0 : MINT_PRICE;
        return _doMint(expected, freeMint);
    }

    /// @notice OPEN lane: anyone can mint, no Agent ID needed. Every mint
    ///  costs 0.001 BNB exact — no free mint on this lane.
    function mintPublic() external payable nonReentrant returns (uint256 tokenId) {
        if (!mintOpen) revert MintClosed();
        if (totalMinted >= MAX_SUPPLY) revert SoldOut();

        return _doMint(MINT_PRICE, false);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked(baseURI, typeSlugs[tokenType[tokenId]], ".json"));
    }
}
