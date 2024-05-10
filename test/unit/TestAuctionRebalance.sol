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
        initAuctionModule();
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
}
