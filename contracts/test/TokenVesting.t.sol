// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { MockToken } from "../src/MockToken.sol";
import { TokenVesting } from "../src/TokenVesting.sol";

/**
 * @title TokenVestingTest
 * @dev Comprehensive Foundry test suite for the TokenVesting smart contract.
 * Includes exhaustive tests for creation, edge cases, reverts, and linear vesting math.
 */
contract TokenVestingTest is Test {
    MockToken public token;
    TokenVesting public vesting;

    address public owner = address(1);
    address public beneficiary1 = address(2);
    address public beneficiary2 = address(3);

    uint256 public constant TOTAL_AMOUNT = 365 * 10**18;
    uint256 public constant CLIFF_DURATION = 30 days;
    uint256 public constant DURATION = 365 days;

    function setUp() public {
        vm.startPrank(owner);
        
        token = new MockToken();
        vesting = new TokenVesting(address(token));
        
        token.approve(address(vesting), type(uint256).max);

        vm.stopPrank();
    }

    // --- Schedule Creation Tests ---

    function test_CreateVestingSchedule() public {
        vm.startPrank(owner);
        uint256 start = block.timestamp;

        vm.expectEmit(true, true, false, true);
        emit TokenVesting.VestingScheduleCreated(keccak256(abi.encode(beneficiary1, start, 0)), beneficiary1, TOTAL_AMOUNT);
        
        vesting.createVestingSchedule(
            beneficiary1,
            start,
            CLIFF_DURATION,
            DURATION,
            TOTAL_AMOUNT
        );

        assertEq(vesting.getSchedulesCount(), 1);
        bytes32 scheduleId = vesting.scheduleIds(0);
        
        TokenVesting.VestingSchedule memory schedule = vesting.getVestingSchedule(scheduleId);
        
        assertEq(schedule.beneficiary, beneficiary1);
        assertEq(schedule.cliff, start + CLIFF_DURATION);
        assertEq(schedule.duration, DURATION);
        assertEq(schedule.totalAmount, TOTAL_AMOUNT);
        assertEq(schedule.releasedAmount, 0);
        
        assertEq(token.balanceOf(address(vesting)), TOTAL_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_NotOwnerCreatesSchedule() public {
        vm.startPrank(beneficiary1);
        vm.expectRevert(); // Standard Ownable revert
        vesting.createVestingSchedule(beneficiary1, block.timestamp, CLIFF_DURATION, DURATION, TOTAL_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroAddressBeneficiary() public {
        vm.startPrank(owner);
        vm.expectRevert(TokenVesting.ZeroAddress.selector);
        vesting.createVestingSchedule(address(0), block.timestamp, CLIFF_DURATION, DURATION, TOTAL_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroDuration() public {
        vm.startPrank(owner);
        vm.expectRevert(TokenVesting.InvalidDuration.selector);
        vesting.createVestingSchedule(beneficiary1, block.timestamp, CLIFF_DURATION, 0, TOTAL_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_CliffGreaterThanDuration() public {
        vm.startPrank(owner);
        vm.expectRevert(TokenVesting.CliffGreaterThanDuration.selector);
        vesting.createVestingSchedule(beneficiary1, block.timestamp, 400 days, DURATION, TOTAL_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(TokenVesting.ZeroAmount.selector);
        vesting.createVestingSchedule(beneficiary1, block.timestamp, CLIFF_DURATION, DURATION, 0);
        vm.stopPrank();
    }

    // --- Claiming & Vesting Math Tests ---

    function _createStandardSchedule() internal returns (bytes32) {
        vm.startPrank(owner);
        vesting.createVestingSchedule(beneficiary1, block.timestamp, CLIFF_DURATION, DURATION, TOTAL_AMOUNT);
        vm.stopPrank();
        return vesting.scheduleIds(0);
    }

    function test_RevertWhen_ClaimBeforeCliff() public {
        bytes32 scheduleId = _createStandardSchedule();

        vm.warp(block.timestamp + CLIFF_DURATION - 1 seconds);

        vm.startPrank(beneficiary1);
        vm.expectRevert(TokenVesting.CliffNotReached.selector);
        vesting.claimTokens(scheduleId);
        vm.stopPrank();
    }

    function test_RevertWhen_ScheduleNotFound() public {
        bytes32 fakeId = keccak256("fake");
        vm.startPrank(beneficiary1);
        vm.expectRevert(TokenVesting.ScheduleNotFound.selector);
        vesting.claimTokens(fakeId);
        vm.stopPrank();
    }

    function test_ClaimTokensExactlyAtCliff() public {
        uint256 start = block.timestamp;
        bytes32 scheduleId = _createStandardSchedule();

        vm.warp(start + CLIFF_DURATION); // Exactly 30 days

        vm.startPrank(beneficiary1);
        vesting.claimTokens(scheduleId);
        vm.stopPrank();

        // (365 Tokens * 30 days) / 365 days = 30 Tokens
        uint256 expectedAmount = (TOTAL_AMOUNT * CLIFF_DURATION) / DURATION;
        assertEq(token.balanceOf(beneficiary1), expectedAmount);
    }

    function test_ClaimTokensHalfway() public {
        uint256 start = block.timestamp;
        bytes32 scheduleId = _createStandardSchedule();

        uint256 halfway = DURATION / 2;
        vm.warp(start + halfway); 

        vm.startPrank(beneficiary1);
        vesting.claimTokens(scheduleId);
        vm.stopPrank();

        uint256 expectedAmount = (TOTAL_AMOUNT * halfway) / DURATION;
        assertEq(token.balanceOf(beneficiary1), expectedAmount);
    }

    function test_ClaimTokensFullDuration() public {
        uint256 start = block.timestamp;
        bytes32 scheduleId = _createStandardSchedule();

        vm.warp(start + DURATION + 10 days); // Past full duration

        vm.startPrank(beneficiary1);
        vesting.claimTokens(scheduleId);
        vm.stopPrank();

        assertEq(token.balanceOf(beneficiary1), TOTAL_AMOUNT);
        
        TokenVesting.VestingSchedule memory schedule = vesting.getVestingSchedule(scheduleId);
        assertEq(schedule.releasedAmount, TOTAL_AMOUNT);
    }

    function test_RevertWhen_NoReleasableTokens() public {
        uint256 start = block.timestamp;
        bytes32 scheduleId = _createStandardSchedule();

        vm.warp(start + DURATION); // Fast forward to end

        vm.startPrank(beneficiary1);
        vesting.claimTokens(scheduleId); // Claim all
        
        // Try claiming again immediately
        vm.expectRevert(TokenVesting.NoReleasableTokens.selector);
        vesting.claimTokens(scheduleId);
        vm.stopPrank();
    }

    function test_MultipleClaims() public {
        uint256 start = block.timestamp;
        bytes32 scheduleId = _createStandardSchedule();

        vm.startPrank(beneficiary1);
        
        // Claim 1 at Cliff (30 days)
        vm.warp(start + CLIFF_DURATION);
        vesting.claimTokens(scheduleId);
        uint256 balance1 = token.balanceOf(beneficiary1);
        assertEq(balance1, (TOTAL_AMOUNT * CLIFF_DURATION) / DURATION);

        // Claim 2 at 100 days
        uint256 targetDay = 100 days;
        vm.warp(start + targetDay);
        vesting.claimTokens(scheduleId);
        uint256 balance2 = token.balanceOf(beneficiary1);
        assertEq(balance2, (TOTAL_AMOUNT * targetDay) / DURATION);

        // Claim 3 at Full Duration
        vm.warp(start + DURATION);
        vesting.claimTokens(scheduleId);
        assertEq(token.balanceOf(beneficiary1), TOTAL_AMOUNT);

        vm.stopPrank();
    }
}
