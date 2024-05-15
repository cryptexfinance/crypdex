// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/console.sol";

import {AddressArrayUtils} from "contracts/lib/AddressArrayUtils.sol";
import {AuctionRebalanceModuleV1} from "contracts/modules/AuctionRebalanceModuleV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PreciseUnitMath} from "contracts/lib/PreciseUnitMath.sol";
import {Controller} from "contracts/protocol/Controller.sol";
import {IAuctionPriceAdapterV1} from "contracts/interfaces/IAuctionPriceAdapterV1.sol";
import {ISetToken} from "contracts/interfaces/ISetToken.sol";

import {AuctionFixture} from "../fixtures/AuctionFixture.sol";


contract TestAuctionRebalance is AuctionFixture {
    using AddressArrayUtils for address[];

    function setUp() external {
        setUpAuctionContracts();
        setupIndexToken();
        initDefaultRebalanceData();
        initAuctionModule(setToken);
    }

    function testSetsAuctionParamsCorrectly() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        address[] memory aggregateComponents = setToken.getComponents();
        for(uint256 i=0; i < defaultOldComponentsAuctionParams.length; i++) {
            (
                uint256 targetUnit,
                string memory priceAdapterName,
                bytes memory priceAdapterConfigData
            ) = auctionRebalanceModuleV1.executionInfo(setToken, IERC20(aggregateComponents[i]));
            assertEq(targetUnit, defaultOldComponentsAuctionParams[i].targetUnit);
            assertEq(priceAdapterName, defaultOldComponentsAuctionParams[i].priceAdapterName);
            assertEq(priceAdapterConfigData, defaultOldComponentsAuctionParams[i].priceAdapterConfigData);
        }
    }

    function testAuctionRebalanceInfo() external {
        uint256 executionTimeStamp = block.timestamp + 1000;
        vm.warp(executionTimeStamp);
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        (
            IERC20 quoteAsset,
            uint256 rebalanceStartTime,
            uint256 rebalanceDuration,
            uint256 positionMultiplier,
            uint256 raiseTargetPercentage
        ) = auctionRebalanceModuleV1.rebalanceInfo(setToken);

        assertEq(address(quoteAsset), address(defaultQuoteAsset));
        assertEq(rebalanceStartTime, executionTimeStamp);
        assertEq(rebalanceDuration, defaultDuration);
        assertEq(positionMultiplier, uint256(defaultPositionMultiplier));
        assertEq(raiseTargetPercentage, 0);
    }

    function testEmitsCorrectEvent() external {
        address[] memory aggregateComponents = setToken.getComponents();
        vm.expectEmit(true, true, true, true, address(auctionRebalanceModuleV1));
        emit AuctionRebalanceModuleV1.RebalanceStarted(
            setToken,
            defaultQuoteAsset,
            defaultShouldLockSetToken,
            defaultDuration,
            uint256(defaultPositionMultiplier),
            aggregateComponents,
            defaultOldComponentsAuctionParams
        );
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
    }

    function testIsRebalanceDurationElapsed() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        vm.warp(defaultDuration + 1);
        assertTrue(auctionRebalanceModuleV1.isRebalanceDurationElapsed(setToken));
    }

    function testGetRebalanceComponents() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        address[] memory expectedComponents = new address[](3);
        expectedComponents[0] = address(dai);
        expectedComponents[1] = address(wbtc);
        expectedComponents[2] = address(weth);
        address[] memory rebalanceComponents = auctionRebalanceModuleV1.getRebalanceComponents(setToken);
        assertEq(rebalanceComponents, expectedComponents);
    }

    function testGetAuctionSizeAndDirectionSellAuction() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        (bool isSellAuction, uint256 componentQuantity) = auctionRebalanceModuleV1.getAuctionSizeAndDirection(
            setToken, IERC20(address(dai))
        );
        uint256 totalSupply = setToken.totalSupply();
        uint256 expectedDaiSize = PreciseUnitMath.preciseMul(uint256(toWETHUnits(900)), totalSupply);
        assertEq(componentQuantity, expectedDaiSize);
        assertTrue(isSellAuction);
    }

    function testGetAuctionSizeAndDirectionBuyAuction() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        (bool isSellAuction, uint256 componentQuantity) = auctionRebalanceModuleV1.getAuctionSizeAndDirection(
            setToken, IERC20(address(wbtc))
        );
        uint256 totalSupply = setToken.totalSupply();
        uint256 expectedWbtcSize = PreciseUnitMath.preciseMul(uint256(toWBTCUnits(1)/10), totalSupply);
        assertEq(componentQuantity, expectedWbtcSize);
        assertFalse(isSellAuction);
    }

    function testSellAuctionUnchangedWhenProtocolFee() external {
        uint256 feePercentage = 5 ether/1000;
        vm.prank(deployer);
        Controller(address(controller)).addFee(address(auctionRebalanceModuleV1), 0, feePercentage);
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        (bool isSellAuction, uint256 componentQuantity) = auctionRebalanceModuleV1.getAuctionSizeAndDirection(
            setToken, IERC20(address(dai))
        );
        uint256 totalSupply = setToken.totalSupply();
        uint256 expectedDaiSize = PreciseUnitMath.preciseMul(uint256(toWETHUnits(900)), totalSupply);
        assertEq(componentQuantity, expectedDaiSize);
        assertTrue(isSellAuction);
    }

    function testBuyAuctionChangedWhenProtocolFee() external {
        uint256 feePercentage = 5 ether/1000;
        vm.prank(deployer);
        Controller(address(controller)).addFee(address(auctionRebalanceModuleV1), 0, feePercentage);
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        (bool isSellAuction, uint256 componentQuantity) = auctionRebalanceModuleV1.getAuctionSizeAndDirection(
            setToken, IERC20(address(wbtc))
        );
        uint256 totalSupply = setToken.totalSupply();
        uint256 expectedWbtcSize = PreciseUnitMath.preciseDiv(
            PreciseUnitMath.preciseMul(uint256(toWBTCUnits(1)/10), totalSupply),
            PRECISE_UNIT - feePercentage
        );
        assertEq(componentQuantity, expectedWbtcSize);
        assertFalse(isSellAuction);
    }

    function testRebalanceDurationNotElapsed() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        assertFalse(auctionRebalanceModuleV1.isRebalanceDurationElapsed(setToken));
    }

    function testGetQuoteAssetBalance() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        assertEq(auctionRebalanceModuleV1.getQuoteAssetBalance(setToken), uint256(toWETHUnits(5)));
    }

    function testGetBidPreview() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        IERC20 subjectComponent = IERC20(address(dai));
        IERC20 subjectQuoteAsset = IERC20(address(weth));
        uint256 subjectComponentQuantity = uint256(toDAIUnits(900));
        uint256 subjectQuoteAssetLimit = uint256(toWETHUnits(45))/100;
        bool subjectIsSellAuction = true;
         AuctionRebalanceModuleV1.BidInfo memory bidInfo = auctionRebalanceModuleV1.getBidPreview(
            setToken,
            subjectComponent,
            subjectQuoteAsset,
            subjectComponentQuantity,
            subjectQuoteAssetLimit,
            subjectIsSellAuction
        );
        assertEq(address(bidInfo.setToken), address(setToken));
        assertEq(address(bidInfo.sendToken), address(subjectComponent));
        assertEq(address(bidInfo.receiveToken), address(subjectQuoteAsset));
        assertEq(address(bidInfo.priceAdapter), address(constantPriceAdapter));
        assertEq(bidInfo.priceAdapterConfigData, defaultDaiData);
        assertEq(bidInfo.isSellAuction, true);
        assertEq(bidInfo.auctionQuantity, subjectComponentQuantity);
        assertEq(bidInfo.componentPrice, defaultDaiPrice);
        assertEq(bidInfo.quantitySentBySet, subjectComponentQuantity);
        assertEq(bidInfo.quantityReceivedBySet, subjectQuoteAssetLimit);
        assertEq(bidInfo.preBidTokenSentBalance, 10000 ether);
        assertEq(bidInfo.preBidTokenReceivedBalance, 5 ether);
        assertEq(bidInfo.setTotalSupply, 1 ether);
    }

    function testSetRaiseTargetPercentage() external {
        uint256 raiseTargetPercentage = 1 ether/1000;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(auctionRebalanceModuleV1));
        emit AuctionRebalanceModuleV1.RaiseTargetPercentageUpdated(setToken, raiseTargetPercentage);
        auctionRebalanceModuleV1.setRaiseTargetPercentage(setToken, raiseTargetPercentage);
        (,,,,uint256 newRaiseTargetPercentage) = auctionRebalanceModuleV1.rebalanceInfo(setToken);
        assertEq(newRaiseTargetPercentage, raiseTargetPercentage);
    }

    function testRaiseAssetTargets() external {
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory oldComponentsAuctionParams = new AuctionRebalanceModuleV1.AuctionExecutionParams[](3);
        oldComponentsAuctionParams[0] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toDAIUnits(9100)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultDaiData
        });
        oldComponentsAuctionParams[1] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWBTCUnits(54)/int256(100)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultWbtcData
        });
        oldComponentsAuctionParams[2] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWETHUnits(4)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultWethData
        });
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          oldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        uint256 raiseTargetPercentage = 25 ether/10000;
        vm.prank(owner);
        auctionRebalanceModuleV1.setRaiseTargetPercentage(setToken, raiseTargetPercentage);
        fundBidder(address(weth), uint256(toWETHUnits(45))/100);
        fundBidder(address(wbtc), uint256(toWBTCUnits(4))/100);
        placeBid(setToken, dai, IERC20(address(weth)), uint256(toDAIUnits(900)), uint256(toWETHUnits(45))/100, true);
        placeBid(setToken, wbtc, IERC20(address(weth)), uint256(toWBTCUnits(4))/100, uint256(toWETHUnits(58))/100, false);

        (,,,uint256 prePositionMultiplier,) = auctionRebalanceModuleV1.rebalanceInfo(setToken);
        vm.expectRevert("Target already met");
        auctionRebalanceModuleV1.getAuctionSizeAndDirection(setToken, IERC20(address(dai)));
        vm.expectRevert("Target already met");
        auctionRebalanceModuleV1.getAuctionSizeAndDirection(setToken, IERC20(address(wbtc)));
        uint256 expectedPositionMultiplier = PreciseUnitMath.preciseDiv(prePositionMultiplier, PRECISE_UNIT + raiseTargetPercentage);

        vm.prank(bidder);
        vm.expectEmit(true, true, true, true, address(auctionRebalanceModuleV1));
        emit AuctionRebalanceModuleV1.AssetTargetsRaised(setToken, expectedPositionMultiplier);
        auctionRebalanceModuleV1.raiseAssetTargets(setToken);

        (,,,uint256 positionMultiplier,) = auctionRebalanceModuleV1.rebalanceInfo(setToken);
        assertEq(positionMultiplier, expectedPositionMultiplier);
        (bool daiDirection, uint256 daiSize) = auctionRebalanceModuleV1.getAuctionSizeAndDirection(setToken, IERC20(address(dai)));
        (bool wbtcDirection, uint256 wbtcSize) = auctionRebalanceModuleV1.getAuctionSizeAndDirection(setToken, IERC20(address(wbtc)));
        assertGt(daiSize, 225 ether/100);
        assertFalse(daiDirection);
        assertGt(wbtcSize, uint256(toWBTCUnits(1))/10000);
        assertFalse(wbtcDirection);
    }

    function testCannotRaiseAssetTargets() external {
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory oldComponentsAuctionParams = new AuctionRebalanceModuleV1.AuctionExecutionParams[](3);
        oldComponentsAuctionParams[0] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toDAIUnits(9100)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultDaiData
        });
        oldComponentsAuctionParams[1] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWBTCUnits(54)/int256(100)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultWbtcData
        });
        oldComponentsAuctionParams[2] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWETHUnits(4)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultWethData
        });
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          oldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        vm.prank(owner);
        auctionRebalanceModuleV1.setRaiseTargetPercentage(setToken, 25 ether/1000);
        fundBidder(address(weth), 45 ether/100);
        placeBid(setToken, dai, IERC20(address(weth)), uint256(toDAIUnits(900)), uint256(toWETHUnits(45) / 100), true);
        assertFalse(auctionRebalanceModuleV1.canRaiseAssetTargets(setToken));
    }

    function testAllTargetsNotMet() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          true,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        fundBidder(address(weth), uint256(toWETHUnits(45))/100);
        placeBid(setToken, dai, IERC20(address(weth)), uint256(toDAIUnits(900)), uint256(toWETHUnits(45))/100, true);
        assertFalse(auctionRebalanceModuleV1.allTargetsMet(setToken));
    }

    function testAllTargetsMet() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          true,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        fundBidder(address(weth), uint256(toWETHUnits(45))/100);
        fundBidder(address(wbtc), uint256(toWBTCUnits(1))/10);
        placeBid(setToken, dai, IERC20(address(weth)), uint256(toDAIUnits(900)), uint256(toWETHUnits(45))/100, true);
        placeBid(setToken, wbtc, IERC20(address(weth)), uint256(toWBTCUnits(1))/10, uint256(toWETHUnits(145))/100, false);
        assertTrue(auctionRebalanceModuleV1.allTargetsMet(setToken));
    }

    function testIsQuoteAssetExcessOrAtTarget() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          true,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        assertTrue(auctionRebalanceModuleV1.isQuoteAssetExcessOrAtTarget(setToken));
    }

    function testIsQuoteAssetExcessOrAtTargetWhenQuoteAtTarget() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          true,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        fundBidder(address(weth), uint256(toWETHUnits(45))/100);
        fundBidder(address(wbtc), uint256(toWBTCUnits(1))/10);
        placeBid(setToken, dai, IERC20(address(weth)), uint256(toDAIUnits(900)), uint256(toWETHUnits(45))/100, true);
        placeBid(setToken, wbtc, IERC20(address(weth)), uint256(toWBTCUnits(1))/10, uint256(toWETHUnits(145))/100, false);
        assertTrue(auctionRebalanceModuleV1.isQuoteAssetExcessOrAtTarget(setToken));
    }

    function testIsQuoteAssetExcessOrAtTargetWhenQuoteBelowTarget() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          true,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        fundBidder(address(wbtc), uint256(toWBTCUnits(1))/10);
        placeBid(setToken, wbtc, IERC20(address(weth)), uint256(toWBTCUnits(1))/10, uint256(toWETHUnits(145))/100, false);
        assertFalse(auctionRebalanceModuleV1.isQuoteAssetExcessOrAtTarget(setToken));
    }

    function testIsAllowedBidder() external {
        address newBidder = address(0x72);
        address[] memory bidders = new address[](1);
        bool[] memory bidderStatuses = new bool[](1);
        bidders[0] = newBidder;
        bidderStatuses[0] = true;
        vm.prank(owner);
        auctionRebalanceModuleV1.setBidderStatus(setToken, bidders, bidderStatuses);
        assertTrue(auctionRebalanceModuleV1.isAllowedBidder(setToken, newBidder));
    }

    function testNotAllowedBidder() external {
        address newBidder = address(0x72);
        address[] memory bidders = new address[](1);
        bool[] memory bidderStatuses = new bool[](1);
        bidders[0] = newBidder;
        bidderStatuses[0] = false;
        vm.prank(owner);
        auctionRebalanceModuleV1.setBidderStatus(setToken, bidders, bidderStatuses);
        assertFalse(auctionRebalanceModuleV1.isAllowedBidder(setToken, newBidder));
    }

    function testGetAllowedBidders() external {
        address[] memory bidders = new address[](1);
        bidders[0] = bidder;
        assertEq(auctionRebalanceModuleV1.getAllowedBidders(setToken), bidders);
    }

    function testSetBidderStatus() external {
        address bidder2 = address(0x72);
        address bidder3 = address(0x73);
        address[] memory bidders = new address[](3);
        bool[] memory bidderStatuses = new bool[](3);
        bidders[0] = bidder;
        bidders[1] = bidder2;
        bidders[2] = bidder3;
        bidderStatuses[0] = true;
        bidderStatuses[1] = true;
        bidderStatuses[2] = true;
        vm.prank(owner);
        auctionRebalanceModuleV1.setBidderStatus(setToken, bidders, bidderStatuses);

        assertTrue(auctionRebalanceModuleV1.isAllowedBidder(setToken, bidder));
        assertTrue(auctionRebalanceModuleV1.isAllowedBidder(setToken, bidder2));
        assertTrue(auctionRebalanceModuleV1.isAllowedBidder(setToken, bidder3));
    }

    function testSetBidderStatusEvent() external {
        address newBidder = address(0x72);
        address[] memory bidders = new address[](1);
        bool[] memory bidderStatuses = new bool[](1);
        bidders[0] = newBidder;
        bidderStatuses[0] = true;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(auctionRebalanceModuleV1));
        emit AuctionRebalanceModuleV1.BidderStatusUpdated(
            setToken,
            newBidder,
            true
        );
        auctionRebalanceModuleV1.setBidderStatus(setToken, bidders, bidderStatuses);
    }

    function testSetAnyoneBid() external {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(auctionRebalanceModuleV1));
        emit AuctionRebalanceModuleV1.AnyoneBidUpdated(setToken, true);
        auctionRebalanceModuleV1.setAnyoneBid(setToken, true);
        assertTrue(auctionRebalanceModuleV1.permissionInfo(setToken));
    }

    function testNewComponentAdded() external {
        uint256 usdcPerWethDecimalFactor = uint256(toWETHUnits(1) / toUSDCUnits(1));
        uint256 usdcPerWethPrice = (5 ether * usdcPerWethDecimalFactor) / 10000;
        bytes memory usdcPerWethBytes = constantPriceAdapter.getEncodedData(usdcPerWethPrice);
        AuctionRebalanceModuleV1.AuctionExecutionParams memory indexUsdcAuctionExecutionParams = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toUSDCUnits(100)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: usdcPerWethBytes
        });
        address[] memory newComponents = new address[](1);
        newComponents[0] = address(usdc);
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory newComponentsAuctionParams = new AuctionRebalanceModuleV1.AuctionExecutionParams[](1);
        newComponentsAuctionParams[0] = indexUsdcAuctionExecutionParams;
        startRebalance(
          setToken,
          defaultQuoteAsset,
          newComponents,
          newComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        fundBidder(address(usdc), uint256(toUSDCUnits(100)));

        address[] memory _oldComponents = setToken.getComponents();
        assertFalse(_oldComponents.contains(address(usdc)));
        placeBid(setToken, usdc, IERC20(address(weth)), uint256(toUSDCUnits(100)), uint256(toWETHUnits(5) / 100), false);

        address[] memory _newComponents = setToken.getComponents();
        assertTrue(_newComponents.contains(address(usdc)));
    }

    function testUnlockEarly() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          true,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        fundBidder(address(weth), uint256(toWETHUnits(45))/100);
        fundBidder(address(wbtc), uint256(toWBTCUnits(1))/10);


        assertFalse(auctionRebalanceModuleV1.canUnlockEarly(setToken));
        placeBid(setToken, dai, IERC20(address(weth)), uint256(toDAIUnits(900)), uint256(toWETHUnits(45))/100, true);
        placeBid(setToken, wbtc, IERC20(address(weth)), uint256(toWBTCUnits(1))/10, uint256(toWETHUnits(145))/100, false);
        assertTrue(auctionRebalanceModuleV1.canUnlockEarly(setToken));

        assertTrue(setToken.isLocked());
        vm.expectEmit(true, true, true, true, address(auctionRebalanceModuleV1));
        emit AuctionRebalanceModuleV1.LockedRebalanceEndedEarly(setToken);
        auctionRebalanceModuleV1.unlock(setToken);
        assertFalse(setToken.isLocked());
    }

    function testUnlockWhenDurationElapsed() external {
         startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          true,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        vm.prank(owner);
        auctionRebalanceModuleV1.setRaiseTargetPercentage(setToken, 1 ether/1000);

        (,,,,uint256 raiseTargetPercentageBefore) = auctionRebalanceModuleV1.rebalanceInfo(setToken);
        assertTrue(raiseTargetPercentageBefore > 0);
        assertTrue(setToken.isLocked());
        vm.warp(defaultDuration + 1);
        auctionRebalanceModuleV1.unlock(setToken);
        assertFalse(setToken.isLocked());
        (,,,,uint256 raiseTargetPercentageAfter) = auctionRebalanceModuleV1.rebalanceInfo(setToken);
        assertEq(raiseTargetPercentageAfter, 0);
    }

    function testProtocolFeeCharged() external {
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          defaultOldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        uint256 componentAmount = uint256(toWBTCUnits(1))/10;
        uint256 quoteAssetLimit = uint256(toWETHUnits(145))/100;
        uint256 feePercentage = 5 ether/1000;
        fundBidder(address(wbtc), quoteAssetLimit);
        vm.prank(deployer);
        Controller(address(controller)).addFee(
          address(auctionRebalanceModuleV1),
          0, // Fee type on bid function denoted as 0
          feePercentage // Set fee to 5 bps
        );
        uint256 preBidderWbtc = wbtc.balanceOf(bidder);
        uint256 preBidderWeth = weth.balanceOf(bidder);
        uint256 preSetTokenWbtc = wbtc.balanceOf(address(setToken));
        uint256 preSetTokenWeth = weth.balanceOf(address(setToken));
        placeBid(setToken, wbtc, IERC20(address(weth)), componentAmount, quoteAssetLimit, false);

        uint256 protocolFee = (componentAmount * feePercentage) / 1 ether;

        uint256 postBidderWbtc = wbtc.balanceOf(bidder);
        uint256 postBidderWeth = weth.balanceOf(bidder);
        uint256 postSetTokenWbtc = wbtc.balanceOf(address(setToken));
        uint256 postSetTokenWeth = weth.balanceOf(address(setToken));
        assertEq(postBidderWbtc, preBidderWbtc - componentAmount);
        assertEq(postBidderWeth, preBidderWeth + quoteAssetLimit);
        assertEq(postSetTokenWbtc, preSetTokenWbtc + componentAmount - protocolFee);
        assertEq(postSetTokenWeth, preSetTokenWeth - quoteAssetLimit);
    }

    function testBidWithBoundedStepwiseLinearPriceAdapter() external {
        bytes memory daiLinearCurveParams = boundedStepwiseLinearPriceAdapter.getEncodedData(
            55 ether/100000,
            1 ether/100000,
            1 hours,
            true,
            55 ether/100000,
            49 ether/100000
          );
        uint256 wbtcPerWethDecimalFactor = 1 ether/uint256(toWBTCUnits(1));
        bytes memory wbtcLinearCurveParams = boundedStepwiseLinearPriceAdapter.getEncodedData(
            14 ether * wbtcPerWethDecimalFactor,
            (1 ether/10) * wbtcPerWethDecimalFactor,
            1 hours,
            false,
            15 ether * wbtcPerWethDecimalFactor,
            14 ether * wbtcPerWethDecimalFactor
        );
        bytes memory wethLinearCurveParams = boundedStepwiseLinearPriceAdapter.getEncodedData(
            1 ether,
            0,
            1 hours,
            false,
            1 ether,
            1 ether
        );
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory oldComponentsAuctionParams = new AuctionRebalanceModuleV1.AuctionExecutionParams[](3);
        oldComponentsAuctionParams[0] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toDAIUnits(9100)),
          priceAdapterName: BOUNDED_STEPWISE_LINEAR_PRICE_ADAPTER,
          priceAdapterConfigData: daiLinearCurveParams
        });
        oldComponentsAuctionParams[1] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWBTCUnits(6)/int256(10)),
          priceAdapterName: BOUNDED_STEPWISE_LINEAR_PRICE_ADAPTER,
          priceAdapterConfigData: wbtcLinearCurveParams
        });
        oldComponentsAuctionParams[2] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWETHUnits(4)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: wethLinearCurveParams
        });
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          oldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        uint256 componentAmount = uint256(toDAIUnits(900));
        uint256 quoteAssetLimit = uint256(toWETHUnits(45))/100;
        fundBidder(address(weth), quoteAssetLimit);
        uint256 preBidderDai = dai.balanceOf(bidder);
        uint256 preBidderWeth = weth.balanceOf(bidder);
        uint256 preSetTokenDai = dai.balanceOf(address(setToken));
        uint256 preSetTokenWeth = weth.balanceOf(address(setToken));

        vm.warp(block.timestamp + 5 hours);
        placeBid(setToken, dai, IERC20(address(weth)), componentAmount, quoteAssetLimit, true);

        uint256 postBidderDai = dai.balanceOf(bidder);
        uint256 postBidderWeth = weth.balanceOf(bidder);
        uint256 postSetTokenDai = dai.balanceOf(address(setToken));
        uint256 postSetTokenWeth = weth.balanceOf(address(setToken));

        assertEq(postBidderDai, preBidderDai + componentAmount);
        assertEq(postBidderWeth, preBidderWeth - quoteAssetLimit);
        assertEq(postSetTokenDai, preSetTokenDai - componentAmount);
        assertEq(postSetTokenWeth, preSetTokenWeth + quoteAssetLimit);
    }

    function testBidWithBoundedStepwiseExponentialPriceAdapter() external {
        bytes memory daiExponentialCurveParams = boundedStepwiseExponentialPriceAdapter.getEncodedData(
            5 ether/10000,
            1 ether,
            1 ether/100000,
            1 hours,
            true,
            55 ether/100000,
            49 ether/100000
          );
        uint256 wbtcPerWethDecimalFactor = 1 ether/uint256(toWBTCUnits(1));
        bytes memory wbtcExponentialCurveParams = boundedStepwiseExponentialPriceAdapter.getEncodedData(
            14.5 ether * wbtcPerWethDecimalFactor,
            1 ether,
            (1 ether/10) * wbtcPerWethDecimalFactor,
            1 hours,
            false,
            15 ether * wbtcPerWethDecimalFactor,
            14 ether * wbtcPerWethDecimalFactor
        );
        bytes memory wethExponentialCurveParams = boundedStepwiseExponentialPriceAdapter.getEncodedData(
            1 ether,
            1 ether,
            1 ether/10,
            1 hours,
            false,
            1 ether,
            1 ether
        );
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory oldComponentsAuctionParams = new AuctionRebalanceModuleV1.AuctionExecutionParams[](3);
        oldComponentsAuctionParams[0] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toDAIUnits(9100)),
          priceAdapterName: BOUNDED_STEPWISE_EXPONENTIAL_PRICE_ADAPTER,
          priceAdapterConfigData: daiExponentialCurveParams
        });
        oldComponentsAuctionParams[1] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWBTCUnits(6)/int256(10)),
          priceAdapterName: BOUNDED_STEPWISE_EXPONENTIAL_PRICE_ADAPTER,
          priceAdapterConfigData: wbtcExponentialCurveParams
        });
        oldComponentsAuctionParams[2] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWETHUnits(4)),
          priceAdapterName: BOUNDED_STEPWISE_EXPONENTIAL_PRICE_ADAPTER,
          priceAdapterConfigData: wethExponentialCurveParams
        });
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          oldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        uint256 componentAmount = uint256(toDAIUnits(900));
        uint256 quoteAssetLimit = uint256(toWETHUnits(45))/100;
        fundBidder(address(weth), quoteAssetLimit);
        uint256 preBidderDai = dai.balanceOf(bidder);
        uint256 preBidderWeth = weth.balanceOf(bidder);
        uint256 preSetTokenDai = dai.balanceOf(address(setToken));
        uint256 preSetTokenWeth = weth.balanceOf(address(setToken));

        placeBid(setToken, dai, IERC20(address(weth)), componentAmount, quoteAssetLimit, true);

        uint256 postBidderDai = dai.balanceOf(bidder);
        uint256 postBidderWeth = weth.balanceOf(bidder);
        uint256 postSetTokenDai = dai.balanceOf(address(setToken));
        uint256 postSetTokenWeth = weth.balanceOf(address(setToken));

        assertEq(postBidderDai, preBidderDai + componentAmount);
        assertEq(postBidderWeth, preBidderWeth - quoteAssetLimit);
        assertEq(postSetTokenDai, preSetTokenDai - componentAmount);
        assertEq(postSetTokenWeth, preSetTokenWeth + quoteAssetLimit);
    }

    function testBidWithBoundedStepwiseLogarithmicPriceAdapter() external {
        bytes memory daiLogarithmicCurveParams = boundedStepwiseLogarithmicPriceAdapter.getEncodedData(
            5 ether/10000,
            1 ether,
            1 ether/100000,
            1 hours,
            true,
            55 ether/100000,
            49 ether/100000
          );
        uint256 wbtcPerWethDecimalFactor = 1 ether/uint256(toWBTCUnits(1));
        bytes memory wbtcLogarithmicCurveParams = boundedStepwiseLogarithmicPriceAdapter.getEncodedData(
            14.5 ether * wbtcPerWethDecimalFactor,
            1 ether,
            (1 ether/10) * wbtcPerWethDecimalFactor,
            1 hours,
            false,
            15 ether * wbtcPerWethDecimalFactor,
            14 ether * wbtcPerWethDecimalFactor
        );
        bytes memory wethLogarithmicCurveParams = boundedStepwiseLogarithmicPriceAdapter.getEncodedData(
            1 ether,
            1 ether,
            1 ether/10,
            1 hours,
            false,
            1 ether,
            1 ether
        );
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory oldComponentsAuctionParams = new AuctionRebalanceModuleV1.AuctionExecutionParams[](3);
        oldComponentsAuctionParams[0] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toDAIUnits(9100)),
          priceAdapterName: BOUNDED_STEPWISE_LOGARITHMIC_PRICE_ADAPTER,
          priceAdapterConfigData: daiLogarithmicCurveParams
        });
        oldComponentsAuctionParams[1] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWBTCUnits(6)/int256(10)),
          priceAdapterName: BOUNDED_STEPWISE_LOGARITHMIC_PRICE_ADAPTER,
          priceAdapterConfigData: wbtcLogarithmicCurveParams
        });
        oldComponentsAuctionParams[2] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWETHUnits(4)),
          priceAdapterName: BOUNDED_STEPWISE_LOGARITHMIC_PRICE_ADAPTER,
          priceAdapterConfigData: wethLogarithmicCurveParams
        });
        startRebalance(
          setToken,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          oldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        uint256 componentAmount = uint256(toDAIUnits(900));
        uint256 quoteAssetLimit = uint256(toWETHUnits(45))/100;
        fundBidder(address(weth), quoteAssetLimit);
        uint256 preBidderDai = dai.balanceOf(bidder);
        uint256 preBidderWeth = weth.balanceOf(bidder);
        uint256 preSetTokenDai = dai.balanceOf(address(setToken));
        uint256 preSetTokenWeth = weth.balanceOf(address(setToken));

        placeBid(setToken, dai, IERC20(address(weth)), componentAmount, quoteAssetLimit, true);

        uint256 postBidderDai = dai.balanceOf(bidder);
        uint256 postBidderWeth = weth.balanceOf(bidder);
        uint256 postSetTokenDai = dai.balanceOf(address(setToken));
        uint256 postSetTokenWeth = weth.balanceOf(address(setToken));

        assertEq(postBidderDai, preBidderDai + componentAmount);
        assertEq(postBidderWeth, preBidderWeth - quoteAssetLimit);
        assertEq(postSetTokenDai, preSetTokenDai - componentAmount);
        assertEq(postSetTokenWeth, preSetTokenWeth + quoteAssetLimit);
    }

    function testIndexWithoutQuoteAsset() external {
        setupIndexTokenWithoutQuoteAsset();
        AuctionRebalanceModuleV1.AuctionExecutionParams[] memory oldComponentsAuctionParams = new AuctionRebalanceModuleV1.AuctionExecutionParams[](2);
        oldComponentsAuctionParams[0] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toDAIUnits(9100)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultDaiData
        });
        oldComponentsAuctionParams[1] = AuctionRebalanceModuleV1.AuctionExecutionParams({
          targetUnit: uint256(toWBTCUnits(6)/int256(10)),
          priceAdapterName: CONSTANT_PRICE_ADAPTER,
          priceAdapterConfigData: defaultWbtcData
        });
        startRebalance(
          setTokenWithoutQuote,
          defaultQuoteAsset,
          defaultNewComponents,
          defaultNewComponentsAuctionParams,
          oldComponentsAuctionParams,
          defaultShouldLockSetToken,
          defaultDuration,
          uint256(defaultPositionMultiplier)
        );
        uint256 componentAmount = 290 ether;
        uint256 acquiredCapital = 0.145 ether;
        fundBidder(address(weth), acquiredCapital);
        fundBidder(address(wbtc), uint256(toWBTCUnits(1))/100);
        uint256 preBidderDai = dai.balanceOf(bidder);
        uint256 preBidderWeth = weth.balanceOf(bidder);
        uint256 preBidderWbtc = wbtc.balanceOf(bidder);
        uint256 preSetTokenDai = dai.balanceOf(address(setTokenWithoutQuote));
        uint256 preSetTokenWeth = weth.balanceOf(address(setTokenWithoutQuote));
        uint256 preSetTokenWbtc = wbtc.balanceOf(address(setTokenWithoutQuote));

        placeBid(setTokenWithoutQuote, dai, IERC20(address(weth)), 290 ether, acquiredCapital, true);
        placeBid(setTokenWithoutQuote, wbtc, IERC20(address(weth)), uint256(toWBTCUnits(1))/100, acquiredCapital, false);

        uint256 postBidderDai = dai.balanceOf(bidder);
        uint256 postBidderWeth = weth.balanceOf(bidder);
        uint256 postBidderWbtc = wbtc.balanceOf(bidder);
        uint256 postSetTokenDai = dai.balanceOf(address(setTokenWithoutQuote));
        uint256 postSetTokenWeth = weth.balanceOf(address(setTokenWithoutQuote));
        uint256 postSetTokenWbtc = wbtc.balanceOf(address(setTokenWithoutQuote));

        assertEq(postBidderDai, preBidderDai + componentAmount);
        assertEq(postBidderWeth, preBidderWeth);
        assertEq(postBidderWbtc, preBidderWbtc - uint256(toWBTCUnits(1))/100);
        assertEq(postSetTokenDai, preSetTokenDai - componentAmount);
        assertEq(postSetTokenWeth, preSetTokenWeth);
        assertEq(postSetTokenWeth, 0);
        assertEq(postSetTokenWbtc,  preSetTokenWbtc + uint256(toWBTCUnits(1))/100);
    }

}
