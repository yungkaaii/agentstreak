// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AgentStreak
/// @notice Daily check-in for Binance Agent ID holders on BNB Chain.
/// @dev Single file, no external imports. No owner, no pause, no fees,
///      no withdrawals, no minting. Fully immutable once deployed.
///      A "day" is a UTC day: block.timestamp / 1 days.
///      Holding an Agent ID is checked via balanceOf() on the Agent ID
///      registry (ERC-721, non-transferable).
interface IAgentIDRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentStreak {
    /// @notice Agent ID registry (SPACE ID Agent ID) on BNB Chain.
    IAgentIDRegistry public immutable agentIdRegistry;

    /// @notice Stats tracked per check-in address.
    struct Stats {
        uint64 lastCheckInDay;
        uint64 currentStreak;
        uint64 longestStreak;
        uint64 totalCheckIns;
    }

    mapping(address => Stats) private _stats;

    /// @notice Total check-ins across all addresses.
    uint256 public totalCheckIns;

    /// @notice Check-in count per UTC day.
    mapping(uint256 => uint256) public checkInsPerDay;

    /// @notice Emitted on every successful check-in.
    event CheckedIn(address indexed user, uint256 indexed day, uint64 streak);

    error NotAgentIDHolder();
    error AlreadyCheckedInToday();

    constructor(address registry_) {
        agentIdRegistry = IAgentIDRegistry(registry_);
    }

    /// @notice Current UTC day number.
    function currentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    /// @notice True if `user` holds an Agent ID.
    function isHolder(address user) public view returns (bool) {
        return agentIdRegistry.balanceOf(user) > 0;
    }

    /// @notice True if `user` already checked in today.
    function hasCheckedInToday(address user) public view returns (bool) {
        return _stats[user].lastCheckInDay == currentDay();
    }

    /// @notice Full stats for `user`.
    function statsOf(address user)
        public
        view
        returns (uint64 lastCheckInDay, uint64 currentStreak, uint64 longestStreak, uint64 totalCheckIns_)
    {
        Stats storage s = _stats[user];
        return (s.lastCheckInDay, s.currentStreak, s.longestStreak, s.totalCheckIns);
    }

    /// @notice Current streak for `user`. A streak counts as live only if the
    ///         last check-in was today or yesterday; otherwise it reads 0
    ///         (the stored value only updates on the next check-in).
    function liveStreak(address user) public view returns (uint64) {
        Stats storage s = _stats[user];
        uint256 day = currentDay();
        if (s.lastCheckInDay == day || s.lastCheckInDay == day - 1) {
            return s.currentStreak;
        }
        return 0;
    }

    /// @notice Check in for today. One check-in per address per UTC day.
    ///         Streak continues only if yesterday was checked in; otherwise
    ///         the streak restarts at 1. Costs gas only, no fee.
    function checkIn() external {
        if (!isHolder(msg.sender)) revert NotAgentIDHolder();
        uint256 day = currentDay();
        Stats storage s = _stats[msg.sender];
        if (s.lastCheckInDay == day) revert AlreadyCheckedInToday();

        uint64 newStreak = (s.lastCheckInDay == day - 1) ? s.currentStreak + 1 : 1;
        // casting to 'uint64' is safe because a UTC day number fits for ~500 billion years
        // forge-lint: disable-next-line(unsafe-typecast)
        s.lastCheckInDay = uint64(day);
        s.currentStreak = newStreak;
        if (newStreak > s.longestStreak) s.longestStreak = newStreak;
        s.totalCheckIns += 1;

        totalCheckIns += 1;
        checkInsPerDay[day] += 1;

        emit CheckedIn(msg.sender, day, newStreak);
    }
}
