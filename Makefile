-include .env

.PHONY: all setup local-node deploy-anvil deploy-sepolia serve clean

# Setup local project and install Foundry dependencies
setup:
	@echo "🛠️ Installing local workspace packages and submodules..."
	npm install
	cd contracts && forge install OpenZeppelin/openzeppelin-contracts --no-git

# Run a local Anvil node with automatic mining of 1 block per second
local-node:
	@echo "⚡ Starting local Anvil node with uniform block progression..."
	anvil --block-time 1

# Execute deployment shell script against local Anvil instance
deploy-anvil:
	@chmod +x scripts/deploy.sh
	./scripts/deploy.sh anvil

# Execute deployment shell script against Sepolia Testnet
deploy-sepolia:
	@chmod +x scripts/deploy.sh
	./scripts/deploy.sh sepolia

# Serve frontend using locally installed npm dependency
serve:
	@echo "🖥️ Starting local development server from local binary path..."
	./node_modules/.bin/serve .

# Clean compilation outputs and generated frontend config
clean:
	cd contracts && forge clean
	rm -rf contracts/logs/ config.js
