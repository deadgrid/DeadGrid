# DeadGridScores — daily on-chain leaderboard

`DeadGridScores.sol` — top 10 per UTC day, one best score per wallet per day,
submit fee 0.0001 BNB, owner withdraws the fees. BNB Chain.

## Test
```
forge install foundry-rs/forge-std
forge test   # 8 tests
```

## Deploy
Open `leaderboard-deploy.html` in a wallet browser (MetaMask), connect on
BNB Chain mainnet, deploy, then send the contract address to Muse so the
game (`index.html`, `LEADERBOARD_CONTRACT`) can be wired to it.
