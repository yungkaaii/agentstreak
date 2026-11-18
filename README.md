# AgentStreak

A daily check-in dApp for Agent ID holders on BNB Chain, built for the
Agent ID Hackathon (Binance Wallet + BNB Chain).

Agent ID holders check in once per UTC day. The contract tracks each
address's current streak, longest streak, and total check-ins, and emits
an event per check-in. A static frontend shows holder status, streaks,
recent check-ins, and a leaderboard computed from events.

No token. No fees beyond network gas. No rewards promised. No owner
privileges — the contract is fully immutable once deployed.

## How Agent ID is used

The contract gates `checkIn()` on holding an Agent ID: it calls
`balanceOf(address)` on the Agent ID registry (ERC-721, non-transferable)
at `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain and requires
a balance greater than 0. Non-holders revert with `NotAgentIDHolder`.
The registry address is set once in the constructor and is immutable.
Agent ID is never used to look up anyone else's wallet.

## Contract

Single file, no external imports: [`src/AgentStreak.sol`](src/AgentStreak.sol)
(Solidity ^0.8.20).

- `checkIn()` — one check-in per address per UTC day (`block.timestamp / 1 days`).
  Streak continues if yesterday was checked in, otherwise restarts at 1.
  Emits `CheckedIn(user, day, streak)`.
- Views: `statsOf`, `liveStreak` (0 once a day is missed), `hasCheckedInToday`,
  `isHolder`, `totalCheckIns`, `checkInsPerDay`, `currentDay`.
- No owner, no pause, no fees, no withdrawals, no minting. There are no
  owner permissions to disclose: nobody can change, pause, or extract
  anything from this contract.

## Tests

Foundry (`forge`/`cast`). Unit tests use a mock registry; fork tests run
against the real registry on BSC mainnet (read-only, no signing).

```sh
forge test                                  # unit tests
forge test --fork-url https://bsc-rpc.publicnode.com   # includes fork tests
```

## Deployment gas estimate (measured 18 Nov 2026)

- Deployment: **407,236 gas** (`cast estimate --create` against BSC mainnet state).
- At the then-current gas price of 0.05 gwei: **~0.00002 BNB**.
  At 1 gwei: ~0.00041 BNB. Budget ~0.002 BNB to be safe (deploy + a few check-ins).
- `checkIn()`: ~96,700 gas first check-in (cold storage), less on later days.
- Bytecode: 1,748 bytes deployed, 1,609 bytes init code.

## Deploy + verify on BscScan

The deployer needs a small amount of BNB for gas (see estimate above).
Deploy from the machine/account you choose — never share a private key.

```sh
# 1. Dry run first (simulation only, no broadcast):
forge script script/Deploy.s.sol --fork-url https://bsc-rpc.publicnode.com -vv

# 2. Deploy + verify (requires BSCSCAN_API_KEY):
forge script script/Deploy.s.sol --rpc-url https://bsc-rpc.publicnode.com \
  --broadcast --verify --verifier-url https://api.bscscan.com/api \
  --etherscan-api-key $BSCSCAN_API_KEY
```

Alternative: deploy the single file in Remix (compiler 0.8.20, optimizer
on, 200 runs), constructor arg = the registry address above, then verify
via BscScan's "Verify & Publish" with the same file and settings.

After deployment, set the contract address and deployment block in
[`frontend/app.js`](frontend/app.js) (`CONFIG` at the top of the file).

## Frontend

Static, no backend, no build step: [`frontend/index.html`](frontend/index.html)
+ [`frontend/app.js`](frontend/app.js), ethers v6 via CDN.

```sh
cd frontend && python3 -m http.server 8000   # then open http://localhost:8000
```

Or host the `frontend/` folder on any static host (GitHub Pages, IPFS, etc.).

The page connects via the injected wallet (`window.ethereum`, works with
Binance Wallet), checks for BNB Chain (chain 56) and offers a network
switch, reads Agent ID holder status, and lets the user check in. Every
transaction is confirmed by the user in their own wallet — the page never
bypasses confirmations, never collects credentials, and never asks for
seed phrases or private keys.

## Safety notes (hackathon red lines)

- No web-based QR login, no stored sessions, no orders placed on behalf
  of users. Users sign their own check-in transactions.
- No prompts or code that bypass transaction confirmations.
- No asset transfers of any kind: the contract holds no funds and has no
  withdrawal function.
- Contract is open-source, verified on BscScan, with no owner permissions.
- No Binance/BNB branding: the project name is AgentStreak, and the
  frontend only describes the chain factually ("on BNB Chain").
- No credentials collected: no seed phrases, private keys, API secrets,
  or pairing codes anywhere in the project.
- No returns promised: streaks are on-chain records with no monetary value.

## License

MIT — see [LICENSE](LICENSE).
