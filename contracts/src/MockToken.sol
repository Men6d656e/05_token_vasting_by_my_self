// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockToken
 * @dev Simple ERC20 Mock Token for local testing and demonstration purposes.
 * Automatically mints 1,000,000 tokens to the deployer address upon creation.
 */
contract MockToken is ERC20 {
    /**
     * @notice Initializes the Mock Token with a name ("Vesting Test Token") and symbol ("VTT")
     */
    constructor() ERC20("Vesting Test Token", "VTT") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}
