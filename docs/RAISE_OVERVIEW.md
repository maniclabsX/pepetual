# Community Raise Overview

The Community Raise Vault powered the 72-hour fair launch for PEPETUAL Millionaire. This guide documents how the raise functioned from a public perspective so contributors can verify history and understand future events.

## Timeline at a Glance

1. **Announce** — Core team publishes the raise window, contribution caps (if any), and the vault address: `0xBe6F9e80Df056529C4d913BCdC490890E8B6B70f`.
2. **Start Raise** — Ops call `startRaise()`, unlocking deposits for exactly 72 hours (unless closed early).
3. **Contribute** — Anyone can send ETH through the dashboard or directly to the vault address. Deposits emit `ContributionReceived` events with contributor and amount.
4. **Close / Expire** — Ops either close the raise early (`closeRaise()`) or let the timer expire. At this point new deposits are rejected.
5. **Finalize** — Ops call `finalize(...)` to seed Uniswap liquidity with 90.31 % of the ETH raised and swap the remaining 9.69 % into PEPE for treasury allocations. LP tokens are burned automatically.
6. **Claim** — Contributors claim their PEPETUAL allocation (`claimTokens()`) once finalize completes. Claims remain open for 30 days.
7. **Post-Raise** — Any unclaimed tokens after the grace period can be swept back to the treasury.

## Contributor Experience

- Visit the public dashboard and connect an Ethereum wallet.
- Enter an ETH amount and submit the transaction. The UI shows your cumulative contribution, claimable tokens, and the global raise totals in real time.
- After finalize, click “Claim Tokens” to receive your PEPETUAL. The contract enforces the claim ratio based on total deposits.
- If the raise were ever cancelled (did not happen for mainnet), contributors would instead use `refund()` to retrieve their ETH.

## Allocation Math

- Total supply deposited for the raise: **1 B PEPETUAL** (500 M allocated to contributors, 500 M paired with ETH for liquidity).
- Contribution ratio is fixed: every participant receives their pro-rata share of the 500 M contributor pool.
- The vault automatically records each address in `contributions(address)` and tracks claims via `tokensClaimed(address)`.

## Event Logs to Monitor

| Event | Purpose |
| --- | --- |
| `RaiseStarted(uint256 endTime)` | Confirms the raise window opened. |
| `ContributionReceived(address contributor, uint256 amount)` | Fired on each deposit. |
| `RaiseClosed()` | Emitted when the raise stops accepting deposits. |
| `RaiseFinalized(uint256 ethUsedForLP, uint256 ethSwappedToPepe)` | Liquidity seeded and PEPE routing complete. |
| `TokensClaimed(address contributor, uint256 amount)` | Contributor successfully claimed PEPETUAL. |

## Safety Notes

- Only interact with the official vault address above. Any impersonation contracts will not receive PEPETUAL allocations.
- Claims are gas-efficient and can be sent at any time during the 30-day window once finalize succeeds.
- The public dashboard uses the ABIs in this kit (`contracts/CommunityRaiseVault_ABI.json`) to read on-chain data; you can do the same with your preferred tooling.

This vault is now in post-raise mode, but the same mechanics can be reused for future events. Update this guide as parameters change.
