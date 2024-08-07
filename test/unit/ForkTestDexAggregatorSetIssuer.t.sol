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
    address flokiTreasuryAddress = 0xBc530Bfa3FCA1a731149248AfC7F750c18360de1;
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

    uint256 dogeUSDCAmount = uint256((3405643 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0x4206931337dc273a630d328dA6441786BfaD668f&amount=2806361088&srcDecimals=6&destDecimals=8&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes dogeUSDCPayLoad =
        hex"7f4576750000000000000000000000005006860a0906b0d8c9c050200947000030081006000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004206931337dc273a630d328da6441786bfad668f0000000000000000000000000000000000000000000000000000000000347c5300000000000000000000000000000000000000000000000000000000a745ac00000000000000000000000000000000000000000000000000000000000033f74b1462c2ca2b824616a80dbd290f4e52d90000000000000000000000000137039d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e000000160000000000000000000000120000000000000013700000000000027101b81d678ffb9c0263b24a97847620c99d213eb1401400000000000000000000000000000000000000000000000000000000000000000000000000000f28c0498000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c51020030400010680000000000000000000000000000000000000000000000000000000066ab530d00000000000000000000000000000000000000000000000000000000a745ac000000000000000000000000000000000000000000000000000000000000347c53000000000000000000000000000000000000000000000000000000000000002b4206931337dc273a630d328da6441786bfad668f0009c4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000";
    uint256 shibUSDCAmount = uint256((3004400 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE&amount=184275184275184265723905&srcDecimals=6&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes shibUSDCPayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce00000000000000000000000000000000000000000000000000000000002e4d4c00000000000000000000000000000000000000000000270593e7d6829680000100000000000000000000000000000000000000000000000000000000002dd7f093b4313a94e647929e52e39190600fa6000000000000000000000000013703a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000006000000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000bb80000000000000000000000000000000000000000000000000000000000000000";

    uint256 pepeUSDCAmount = uint256((4022892 * 101)) / uint256(100);
    //https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0x6982508145454Ce325dDbE47a25d4ec3d2311933&amount=332741792369121567965185&srcDecimals=6&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes pepeUSDCPayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000006982508145454ce325ddbe47a25d4ec3d231193300000000000000000000000000000000000000000000000000000000003dff90000000000000000000000000000000000000000000004675f7fd4224d200000100000000000000000000000000000000000000000000000000000000003d626cf1e59326739f4535b31916018d27a67a000000000000000000000000013703a20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000600000000000000000000000006982508145454ce325ddbe47a25d4ec3d2311933000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000027100000000000000000000000000000000000000000000000000000000000000000";

    uint256 flokiUSDCAmount;
    bytes flokiUSDCPayLoad;

    uint256 wethUSDCAmount = uint256((3067449 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&destToken=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&amount=965424915686226&srcDecimals=6&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes wethUSDCPayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000002f460b00000000000000000000000000000000000000000000000000036e0c8128235200000000000000000000000000000000000000000000000000000000002ece3964866d9c8bbb420fa194d74e03dfbee9000000000000000000000000013703a9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000060800000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000000";

    uint256 dogeWETHAmount = uint256((1108411581623423 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&destToken=0x4206931337dc273a630d328dA6441786BfaD668f&amount=2806361088&srcDecimals=18&destDecimals=8&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes dogeWETHPayLoad =
        hex"a76f4eb60000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000004206931337dc273a630d328da6441786bfad668f0000000000000000000000000000000000000000000000000003fa2ce75f9ba900000000000000000000000000000000000000000000000000000000a745ac000000000000000000000000000000000000000000000000000003f0182e966c7fd9bfc12a9ce34e04ae626746b384b66e00000000000000000000000001370cd90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000404206931337dc273a630d328da6441786bfad668fc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    uint256 shibWETHAmount = uint256((951668730580914 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&destToken=0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE&amount=184275184275184265723905&srcDecimals=18&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes shibWETHPayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce00000000000000000000000000000000000000000000000000036a316b657c0300000000000000000000000000000000000000000000270593e7d6829680000100000000000000000000000000000000000000000000000000036189a4a14fb2129fa3a6e6894388a817d49979fa1e9300000000000000000000000001370ce100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000006000000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000000000";

    uint256 pepeWETHAmount = uint256((1237056916517651 * 101)) / uint256(100);
    // https://api.paraswap.io/swap?srcToken=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&destToken=0x6982508145454Ce325dDbE47a25d4ec3d2311933&amount=332741792369121567965185&srcDecimals=18&destDecimals=18&side=BUY&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes pepeWETHPayLoad =
        hex"5e94e28d0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006982508145454ce325ddbe47a25d4ec3d2311933000000000000000000000000000000000000000000000000000470590174ec8b000000000000000000000000000000000000000000004675f7fd4224d200000100000000000000000000000000000000000000000000000000046518c2137313e78e9fef30374ff0b173832fb2e2e78100000000000000000000000001370ce70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000600000000000000000000000006982508145454ce325ddbe47a25d4ec3d2311933000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000bb80000000000000000000000000000000000000000000000000000000000000000";

    uint256 flokiWETHAmount;
    bytes flokiWETHPayLoad;

    uint256 wethWETHAmount = 965424915686226;
    bytes wethWETHPayLoad;

    // https://api.paraswap.io/swap?srcToken=0x4206931337dc273a630d328dA6441786BfaD668f&destToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&amount=2806361087&srcDecimals=8&destDecimals=6&side=SELL&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes sellDogeUSDCPayLoad =
        hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e50410000000000000000000000004206931337dc273a630d328da6441786bfad668f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000028d6827da2300000000000000000000000000000000000000000000000000000000d11603aa00000000000000000000000000000000000000000000000000000000d332ae5ee88315512aba4f4c98c60c230b5f594c000000000000000000000000013717a30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002e04206931337dc273a630d328da6441786bfad668f0000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000c0067d751fb1172dbab1fa003efe214ee8f419b60000000000000000000000000000000000000000000000000000028d6827da235f0000d4780a00d2dce0a00004000800cb0e5041000000a000240064ff06000b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000028d6827da23000000000000000000004de4c0067d751fb1172dbab1fa003efe214ee8f419b6000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2e592427a0aece92de3edee1f18e0157c0586156400000140008400000000000300000000000000000000000000000000000000000000000000000000c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c51020030400010680000000000000000000000000000000000000000000000000000000066ac44eb0000000000000000000000000000000000000000000000000f36c2e482a999f90000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000";
    // https://api.paraswap.io/swap?srcToken=0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE&destToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&amount=184275184275184265723904&srcDecimals=18&destDecimals=6&side=SELL&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes sellShibUSDCPayLoad =
        hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e504100000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000986dc9c19dee1be3ffffff00000000000000000000000000000000000000000000000000000000b62c255d00000000000000000000000000000000000000000000000000000000b80337d76f52b681f8ab42fe9d206813f039d1d5000000000000000000000000013717a30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002e095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce0000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000cf6daab95c476106eca715d48de4b13287ffdeaa000000000000000000000000000000000000000000986dc9c19dee1be3ffffff5f0000d4780a00d2dce0a00004000800cb0e5041000000a000240064ff06000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000986dc9c19dee1be3ffffff000000000000000000004de4cf6daab95c476106eca715d48de4b13287ffdeaa000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2e592427a0aece92de3edee1f18e0157c0586156400000140008400000000000300000000000000000000000000000000000000000000000000000000c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c51020030400010680000000000000000000000000000000000000000000000000000000066ac44e80000000000000000000000000000000000000000000000000d416c4e0bb86b680000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000";

    // https://api.paraswap.io/swap?srcToken=0x6982508145454Ce325dDbE47a25d4ec3d2311933&destToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&amount=332741792369121567965184&srcDecimals=18&destDecimals=6&side=SELL&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes sellPepeUSDCPayLoad =
        hex"e3ead59e0000000000000000000000005f0000d4780a00d2dce0a00004000800cb0e50410000000000000000000000006982508145454ce325ddbe47a25d4ec3d2311933000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000001133cd0b54a5fd44fffffff00000000000000000000000000000000000000000000000000000000e8dacd1500000000000000000000000000000000000000000000000000000000eb34ee2ff66fe59ef6bf4009a3503cfd38110b24000000000000000000000000013717a30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002e06982508145454ce325ddbe47a25d4ec3d23119330000006000240000ff00000300000000000000000000000000000000000000000000000000000000a9059cbb000000000000000000000000a43fe16908251ee70ef74718545e4fe6c5ccec9f000000000000000000000000000000000000000001133cd0b54a5fd44fffffff5f0000d4780a00d2dce0a00004000800cb0e5041000000a000240064ff06000b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000001133cd0b54a5fd44fffffff000000000000000000004de4a43fe16908251ee70ef74718545e4fe6c5ccec9f000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2e592427a0aece92de3edee1f18e0157c0586156400000140008400000000000300000000000000000000000000000000000000000000000000000000c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000006a000f20005980200259b80c51020030400010680000000000000000000000000000000000000000000000000000000066ac44e500000000000000000000000000000000000000000000000010f184eda7200d630000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000";

    // https://api.paraswap.io/swap?srcToken=0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E&destToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&amount=20746887966806&srcDecimals=9&destDecimals=6&side=SELL&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=250&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes sellFlokiUSDCPayLoad;

    // https://api.paraswap.io/swap?srcToken=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&destToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&amount=965424915686225&srcDecimals=18&destDecimals=6&side=SELL&network=1&excludeDEXS=ParaSwapPool,ParaSwapLimitOrders&version=6.2&slippage=100&userAddress=0x1473cCdC135f1D365511028bf0e103B959cbceB5
    bytes sellWethUSDCPayLoad =
        hex"876a02f6000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000240000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000d65e0d884c9f27300000000000000000000000000000000000000000000000000000000b810b6f000000000000000000000000000000000000000000000000000000000b9ecae7190fbfb02b1c64338ac3105a319acf5d6000000000000000000000000013717a20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000c0800000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000000000000000000000064000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000000";

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
        dexAggregatorSetIssuer.approveToken(weth, paraSwapV6Address);
        dexAggregatorSetIssuer.approveToken(weth, address(flokiUniswapV2BuyTokens));

        dexAggregatorSetIssuer.approveToken(doge, paraSwapV6Address);
        dexAggregatorSetIssuer.approveToken(shib, paraSwapV6Address);
        dexAggregatorSetIssuer.approveToken(pepe, paraSwapV6Address);
        dexAggregatorSetIssuer.approveToken(floki, address(flokiUniswapV2BuyTokens));
        dexAggregatorSetIssuer.approveToken(weth, paraSwapV6Address);

        dexAggregatorSetIssuer.approveToken(doge, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(shib, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(pepe, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(floki, basicIssuanceModuleAddress);
        dexAggregatorSetIssuer.approveToken(weth, basicIssuanceModuleAddress);

        deal({token: usdcAddress, to: user, give: 10000e6});
        deal({token: wETHAddress, to: user, give: 10000e18});

        vm.makePersistent(user);
        vm.makePersistent(usdcAddress);
        vm.makePersistent(dogeCoinAddress);
        vm.makePersistent(shibAddress);
        vm.makePersistent(pepeAddress);
        vm.makePersistent(flokiAddress);
        vm.makePersistent(wETHAddress);
        vm.makePersistent(paraSwapV6Address);
        vm.makePersistent(memeIndexTokenAddress);
        vm.makePersistent(address(dexAggregatorSetIssuer));
        vm.makePersistent(address(flokiUniswapV2BuyTokens));
        vm.makePersistent(uniswapRouterAddress);
        vm.makePersistent(flokiUinswapV2pairAddress);
        vm.makePersistent(flokiTaxHandlerAddress);
        vm.makePersistent(flokiTreasuryAddress);
        vm.stopPrank();
    }

    function testIssueTokensWithUSDC() external {
        vm.rollFork(20382626);
        vm.startPrank(user);
        (flokiUSDCAmount, flokiUSDCPayLoad) = _computeFlokiTransferData(20746887966806, usdcAddress);
        uint256 totalQuote = dogeUSDCAmount + shibUSDCAmount + pepeUSDCAmount + flokiUSDCAmount + wethUSDCAmount;

        uint256 oldDogeBalance = doge.balanceOf(memeIndexTokenAddress);
        uint256 oldShibBalance = shib.balanceOf(memeIndexTokenAddress);
        uint256 oldPepeBalance = pepe.balanceOf(memeIndexTokenAddress);
        uint256 oldFlokiBalance = floki.balanceOf(memeIndexTokenAddress);
        uint256 oldWethiBalance = weth.balanceOf(memeIndexTokenAddress);

        usdc.approve(address(dexAggregatorSetIssuer), totalQuote);
        uint256 memeIndexQuantity = 1.5 ether;
        bytes[] memory payLoads = new bytes[](5);
        payLoads[0] = dogeUSDCPayLoad;
        payLoads[1] = shibUSDCPayLoad;
        payLoads[2] = pepeUSDCPayLoad;
        payLoads[3] = flokiUSDCPayLoad;
        payLoads[4] = wethUSDCPayLoad;
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

    function testIssueTokensWithWETH() external {
        vm.rollFork(20385003);
        vm.startPrank(user);

        (flokiWETHAmount, flokiWETHPayLoad) = _computeFlokiTransferData(20746887966806, wETHAddress);
        uint256 totalQuote = dogeWETHAmount + shibWETHAmount + pepeWETHAmount + flokiWETHAmount + wethWETHAmount;

        uint256 oldDogeBalance = doge.balanceOf(memeIndexTokenAddress);
        uint256 oldShibBalance = shib.balanceOf(memeIndexTokenAddress);
        uint256 oldPepeBalance = pepe.balanceOf(memeIndexTokenAddress);
        uint256 oldFlokiBalance = floki.balanceOf(memeIndexTokenAddress);
        uint256 oldWethiBalance = weth.balanceOf(memeIndexTokenAddress);

        weth.approve(address(dexAggregatorSetIssuer), totalQuote);
        uint256 memeIndexQuantity = 1.5 ether;
        bytes[] memory payLoads = new bytes[](5);
        payLoads[0] = dogeWETHPayLoad;
        payLoads[1] = shibWETHPayLoad;
        payLoads[2] = pepeWETHPayLoad;
        payLoads[3] = flokiWETHPayLoad;
        payLoads[4] = wethWETHPayLoad;
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
            weth,
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
        assertEq(weth.balanceOf(address(dexAggregatorSetIssuer)), 0);
        assertEq(memeIndexToken.balanceOf(user), memeIndexQuantity);
    }

    function _computeFlokiTransferData(
        uint256 amountOut,
        address quoteAsset
    ) internal view returns (uint256 amountIn, bytes memory payload) {
        address[] memory paths;
        if (quoteAsset == usdcAddress) {
            paths = new address[](3);
            paths[0] = usdcAddress;
            paths[1] = wETHAddress;
            paths[2] = flokiAddress;
        } else if (quoteAsset == wETHAddress) {
            paths = new address[](2);
            paths[0] = wETHAddress;
            paths[1] = flokiAddress;
        } else {
            revert("QuoteAsset not supported");
        }
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

    function testFlokiUniswapV2BuyTokensWithUSDC() external {
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

    function testFlokiUniswapV2BuyTokensWithWETH() external {
        vm.startPrank(user);
        vm.rollFork(20382626);
        address[] memory paths = new address[](2);
        paths[0] = wETHAddress;
        paths[1] = flokiAddress;
        uint256 amountOut = 20746887966806;
        uint256 tax = flokiTaxHandler.getTax(flokiUinswapV2pairAddress, user, amountOut);
        uint256 adjustedAmountOut = (amountOut * amountOut) / (amountOut - tax);
        uint[] memory amounts = uniswapRouter.getAmountsIn(adjustedAmountOut, paths);
        assertEq(floki.balanceOf(user), 0);
        weth.approve(address(flokiUniswapV2BuyTokens), amounts[0]);
        flokiUniswapV2BuyTokens.buyExactFlokiTokens(amountOut, flokiUinswapV2pairAddress, paths);
        assertEq(floki.balanceOf(user), amountOut);
    }

    function _issueMemeToken(uint256 memeIndexQuantity) internal {
        (flokiUSDCAmount, flokiUSDCPayLoad) = _computeFlokiTransferData(20746887966806, usdcAddress);
        uint256 totalQuote = dogeUSDCAmount + shibUSDCAmount + pepeUSDCAmount + flokiUSDCAmount + wethUSDCAmount;
        usdc.approve(address(dexAggregatorSetIssuer), totalQuote);
        bytes[] memory payLoads = new bytes[](5);
        payLoads[0] = dogeUSDCPayLoad;
        payLoads[1] = shibUSDCPayLoad;
        payLoads[2] = pepeUSDCPayLoad;
        payLoads[3] = flokiUSDCPayLoad;
        payLoads[4] = wethUSDCPayLoad;
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
    }

    function _issueMeme(uint256 memeIndexQuantity) internal {
        (address[] memory components, uint256[] memory componentQuantities) = issuanceModule
            .getRequiredComponentUnitsForIssue(memeIndexToken, memeIndexQuantity);
        for (uint i = 0; i < components.length; i++) {
            deal({token: components[i], to: user, give: componentQuantities[i]});
            IERC20(components[i]).approve(basicIssuanceModuleAddress, componentQuantities[i]);
        }
        issuanceModule.issue(memeIndexToken, memeIndexQuantity, user);
    }

    function testRedeemForUSDC() external {
        vm.rollFork(20387746);
        vm.startPrank(user);
        uint256 memeIndexQuantity = 1500 ether;
        _issueMeme(memeIndexQuantity);
        memeIndexToken.approve(address(dexAggregatorSetIssuer), memeIndexQuantity);
        uint256 flokiAmount = 20746887966805499;
        address[] memory paths = new address[](3);
        paths[0] = flokiAddress;
        paths[1] = wETHAddress;
        paths[2] = usdcAddress;
        sellFlokiUSDCPayLoad = abi.encodeWithSelector(
            flokiUniswapV2BuyTokens.sellFlokiToken.selector,
            flokiAmount,
            paths
        );
        bytes[] memory payLoads = new bytes[](5);
        payLoads[0] = sellDogeUSDCPayLoad;
        payLoads[1] = sellShibUSDCPayLoad;
        payLoads[2] = sellPepeUSDCPayLoad;
        payLoads[3] = sellFlokiUSDCPayLoad;
        payLoads[4] = sellWethUSDCPayLoad;
        address[] memory exchanges = new address[](5);
        exchanges[0] = paraSwapV6Address;
        exchanges[1] = paraSwapV6Address;
        exchanges[2] = paraSwapV6Address;
        exchanges[3] = address(flokiUniswapV2BuyTokens);
        exchanges[4] = paraSwapV6Address;
        dexAggregatorSetIssuer.redeemSetTokenAndExchangeTokens(
            memeIndexToken,
            memeIndexQuantity,
            issuanceModule,
            usdc,
            exchanges,
            payLoads
        );
    }

    function testSellFlokiToken() external {
        vm.startPrank(user);
        address[] memory paths = new address[](3);
        paths[0] = flokiAddress;
        paths[1] = wETHAddress;
        paths[2] = usdcAddress;
        uint256 amountIn = 20746887966805;
        uint256 beforeBalance = usdc.balanceOf(user);
        deal({token: flokiAddress, to: user, give: amountIn});
        floki.approve(address(flokiUniswapV2BuyTokens), amountIn);
        flokiUniswapV2BuyTokens.sellFlokiToken(amountIn, paths);
        uint256 afterBalance = usdc.balanceOf(user);
        assertGt(afterBalance, beforeBalance);
    }

    function testTransferTokensOnTokenExchang() external {
        vm.startPrank(deployer);
        uint256 amount = 10e6;
        deal({token: usdcAddress, to: address(dexAggregatorSetIssuer), give: amount});
        assertEq(usdc.balanceOf(address(dexAggregatorSetIssuer)), amount);
        dexAggregatorSetIssuer.transferTokens(usdc, user, amount);
        assertEq(usdc.balanceOf(address(dexAggregatorSetIssuer)), 0);
    }

    function testTransferTokensOnFlokiBuy() external {
        vm.startPrank(deployer);
        uint256 amount = 10e6;
        deal({token: usdcAddress, to: address(flokiUniswapV2BuyTokens), give: amount});
        assertEq(usdc.balanceOf(address(flokiUniswapV2BuyTokens)), amount);
        flokiUniswapV2BuyTokens.transferTokens(usdc, user, amount);
        assertEq(usdc.balanceOf(address(flokiUniswapV2BuyTokens)), 0);
    }
}
