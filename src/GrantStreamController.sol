// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISablierLockup} from "@sablier/v2-core/src/interfaces/ISablierLockup.sol";
import {Lockup} from "@sablier/v2-core/src/types/Lockup.sol";
import {LockupLinear} from "@sablier/v2-core/src/types/LockupLinear.sol";

contract GrantStreamController is AccessControl {
    using SafeERC20 for IERC20;
    bytes32 public constant GRANT_ADMIN_ROLE = keccak256("GRANT_ADMIN_ROLE");

    ISablierLockup public immutable SABLIER;

    // Track created streams by grant ID
    mapping(uint256 => uint256) public grantToStreamId;

    event GrantStreamCreated(
        uint256 indexed grantId, uint256 indexed streamId, address indexed recipient, uint128 amount
    );

    event GrantStreamCanceled(uint256 indexed streamId, uint128 senderAmount, uint128 recipientAmount);

    constructor(address _sablierLockupLinear, address _admin) {
        require(_sablierLockupLinear != address(0), "Invalid Sablier address");

        require(_admin != address(0), "Invalid Admin address");

        SABLIER = ISablierLockup(_sablierLockupLinear);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(GRANT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice Creates a new linear stream for a grantee.
     * @param grantId Unique identifier for the DAO grant proposal.
     * @param token ERC-20 token address being streamed.
     * @param recipient Wallet receiving the stream.
     * @param amount Total tokens allocated to the stream.
     * @param durationInSeconds Stream duration in seconds.
     */
    function createGrantStream(
        uint256 grantId,
        IERC20 token,
        address recipient,
        uint128 amount,
        uint40 durationInSeconds
    ) external onlyRole(GRANT_ADMIN_ROLE) returns (uint256 streamId) {
        require(grantToStreamId[grantId] == 0, "Grant already streamed");

        require(recipient != address(0), "Invalid recipient");

        require(address(token) != address(0), "Invalid token");

        require(amount > 0, "Amount must be greater than zero");

        require(durationInSeconds > 0, "Duration must be greater than zero");

        // Transfer grant funds from the DAO/admin to this controller.
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Approve Sablier to pull the grant funds.
        token.forceApprove(address(SABLIER), amount);

        // Configure Sablier Linear Stream parameters.
        Lockup.CreateWithDurations memory params = Lockup.CreateWithDurations({
            sender: address(this),
            recipient: recipient,
            depositAmount: amount,
            token: token,
            cancelable: true,
            transferable: true,
            shape: "linear"
        });

        LockupLinear.UnlockAmounts memory unlockAmounts = LockupLinear.UnlockAmounts({start: 0, cliff: 0});

        LockupLinear.Durations memory durations = LockupLinear.Durations({cliff: 0, total: durationInSeconds});

        // Create the stream through Sablier.
        streamId = SABLIER.createWithDurationsLL(params, unlockAmounts, durations);

        grantToStreamId[grantId] = streamId;

        emit GrantStreamCreated(grantId, streamId, recipient, amount);
    }

    /**
     * @notice Cancels an active stream.
     */
    function cancelGrantStream(uint256 streamId) external onlyRole(GRANT_ADMIN_ROLE) {
        SABLIER.cancel(streamId);

        // The refunded tokens are now held by this controller.
        // We need to determine the token associated with the stream
        // before forwarding the refund to the grant admin.
    }
}
