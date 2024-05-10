// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/console.sol";

import {StreamingFeeModule} from "contracts/modules/StreamingFeeModule.sol";
import { IManagerIssuanceHook } from "contracts/interfaces/IManagerIssuanceHook.sol";
import {Controller} from "contracts/protocol/Controller.sol";
import {PreciseUnitMath} from "contracts/lib/PreciseUnitMath.sol";

import "../fixtures/SystemFixture.sol";

contract TestStreamingFee is SystemFixture {
    ISetToken setToken;

    address streamingFeeRecepient = address(0x81);

    uint256 protocolFee = 15 ether/100;

    function setUp() external {
        setUpSystem();
        setupIndexToken();
        issueTokenAndSetupFee();
    }

    function setupIndexToken() internal {
        StreamingFeeModule.FeeState memory feeSettings = StreamingFeeModule.FeeState({
          feeRecipient: streamingFeeRecepient,
          maxStreamingFeePercentage: 1 ether/10,
          streamingFeePercentage: 2 ether/ 100,
          lastStreamingFeeTimestamp: 0
        });
        address[] memory _components = new address[](1);
        int256[] memory _units = new int256[](1);
        address[] memory _modules = new address[](2);
        _components[0] = address(wbtc);
        _units[0] = toWETHUnits(1)/10;
        _modules[0] = address(basicIssuanceModule);
        _modules[1] = address(streamingFeeModule);
        vm.startPrank(owner);
        setToken = createSetToken(_components, _units, _modules);
        streamingFeeModule.initialize(setToken, feeSettings);
        basicIssuanceModule.initialize(setToken, IManagerIssuanceHook(address(0)));
        setUpBalance(owner);
        vm.stopPrank();
    }

    function issueTokenAndSetupFee() internal {
        vm.startPrank(owner);
        weth.approve(address(basicIssuanceModule),1 ether);
        basicIssuanceModule.issue(setToken, 1 ether, owner);
        vm.stopPrank();
        vm.prank(deployer);
        Controller(address(controller)).addFee(address(streamingFeeModule), 0, protocolFee);
    }

    function getStreamingFee(uint256 previousAccrueTimestamp, uint256 recentAccrueTimestamp, uint256 streamingFee) internal view returns (uint256) {
        (, ,uint256 streamingFeePercentage,) = streamingFeeModule.feeStates(setToken);
        uint256 accrualRate;
        if(streamingFee !=0 ) {
            accrualRate = streamingFee;
        }
        else {
            accrualRate = streamingFeePercentage;
        }
        uint256 timeElapsed = recentAccrueTimestamp - previousAccrueTimestamp;
        return (timeElapsed * accrualRate)/ ONE_YEAR_IN_SECONDS;
    }

    function getStreamingFeeInflationAmount(uint256 inflationPercent, uint256 totalSupply) internal pure returns (uint256) {
        return (inflationPercent * totalSupply) / (1 ether - inflationPercent);
    }

    function getPostFeePositionUnits(int256[] memory preFeeUnits, uint256 inflationPercent) internal view returns(int256[] memory newUnits){
        newUnits = new int256[](preFeeUnits.length);
        for (uint256 i = 0; i < preFeeUnits.length; i++) {
            if (preFeeUnits[i] >=0) {
              newUnits[i] = (PreciseUnitMath.preciseMul(preFeeUnits[i], int256(PRECISE_UNIT- inflationPercent)));
            } else {
              newUnits[i] = int256(PreciseUnitMath.preciseMulCeil(uint256(preFeeUnits[i]), PRECISE_UNIT - inflationPercent));
            }
          }
    }

    function testAccrueFeeMintsCorrectAmount() external{
        uint256 previousAccrueTimestamp = block.timestamp;
        uint256 recentAccrueTimestamp = block.timestamp + ONE_YEAR_IN_SECONDS;
        uint256 totalSupply = setToken.totalSupply();

        assertEq(setToken.balanceOf(streamingFeeRecepient), 0);
        vm.warp(recentAccrueTimestamp);
        streamingFeeModule.accrueFee(setToken);
        assertTrue(setToken.balanceOf(streamingFeeRecepient) > 0);

        uint256 expectedFeeInflation = getStreamingFee(previousAccrueTimestamp, recentAccrueTimestamp, 0);
        uint256 feeInflation = getStreamingFeeInflationAmount(expectedFeeInflation, totalSupply);
        uint256 protocolFeeAmount = (feeInflation * protocolFee) / 1 ether;
        assertEq(setToken.balanceOf(streamingFeeRecepient), feeInflation - protocolFeeAmount);
    }

    function testAccrueFeeEmitsCorrectEvent() external{
        uint256 previousAccrueTimestamp = block.timestamp;
        uint256 recentAccrueTimestamp = block.timestamp + ONE_YEAR_IN_SECONDS;
        uint256 totalSupply = setToken.totalSupply();
        uint256 expectedFeeInflation = getStreamingFee(previousAccrueTimestamp, recentAccrueTimestamp, 0);
        uint256 feeInflation = getStreamingFeeInflationAmount(expectedFeeInflation, totalSupply);
        uint256 protocolFeeAmount = (feeInflation * protocolFee) / 1 ether;

        vm.warp(recentAccrueTimestamp);
        vm.expectEmit(true, true, true, true, address(streamingFeeModule));
        emit StreamingFeeModule.FeeActualized(address(setToken), feeInflation - protocolFeeAmount, protocolFeeAmount);
        streamingFeeModule.accrueFee(setToken);
    }

    function testAccrueFeeAdjustsTotalSupplyCorrectly() external {
        uint256 previousAccrueTimestamp = block.timestamp;
        uint256 recentAccrueTimestamp = block.timestamp + ONE_YEAR_IN_SECONDS;
        uint256 previousTotalSupply = setToken.totalSupply();
        uint256 expectedFeeInflation = getStreamingFee(previousAccrueTimestamp, recentAccrueTimestamp, 0);
        uint256 feeInflation = getStreamingFeeInflationAmount(expectedFeeInflation, previousTotalSupply);

        vm.warp(recentAccrueTimestamp);
        streamingFeeModule.accrueFee(setToken);
        uint256 newTotalSupply = setToken.totalSupply();
        assertEq(newTotalSupply, previousTotalSupply + feeInflation);
    }

    function testLastStreamingFeeTimestampSetCorrectly() external {
        uint256 executionTimestamp = block.timestamp + 10000;
        vm.warp(executionTimestamp);
        streamingFeeModule.accrueFee(setToken);
        (,,,uint256 lastStreamingFeeTimestamp) = streamingFeeModule.feeStates(setToken);
        assertEq(lastStreamingFeeTimestamp, executionTimestamp);
    }

    function testUpdatesPositionMultiplierCorrectly() external {
        (,,,uint256 previousAccrueTimestamp) = streamingFeeModule.feeStates(setToken);
        uint256 recentAccrueTimestamp = block.timestamp + ONE_YEAR_IN_SECONDS;
        uint256 expectedFeeInflation = getStreamingFee(previousAccrueTimestamp, recentAccrueTimestamp, 0);
        int256 expectedNewMultiplier = int256(1 ether - expectedFeeInflation);

        vm.warp(recentAccrueTimestamp);
        streamingFeeModule.accrueFee(setToken);
        int256 newMultiplier = setToken.positionMultiplier();
        assertEq(newMultiplier, expectedNewMultiplier);
    }

    function testUpdatesPositionCorrectly() external {
        (,,,uint256 previousAccrueTimestamp) = streamingFeeModule.feeStates(setToken);
        ISetToken.Position[] memory oldPositions = setToken.getPositions();
        uint256 recentAccrueTimestamp = block.timestamp + ONE_YEAR_IN_SECONDS;
        uint256 expectedFeeInflation = getStreamingFee(previousAccrueTimestamp, recentAccrueTimestamp, 0);
        vm.warp(recentAccrueTimestamp);
        streamingFeeModule.accrueFee(setToken);
        int256[] memory preFeeUnits = new int256[](1);
        preFeeUnits[0] = oldPositions[0].unit;
        int256[] memory expectedNewUnits = getPostFeePositionUnits(preFeeUnits, expectedFeeInflation);
        ISetToken.Position[] memory newPositions = setToken.getPositions();
        assertEq(newPositions[0].unit, expectedNewUnits[0]);
    }

    function testProtocolFeeZeroMintsNoSets() external {
        vm.prank(deployer);
        Controller(address(controller)).editFee(address(streamingFeeModule), 0, 0);

        vm.warp(block.timestamp + ONE_YEAR_IN_SECONDS);
        streamingFeeModule.accrueFee(setToken);
        assertEq(setToken.balanceOf(protocolFeeRecipient), 0);
    }

    function testProtocolFeeZeroMintsCorrectly() external {
        vm.prank(deployer);
        Controller(address(controller)).editFee(address(streamingFeeModule), 0, 0);
        (,,,uint256 previousAccrueTimestamp) = streamingFeeModule.feeStates(setToken);
        uint256 recentAccrueTimestamp = block.timestamp + ONE_YEAR_IN_SECONDS;
        uint256 previousTotalSupply = setToken.totalSupply();
        uint256 expectedFeeInflation = getStreamingFee(previousAccrueTimestamp, recentAccrueTimestamp, 0);
        uint256 feeInflation = getStreamingFeeInflationAmount(expectedFeeInflation, previousTotalSupply);

        vm.warp(recentAccrueTimestamp);
        streamingFeeModule.accrueFee(setToken);
        assertEq(setToken.balanceOf(streamingFeeRecepient), feeInflation);
    }

    function testStreamingFeeZero() external {
        vm.prank(owner);
        streamingFeeModule.updateStreamingFee(setToken, 0);
        vm.warp(block.timestamp + ONE_YEAR_IN_SECONDS);
        streamingFeeModule.accrueFee(setToken);
        assertEq(setToken.balanceOf(streamingFeeRecepient), 0);
    }

    function testStreamingFeeZeroSetsLastTimeStamp() external {
        vm.prank(owner);
        streamingFeeModule.updateStreamingFee(setToken, 0);
        uint256 txnTimestamp = block.timestamp + ONE_YEAR_IN_SECONDS;
        vm.warp(txnTimestamp);
        streamingFeeModule.accrueFee(setToken);

        (,,,uint256 lastStreamingFeeTimestamp) = streamingFeeModule.feeStates(setToken);
        assertEq(lastStreamingFeeTimestamp, txnTimestamp);
    }

    function testUpdateFeeRecipient()  external {
        address newFeeRecipient = address(0x82);
        assertTrue(newFeeRecipient != streamingFeeRecepient);
        (address feeRecipient,,,) = streamingFeeModule.feeStates(setToken);
        assertEq(feeRecipient, streamingFeeRecepient);

        vm.prank(owner);
        streamingFeeModule.updateFeeRecipient(setToken, newFeeRecipient);
        (feeRecipient,,,) = streamingFeeModule.feeStates(setToken);
        assertEq(feeRecipient, newFeeRecipient);
    }

    function testUpdateStreamingFee() external {
        uint256 newFee = 3 ether/100;
        vm.prank(owner);
        streamingFeeModule.updateStreamingFee(setToken, newFee);
        (,,uint256 streamingFeePercentage,) = streamingFeeModule.feeStates(setToken);
        assertEq(streamingFeePercentage, newFee);
    }
}
