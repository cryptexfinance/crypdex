// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "../fixtures/SystemFixture.sol";
import {SetValuer} from "contracts/protocol/SetValuer.sol";
import {IManagerIssuanceHook} from "contracts/interfaces/IManagerIssuanceHook.sol";
import { PreciseUnitMath } from "contracts/lib/PreciseUnitMath.sol";

contract TestSetValuer is SystemFixture {
    using PreciseUnitMath for uint256;

    ISetToken setToken;
    uint256 usdcUnit;
    uint256 wETHUnit;
    uint256 baseUSDCUnit;
    uint256 baseWETHUnit;
    uint256 usdcPrice;
    uint256 wETHPrice;

    function setUp() external {
        setUpSystem();
        initIndexToken();
        usdcUnit = uint256(toUSDCUnits(100));
        wETHUnit = uint256(toWETHUnits(1));
        baseUSDCUnit = uint256(toUSDCUnits(1));
        baseWETHUnit = uint256(toWETHUnits(1));
        usdcPrice = 1 ether;
        wETHPrice = 230 ether;
    }

    function initIndexToken() private {
        address[] memory _components = new address[](2);
        int256[] memory _units = new int256[](2);
        address[] memory _modules = new address[](1);
        _components[0] = address(usdc);
        _components[1] = address(weth);
        // 100 USDC at $1 and 1 WETH at $230
        _units[0] = toUSDCUnits(100);
        _units[1] = toWETHUnits(1);
        _modules[0] = address(basicIssuanceModule);
        setToken = createSetToken(_components, _units, _modules);
        vm.prank(owner);
        basicIssuanceModule.initialize(setToken, IManagerIssuanceHook(address(0)));
    }

    function testController() external {
        assertEq(address(setValuer.controller()), address(controller));
    }

    function testCalculateSetTokenValuation() external {
        vm.prank(deployer);
        uint256 valuation = setValuer.calculateSetTokenValuation(setToken, address(usdc));
        uint256 normalizedUnitOne = usdcUnit.preciseDiv(baseUSDCUnit);
        uint256 normalizedUnitTwo = wETHUnit.preciseDiv(baseWETHUnit);
        uint256 expectedValuation = normalizedUnitOne.preciseMul(usdcPrice) + normalizedUnitTwo.preciseMul(wETHPrice);
        assertEq(valuation, expectedValuation);
    }
}
