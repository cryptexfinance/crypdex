// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Controller } from "contracts/protocol/Controller.sol";
import { IController } from "contracts/interfaces/IController.sol";
import { IOracle } from "contracts/interfaces/IOracle.sol";
import { PriceOracle } from "contracts/protocol/PriceOracle.sol";
import {MockOracle} from "contracts/mocks/MockOracle.sol";
import {MockOracleAdapter} from "contracts/mocks/MockOracleAdapter.sol";


contract TestPriceOracle is Test {

    Controller controller;
    PriceOracle masterOracle;
    MockOracleAdapter oracleAdapter;
    MockOracle ethusdcOracle;
    MockOracle ethbtcOracle;

    address deployer = address(0x51);

    address wETH = address(0x61);
    address wBTC = address(0x62);
    address USDC = address(0x63);
    address adapterAsset = address(0x64);

    uint256 initialETHValue = 235 ether;
    uint256 initialETHBTCValue = 0.025 ether;
    uint256 adapterDummyPrice = 5 ether;

    address[] defaultModules = [deployer];


    function setUp() external {
        vm.startPrank(deployer);
        ethusdcOracle = new MockOracle(initialETHValue);
        ethbtcOracle = new MockOracle(initialETHBTCValue);
        oracleAdapter = new MockOracleAdapter(adapterAsset, adapterDummyPrice);
        controller = new Controller(deployer);
        controller.initialize(new address[](0), defaultModules, new address[](0), new uint256[](0));
        setUpPriceOracle();
        vm.stopPrank();
    }

    function setUpPriceOracle() private {
        address[] memory priceOracleAdapters = new address[](1);
        address[] memory priceOracleAssetOnes = new address[](2);
        address[] memory priceOracleAssetTwos = new address[](2);
        IOracle[] memory oracles  = new IOracle[](2);
        priceOracleAdapters[0] = address(oracleAdapter);
        priceOracleAssetOnes[0] = wETH;
        priceOracleAssetOnes[1] = wETH;
        priceOracleAssetTwos[0] = USDC;
        priceOracleAssetTwos[1] = wBTC;
        oracles[0] = IOracle(address(ethusdcOracle));
        oracles[1] = IOracle(address(ethbtcOracle));
        masterOracle = new PriceOracle(
            IController(address(controller)),
            wETH,
            priceOracleAdapters,
            priceOracleAssetOnes,
            priceOracleAssetTwos,
            oracles
        );
    }

    function inverse(uint256 val) private view returns(uint256) {
        return (1 ether * 1 ether) / val;
    }

    function testControllerSet() external {
        assertEq(
            address(masterOracle.controller()), address(controller)
        );
    }

    function testGetPrice() external {
        vm.prank(deployer);
        uint256 actualPrice = masterOracle.getPrice(wETH, USDC);
        assertEq(actualPrice, ethusdcOracle.read());
    }

    function testInversePrice() external {
        vm.prank(deployer);
        uint256 actualPrice = masterOracle.getPrice(USDC, wETH);
        uint256 expectedPrice = inverse(initialETHValue);
        assertEq(actualPrice, expectedPrice);
    }

    function testMasterQuotePrice() external {
        vm.prank(deployer);
        uint256 actualPrice = masterOracle.getPrice(wBTC, USDC);
        uint256 expectedPrice = (inverse(initialETHBTCValue) * 1 ether) / inverse(initialETHValue);
        assertEq(actualPrice, expectedPrice);
    }

    function testAdapterPrice() external {
        vm.prank(deployer);
        uint256 actualPrice = masterOracle.getPrice(adapterAsset, USDC);
        assertEq(actualPrice, adapterDummyPrice);
    }

    function testPriceWhenNoAssetPair() external {
        address unknownAsset = address(0x71);
        vm.prank(deployer);
        vm.expectRevert("PriceOracle.getPrice: Price not found.");
        uint256 actualPrice = masterOracle.getPrice(unknownAsset, USDC);
    }

    function testEditPair() external {
        address newOracle = address(0x72);
        vm.prank(deployer);
        vm.expectEmit(true, false, false, true, address(masterOracle));
        emit PriceOracle.PairEdited(wETH, USDC, newOracle);
        masterOracle.editPair(
            wETH,
            USDC,
            IOracle(newOracle)
        );
        assertEq(
            address(masterOracle.oracles(wETH, USDC)),
            newOracle
        );
    }

    function testAddPair() external {
        address randomAsset = address(0x71);
        address newOracle = address(0x72);
        vm.prank(deployer);
        vm.expectEmit(true, false, false, true, address(masterOracle));
        emit PriceOracle.PairAdded(randomAsset, USDC, newOracle);
        masterOracle.addPair(
            randomAsset,
            USDC,
            IOracle(newOracle)
        );
        assertEq(
            address(masterOracle.oracles(randomAsset, USDC)),
            newOracle
        );
    }

    function testRemovePair() external {
        vm.prank(deployer);
        vm.expectEmit(true, false, false, true, address(masterOracle));
        emit PriceOracle.PairRemoved(wETH, USDC, address(ethusdcOracle));
        masterOracle.removePair(
            wETH,
            USDC
        );
        assertEq(
            address(masterOracle.oracles(wETH, USDC)),
            address(0)
        );
    }
}
