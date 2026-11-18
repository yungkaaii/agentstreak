// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentStreak.sol";

/// @notice Deploys AgentStreak on BNB Chain.
///         Dry-run (no broadcast, no signing):
///           forge script script/Deploy.s.sol --fork-url https://bsc-rpc.publicnode.com -vv
///         Real deploy (only when the user explicitly approves, with their own key):
///           forge script script/Deploy.s.sol --rpc-url https://bsc-rpc.publicnode.com \
///             --broadcast --verify --verifier-url https://api.bscscan.com/api \
///             --etherscan-api-key $BSCSCAN_API_KEY
contract Deploy is Script {
    address public constant REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external {
        vm.startBroadcast();
        AgentStreak streak = new AgentStreak(REGISTRY);
        vm.stopBroadcast();
        console2.log("AgentStreak deployed at:", address(streak));
    }
}
