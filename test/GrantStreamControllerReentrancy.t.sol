// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {GrantStreamController} from "../src/GrantStreamController.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Lockup} from "@sablier/v2-core/src/types/Lockup.sol";
import {LockupLinear} from "@sablier/v2-core/src/types/LockupLinear.sol";

contract MockSablier {
    uint256 public nextStreamId = 1;
    uint256 public createCount;

    function createWithDurationsLL(
        Lockup.CreateWithDurations calldata params,
        LockupLinear.UnlockAmounts calldata,
        LockupLinear.Durations calldata
    ) external returns (uint256 streamId) {
        createCount++;

        IERC20(address(params.token)).transferFrom(msg.sender, address(this), params.depositAmount);

        streamId = nextStreamId++;
    }
}

contract ReentrantToken is ERC20 {
    ReentrantGrantAdmin public adminContract;

    bool public callbackEnabled;
    bool private insideCallback;

    constructor() ERC20("Reentrant Token", "RNT") {}

    function setAdminContract(ReentrantGrantAdmin _adminContract) external {
        adminContract = _adminContract;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function enableCallback() external {
        callbackEnabled = true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        bool success = super.transferFrom(from, to, value);

        if (callbackEnabled && !insideCallback && address(adminContract) != address(0)) {
            insideCallback = true;

            adminContract.reenter();

            insideCallback = false;
        }

        return success;
    }
}

contract ReentrantGrantAdmin {
    GrantStreamController public controller;
    ReentrantToken public token;

    uint256 public grantId;
    address public recipient;
    uint128 public amount;
    uint40 public duration;

    bool public reentryEnabled;

    function configure(
        GrantStreamController _controller,
        ReentrantToken _token,
        uint256 _grantId,
        address _recipient,
        uint128 _amount,
        uint40 _duration
    ) external {
        controller = _controller;
        token = _token;
        grantId = _grantId;
        recipient = _recipient;
        amount = _amount;
        duration = _duration;
    }

    function approveController() external {
        token.approve(address(controller), type(uint256).max);
    }

    function enableReentry() external {
        reentryEnabled = true;
    }

    function createStream() external {
        controller.createGrantStream(grantId, IERC20(address(token)), recipient, amount, duration);
    }

    function reenter() external {
        if (!reentryEnabled) {
            return;
        }

        reentryEnabled = false;

        controller.createGrantStream(grantId, IERC20(address(token)), recipient, amount, duration);
    }
}

contract GrantStreamControllerReentrancyTest is Test {
    GrantStreamController controller;
    MockSablier mockSablier;
    ReentrantToken token;
    ReentrantGrantAdmin adminContract;

    address recipient = address(0xBEEF);

    function setUp() public {
        mockSablier = new MockSablier();

        adminContract = new ReentrantGrantAdmin();

        controller = new GrantStreamController(address(mockSablier), address(adminContract));

        token = new ReentrantToken();

        token.setAdminContract(adminContract);

        adminContract.configure(controller, token, 500, recipient, 1_000 ether, 30 days);

        // Enough tokens for two streams.
        token.mint(address(adminContract), 2_000 ether);

        adminContract.approveController();

        token.enableCallback();
        adminContract.enableReentry();
    }

    function test_ReentrancyCannotCreateTwoStreamsForSameGrant() public {
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);

        adminContract.createStream();
    }
}
