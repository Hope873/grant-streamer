# Grant Streamer

`GrantStreamController` is a Solidity controller for creating and cancelling Sablier Lockup Linear token streams for DAO grants.

## Overview

The controller:

- Allows only accounts with `GRANT_ADMIN_ROLE` to create and cancel grant streams.
- Pulls grant funds from the caller using `SafeERC20`.
- Rejects fee-on-transfer and other incompatible ERC-20 tokens by verifying the exact received amount.
- Creates non-transferable, cancelable Sablier Lockup Linear streams.
- Records the original funder and refunds that funder when a stream is cancelled.
- Prevents a grant ID from being streamed more than once, including after cancellation.
- Uses `ReentrancyGuard` on stream creation and cancellation.
- Approves Sablier only for the exact stream amount.

## Project Structure

```text
src/
  GrantStreamController.sol
  TestToken.sol

script/
  DeployGrantStreamController.s.sol
  DeployTestToken.s.sol

test/
  GrantStreamController.t.sol
  GrantStreamControllerFeeToken.t.sol
  GrantStreamControllerReentrancy.t.sol
```

## Requirements

- Foundry
- Solidity `^0.8.20`
- Sablier Lockup v3.0.1

## Build and Test

```shell
forge build
forge test
forge fmt --check
```

The current test suite contains 32 tests covering stream creation, cancellation, access control, reentrancy protection, token handling, grant-ID reuse, and Sablier allowance cleanup.

## Environment

Create a local `.env` file from `.env.example`:

```env
RPC_URL=
PRIVATE_KEY=
ADMIN_ADDRESS=
SABLIER_LOCKUP_LINEAR=
GRANT_STREAM_CONTROLLER=
```

Never commit `.env` or expose the deployment private key.

## Deployment

The controller deployment script reads `SABLIER_LOCKUP_LINEAR` and `ADMIN_ADDRESS` from the environment.

Example:

```shell
forge script script/DeployGrantStreamController.s.sol:DeployGrantStreamController --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
```

## Arbitrum Sepolia Validation

The controller has been deployed and tested end-to-end on Arbitrum Sepolia.

### Sablier Lockup

`0x5Bd5A50100d0cBC93837a1d10C816614008554fe`

### GrantStreamController

`0x5E6140659DFF8b12754518fBB8DC99097ffFF4bB`

### TestToken

`0x7A30E94Ec82D7fD07441D2157E618Ce1536bEB72`

The live validation successfully created stream ID `10` for a 100 GST, one-hour stream and subsequently cancelled it. The cancellation refund was returned to the original funder.

## Security Notes

Grant administrators should verify:

1. The Sablier Lockup deployment address matches the intended network.
2. The token is a standard ERC-20 compatible with exact-value transfers.
3. The recipient address is correct before creating a stream.
4. The grant ID is unique.
5. The admin account is securely controlled.
6. The deployment private key is never stored in the repository.

The controller's grant-admin role is required to create and cancel streams. Stream state is written only after the underlying Sablier operation succeeds.

Additional safeguards include:

- `ReentrancyGuard` protects stream creation and cancellation.
- Token funding uses `SafeERC20` with an exact balance-delta check, rejecting fee-on-transfer or otherwise incompatible tokens.
- Sablier approval uses `forceApprove` for compatibility with tokens that require allowance resets.
- Created streams are non-transferable, preventing the stream NFT from being moved to another owner.
- Cancellation is restricted to the controller's recorded stream and refunds the original funder.
- A grant ID cannot be reused after a stream has been created, including after cancellation.
- The controller has no upgrade mechanism. A new deployment is required for contract logic changes.

## Contract Size

The current `GrantStreamController` build is approximately 8.95 KB of runtime bytecode, leaving substantial headroom below the EVM contract-size limit.

## License

MIT
