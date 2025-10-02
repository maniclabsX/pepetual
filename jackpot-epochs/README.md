# PEPEtual Jackpot Epochs

Public audit trail of all jackpot claims in the PEPEtual Millionaire system.

## Structure

```
jackpot-epochs/
├── logs/           # Human-readable summaries by year
│   └── YYYY/
│       └── epoch-XXXX.md
└── proofs/         # Machine-readable JSON artifacts
    └── epoch-XXXX.json
```

## Logs

Human-friendly markdown summaries of each epoch claim, including:
- Epoch ID, tier, and prize amount
- Winner address
- Transaction hashes (claim, seed, L2 mirror)
- VRF details (request ID, random seed, merkle root)
- Tier advancement and carry-over information

## Proofs

Machine-readable JSON artifacts for automated verification:
- Complete epoch metadata
- Transaction details (hashes, block numbers, gas)
- Event data (JackpotClaimed, TierAdvanced, PondCarryOver)
- Timestamps and versioning

## Verification

All claims are verifiable on-chain:
- **Ethereum Mainnet:** View claim transactions on [Etherscan](https://etherscan.io)
- **Arbitrum:** View VRF mirror transactions on [Arbiscan](https://arbiscan.io)
- **VRF:** Verify randomness via Chainlink VRF subscription

## Automation

Epochs are published automatically by the keeper system after each successful claim.

---

*Published by Manic*
