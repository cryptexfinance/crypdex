// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/console.sol";

import {AuctionRebalanceModuleV1} from "contracts/modules/AuctionRebalanceModuleV1.sol";
import {BoundedStepwiseExponentialPriceAdapter} from "contracts/auction-pricing/BoundedStepwiseExponentialPriceAdapter.sol";
import {BoundedStepwiseLinearPriceAdapter} from "contracts/auction-pricing/BoundedStepwiseLinearPriceAdapter.sol";
import {BoundedStepwiseLogarithmicPriceAdapter} from "contracts/auction-pricing/BoundedStepwiseLogarithmicPriceAdapter.sol";
import {ConstantPriceAdapter} from "contracts/auction-pricing/ConstantPriceAdapter.sol";
import {StreamingFeeModule} from "contracts/modules/StreamingFeeModule.sol";
import {Controller} from "contracts/protocol/Controller.sol";
import { ISetToken } from "contracts/interfaces/ISetToken.sol";
import { IManagerIssuanceHook } from "contracts/interfaces/IManagerIssuanceHook.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {SystemFixture} from "./SystemFixture.sol";

contract AuctionFixture is SystemFixture {
    address bidder = address(0x71);

    AuctionRebalanceModuleV1 internal auctionRebalanceModuleV1;
    BoundedStepwiseExponentialPriceAdapter internal boundedStepwiseExponentialPriceAdapter;
    BoundedStepwiseLinearPriceAdapter internal boundedStepwiseLinearPriceAdapter;
    BoundedStepwiseLogarithmicPriceAdapter internal boundedStepwiseLogarithmicPriceAdapter;
    ConstantPriceAdapter internal constantPriceAdapter;

    string constant internal CONSTANT_PRICE_ADAPTER = "CONSTANT_PRICE_ADAPTER";
    string constant internal BOUNDED_STEPWISE_EXPONENTIAL_PRICE_ADAPTER = "BOUNDED_STEPWISE_EXPONENTIAL_PRICE_ADAPTER";
    string constant internal BOUNDED_STEPWISE_LINEAR_PRICE_ADAPTER = "BOUNDED_STEPWISE_LINEAR_PRICE_ADAPTER";
    string constant internal BOUNDED_STEPWISE_LOGARITHMIC_PRICE_ADAPTER = "BOUNDED_STEPWISE_LOGARITHMIC_PRICE_ADAPTER";

    uint256 internal wbtcPerWethDecimalFactor;
    uint256 internal defaultDaiPrice;
    uint256 internal defaultWbtcPrice;
    uint256 internal defaultWethPrice;
    bytes internal defaultDaiData;
    bytes internal defaultWbtcData;
    bytes internal defaultWethData;
    address[] internal defaultNewComponents;
    AuctionRebalanceModuleV1.AuctionExecutionParams[] internal defaultOldComponentsAuctionParams;
    AuctionRebalanceModuleV1.AuctionExecutionParams[] internal defaultNewComponentsAuctionParams;
    IERC20 internal defaultQuoteAsset;
    bool internal defaultShouldLockSetToken;
    uint256 internal defaultDuration;
    ISetToken internal setToken;
    ISetToken internal setTokenWithoutQuote;
    int256 internal defaultPositionMultiplier;

    uint256 constant internal ONE_DAY_IN_SECONDS = 24 * 60 * 60;

    function fundBidder(address erc20, uint256 amount) internal {
        vm.prank(owner);
        MockERC20(erc20).transfer(bidder, amount);
        vm.prank(bidder);
        MockERC20(erc20).approve(address(auctionRebalanceModuleV1), amount);
    }

    function placeBid(
        ISetToken _setToken,
        IERC20 component,
        IERC20 quoteAsset,
        uint256 componentAmount,
        uint256 quoteAssetLimit,
        bool isSellAuction
    ) internal {
        vm.prank(bidder);
        auctionRebalanceModuleV1.bid(
            _setToken,
            component,
            quoteAsset,
            componentAmount,
            quoteAssetLimit,
            isSellAuction
        );
    }

    function initDefaultRebalanceData() internal {
        wbtcPerWethDecimalFactor = uint256(toWETHUnits(1) / toWBTCUnits(1));
        defaultDaiPrice = 5 ether/ 10000;
        defaultWbtcPrice = (145 ether * wbtcPerWethDecimalFactor) / 10;
        defaultWethPrice = 1 ether;

        defaultDaiData = constantPriceAdapter.getEncodedData(defaultDaiPrice);
        defaultWbtcData = constantPriceAdapter.getEncodedData(defaultWbtcPrice);
        defaultWethData = constantPriceAdapter.getEncodedData(defaultWethPrice);

        defaultOldComponentsAuctionParams.push(AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toDAIUnits(9100)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultDaiData
        }));
        defaultOldComponentsAuctionParams.push(AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWBTCUnits(6)/int256(10)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultWbtcData
        }));
        defaultOldComponentsAuctionParams.push(AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWETHUnits(4)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultWethData
        }));


      defaultQuoteAsset = IERC20(address(weth));
      defaultShouldLockSetToken = false;
      defaultDuration = ONE_DAY_IN_SECONDS * 5;
      defaultPositionMultiplier = setToken.positionMultiplier();
    }

    function setUpAuctionContracts() internal {
        setUpSystem();
        vm.startPrank(deployer);
        auctionRebalanceModuleV1 = new AuctionRebalanceModuleV1(controller);
        boundedStepwiseExponentialPriceAdapter = new BoundedStepwiseExponentialPriceAdapter();
        boundedStepwiseLinearPriceAdapter = new BoundedStepwiseLinearPriceAdapter();
        boundedStepwiseLogarithmicPriceAdapter = new BoundedStepwiseLogarithmicPriceAdapter();
        constantPriceAdapter = new ConstantPriceAdapter();
        Controller(address(controller)).addModule(address(auctionRebalanceModuleV1));
        setupIntegrationRegistry();
        vm.stopPrank();
    }

    function setupIntegrationRegistry() internal {
        address[] memory _modules = new address[](4);
        string[] memory _names = new string[](4);
        address[] memory _adapters = new address[](4);
        _modules[0] = address(auctionRebalanceModuleV1);
        _modules[1] = address(auctionRebalanceModuleV1);
        _modules[2] = address(auctionRebalanceModuleV1);
        _modules[3] = address(auctionRebalanceModuleV1);
        _names[0] = CONSTANT_PRICE_ADAPTER;
        _names[1] = BOUNDED_STEPWISE_EXPONENTIAL_PRICE_ADAPTER;
        _names[2] = BOUNDED_STEPWISE_LINEAR_PRICE_ADAPTER;
        _names[3] = BOUNDED_STEPWISE_LOGARITHMIC_PRICE_ADAPTER;
        _adapters[0] = address(constantPriceAdapter);
        _adapters[1] = address(boundedStepwiseExponentialPriceAdapter);
        _adapters[2] = address(boundedStepwiseLinearPriceAdapter);
        _adapters[3] = address(boundedStepwiseLogarithmicPriceAdapter);
        integrationRegistry.batchAddIntegration(
            _modules,
            _names,
            _adapters
        );
    }

    function setupIndexToken() internal {
        StreamingFeeModule.FeeState memory feeSettings = StreamingFeeModule.FeeState({
          feeRecipient: owner,
          maxStreamingFeePercentage: 1 ether/10,
          streamingFeePercentage: 1 ether/ 100,
          lastStreamingFeeTimestamp: 0
        });
        address[] memory _components = new address[](3);
        int256[] memory _units = new int256[](3);
        address[] memory _modules = new address[](3);
        _components[0] = address(dai);
        _components[1] = address(wbtc);
        _components[2] = address(weth);
        _units[0] = toDAIUnits(10000);
        _units[1] = toWBTCUnits(5)/10;
        _units[2] = toWETHUnits(5);
        _modules[0] = address(basicIssuanceModule);
        _modules[1] = address(streamingFeeModule);
        _modules[2] = address(auctionRebalanceModuleV1);
        vm.startPrank(owner);
        setToken = createSetToken(_components, _units, _modules);
        streamingFeeModule.initialize(setToken, feeSettings);
        basicIssuanceModule.initialize(setToken, IManagerIssuanceHook(address(0)));
        setUpBalance(owner);
        vm.stopPrank();
        approveAndIssueSetToken(setToken, 1 ether, owner);
    }

    function initAuctionModule(ISetToken _setToken) internal {
        vm.startPrank(owner);
        auctionRebalanceModuleV1.initialize(_setToken);
        address[] memory bidders = new address[](1);
        bool[] memory statuses = new bool[](1);
        bidders[0] = bidder;
        statuses[0] = true;
        auctionRebalanceModuleV1.setBidderStatus(_setToken, bidders, statuses);
        vm.stopPrank();
    }

    function setupIndexTokenWithoutQuoteAsset() internal {
        StreamingFeeModule.FeeState memory feeSettings = StreamingFeeModule.FeeState({
          feeRecipient: owner,
          maxStreamingFeePercentage: 1 ether/10,
          streamingFeePercentage: 1 ether/ 100,
          lastStreamingFeeTimestamp: 0
        });
        address[] memory _components = new address[](2);
        int256[] memory _units = new int256[](2);
        address[] memory _modules = new address[](3);
        _components[0] = address(dai);
        _components[1] = address(wbtc);
        _units[0] = toDAIUnits(10000);
        _units[1] = toWBTCUnits(5)/10;
        _modules[0] = address(basicIssuanceModule);
        _modules[1] = address(streamingFeeModule);
        _modules[2] = address(auctionRebalanceModuleV1);
        vm.startPrank(owner);
        setTokenWithoutQuote = createSetToken(_components, _units, _modules);
        streamingFeeModule.initialize(setTokenWithoutQuote, feeSettings);
        basicIssuanceModule.initialize(setTokenWithoutQuote, IManagerIssuanceHook(address(0)));
        setUpBalance(owner);
        vm.stopPrank();
        approveAndIssueSetToken(setTokenWithoutQuote, 1 ether, owner);
        initAuctionModule(setTokenWithoutQuote);
    }

    function startRebalance(
        ISetToken _setToken,
        IERC20 _quoteAsset,
        address[] memory _newComponents,
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory _newComponentsAuctionParams,
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory _oldComponentsAuctionParams,
        bool _shouldLockSetToken,
        uint256 _rebalanceDuration,
        uint256 _initialPositionMultiplier
    ) internal {
        vm.prank(owner);
        auctionRebalanceModuleV1.startRebalance(
          _setToken,
          _quoteAsset,
          _newComponents,
          _newComponentsAuctionParams,
          _oldComponentsAuctionParams,
          _shouldLockSetToken,
          _rebalanceDuration,
          _initialPositionMultiplier
        );
    }
}
