# ⏳ Production-Grade Token Vesting Protocol

A complete decentralized application (DApp) for creating and managing linear token vesting schedules. This project provides a fully automated pipeline encompassing smart contract compilation, automated deployment, frontend configuration injection, and an intuitive UI dashboard.

## 🏗️ Architecture & Enhancements

- **Frontend**: Vanilla JavaScript (ES6+), HTML5, CSS3. Fully documented using **JSDocs** standards in `app.js` for precise variable mapping and async definitions.
- **Smart Contracts**: Solidity `^0.8.20`. Follows **CEI (Checks-Effects-Interactions)** patterns and employs **NatSpec** standard documentation.
- **Backend Framework**: [Foundry](https://getfoundry.sh/) (Forge, Anvil, Cast).
- **Libraries**: OpenZeppelin Contracts (Security, ERC20, Ownable, ReentrancyGuard). Installed natively using the upgraded `--no-git` forge command in the Makefile.
- **Testing**: 100% coverage with 15 Foundry tests encompassing math validations, temporal logic, and reverts.

---

## 🚀 Quick Start (Local Development)

### 1. Environment Setup

Copy the environment template and populate it if needed (not strictly required for local Anvil development).

```bash
cp .env.example .env
```

Install local node modules and Foundry submodules. *This resolves missing OpenZeppelin dependencies utilizing the corrected `forge install --no-git` command.*

```bash
make setup
```

### 2. Start the Blockchain Node

Run a local Anvil node. This simulates a real blockchain environment with a 1-second block time. **Keep this running in a dedicated terminal.**

```bash
make local-node
```

### 3. Deploy the Smart Contracts

In a **separate terminal**, deploy the smart contracts to your local Anvil node. This step automatically compiles the contracts, deploys them, extracts the deployed addresses, and generates a `config.js` file for the frontend!

```bash
make deploy-anvil
```

### 4. Serve the Frontend Interface

Launch the frontend using the localized server:

```bash
make serve
```

Visit the displayed `localhost` URL in your web browser. Make sure you have a Web3 Wallet (like MetaMask) configured to connect to your local Anvil network (`http://127.0.0.1:8545`, Chain ID: `31337`).

---

## 🧪 Testing Suite

This repository features comprehensive, 100% gas-optimized Foundry testing, including math validations for linear vesting fractions, cliff timelines, and deep edge-case revert testing.

To run the entire test suite (15 exhaustive tests):
```bash
cd contracts && forge test
```

### 1. Token Initialization Tests (`MockToken.t.sol`)
- `test_InitialSupplyMintedToDeployer()`: Validates that 1,000,000 VTT tokens are properly minted to the deployer.
- `test_TokenMetadata()`: Ensures the ERC20 token correctly binds the name "Vesting Test Token" and symbol "VTT".

### 2. Linear Vesting Math & Edge Cases (`TokenVesting.t.sol`)
- **Mathematical Bound Checks**: Tests `ClaimTokensExactlyAtCliff()`, `ClaimTokensHalfway()`, `ClaimTokensFullDuration()`, and incremental `MultipleClaims()` leveraging the VM's `warp` time-travel feature to test to-the-second accuracy.
- **Revert Checkpoints**: Thoroughly stress tests unauthorized calls, `ZeroAddress` allocations, `ZeroAmount`, missing schedules, and `NoReleasableTokens` double-claim protections.

---

## 🌐 Deploying to Testnet (Sepolia)

To deploy to a public testnet like Sepolia:

1. Update your `.env` file with your `PRIVATE_KEY` and your Alchemy `SEPOLIA_RPC_URL`.
2. Ensure your wallet has sufficient Sepolia ETH for gas fees.
3. Run the automated deployment script targeting Sepolia:

```bash
make deploy-sepolia
```

The scripts will handle everything and seamlessly sync the newly deployed contract addresses directly to your web interface.

---

## 📂 Project Structure

```text
├── index.html                # Frontend Viewport
├── app.js                    # Web3 interaction logic & UI bindings (JSDoc annotated)
├── style.css                 # Interface styling & themes
├── config.js                 # Auto-generated runtime configurations
├── package.json              # Node dependencies (Local Server)
├── Makefile                  # Orchestration build runner (Uses --no-git)
├── scripts/
│   └── deploy.sh             # Bash deployment engine
└── contracts/                # Foundry Ecosystem
    ├── foundry.toml          # Foundry settings
    ├── src/
    │   ├── MockToken.sol     # ERC20 Mock implementation (NatSpec)
    │   └── TokenVesting.sol  # Core linear vesting logic (NatSpec, Yul Assembly)
    ├── test/
    │   ├── MockToken.t.sol   # Metadata and supply tests
    │   └── TokenVesting.t.sol# 13 extensive schedule & temporal tests
    └── script/
        └── DeployVesting.s.sol # Foundry Deployment scripts
```

## 🔐 Smart Contract Details

The `TokenVesting.sol` contract incorporates state-of-the-art security features:
- **Linear Vesting Mechanics**: Releases tokens continuously block-by-block after a cliff.
- **Security Checkpoints**: Built utilizing OpenZeppelin's `SafeERC20`, `Ownable`, and `ReentrancyGuard` to prevent reentrancy attacks and loss of funds.
- **Yul Assembly Hashing**: Replaces standard `abi.encode` with an optimal inline memory `keccak256` assembly routine.
- **Extensive NatSpec**: Fully documented utilizing Ethereum's NatSpec standard for developer tooling visibility.
