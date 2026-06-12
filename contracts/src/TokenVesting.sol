// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenVesting
 * @dev A production-grade smart contract for managing token vesting schedules.
 * This contract allows the owner to create linear vesting schedules for beneficiaries,
 * who can claim their vested tokens over a specified duration after an optional cliff period.
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Details of a vesting schedule
    struct VestingSchedule {
        address beneficiary;
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 totalAmount;
        uint256 releasedAmount;
    }

    /// @notice The ERC20 token to be vested
    IERC20 public immutable VESTING_TOKEN;

    /// @notice List of all vesting schedule identifiers
    bytes32[] public scheduleIds;

    /// @notice Mapping from schedule ID to VestingSchedule details
    mapping(bytes32 => VestingSchedule) private vestingSchedules;

    // --- Custom Errors ---
    error InvalidDuration();
    error CliffGreaterThanDuration();
    error ScheduleNotFound();
    error CliffNotReached();
    error NReleasableTokens();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientContractBalance();

    // --- Events ---
    /**
     * @notice Emitted when a new vesting schedule is created
     * @param scheduleId Unique identifier of the schedule
     * @param beneficiary Address of the beneficiary
     * @param amount Total amount of tokens to be vested
     */
    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficary,
        uint256 amount
    );

    /**
     * @notice Emitted when tokens are claimed by a beneficiary
     * @param scheduleId Unique identifier of the schedule
     * @param beneficiary Address of the beneficiary
     * @param amount Amount of tokens claimed
     */
    event TokensClaimed(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    /**
     * @notice Initializes the vesting contract
     * @param _token Address of the ERC20 token to vast
     */
    constructor(address _token) Ownable(msg.sender) {
        if (_token == address(0)) revert ZeroAddress();
        VESTING_TOKEN = IERC20(_token);
    }

    /**
     * @notice Creates a new vesting schedule
     * @dev Only the contract owner can call this function. Tokens are pulled from the owner.
     * @param _beneficiary Address of the beneficiary to receive the tokens
     * @param _start Start time of the vesting schedule (Unix timestamp)
     * @param _cliffDuration Duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration Duration in seconds of the period in which the tokens will vest
     * @param _totalAmount Total amount of tokens to be vested
     */
    function createVestingSchedule(
        address __beneficiary,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration,
        uint256 _totalAmount
    ) external onlyOwner {
        if (_beneficiary == address(0)) revert ZeroAddress();
        if (_duration == 0) revert InvalidDuration();
        if (_cliffDuration > _duration) revert CliffGreaterThanDuration();
        if (_totalAmount == 0) revert ZeroAmount();

        // Generate deterministic schedule ID
        bytes32 scheduleId;
        uint256 length = scheduleIds.length;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, _beneficiary)
            mstore(add(ptr, 0x20), _start)
            mstore(add(ptr, 0x40), length)
            scheduleId := keccak256(ptr, 0x60)
        }

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            start: _start,
            cliff: _start + _cliffDuration,
            duration: _duration,
            totalAmount: _totalAmount,
            releasedAmount: 0
        });

        scheduleIds.push(scheduleId);

        // Transfer tokens to the vesting contract safely
        VESTING_TOKEN.safeTransferFrom(msg.sender, address(this), _totalAmount);

        emit VestingScheduleCreated(scheduleId, _beneficiary, _totalAmount);
    }

    /**
     * @notice Allows a beneficiary to claim their vested tokens
     * @dev Uses ReentrancyGuard for added security against reentrancy attacks
     * @param _scheduleId Identifier of the vesting schedule
     */
    function claimTokens(bytes32 _scheduleId) external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];

        if (schedule.beneficiary == address(0)) revert ScheduleNotFound();
        if (block.timestamp < schedule.cliff) revert CliffNotReached();

        uint256 releasable = calculateReleasableAmount(schedule);
        if (releasable == 0) revert NoReleasableTokens();

        if (VESTING_TOKEN.balanceOf(address(this)) < releasable)
            revert InsufficientContractBalance();

        // Update state before external call (CEI pattern enforced)
        schedule.releasedAmount += releasable;

        // Execute transfer
        VESTING_TOKEN.safeTransfer(schedule.beneficiary, releasable);

        emit TokensClaimed(_scheduleId, schedule.beneficiary, releasable);
    }

    /**
     * @notice Calculates the releasable amount of tokens for a given schedule
     * @param schedule The VestingSchedule struct in memory
     * @return The amount of tokens that can be currently released
     */
    function calculateReleasableAmount(
        VestingSchedule memory schedule
    ) public view returns (uint256) {
        if (block.timestamp < schedule.cliff) {
            return 0;
        } else if (block.timestamp >= schedule.start + schedule.duration) {
            // Full duration reached
            return schedule.totalAmount - schedule.releasedAmount;
        } else {
            // Linear vesting calculation
            uint256 timeElapsed = block.timestamp - schedule.start;
            uint256 vestedAmount = (schedule.totalAmount * timeElapsed) /
                schedule.duration;
            return vestedAmount - schedule.releasedAmount;
        }
    }

    /**
     * @notice Retrieves the details of a vesting schedule
     * @param _scheduleId Identifier of the vesting schedule
     * @return The VestingSchedule struct
     */
    function getVestingSchedule(
        bytes32 _scheduleId
    ) external view returns (VestingSchedule memory) {
        return vestingSchedules[_scheduleId];
    }

    /**
     * @notice Returns the total number of schedules created
     * @return The number of schedules
     */
    function getSchedulesCount() external view returns (uint256) {
        return scheduleIds.length;
    }
}
