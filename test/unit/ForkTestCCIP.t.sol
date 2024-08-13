// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";


contract ForkTestCCIP is Test {

    address user = 0xF8E3b46Ed9efD7e28a0fcB1B62F76747474f5018;
    address memeIndexTokenAddress = 0xA544b3F0c46c15F0B2b00ba3D67b56C250287905;
    address mainnetRouterAddress = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    IRouterClient mainnetRouter = IRouterClient(mainnetRouterAddress);
    IERC20 memeIndex = IERC20(memeIndexTokenAddress);

    function test() external {
        vm.startPrank(user);
        uint64 destinationChainSelector = 15971525489660198786;
        address receiver = user;
        string memory message = "";
        address token = memeIndexTokenAddress;
        uint256 amount = 1 ether;

        memeIndex.approve(mainnetRouterAddress, 1 ether);
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
        uint256 fees = mainnetRouter.getFee(destinationChainSelector, evm2AnyMessage);

        bytes32 messageId = mainnetRouter.ccipSend{value: fees}(
            destinationChainSelector,
            evm2AnyMessage
        );
        console.logBytes32(messageId);
    }

}
