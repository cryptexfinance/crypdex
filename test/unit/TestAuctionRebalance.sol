// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/console.sol";

import {AddressArrayUtils} from "contracts/lib/AddressArrayUtils.sol";
import {AuctionRebalanceModuleV1} from "contracts/modules/AuctionRebalanceModuleV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AuctionFixture} from "../fixtures/AuctionFixture.sol";


contract TestAuctionRebalance is AuctionFixture {
    using AddressArrayUtils for address[];

    function setUp() external {
        setUpAuctionContracts();
        setupIndexToken();
        initDefaultRebalanceData();
        initAuctionModule();
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
