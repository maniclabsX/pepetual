# PEPETUAL Millionaire Overview

PEPETUAL Millionaire is a mainnet DeFi protocol that routes a 9.69 % trading fee into PEPE buys. Those swaps fund pond spillovers, PEPE burns, Frogholder rewards, development, and community art.

## Key Components

- **PEPETUAL Token (`ERC20`)** — Handles tax routing, limit logic, and exposes owner hooks for depositing PEPE into the pond and rewards buffers.
- **PondManager** — Receives PEPE from the token, schedules spillovers, snapshots Frogholders, and calls Chainlink VRF to select the catch recipient.
- **CommunityRaiseVault** — Recorded the original fair-launch raise. Contributors claimed PEPETUAL after LP seeding. The vault now primarily houses claim history and emergency controls.
- **Public Dashboard** — A read-only interface for Frogholders and contributors. It surfaces pond progress, spillover history, token stats, and claim tooling for the raise vault.
- **Owner Dashboard (Private)** — Separate operational tooling for limit exemptions, manual deposits, and emergency controls. Not included in the public repo.

## Spillover Cycle

1. Trades fill the active Pond with PEPE until the Overflow Point is hit.
2. PondManager captures a snapshot of all Frogholders (wallets with ≥ 100 PEPETUAL).
3. Chainlink VRF selects one Frogholder to catch the spillover.
4. The chosen wallet receives the PEPE catch automatically.
5. The Pond advances to the next tier and begins filling again.

## Tokenomics Snapshot

- **Trading Tax:** 9.69 % of each swap, routed as follows:
  - 6.90 % → Pond spillovers (PEPE stored for the next catch)
  - 0.69 % → PEPE burn
  - 0.69 % → PEPETUAL burn
  - 0.69 % → Frogholder rewards pool
  - 0.69 % → Development treasury
  - 0.03 % → Community art budget
- **Frogholder Eligibility:** Maintain ≥ 100 PEPETUAL to accrue rewards and stay in spillover snapshots.
- **Anti-Whale Controls:** Max transaction and wallet limits protect the opening distribution; trusted addresses are added to the exemption list by ops.

## Contract Addresses (Mainnet)

| Contract | Address |
| --- | --- |
| PEPETUAL Token | `0xdC80d4Cb7fF1Fe185B4509C400aeC5A7d17FB19A` |
| PondManager | `0x70c9056362afEDeECc51b7C6A74A1D88e912Fb57` |
| CommunityRaiseVault | `0xd63816880ACf01703CD10f70aFE2A65b23518725` |
| PEPE Token | `0x6982508145454Ce325dDbE47a25d4ec3d2311933` |
| Uniswap V2 Router | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| Chainlink VRF Coordinator | `0xD7f86b4b8Cae7D942340FF628F82735b7a20893a` |

The same data is available in machine-readable form inside `contracts/addresses.mainnet.json`.

## Resources

- [Language Framework](./LANGUAGE_FRAMEWORK.md) — Consistent wording for ponds, spillovers, and catches.
- [Raise Overview](./RAISE_OVERVIEW.md) — How the fair launch vault worked and what contributors experienced.
- [Security & Monitoring](./SECURITY.md) — Operational safeguards and best practices for Frogholders.

Keep this overview updated when contract addresses or tax routing change.
