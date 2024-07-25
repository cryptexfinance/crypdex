// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenExchangeSetIssuer} from "contracts/extensions/TokenExchangeSetIssuer.sol";
import {BasicIssuanceModule} from "contracts/modules/BasicIssuanceModule.sol";
import {ISetToken} from "contracts/interfaces/ISetToken.sol";
import {FlokiUniswapV2BuyTokens} from "contracts/extensions/FlokiUniswapV2BuyTokens.sol";
import {IFlokiTaxHandler} from "contracts/interfaces/external/IFlokiTaxHandler.sol";
import {IUniswapV2Router} from "contracts/interfaces/external/IUniswapV2Router.sol";

contract ForkTestDexAggregatorSetIssuer is Test {
    TokenExchangeSetIssuer dexAggregatorSetIssuer;
    FlokiUniswapV2BuyTokens flokiUniswapV2BuyTokens;

    address usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address dogeCoinAddress = 0x4206931337dc273a630d328dA6441786BfaD668f;
    address shibAddress = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address pepeAddress = 0x6982508145454Ce325dDbE47a25d4ec3d2311933;
    address flokiAddress = 0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E;
    address wETHAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address paraSwapV6Address = 0x6A000F20005980200259B80c5102003040001068;
    address basicIssuanceModuleAddress = 0x9330d0F979af5c8a5f2380f7bc41234A7d8A15de;
    address memeIndexTokenAddress = 0xA544b3F0c46c15F0B2b00ba3D67b56C250287905;
    address flokiUinswapV2pairAddress = 0xca7c2771D248dCBe09EABE0CE57A62e18dA178c0;
    address flokiTaxHandlerAddress = 0x834F96fD4fE9147a2a647D957FBbE67FEc62B67b;
    address uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    IERC20 usdc = IERC20(usdcAddress);
    IERC20 doge = IERC20(dogeCoinAddress);
    IERC20 shib = IERC20(shibAddress);
    IERC20 pepe = IERC20(pepeAddress);
    IERC20 floki = IERC20(flokiAddress);
    IERC20 weth = IERC20(wETHAddress);

    BasicIssuanceModule issuanceModule = BasicIssuanceModule(basicIssuanceModuleAddress);
    ISetToken memeIndexToken = ISetToken(memeIndexTokenAddress);
    IUniswapV2Router uniswapRouter = IUniswapV2Router(uniswapRouterAddress);
    IFlokiTaxHandler flokiTaxHandler = IFlokiTaxHandler(flokiTaxHandlerAddress);

    address user = 0x92717c31E2A6C74c6Ec366bF5157563e88705205;
    address deployer = address(0x52);

    uint256 dogeQuoteAmount = uint256((3405643 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0x4206931337dc273a630d328dA6441786BfaD668f&amount=2806361088&srcDecimals=6&destDecimals=8&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes dogePayLoad =
        hex"7f4576750000000000000000000000005006860a0906b0d8c9c050200947000030081006000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004206931337dc273a630d328da6441786bfad668f0000000000000000000000000000000000000000000000000000000000347c5300000000000000000000000000000000000000000000000000000000a745ac00000000000000000000000000000000000000000000000000000000000033f74b1462c2ca2b824616a80dbd290f4e52d90000000000000000000000000137039d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e000000160000000000000000000000120000000000000013700000000000027101b81d678ffb9c0263b24a97847620c99d213eb1401400000000000000000000000000000000000000000000000000000000000000000000000000000f28c0498000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c51020030400010680000000000000000000000000000000000000000000000000000000066ab530d00000000000000000000000000000000000000000000000000000000a745ac000000000000000000000000000000000000000000000000000000000000347c53000000000000000000000000000000000000000000000000000000000000002b4206931337dc273a630d328da6441786bfad668f0009c4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000";
    uint256 shibQuoteAmount = uint256((3004400 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE&amount=184275184275184265723905&srcDecimals=6&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes shibPayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce00000000000000000000000000000000000000000000000000000000002e4d4c00000000000000000000000000000000000000000000270593e7d6829680000100000000000000000000000000000000000000000000000000000000002dd7f093b4313a94e647929e52e39190600fa6000000000000000000000000013703a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000006000000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000bb80000000000000000000000000000000000000000000000000000000000000000";

    uint256 pepeQuoteAmount = uint256((4022892 * 101)) / uint256(100);
    //https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0x6982508145454Ce325dDbE47a25d4ec3d2311933&amount=332741792369121567965185&srcDecimals=6&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes pepePayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000006982508145454ce325ddbe47a25d4ec3d231193300000000000000000000000000000000000000000000000000000000003dff90000000000000000000000000000000000000000000004675f7fd4224d200000100000000000000000000000000000000000000000000000000000000003d626cf1e59326739f4535b31916018d27a67a000000000000000000000000013703a20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000600000000000000000000000006982508145454ce325ddbe47a25d4ec3d2311933000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000027100000000000000000000000000000000000000000000000000000000000000000";

    uint256 flokiQuoteAmount;
    bytes flokiPayLoad;

    uint256 wethQuoteAmount = uint256((3067449 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&amount=965424915686226&srcDecimals=6&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes wethPayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000002f460b00000000000000000000000000000000000000000000000000036e0c8128235200000000000000000000000000000000000000000000000000000000002ece3964866d9c8bbb420fa194d74e03dfbee9000000000000000000000000013703a9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000060800000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000000";

    function setUp() external {
        vm.startPrank(deployer);
        dexAggregatorSetIssuer = new TokenExchangeSetIssuer();
        flokiUniswapV2BuyTokens = new FlokiUniswapV2BuyTokens(
            flokiTaxHandlerAddress,
            uniswapRouterAddress,
            flokiAddress
        );
        dexAggregatorSetIssuer.approveToken(usdc, paraSwapV6Address);
        dexAggregatorSetIssuer.approveToken(usdc, address(flokiUniswapV2BuyTokens));
        dexAggregatorSetIssuer.approveToken(doge, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(shib, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(pepe, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(floki, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(weth, basicIssuanceModuleAddress);
        deal({token: usdcAddress, to: user, give: 10000e6});
        vm.makePersistent(user);
        vm.makePersistent(usdcAddress);
        vm.makePersistent(dogeCoinAddress);
        vm.makePersistent(shibAddress);
        vm.makePersistent(pepeAddress);
        vm.makePersistent(flokiAddress);
        vm.makePersistent(wETHAddress);
        vm.makePersistent(paraSwapV6Address);
        vm.makePersistent(address(dexAggregatorSetIssuer));
        vm.makePersistent(address(flokiUniswapV2BuyTokens));
        vm.stopPrank();
    }

    function testIssueTokens() external {
        (flokiQuoteAmount, flokiPayLoad) = _computeFlokiTransferData(20746887966806);
        uint256 totalQuote = dogeQuoteAmount + shibQuoteAmount + pepeQuoteAmount + flokiQuoteAmount + wethQuoteAmount;

        uint256 oldDogeBalance = doge.balanceOf(memeIndexTokenAddress);
        uint256 oldShibBalance = shib.balanceOf(memeIndexTokenAddress);
        uint256 oldPepeBalance = pepe.balanceOf(memeIndexTokenAddress);
        uint256 oldFlokiBalance = floki.balanceOf(memeIndexTokenAddress);
        uint256 oldWethiBalance = weth.balanceOf(memeIndexTokenAddress);

        vm.rollFork(20382626);
        vm.startPrank(user);
        usdc.approve(address(dexAggregatorSetIssuer), totalQuote);
        uint256 memeIndexQuantity = 1.5 ether;
        bytes[] memory payLoads = new bytes[](5);
        payLoads[0] = dogePayLoad;
        payLoads[1] = shibPayLoad;
        payLoads[2] = pepePayLoad;
        payLoads[3] = flokiPayLoad;
        payLoads[4] = wethPayLoad;
        address[] memory exchanges = new address[](5);
        exchanges[0] = paraSwapV6Address;
        exchanges[1] = paraSwapV6Address;
        exchanges[2] = paraSwapV6Address;
        exchanges[3] = address(flokiUniswapV2BuyTokens);
        exchanges[4] = paraSwapV6Address;
        dexAggregatorSetIssuer.buyComponentsAndIssueSetToken(
            memeIndexToken,
            memeIndexQuantity,
            issuanceModule,
            usdc,
            totalQuote,
            exchanges,
            payLoads
        );

        uint256 newDogeBalance = doge.balanceOf(memeIndexTokenAddress);
        uint256 newShibBalance = shib.balanceOf(memeIndexTokenAddress);
        uint256 newPepeBalance = pepe.balanceOf(memeIndexTokenAddress);
        uint256 newFlokiBalance = floki.balanceOf(memeIndexTokenAddress);
        uint256 newWethiBalance = weth.balanceOf(memeIndexTokenAddress);
        assertGt(newDogeBalance, oldDogeBalance);
        assertGt(newShibBalance, oldShibBalance);
        assertGt(newPepeBalance, oldPepeBalance);
        assertGt(newFlokiBalance, oldFlokiBalance);
        assertGt(newWethiBalance, oldWethiBalance);
        assertEq(usdc.balanceOf(address(dexAggregatorSetIssuer)), 0);
        assertEq(memeIndexToken.balanceOf(user), memeIndexQuantity);
    }

    function _computeFlokiTransferData(
        uint256 amountOut
    ) internal view returns (uint256 amountIn, bytes memory payload) {
        address[] memory paths = new address[](3);
        paths[0] = usdcAddress;
        paths[1] = wETHAddress;
        paths[2] = flokiAddress;
        uint256 tax = flokiTaxHandler.getTax(flokiUinswapV2pairAddress, user, amountOut);
        uint256 adjustedAmountOut = (amountOut * amountOut) / (amountOut - tax);
        amountIn = uniswapRouter.getAmountsIn(adjustedAmountOut, paths)[0];
        payload = abi.encodeWithSelector(
            flokiUniswapV2BuyTokens.buyExactFlokiTokens.selector,
            amountOut,
            flokiUinswapV2pairAddress,
            paths
        );
    }

    function testFlokiUniswapV2BuyTokens() external {
        vm.startPrank(user);
        vm.rollFork(20382626);
        address[] memory paths = new address[](3);
        paths[0] = usdcAddress;
        paths[1] = wETHAddress;
        paths[2] = flokiAddress;
        uint256 amountOut = 20746887966806;
        uint256 tax = flokiTaxHandler.getTax(flokiUinswapV2pairAddress, user, amountOut);
        uint256 adjustedAmountOut = (amountOut * amountOut) / (amountOut - tax);
        uint[] memory amounts = uniswapRouter.getAmountsIn(adjustedAmountOut, paths);
        assertEq(floki.balanceOf(user), 0);
        usdc.approve(address(flokiUniswapV2BuyTokens), amounts[0]);
        flokiUniswapV2BuyTokens.buyExactFlokiTokens(amountOut, flokiUinswapV2pairAddress, paths);
        assertEq(floki.balanceOf(user), amountOut);
    }
}
