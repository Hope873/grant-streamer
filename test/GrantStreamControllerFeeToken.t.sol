// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GrantStreamController} from "../src/GrantStreamController.sol";

contract FeeOnTransferToken is ERC20 {
    uint256 public constant FEE_BPS = 100; // 1%
    uint256 public constant BPS = 10_000;

    constructor() ERC20("Fee Token", "FEE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        // Do not charge a fee on mint or burn.
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * FEE_BPS) / BPS;
        uint256 received = value - fee;

        super._update(from, to, received);
        super._update(from, address(0), fee);
    }
}

contract GrantStreamControllerFeeTokenTest is Test {
    address constant SABLIER_LOCKUP_LINEAR = 0xF12AbfB041b5064b839Ca56638cDB62fEA712Db5;

    GrantStreamController controller;
    FeeOnTransferToken feeToken;

    address admin = address(0x1);
    address recipient = address(0x2);

    function setUp() public {
        vm.createSelectFork("https://arb1.arbitrum.io/rpc");

        controller = new GrantStreamController(SABLIER_LOCKUP_LINEAR, admin);

        feeToken = new FeeOnTransferToken();

        feeToken.mint(admin, 10_000 ether);
    }

    function test_RevertWhen_FeeOnTransferTokenReceivedAmountIsIncorrect() public {
        uint256 grantId = 200;
        uint128 amount = 1_000 ether;
        uint40 duration = 30 days;

        vm.startPrank(admin);

        feeToken.approve(address(controller), amount);

        vm.expectRevert(bytes("Unsupported token transfer"));

        controller.createGrantStream(grantId, IERC20(address(feeToken)), recipient, amount, duration);

        vm.stopPrank();

        // Entire transaction must revert atomically.
        assertEq(feeToken.balanceOf(admin), 10_000 ether, "Admin balance should remain unchanged");

        assertEq(feeToken.balanceOf(address(controller)), 0, "Controller should retain no tokens");

        assertEq(controller.grantToStreamId(grantId), 0, "No stream should be recorded");
    }
}
