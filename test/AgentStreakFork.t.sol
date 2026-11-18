// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentStreak.sol";

/// @notice Fork test against the REAL Agent ID registry on BSC mainnet.
///         Read-only: pranks a known holder, no signing, no transactions.
///         Run with: forge test --match-contract AgentStreakForkTest
///                   --fork-url https://bsc-rpc.publicnode.com
contract AgentStreakForkTest is Test {
    // Real Agent ID registry (SPACE ID Agent ID, ERC-721).
    address public constant REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    // Known Agent ID holder (belabol.ai wallet).
    address public constant HOLDER = 0xF081302CdcA1396a14833241295E23Cdc89e6366;
    // Fresh address with no Agent ID.
    address public constant NON_HOLDER = address(0xDEAD);

    AgentStreak public streak;

    function setUp() public {
        streak = new AgentStreak(REGISTRY);
    }

    function testRealRegistryHolderCanCheckIn() public {
        assertTrue(streak.isHolder(HOLDER), "known holder must read as holder");
        vm.prank(HOLDER);
        streak.checkIn();
        (, uint64 cur,, uint64 total) = streak.statsOf(HOLDER);
        assertEq(cur, 1);
        assertEq(total, 1);
    }

    function testRealRegistryNonHolderReverts() public {
        assertFalse(streak.isHolder(NON_HOLDER), "fresh address must not be a holder");
        vm.prank(NON_HOLDER);
        vm.expectRevert(AgentStreak.NotAgentIDHolder.selector);
        streak.checkIn();
    }
}
