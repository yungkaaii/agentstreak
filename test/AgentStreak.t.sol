// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentStreak.sol";

/// @notice Minimal mock of the Agent ID registry: balanceOf returns 1 for
///         addresses flagged as holders, 0 otherwise.
contract MockRegistry {
    mapping(address => bool) public holders;

    function setHolder(address user, bool isHolder_) external {
        holders[user] = isHolder_;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return holders[owner] ? 1 : 0;
    }
}

contract AgentStreakTest is Test {
    AgentStreak public streak;
    MockRegistry public registry;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    // Start at a fixed UTC timestamp: 2026-11-18 12:00:00 UTC.
    uint256 public constant T0 = 1795003200;

    event CheckedIn(address indexed user, uint256 indexed day, uint64 streak);

    function setUp() public {
        vm.warp(T0);
        registry = new MockRegistry();
        registry.setHolder(alice, true);
        streak = new AgentStreak(address(registry));
    }

    function testNonHolderReverts() public {
        vm.prank(bob);
        vm.expectRevert(AgentStreak.NotAgentIDHolder.selector);
        streak.checkIn();
    }

    function testHolderChecksIn() public {
        vm.prank(alice);
        streak.checkIn();
        (uint64 lastDay, uint64 cur, uint64 longest, uint64 total) = streak.statsOf(alice);
        assertEq(lastDay, T0 / 1 days);
        assertEq(cur, 1);
        assertEq(longest, 1);
        assertEq(total, 1);
        assertEq(streak.totalCheckIns(), 1);
        assertEq(streak.checkInsPerDay(T0 / 1 days), 1);
        assertTrue(streak.hasCheckedInToday(alice));
        assertTrue(streak.isHolder(alice));
        assertFalse(streak.isHolder(bob));
    }

    function testDoubleCheckInSameDayReverts() public {
        vm.prank(alice);
        streak.checkIn();
        vm.prank(alice);
        vm.expectRevert(AgentStreak.AlreadyCheckedInToday.selector);
        streak.checkIn();
    }

    function testStreakIncrementsAcrossConsecutiveDays() public {
        for (uint64 i = 1; i <= 5; i++) {
            vm.warp(T0 + (i - 1) * 1 days);
            vm.prank(alice);
            streak.checkIn();
            (, uint64 cur, uint64 longest, uint64 total) = streak.statsOf(alice);
            assertEq(cur, i);
            assertEq(longest, i);
            assertEq(total, i);
        }
        assertEq(streak.liveStreak(alice), 5);
    }

    function testStreakResetsAfterMissedDay() public {
        vm.prank(alice);
        streak.checkIn();
        vm.warp(T0 + 1 days);
        vm.prank(alice);
        streak.checkIn();
        // Skip a full day, check in on the third day after start.
        vm.warp(T0 + 3 days);
        vm.prank(alice);
        streak.checkIn();
        (, uint64 cur, uint64 longest, uint64 total) = streak.statsOf(alice);
        assertEq(cur, 1, "streak restarts at 1 after a missed day");
        assertEq(longest, 2, "longest streak is preserved");
        assertEq(total, 3);
    }

    function testLiveStreakReadsZeroAfterGap() public {
        vm.prank(alice);
        streak.checkIn();
        // Two days later without checking in: streak is dead.
        vm.warp(T0 + 2 days);
        assertEq(streak.liveStreak(alice), 0);
        // But one day later it still reads live (yesterday counts).
        vm.warp(T0 + 1 days);
        assertEq(streak.liveStreak(alice), 1);
    }

    function testEventEmitted() public {
        uint256 day = T0 / 1 days;
        vm.expectEmit(true, true, false, true);
        emit CheckedIn(alice, day, 1);
        vm.prank(alice);
        streak.checkIn();
    }

    function testMultipleUsersIndependent() public {
        registry.setHolder(bob, true);
        vm.prank(alice);
        streak.checkIn();
        vm.warp(T0 + 1 days);
        vm.prank(bob);
        streak.checkIn();
        (, uint64 aliceCur,,) = streak.statsOf(alice);
        (, uint64 bobCur,,) = streak.statsOf(bob);
        assertEq(aliceCur, 1);
        assertEq(bobCur, 1);
        assertEq(streak.totalCheckIns(), 2);
        assertEq(streak.checkInsPerDay(T0 / 1 days), 1);
        assertEq(streak.checkInsPerDay(T0 / 1 days + 1), 1);
    }

    function testDayBoundary() public {
        // Check in one second before UTC midnight, then one second after.
        uint256 midnight = ((T0 / 1 days) + 1) * 1 days;
        vm.warp(midnight - 1);
        vm.prank(alice);
        streak.checkIn();
        vm.warp(midnight);
        assertFalse(streak.hasCheckedInToday(alice));
        vm.prank(alice);
        streak.checkIn();
        (, uint64 cur,,) = streak.statsOf(alice);
        assertEq(cur, 2, "consecutive UTC days continue the streak");
    }
}
