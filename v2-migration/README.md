# PEPETUAL V2 Migration

**Status:** Migration vault deployment pending

**Merkle Root:** `0x55ab19ef8bcf241ebea7652344703a1c68a5f8737e9c13633b8c778bf9d8435d`

---

## Overview

This folder contains the V2 migration system for Frogholders affected by the V1 contract issue.

### The V1 Issue

The original PEPETUAL V1 contract had an auto-fee processing mechanism that caused infinite recursion during swaps, making the token non-functional with tax enabled. Tax had to be disabled (0%) to allow trading, breaking the Pond filling mechanics.

### The V2 Solution

V2 PEPETUAL features:
- **Fixed fee processing:** Manual-only, no auto-trigger recursion
- **Same 9.69% tax structure** with proper distribution to Ponds
- **Keeper system** for controlled fee processing
- **All original features:** 9-tier Ponds, PEPE rewards, Spillover mechanics

### Migration Mechanism

V1 Frogholders can migrate 1:1 to V2 via the Migration Vault:
1. Frogholder sends V1 tokens to vault
2. Vault swaps V1 → ETH on market
3. Frogholder receives equal V2 tokens (1:1)
4. Protocol uses recovered ETH to seed V2 liquidity

---

## Files

### Contracts

- **`contracts/PEPETUALV2.sol`** - V2 token with fixed fee processing
- **`contracts/MigrationVault.sol`** - V1→V2 exchange contract with Merkle verification

### Snapshot Data

- **`snapshot/claims.json`** - Complete Merkle tree with proofs for 152 eligible Frogholders
  - Total eligible: 204,212,270.87 PEPETUAL
  - Includes unclaimed raise allocations

### Documentation

- **`docs/MIGRATION_SNAPSHOT.md`** - Complete migration guide and snapshot details
- **`docs/UNCLAIMED_TOKENS.md`** - Report on unclaimed raise allocations

---

## Migration Details

**Snapshot Block:** 23,529,904 (October 7, 2025)

**Eligible Frogholders:** 152

**Total Migrateable:** 204,212,270.87 PEPETUAL (20.4% of V1 supply)

**Pre-fund Required:** Migration vault must be loaded with 204.2M V2 tokens before opening

---

## For V1 Frogholders

### Check Your Eligibility

Load `snapshot/claims.json` and search for your address to find:
- Your migration allowance
- Your Merkle proof (needed for migration)

### Migration Steps

1. Approve V1 PEPETUAL for migration vault
2. Call `migrate()` with your proof from claims.json
3. Receive V2 PEPETUAL 1:1
4. Continue as Frogholder in the V2 Pond system

**Detailed instructions will be provided once migration vault is deployed.**

---

## Technical Resources

- **V1 Contract:** `0xdC80d4Cb7fF1Fe185B4509C400aeC5A7d17FB19A`
- **V2 Contract:** TBD (pending deployment)
- **Migration Vault:** TBD (pending deployment)
- **Uniswap Router:** `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`

---

**Repository:** https://github.com/maniclabsX/pepetual
