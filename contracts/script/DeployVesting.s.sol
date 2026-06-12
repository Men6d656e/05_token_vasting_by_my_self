// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { MockToken } from "../src/MockToken.sol";
import { TokenVesting } from "../src/TokenVesting.sol";

/**
 * @title DeployVesting
 * @dev Foundry script to deploy the MockToken and TokenVesting contracts securely.
 * This script retrieves the private key from the environment variables.
 */
contract DeployVesting is Script {
    /**
     * @notice Main deployment execution function
     * @dev Deploys the MockToken first, and uses its address to initialize TokenVesting
     */
    function run() external {
        // Retrieve private key from .env, falling back to Anvil's default account zero
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        // Begin broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the Mock ERC20 Token
        MockToken token = new MockToken();
        console.log("Deployed MockToken at:", address(token));

        // 2. Deploy the Vesting Contract, supplying the Mock Token address
        TokenVesting vesting = new TokenVesting(address(token));
        console.log("Deployed TokenVesting at:", address(vesting));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
