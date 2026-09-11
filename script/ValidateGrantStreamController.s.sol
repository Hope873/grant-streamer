// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GrantStreamController} from "../src/GrantStreamController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Lockup} from "@sablier/lockup/types/Lockup.sol";

contract ValidateGrantStreamController is Script {
    function run() external view {
        address controllerAddress = vm.envAddress("GRANT_STREAM_CONTROLLER");
        address expectedSablier = vm.envAddress("SABLIER_LOCKUP_LINEAR");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        GrantStreamController controller = GrantStreamController(controllerAddress);

        require(address(controller.SABLIER()) == expectedSablier, "Unexpected Sablier address");
        require(
            controller.hasRole(controller.GRANT_ADMIN_ROLE(), admin), "ADMIN_ADDRESS does not have GRANT_ADMIN_ROLE"
        );

        console2.log("GrantStreamController:", controllerAddress);
        console2.log("Sablier:", address(controller.SABLIER()));
        console2.log("Admin:", admin);
        console2.log("Configuration validation passed");

        if (!vm.envOr("VALIDATE_GRANT", false)) {
            return;
        }

        uint256 grantId = vm.envUint("GRANT_ID");

        (
            uint256 streamId,
            address recipient,
            IERC20 token,
            address funder,
            Lockup.Status status,
            uint128 streamedAmount,
            uint128 withdrawableAmount,
            uint128 refundableAmount
        ) = controller.getGrantStreamStatus(grantId);

        require(streamId != 0, "Grant has no stream");
        require(controller.streamToGrantId(streamId) == grantId, "Grant/stream mapping mismatch");

        if (status == Lockup.Status.STREAMING) {
            require(controller.streamActive(streamId), "Active stream not marked active");
            require(address(token) != address(0), "Active stream token missing");
            require(funder != address(0), "Active stream funder missing");
        } else if (status == Lockup.Status.CANCELED || status == Lockup.Status.DEPLETED) {
            require(!controller.streamActive(streamId), "Terminal stream still marked active");
            require(address(token) == address(0), "Terminal stream token not cleared");
            require(funder == address(0), "Terminal stream funder not cleared");
        }

        console2.log("Grant ID:", grantId);
        console2.log("Stream ID:", streamId);
        console2.log("Recipient:", recipient);
        console2.log("Token:", address(token));
        console2.log("Funder:", funder);
        console2.log("Status:", uint256(status));
        console2.log("Streamed:", uint256(streamedAmount));
        console2.log("Withdrawable:", uint256(withdrawableAmount));
        console2.log("Refundable:", uint256(refundableAmount));
        console2.log("Grant validation passed");
    }
}
