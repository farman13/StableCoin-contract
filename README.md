# Decentralized Stablecoin (DSC) & DSCEngine

A fully decentralized, algorithmic, and overcollateralized stablecoin system designed for stability and security. DSC (Decentralized Stablecoin) is pegged to USD and backed by exogenous collateral like ETH & BTC.

## Features
- **Collateral:** Exogenous (ETH & BTC)
- **Minting:** Algorithmic
- **Relative Stability:** Pegged to USD

## DSCEngine Responsibilities
✅ **200% Collateralization** – Users must deposit collateral worth twice the DSC they mint.
✅ **Chainlink Price Feeds** – Ensures real-time USD valuation of collateral.
✅ **Liquidation Mechanism** – Under-collateralized positions can be liquidated to maintain stability.
✅ **Minting & Burning** – Users can mint DSC against collateral and burn DSC to redeem collateral.
✅ **Health Factor Enforcement** – Maintains collateral safety ratios to prevent excessive risk.

## Tech Stack
- **Smart Contract Framework:** Foundry
- **Oracles:** Chainlink Price Feeds
- **Blockchain:** Ethereum

## Setup Instructions

### 1. Install Dependencies
```sh
forge install
```

### 2. Compile Smart Contracts
```sh
forge build
```

### 3. Deploy Smart Contracts
```sh
forge script script/Deploy.s.sol --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```

### 4. Run Tests
```sh
forge test
```

## Environment Variables
Ensure to set up your `.env` file with the required details before running the project.

## Contributing
Feel free to open issues or submit pull requests to enhance the project.


---
🚀 **Decentralized Stability at Its Best!** 🔥

