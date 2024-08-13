// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

contract TransferMainnetToBase is Script {
    address user = 0xF8E3b46Ed9efD7e28a0fcB1B62F76747474f5018;
    address memeIndexTokenAddress = 0x15f9cec1c568352Cd48Da1E84D3e74F27f6ee160;
    address baseRouterAddress = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    IRouterClient baseRouter = IRouterClient(baseRouterAddress);
    IERC20 memeIndex = IERC20(memeIndexTokenAddress);

    function run() external {
        uint256 privateKey = vm.envUint("LEARN_DEFI_PRIVATE_KEY");
        uint64 destinationChainSelector = 5009297550715157269;
        address receiver = user;
        string memory message = "";
        address token = memeIndexTokenAddress;
        uint256 amount = 1 ether;

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: token,
            amount: amount
        });
        tokenAmounts[0] = tokenAmount;
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: abi.encode(message), // ABI-encoded string message
            tokenAmounts: tokenAmounts, // Tokens amounts
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000}) // Additional arguments, setting gas limit and non-strict sequency mode
            ),
            feeToken: address(0) // Setting feeToken to zero address, indicating native asset will be used for fees
        });
        vm.startBroadcast(privateKey);
        memeIndex.approve(baseRouterAddress, amount);
        uint256 fees = baseRouter.getFee(destinationChainSelector, evm2AnyMessage);
        bytes32 messageId = baseRouter.ccipSend{value: fees}(
            destinationChainSelector,
            evm2AnyMessage
        );
        console.logBytes32(messageId);
        vm.stopBroadcast();
    }
}
