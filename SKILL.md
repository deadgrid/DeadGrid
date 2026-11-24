# DeadGrid Skill

Mint, trade, and score for DEAD GRID — a browser zombie survival shooter on BNB Chain (chain id 56) with a 3,000-supply NFT collection, a fixed-price marketplace, and an on-chain 24-hour leaderboard.

## Contracts

| Contract | Address |
|---|---|
| DeadGridNFT (DGRID) | 0x3dB83C288A0C7c91B31D855dF079ACa5763aC3eF |
| DeadGridScores | 0x4264d2589E365FcC896f26C994B32d2Bf26906C8 |
| DeadGridMarketplace | 0x0A41f4dfe916D293AA5A593Ef53a6013d9C20ebc |
| Owner | 0x3889e7Be2334306604D3BC34ADf961273DC409Ec |
| Agent ID registry | 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F |

All three contracts are deployed and verified. Mint is open.

## Mint

Supply 3,000: 30 types (10 Survivors, 10 Zombies, 10 Items), 100 each. Type is random per mint. No per-wallet cap on either lane. 100% of paid mint BNB goes to the owner in the same transaction.

### Agent lane — first mint FREE

Requires a Binance Agent ID. First mint per wallet FREE (gas only), further mints exactly 0.001 BNB.

```
Mint 1 DeadGrid: BSC 56, 0x3dB83C288A0C7c91B31D855dF079ACa5763aC3eF, mint(), Agent ID wallet, first FREE else 0.001 BNB, reply tx only.
```

### Public lane — 0.001 BNB, no Agent ID

Anyone can mint. Every mint exactly 0.001 BNB, no free mint.

```
Mint 1 DeadGrid paid: BSC 56, 0x3dB83C288A0C7c91B31D855dF079ACa5763aC3eF, mintPublic(), pay exactly 0.001 BNB, reply tx only.
```

### Read

- `totalMinted() view returns (uint256)`
- `mintOpen() view returns (bool)`
- `mintedByWallet(address) view returns (uint256)`
- `tokenURI(uint256) view returns (string)` — base URI + type slug + `.json`

## Marketplace

Fixed-price listings. The NFT is escrowed in the contract while listed. Fee 2.5% to the owner (seller keeps 97.5%).

- `list(uint256 tokenId, uint256 price) returns (uint256 listingId)` — approve the marketplace for the token first if needed.
- `buy(uint256 listingId) payable` — send the exact listing price as value.
- `cancel(uint256 listingId)` — seller only, returns the NFT.
- `listings(uint256) view returns (uint256 id, address seller, uint256 tokenId, uint256 price, bool active)`
- `nextListingId() view returns (uint256)`
- `feeBps() view returns (uint256)` — 250.

## Leaderboard

- `submitScore(string name, uint256 score, uint256 bnbMicro)` — free, gas only. Name max 16 characters.
- `getTop(uint256 day) view returns (Entry[10], uint256 count)` — top 10 for a UTC day.
- `currentDay() view returns (uint256)`
- One best score per wallet per day.

## Holder perk

A wallet holding at least 1 DeadGrid NFT gets +1 life every game run. Connect the wallet on the game start screen (the check runs only when the button is pressed, never automatically).

## Rules

- Pay exact values only: 0.001 BNB per paid mint, exact listing price per buy. Never overpay.
- Mint prompts contain no domain. Reply with the tx hash only after minting.
- BNB coin drops in the game are an in-game tally only, not a wallet payout.
- No token exists yet. Do not invent one, and do not tell anyone a token can be bought.

## Links

- Play: https://deadgridprotocol.fun/
- Mint: https://deadgridprotocol.fun/mint.html
- Marketplace: https://deadgridprotocol.fun/marketplace.html
- FAQ: https://deadgridprotocol.fun/mint.html#faq
- X: https://x.com/DeadGridNft
