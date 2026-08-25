// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GrantStreamController} from "../src/GrantStreamController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISablierLockup} from "@sablier/v2-core/src/interfaces/ISablierLockup.sol";

contract GrantStreamControllerTest is Test {
    GrantStreamController public controller;

    // Arbitrum Mainnet Addresses
    address constant SABLIER_LOCKUP_LINEAR = 0xF12AbfB041b5064b839Ca56638cDB62fEA712Db5;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant USDC_WHALE = 0x47c031236e19d024b42f8AE6780E44A573170703;

    address admin = address(0x1);
    address recipient = address(0x2);

    function setUp() public {
        // Fork Arbitrum at block height
        vm.createSelectFork("https://arb1.arbitrum.io/rpc");

        vm.startPrank(admin);
        controller = new GrantStreamController(SABLIER_LOCKUP_LINEAR, admin);
        vm.stopPrank();

        // Fund admin with USDC from whale
        vm.prank(USDC_WHALE);

        bool success = IERC20(USDC).transfer(admin, 10_000 * 1e6);

        assertTrue(success, "USDC transfer failed");
    }

    function test_CreateGrantStream() public {
        uint256 grantId = 101;
        uint128 grantAmount = 5_000 * 1e6; // 5,000 USDC
        uint40 duration = 30 days;

        vm.startPrank(admin);
        IERC20(USDC).approve(address(controller), grantAmount);

        uint256 streamId = controller.createGrantStream(grantId, IERC20(USDC), recipient, grantAmount, duration);
        vm.stopPrank();

        assertGt(streamId, 0);
        assertEq(controller.grantToStreamId(grantId), streamId);
    }

    function test_SablierAddress() public view {
        uint256 codeSize;

        address target = SABLIER_LOCKUP_LINEAR;

        assembly {
            codeSize := extcodesize(target)
        }

        console2.log("Sablier address:", target);
        console2.log("Code size:", codeSize);

        assertGt(codeSize, 0, "Sablier address has no contract code");
    }

    function test_CancelGrantStream_BeforeStreamingStarts() public {
        uint256 grantId = 104;
        uint128 grantAmount = 5_000 * 1e6;
        uint40 duration = 30 days;

        uint256 adminBalanceBefore = IERC20(USDC).balanceOf(admin);
        uint256 recipientBalanceBefore = IERC20(USDC).balanceOf(recipient);

        vm.startPrank(admin);

        IERC20(USDC).approve(address(controller), grantAmount);

        uint256 streamId = controller.createGrantStream(
            grantId,
            IERC20(USDC),
            recipient,
            grantAmount,
            duration
        );

        // Cancel immediately, before any meaningful vesting occurs.
        controller.cancelGrantStream(streamId);

        vm.stopPrank();

        uint256 adminBalanceAfter = IERC20(USDC).balanceOf(admin);
        uint256 recipientBalanceAfter = IERC20(USDC).balanceOf(recipient);

        // The full amount should be refunded to the admin.
        assertEq(
            adminBalanceAfter,
            adminBalanceBefore,
            "Admin should receive the full refund"
        );

        // Recipient should receive nothing.
        assertEq(
            recipientBalanceAfter,
            recipientBalanceBefore,
            "Recipient should receive nothing"
        );

        // Controller must not retain any USDC.
        assertEq(
            IERC20(USDC).balanceOf(address(controller)),
            0,
            "Controller should not retain USDC"
        );

        // The grant should still map to the canceled stream.
        assertEq(
            controller.grantToStreamId(grantId),
            streamId,
            "Grant should remain mapped to canceled stream"
        );
    }

    function test_RevertWhen_CancelGrantStream_AfterFullyVested() public {
        uint256 grantId = 105;
        uint128 grantAmount = 5_000 * 1e6;
        uint40 duration = 30 days;

        vm.startPrank(admin);

        IERC20(USDC).approve(address(controller), grantAmount);

        uint256 streamId = controller.createGrantStream(
            grantId,
            IERC20(USDC),
            recipient,
            grantAmount,
            duration
        );

        // Move exactly to the end of the stream.
        vm.warp(block.timestamp + duration);

        // A fully vested stream cannot be canceled.
        vm.expectRevert();

        controller.cancelGrantStream(streamId);

        vm.stopPrank();
    }

    function test_CancelGrantStream_AfterStreamingStarts() public {
        uint256 grantId = 103;
        uint128 grantAmount = 5_000 * 1e6;
        uint40 duration = 30 days;

        uint256 adminBalanceBefore = IERC20(USDC).balanceOf(admin);

        vm.startPrank(admin);

        IERC20(USDC).approve(address(controller), grantAmount);

        uint256 streamId = controller.createGrantStream(
            grantId,
            IERC20(USDC),
            recipient,
            grantAmount,
            duration
        );

        // Move halfway through the stream.
        vm.warp(block.timestamp + 15 days);

        // Cancel after the stream has partially vested.
        controller.cancelGrantStream(streamId);

        vm.stopPrank();

        uint256 adminBalanceAfter = IERC20(USDC).balanceOf(admin);

        // Approximately half should have been refunded to the admin.
        assertEq(
            adminBalanceAfter,
            adminBalanceBefore - (grantAmount / 2),
            "Admin should have a net loss of approximately half"
        );

        // The controller must not retain any USDC.
        assertEq(
            IERC20(USDC).balanceOf(address(controller)),
            0,
            "Controller should not retain refunded funds"
        );

        // The recipient's streamed amount should be approximately half.
        uint128 streamedAmount = ISablierLockup(SABLIER_LOCKUP_LINEAR).streamedAmountOf(streamId);

        assertApproxEqAbs(
            streamedAmount,
            grantAmount / 2,
            1,
            "Approximately half should be streamed to recipient"
        );
    }

    function test_RevertWhen_NonAdminCreatesGrantStream() public {
        uint256 grantId = 200;
        uint128 grantAmount = 1_000 * 1e6;
        uint40 duration = 30 days;

        address attacker = address(0x3);

        vm.startPrank(attacker);

        vm.expectRevert();
        controller.createGrantStream(
            grantId,
            IERC20(USDC),
            recipient,
            grantAmount,
            duration
        );

        vm.stopPrank();
    }

    function test_RevertWhen_NonAdminCancelsGrantStream() public {
        uint256 grantId = 201;
        uint128 grantAmount = 1_000 * 1e6;
        uint40 duration = 30 days;

        vm.startPrank(admin);

        IERC20(USDC).approve(address(controller), grantAmount);

        uint256 streamId = controller.createGrantStream(
            grantId,
            IERC20(USDC),
            recipient,
            grantAmount,
            duration
        );

        vm.stopPrank();

        address attacker = address(0x3);

        vm.startPrank(attacker);

        vm.expectRevert();
        controller.cancelGrantStream(streamId);

        vm.stopPrank();
    }

    function test_RevertWhen_RecipientIsZero() public {
        uint256 grantId = 300;
        uint128 grantAmount = 1_000 * 1e6;
        uint40 duration = 30 days;

        vm.startPrank(admin);
        IERC20(USDC).approve(address(controller), grantAmount);

        vm.expectRevert("Invalid recipient");

        controller.createGrantStream(grantId, IERC20(USDC), address(0), grantAmount, duration);

        vm.stopPrank();
    }

    function test_RevertWhen_TokenIsZero() public {
        uint256 grantId = 301;
        uint128 grantAmount = 1_000 * 1e6;
        uint40 duration = 30 days;

        vm.startPrank(admin);

        vm.expectRevert("Invalid token");

        controller.createGrantStream(grantId, IERC20(address(0)), recipient, grantAmount, duration);

        vm.stopPrank();
    }

    function test_RevertWhen_AmountIsZero() public {
        uint256 grantId = 302;
        uint40 duration = 30 days;

        vm.startPrank(admin);

        vm.expectRevert("Amount must be greater than zero");

        controller.createGrantStream(grantId, IERC20(USDC), recipient, 0, duration);

        vm.stopPrank();
    }

    function test_RevertWhen_DurationIsZero() public {
        uint256 grantId = 303;
        uint128 grantAmount = 1_000 * 1e6;

        vm.startPrank(admin);

        IERC20(USDC).approve(address(controller), grantAmount);

        vm.expectRevert("Duration must be greater than zero");

        controller.createGrantStream(grantId, IERC20(USDC), recipient, grantAmount, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_GrantAlreadyStreamed() public {
        uint256 grantId = 400;
        uint128 grantAmount = 1_000 * 1e6;
        uint40 duration = 30 days;

        vm.startPrank(admin);

        IERC20(USDC).approve(address(controller), grantAmount * 2);

        controller.createGrantStream(grantId, IERC20(USDC), recipient, grantAmount, duration);

        vm.expectRevert("Grant already streamed");

        controller.createGrantStream(grantId, IERC20(USDC), recipient, grantAmount, duration);

        vm.stopPrank();
    }

    function test_CreateGrantStream_TransfersFundsCorrectly() public {
        uint256 grantId = 500;
        uint128 grantAmount = 1_000 * 1e6;
        uint40 duration = 30 days;

        uint256 adminBalanceBefore = IERC20(USDC).balanceOf(admin);
        uint256 controllerBalanceBefore = IERC20(USDC).balanceOf(address(controller));

        vm.startPrank(admin);

        IERC20(USDC).approve(address(controller), grantAmount);

        controller.createGrantStream(grantId, IERC20(USDC), recipient, grantAmount, duration);

        vm.stopPrank();

        uint256 adminBalanceAfter = IERC20(USDC).balanceOf(admin);
        uint256 controllerBalanceAfter = IERC20(USDC).balanceOf(address(controller));

        assertEq(adminBalanceBefore - adminBalanceAfter, grantAmount);

        assertEq(controllerBalanceAfter, controllerBalanceBefore);
    }
}
