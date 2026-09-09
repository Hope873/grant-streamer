// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GrantStreamController} from "../src/GrantStreamController.sol";

contract DeployGrantStreamController is Script {
    function run() external returns (GrantStreamController controller) {
        address sablier = vm.envAddress("SABLIER_LOCKUP_LINEAR");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast();

        controller = new GrantStreamController(sablier, admin);

        vm.stopBroadcast();

        console2.log("GrantStreamController deployed at:", address(controller));
        console2.log("Sablier:", sablier);
        console2.log("Admin:", admin);
    }
}
