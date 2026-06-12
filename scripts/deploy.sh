#!/usr/bin/env bash
set -eo pipefail

NETWORK=${1:-anvil}
LOG_DIR="./contracts/logs"
mkdir -p "$LOG_DIR"

echo "⚙️ Compiling contracts..."
cd contracts && forge build && cd ..

if [ "$NETWORK" = "sepolia" ]; then
    echo "🌐 Deploying to Sepolia Testnet via Alchemy..."
    source .env
    cd contracts && forge script script/DeployVesting.s.sol:DeployVesting \
        --rpc-url "$SEPOLIA_RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --broadcast --verify \
        | tee logs/sepolia_deploy.log && cd ..
    LOG_FILE="$LOG_DIR/sepolia_deploy.log"
else
    echo "🛑 Deploying to Local Anvil Chain..."
    cd contracts && forge script script/DeployVesting.s.sol:DeployVesting \
        --rpc-url "http://127.0.0.1:8545" \
        --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
        --broadcast \
        | tee logs/anvil_deploy.log && cd ..
    LOG_FILE="$LOG_DIR/anvil_deploy.log"
fi

echo "🔍 Processing deployment telemetry logs..."
TOKEN_ADDRESS=$(grep -E "Deployed MockToken at:" "$LOG_FILE" | awk '{print $4}' || true)
VESTING_ADDRESS=$(grep -E "Deployed TokenVesting at:" "$LOG_FILE" | awk '{print $4}' || true)

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
