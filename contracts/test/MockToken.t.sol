// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { MockToken } from "../src/MockToken.sol";

/**
 * @title MockTokenTest
 * @dev Foundry test suite for the MockToken smart contract.
 * Ensures the token initializes correctly with the expected name, symbol, and initial supply.
 */
contract MockTokenTest is Test {
    MockToken public token;
    address public deployer = address(1);

    function setUp() public {
        vm.prank(deployer);
        token = new MockToken();
    }

    function test_InitialSupplyMintedToDeployer() public view {
        uint256 expectedSupply = 1_000_000 * 10**18;
        assertEq(token.totalSupply(), expectedSupply, "Total supply should be 1 million tokens");
        assertEq(token.balanceOf(deployer), expectedSupply, "Deployer should receive all initial supply");
    }

    function test_TokenMetadata() public view {
        assertEq(token.name(), "Vesting Test Token", "Token name mismatch");
        assertEq(token.symbol(), "VTT", "Token symbol mismatch");
        assertEq(token.decimals(), 18, "Token decimals should be 18");
    }
}
