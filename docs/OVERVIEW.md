# PEPETUAL Millionaire Overview

PEPETUAL Millionaire is a mainnet DeFi protocol that routes a 9.69 % trading fee into PEPE buys. Those swaps fund pond spillovers, PEPE burns, Frogholder rewards, development, and community art.

## Key Components

- **PEPETUAL Token (`ERC20`)** — Handles tax routing, limit logic, and exposes owner hooks for depositing PEPE into the pond and rewards buffers.
- **PondManager (Ethereum)** — Receives PEPE from the token, commits Merkle roots of eligible Frogholders, and finalizes spillovers once randomness is mirrored back on-chain.
- **Arbitrum Pond Helper (L2)** — Mirrors each Merkle root to Arbitrum One, requests Chainlink VRF, and emits a winning seed that is relayed to mainnet.
- **CommunityRaiseVault** — Recorded the original fair-launch raise. Contributors claimed PEPETUAL after LP seeding. The vault now primarily houses claim history and emergency controls.
- **Public Dashboard** — A read-only interface for Frogholders and contributors. It surfaces pond progress, spillover history, token stats, and claim tooling for the raise vault.
- **Owner Dashboard (Private)** — Separate operational tooling for limit exemptions, manual deposits, and emergency controls. Not included in the public repo.

## Spillover Cycle

1. Trades fill the active Pond with PEPE until the Overflow Point is hit.
2. A keeper snapshots all Frogholders (wallets with ≥ 100 PEPETUAL) and stores the Merkle root on PondManager.
3. The same root is mirrored to the Arbitrum helper, which requests Chainlink VRF for verifiable randomness.
4. The emitted seed is relayed back to Ethereum; anyone can submit the Merkle proof to claim the catch.
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
| PondManager (Ethereum) | `0x664B094c34568fEC7fe1776ca8AeBEB4746C431b` |
| Arbitrum Pond Helper | `0x164fbd9B6dE4F3711bbAad6706E1d4087b0986f0` |
| CommunityRaiseVault | `0x768f997cA7736282603AE9cca8734713ac2233E5` |
| PEPE Token | `0x6982508145454Ce325dDbE47a25d4ec3d2311933` |
| Uniswap V2 Router | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| Chainlink VRF Coordinator (Arbitrum One) | `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e` |

The same data is available in machine-readable form inside `contracts/addresses.mainnet.json`.

## Resources

- [Language Framework](./LANGUAGE_FRAMEWORK.md) — Consistent wording for ponds, spillovers, and catches.
- [Raise Overview](./RAISE_OVERVIEW.md) — How the fair launch vault worked and what contributors experienced.
- [Security & Monitoring](./SECURITY.md) — Operational safeguards and best practices for Frogholders.

Keep this overview updated when contract addresses or tax routing change.
