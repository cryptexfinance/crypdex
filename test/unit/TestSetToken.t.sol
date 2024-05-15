// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/console.sol";

import {SetToken} from "contracts/protocol/SetToken.sol";
import {PreciseUnitMath} from "contracts/lib/PreciseUnitMath.sol";
import {IModule} from "contracts/interfaces/IModule.sol";
import "../fixtures/SystemFixture.sol";

contract MockModule is IModule {
    function removeModule() external {

    }
}

contract TestSetToken is SystemFixture {
    ISetToken internal iSetToken;
    SetToken internal setToken;
    address internal locker = address(0x67);
    function setUp() external {
        setUpSystem();
        vm.prank(deployer);
        Controller(address(controller)).addModule(locker);
        iSetToken = setupToken();
        setToken = SetToken(payable(address(iSetToken)));
    }

    function setupToken() internal returns (ISetToken _iSetToken) {
        address[] memory _components = new address[](2);
        int256[] memory _units = new int256[](2);
        address[] memory _modules = new address[](2);
        _components[0] = address(dai);
        _components[1] = address(wbtc);
        _units[0] = toDAIUnits(10000);
        _units[1] = toWBTCUnits(5)/10;
        _modules[0] = address(basicIssuanceModule);
        _modules[1] = locker;
        vm.startPrank(owner);
        _iSetToken = createSetToken(_components, _units, _modules);
        basicIssuanceModule.initialize(_iSetToken, IManagerIssuanceHook(address(0)));
        vm.stopPrank();
    }

    function testParameters() external {
        assertEq(setToken.name(), defaultName);
        assertEq(setToken.symbol(), defaultSymbol);
        assertEq(setToken.manager(), owner);
        assertEq(address(setToken.controller()), address(controller));
        assertEq(uint256(setToken.positionMultiplier()), PRECISE_UNIT);
    }

    function testComponents() external {
        assertEq(setToken.components(0), address(dai));
        assertEq(setToken.components(1), address(wbtc));
        assertEq(setToken.getDefaultPositionRealUnit(address(dai)), toDAIUnits(10000));
        assertEq(setToken.getDefaultPositionRealUnit(address(wbtc)), toWBTCUnits(5)/10);
    }

    function testInvoke() external {
        bytes memory callData = abi.encodeWithSelector(dai.approve.selector, owner, 100);
        assertEq(dai.allowance(address(setToken), owner), 0);
        vm.prank(address(basicIssuanceModule));
        setToken.invoke(address(dai), 0, callData);
        assertEq(dai.allowance(address(setToken), owner), 100);
    }

    function testLocked() external {
        assertFalse(setToken.isLocked());
        vm.prank(address(basicIssuanceModule));
        setToken.lock();
        assertTrue(setToken.isLocked());
        assertEq(setToken.locker(), address(basicIssuanceModule));
    }

    function testWhenCallerNotModule() external {
        vm.expectRevert("Only the module can call");
        setToken.lock();
    }

    function testSendEth() external {
        ISetToken  setTokenReceivingETH = setupToken();
        (bool success, ) = payable(address(setToken)).call{value: 3 ether}("");
        require(success, "Transfer failed!");
        assertEq(address(setTokenReceivingETH).balance, 0);
        vm.prank(address(basicIssuanceModule));
        setToken.invoke(address(setTokenReceivingETH), 2 ether, bytes(""));
        assertEq(address(setTokenReceivingETH).balance, 2 ether);
    }

    function testAddComponent() external {
        address[] memory oldComponents = setToken.getComponents();
        vm.prank(address(basicIssuanceModule));
        setToken.addComponent(address(weth));
        address[] memory newComponents = setToken.getComponents();
        assertEq(newComponents.length, oldComponents.length + 1);
        assertEq(setToken.components(2), address(weth));
    }

    function testErrorWhenAddExistingComponent() external {
        vm.expectRevert("Must not be component");
        vm.prank(address(basicIssuanceModule));
        setToken.addComponent(address(wbtc));
    }

    function testRemoveComponent() external {
        address[] memory oldComponents = setToken.getComponents();
        vm.prank(address(basicIssuanceModule));
        setToken.removeComponent(address(wbtc));
        address[] memory newComponents = setToken.getComponents();
        assertEq(newComponents.length, oldComponents.length - 1);
    }

    function testEditDefaultPosition() external {
        int256 newUnit = 4 ether;
        vm.prank(address(basicIssuanceModule));
        setToken.editDefaultPositionUnit(address(dai), newUnit);
        assertEq(setToken.getDefaultPositionRealUnit(address(dai)), newUnit);
    }

    function testEditPositionMultiplier()  external {
        int256 multiplier = 2 ether;
        vm.prank(address(basicIssuanceModule));
        setToken.editPositionMultiplier(multiplier);
        assertEq(setToken.positionMultiplier(), multiplier);
        int256 expectedRealUnit = PreciseUnitMath.preciseMul(toDAIUnits(10000), multiplier);
        assertEq(setToken.getDefaultPositionRealUnit(address(dai)), expectedRealUnit);
    }

    function testUnlock() external {
        assertFalse(setToken.isLocked());
        vm.startPrank(address(basicIssuanceModule));
        setToken.lock();
        assertTrue(setToken.isLocked());
        setToken.unlock();
        assertFalse(setToken.isLocked());
        assertEq(setToken.locker(), address(0));
        vm.stopPrank();
    }

    function testMint() external {
        assertEq(setToken.balanceOf(owner), 0);
        vm.prank(address(basicIssuanceModule));
        setToken.mint(owner, 3 ether);
        assertEq(setToken.balanceOf(owner), 3 ether);
    }

    function testMintWhenLocked() external {
        vm.prank(locker);
        setToken.initializeModule();
        vm.prank(address(locker));
        setToken.lock();
        vm.expectRevert("When locked, only the locker can call");
        vm.prank(address(basicIssuanceModule));
        setToken.mint(owner, 3 ether);
    }

    function testBurn() external {
        vm.startPrank(address(basicIssuanceModule));
        setToken.mint(owner, 3 ether);
        assertEq(setToken.balanceOf(owner), 3 ether);
        setToken.burn(owner, 3 ether);
        assertEq(setToken.balanceOf(owner), 0);
        vm.stopPrank();
    }

    function testBurnWhenLocked() external {
        vm.startPrank(locker);
        setToken.initializeModule();
        setToken.lock();
        // locker module can mint after locking
        setToken.mint(owner, 3 ether);
        vm.stopPrank();
        vm.expectRevert("When locked, only the locker can call");
        vm.prank(address(basicIssuanceModule));
        setToken.mint(owner, 3 ether);
    }

    function testAddModule() external {
        address newModule = address(0x91);
        vm.prank(deployer);
        Controller(address(controller)).addModule(newModule);
        vm.prank(owner);
        setToken.addModule(newModule);
        ISetToken.ModuleState moduleState = setToken.moduleStates(newModule);
        assertEq(uint256(moduleState), uint256(ISetToken.ModuleState.PENDING));
        vm.prank(newModule);
        setToken.initializeModule();
        moduleState = setToken.moduleStates(newModule);
        assertEq(uint256(moduleState), uint256(ISetToken.ModuleState.INITIALIZED));
    }

    function testRemoveModule() external {
        MockModule _newModule = new MockModule();
        address newModuleAddress = address(_newModule);
        vm.prank(deployer);
        Controller(address(controller)).addModule(newModuleAddress);
        vm.prank(owner);
        setToken.addModule(newModuleAddress);
        ISetToken.ModuleState moduleState = setToken.moduleStates(newModuleAddress);
        assertEq(uint256(moduleState), uint256(ISetToken.ModuleState.PENDING));
        vm.prank(newModuleAddress);
        setToken.initializeModule();
        vm.prank(owner);
        setToken.removeModule(newModuleAddress);
        moduleState = setToken.moduleStates(newModuleAddress);
        assertEq(uint256(moduleState), uint256(ISetToken.ModuleState.NONE));
    }
}
