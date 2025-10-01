# Security & Monitoring Notes

PEPETUAL Millionaire blends on-chain automation with manual oversight. This document highlights public-facing safeguards and the signals Frogholders can monitor.

## Smart-Contract Protections

- **Chainlink VRF + Merkle Proofs** — PondManager stores a Merkle root of the eligible Frogholders on Ethereum. The Arbitrum helper requests verifiable randomness and emits `WinnerSeed` events that anyone can audit before mirroring the seed back on-chain.
- **Snapshot Guardrails** — Each spillover requires a confirmed holder snapshot before VRF selection, preventing last-minute balance manipulation.
- **Whale Limits** — Maximum transaction and wallet limits are active around launch. Core contracts and trusted addresses are added to the exemption list on-chain; anyone can read `isLimitExempt(address)` from the token contract.
- **Immutable Tax Routing** — The 9.69 % split is coded at deploy time. Owners can adjust the base rate (capped at 10 %), but the distribution shares remain fixed.

## Monitoring Checklist

- **Pond Progress** — `PondManager.getCurrentTierInfo()` exposes the current tier, PEPE accumulated, and percentage filled relative to the Overflow Point.
- **Merkle & Seed Events** — Watch `PondManager.EpochRootSet` (snapshot committed) and `ArbitrumPondHelper.WinnerSeed` (seed delivered). Both logs are immutable on-chain.
- **Rewards Reserve** — `PEPETUAL.getRewardsReserveInfo()` shows PEPE set aside for Frogholder claims versus the amount already claimed.
- **Raise Vault State** — `CommunityRaiseVault.state()` indicates whether the vault is `Collecting`, `Finalized`, or `Cancelled`. Post-launch it remains `Finalized`.
- **VRF Subscription** — Chainlink subscription ID `83340410701333406144989824629012465981303258259316385760271338137756579289992` on Arbitrum One should stay funded. Anyone can verify the balance in the Chainlink UI.

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
