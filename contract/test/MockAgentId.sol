// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Minimal stand-in for the Binance Agent ID NFT (mainnet
/// 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F). TESTS ONLY.
/// On mainnet the real Agent ID contract address is used instead.
contract MockAgentId is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Mock Agent ID", "AGENTID") {}

    function mintTo(address to) external returns (uint256 tokenId) {
        tokenId = _nextId++;
        _safeMint(to, tokenId);
    }
}
