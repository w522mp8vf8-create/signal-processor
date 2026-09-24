# Signal Processor (SPROC)

An on-chain revenue-sharing processor for an AI trading-signal agent, live on **X Layer mainnet**.

Every SPROC trade pays a 3% tax: **50% streams to SPROC holders as OKB dividends**, while the creator share is split **60% to an autonomous buyback-and-burn circuit**, **25% to agent operations**, and **15% to the project treasury**.

Built for the **TapeOut Genesis Transistor Hackathon** (IGNIX × Metagents × X Layer).

- Product page: https://muse.ai/s/signal-processor-demo-lxp6omryxsxjxvxz
- IGNIX token page: https://ignix.bot/launch?token=0xa79c5b63e778185269a294fdf411b3734c5beeee

## Live contracts (X Layer mainnet)

| Item | Address |
|---|---|
| SPROC token | `0xa79c5b63e778185269a294fdf411b3734c5beeee` |
| BuybackCircuitV2 | `0xf4Af20e9ca5c1b6F509F5321e5033382cC3BB771` |
| Tax Distribution Vault | `0x67110f1081b747353f48ffd8a35f40006228f648` |
| Agent operations wallet | `0x521a819acdb0cff42681f6dfbb99b8154ea348cb` |
| Project treasury wallet | `0x32e39f50509748d0a19a7e66c3d536e0ab51c077` |

- Launch tx: `0x61e438a86f1e4cb26f70f9863d8111c4e39940553f07f796a224937ecfeaa1a3` (block 71463041)
- BuybackCircuitV2 deploy tx: `0x995f910cacb17a9aff6afe55312fd7c4245368d5c4bab1a254ddc48e5d90e957` (block 71462824)

Token facts: name `Signal Processor`, ticker `SPROC`, 18 decimals, 1,000,000,000 supply.

## How it works

1. Every buy and sell pays **3% tax**.
2. **50% of the tax** goes to SPROC holders as **OKB dividends** — 24h linear release, 10,000 SPROC minimum holding to qualify.
3. **50% of the tax** goes to the creator vault, whose recipient list was **locked at launch**:
   - **60%** → BuybackCircuitV2: once it accumulates **5 OKB**, anyone can call `execute(minOut)` — it wraps OKB → WOKB, swaps for SPROC on the official Uniswap V2 router, and sends everything to the burn address.
   - **25%** → agent operations wallet
   - **15%** → project treasury wallet
4. Anti-snipe is on: 50% → 0% linear decay over 30 minutes.
5. Graduation protection: 100 days; graduation target 85 OKB; 80% bonding curve / 20% DEX liquidity.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design.

## Security

- **No upgrade, no admin, no withdrawal backdoor.** The BuybackCircuit can never send funds anywhere except the burn address.
- `setSPROC` could be called exactly **once** by the deployer (SPROC did not exist when the circuit was deployed). It has been called; the permission is **permanently burned**.
- The vault recipient list (60/25/15) was locked in the launch transaction and cannot be changed.

## Calling `execute(minOut)`

Anyone can trigger a buyback once the circuit holds ≥ 5 OKB:

```solidity
BuybackCircuitV2(0xf4Af20e9ca5c1b6F509F5321e5033382cC3BB771).execute(minOut);
```

`minOut` is slippage protection: the minimum SPROC expected from the swap. Quote the V2 pair off-chain first, and remember SPROC carries a **3% buy tax**, so quote the after-tax net amount.

## Repo layout

```
contracts/BuybackCircuitV2.sol   # the deployed buyback-and-burn circuit (exact source)
docs/ARCHITECTURE.md             # system design: vault, tax routing, circuit
assets/sproc-logo.webp           # project logo
```

## Hackathon

TapeOut Genesis Transistor Hackathon — IGNIX × Metagents × X Layer, Sep 22 – Oct 6, 2026 (HKT). The processor was deployed from the TapeOut factory to X Layer mainnet and the buyback circuit was taped out before the deadline.

## Disclaimer

SPROC is an experimental hackathon project. Nothing here is financial advice. Smart contracts are immutable — read them before interacting.
