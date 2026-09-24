# Signal Processor — Architecture

## Overview

Signal Processor (SPROC) is a revenue-sharing processor for an AI trading-signal
agent on X Layer. Design goal: every trade of the token automatically funds three
things — holder dividends, an autonomous buyback-and-burn loop, and the agent's
own operations — with no trusted operator in the loop after launch.

## Components

Tax flow per trade (3% buy / 3% sell):

- 50% → SPROC holders as OKB dividends (24h linear release, 10,000 SPROC
  minimum holding to qualify)
- 50% → creator vault, recipients locked at launch:
  - 60% → BuybackCircuitV2 (`0xf4Af20e9ca5c1b6F509F5321e5033382cC3BB771`)
  - 25% → agent operations wallet (`0x521a819acdb0cff42681f6dfbb99b8154ea348cb`)
  - 15% → project treasury wallet (`0x32e39f50509748d0a19a7e66c3d536e0ab51c077`)

### 1. Tax Distribution Vault (IGNIX)

IGNIX's vault contract (`0x67110f1081b747353f48ffd8a35f40006228f648`) collects
the 3% trading tax. The recipient list and percentages are fixed in the launch
transaction (`6000 / 2500 / 1500` bps) and cannot be changed afterwards.

### 2. BuybackCircuitV2 — the taped-out circuit

Source: `contracts/BuybackCircuitV2.sol`. Deployed BEFORE the SPROC launch
(because the vault recipient list is locked at launch), then bound to SPROC via
a one-time `setSPROC()` call.

- Receives native OKB automatically from the vault (no signature needed).
- When its balance reaches 5 OKB, anyone can call `execute(minOut)`:
  1. Wraps OKB → WOKB (`0xe538905cf8410324e03a5a23c1c177a474d59b2b`)
  2. Swaps WOKB → SPROC on X Layer's official Uniswap V2 Router02
     (`0x182a927119D56008d921126764bF884221b10f59`) using the
     fee-on-transfer-safe swap function (SPROC has a 3% buy tax)
  3. Sends 100% of the SPROC received to the burn address
- `minOut` is keeper-side slippage protection, quoted off-chain before calling.
- Security: no upgrade path, no admin, no withdrawal function. The deployer's
  only privilege was the single `setSPROC()` call, now permanently spent. Funds
  can only ever be burned.

### 3. Operations & treasury wallets

Plain EOAs receiving 25% and 15% of the creator share for agent operations and
the project treasury. Outside the trustless loop by design — disclosed here for
transparency.

## Launch parameters (verified on-chain)

- Buy tax 3% / Sell tax 3%; holder / creator split 50% / 50%
- Anti-snipe: on, 50% → 0% linear decay over 30 minutes
- Graduation protection: 100 days; graduation target 85 OKB
- Bonding curve 80% / DEX liquidity 20%

## Design history

An earlier V1 circuit (`0x411b1666e5b917b22f0bde5525593ed111760755`) targeted
Uniswap V3, but IGNIX confirmed taxed tokens graduate into Uniswap V2, so V1 was
deprecated before launch (it holds no funds and has no withdrawal path). V2 is
the circuit wired into the vault.
