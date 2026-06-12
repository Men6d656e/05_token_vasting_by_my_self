#!/usr/bin/env bash
set -e

NETWORK=${1:-anvil}
LOG_DIR="./contracts/logs"
mkdir -p "$LOG_DIR"

echo "⚙️ Compiling contracts..."
cd contracts && forge build && cd ..

if [ "$NETWORK" = "sepolia" ]; then
    echo "🌐 Deploying to Sepolia Testnet..."
    source .env
    
    if [ -z "$ETHERSCAN_API_KEY" ]; then
        echo "❌ Error: ETHERSCAN_API_KEY is not set in .env"
        exit 1
    fi

    # Prompt for private key securely (no echo) and pass via --private-key
    echo "Enter your Sepolia wallet private key:"
    read -s PRIVATE_KEY
    echo
    cd contracts
    forge script script/DeployVesting.s.sol:DeployVesting \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --broadcast \
        --verify \
        --etherscan-api-key "$ETHERSCAN_API_KEY"
    cd ..
    unset PRIVATE_KEY
    
    echo "Saving tracking metadata..."
    CHAIN_ID="11155111"
    cp contracts/broadcast/DeployVesting.s.sol/11155111/run-latest.json "$LOG_DIR/sepolia_deploy.log" || true
    LOG_FILE="$LOG_DIR/sepolia_deploy.log"
else
    echo "🛑 Deploying to Local Anvil Chain..."
    cd contracts
    forge script script/DeployVesting.s.sol:DeployVesting \
        --rpc-url "http://127.0.0.1:8545" \
        --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
        --broadcast
    cd ..
    
    CHAIN_ID="31337"
    cp contracts/broadcast/DeployVesting.s.sol/31337/run-latest.json "$LOG_DIR/anvil_deploy.log" || true
    LOG_FILE="$LOG_DIR/anvil_deploy.log"
fi

echo "🔍 Processing deployment telemetry logs..."
BROADCAST_DIR="contracts/broadcast/DeployVesting.s.sol/$CHAIN_ID"
TOKEN_ADDRESS=$(jq -r '.transactions[] | select(.contractName=="MockToken") | .contractAddress' "$BROADCAST_DIR/run-latest.json" 2>/dev/null || true)
VESTING_ADDRESS=$(jq -r '.transactions[] | select(.contractName=="TokenVesting") | .contractAddress' "$BROADCAST_DIR/run-latest.json" 2>/dev/null || true)

echo "✅ Extracted Token: $TOKEN_ADDRESS"
echo "✅ Extracted Vesting: $VESTING_ADDRESS"

echo "📝 Parsing ABIs and outputting config.js into root environment..."
TOKEN_ABI=$(cat contracts/out/MockToken.sol/MockToken.json | jq '.abi')
VESTING_ABI=$(cat contracts/out/TokenVesting.sol/TokenVesting.json | jq '.abi')

cat << EOF > ./config.js
// Auto-generated via deployment pipeline script. Do not modify directly.
export const CONTRACT_CONFIG = {
    network: "${NETWORK}",
    tokenAddress: "${TOKEN_ADDRESS}",
    vestingAddress: "${VESTING_ADDRESS}",
    tokenAbi: ${TOKEN_ABI},
    vestingAbi: ${VESTING_ABI}
};
EOF

echo "🚀 Workspace frontend configuration synchronization complete!"