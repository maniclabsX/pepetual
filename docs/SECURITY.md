# Security & Monitoring Notes

PEPETUAL Millionaire blends on-chain automation with manual oversight. This document highlights public-facing safeguards and the signals Frogholders can monitor.

## Smart-Contract Protections

- **Chainlink VRF** — PondManager requests verifiable randomness for every spillover. Requests and fulfillments emit events (`DrawRequested`, `DrawFulfilled`) that anyone can track.
- **Snapshot Guardrails** — Each spillover requires a confirmed holder snapshot before VRF selection, preventing last-minute balance manipulation.
- **Whale Limits** — Maximum transaction and wallet limits are active around launch. Core contracts and trusted addresses are added to the exemption list on-chain; anyone can read `isLimitExempt(address)` from the token contract.
- **Immutable Tax Routing** — The 9.69 % split is coded at deploy time. Owners can adjust the base rate (capped at 10 %), but the distribution shares remain fixed.

## Monitoring Checklist

- **Pond Progress** — `PondManager.getActivePond()` exposes the current tier, PEPE accumulated, and whether a spillover is pending.
- **Pending Draws** — `PondManager.getPendingDraws()` should remain short; if a request lingers, ops may trigger `cleanupExpiredDraws()`.
- **Rewards Reserve** — `PEPETUAL.getRewardsReserveInfo()` shows PEPE set aside for Frogholder claims versus the amount already claimed.
- **Raise Vault State** — `CommunityRaiseVault.state()` indicates whether the vault is `Collecting`, `Finalized`, or `Cancelled`. Post-launch it remains `Finalized`.
- **VRF Subscription** — Chainlink subscription ID `86982725553250447959418931341108914180004046170013045732174503829644312482004` should stay funded. Anyone can verify the balance in the Chainlink UI.

## Responsible Disclosure

If you discover a vulnerability, contact the team privately before sharing details publicly. Include:

- Description of the issue and affected contract/function.
- Reproduction steps or proof-of-concept.
- Suggested mitigation if available.

A dedicated security contact address will be published alongside the public repository.

## Staying Safe as a Frogholder

- Interact only with the contract addresses listed in this kit.
- Beware of airdrops or approvals that claim to “boost” spillover odds—there is no such mechanism.
- Use hardware wallets or trusted custody for large PEPETUAL balances.
- Verify dapp URLs and ensure your browser wallet is connected to Ethereum mainnet (chain id 1).

Security evolves—update this document whenever contract upgrades, new tooling, or policy changes occur.
