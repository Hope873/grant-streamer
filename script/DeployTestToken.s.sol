// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TestToken} from "../src/TestToken.sol";

contract DeployTestToken is Script {
    function run() external returns (TestToken token) {
        vm.startBroadcast();

        token = new TestToken();

        vm.stopBroadcast();

        console2.log("TestToken deployed at:", address(token));
    }
}
