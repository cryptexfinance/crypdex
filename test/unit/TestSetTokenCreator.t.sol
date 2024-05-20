// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Controller} from "contracts/protocol/Controller.sol";
import {SetTokenCreator} from "contracts/protocol/SetTokenCreator.sol";

import {IController} from "contracts/interfaces/IController.sol";
import {ISetToken} from "contracts/interfaces/ISetToken.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {WETH9} from "../mocks/WETH9.sol";

contract TestSetTokenCreator is Test {
  address internal deployer = address(0x51);
  address internal owner = address(0x52);
  address internal protocolFeeRecipient = address(0x53);

  address internal module1 = address(0x61);
  address internal module2 = address(0x62);

  string internal defaultName = "SetToken";
  string internal defaultSymbol = "SET";

  address[] internal components;
  int256[] internal units = [int256(1 ether), int256(2 ether)];
  address[] internal modules = [module1, module2];

  WETH9 internal weth;
  MockERC20 internal dai;

  Controller internal controller;
  SetTokenCreator internal setTokenCreator;

  function setUp() external {
    vm.startPrank(deployer);
    controller = new Controller(protocolFeeRecipient);
    setTokenCreator = new SetTokenCreator(IController(address(controller)));
    initializeController();
    weth = new WETH9();
    dai = new MockERC20(deployer, 10000000 ether, "DAI", "DAI", 18);
    controller.addModule(module1);
    controller.addModule(module2);
    vm.stopPrank();
    components.push(address(weth));
    components.push(address(dai));
  }

  function initializeController() internal {
    address[] memory _factories = new address[](1);
    address[] memory _modules = new address[](0);
    address[] memory _resources = new address[](0);
    uint256[] memory _resourceIds = new uint256[](0);
    _factories[0] = address(setTokenCreator);
    Controller(address(controller)).initialize(
      _factories,
      _modules,
      _resources,
      _resourceIds
    );
  }

  function createSetToken(
    address[] memory _components,
    int256[] memory _units,
    address[] memory _modules
  ) internal returns (ISetToken setToken) {
    vm.startPrank(deployer);
    vm.stopPrank();
    setToken = ISetToken(
      setTokenCreator.create(
        _components,
        _units,
        _modules,
        owner,
        defaultName,
        defaultSymbol
      )
    );
  }

  function testControllerSetCorrectly() external {
    assertEq(address(setTokenCreator.controller()), address(controller));
  }

  function testSetCreateControllerSet() external {
    ISetToken setToken = createSetToken(components, units, modules);
    assertTrue(controller.isSet(address(setToken)));
  }

  function testSetCreateEvent() external {
    // https://gist.github.com/voith/aebe4dba131241070edf808e244306f8
    bytes32 hash = keccak256(
      abi.encodePacked(
        bytes1(0xd6),
        bytes1(0x94),
        address(setTokenCreator),
        uint8(vm.getNonce(address(setTokenCreator)))
      )
    );
    address setTokenAddress = address(uint160(uint256(hash)));
    vm.expectEmit(false, true, false, true, address(setTokenCreator));
    emit SetTokenCreator.SetTokenCreated(
      setTokenAddress,
      owner,
      defaultName,
      defaultSymbol
    );
    createSetToken(components, units, modules);
  }

  function testNoComponents() external {
    address[] memory _components;
    vm.expectRevert("Must have at least 1 component");
    createSetToken(_components, units, modules);
  }

  function testDuplicateComponents() external {
    address[] memory _components = new address[](2);
    _components[0] = address(weth);
    _components[1] = address(weth);
    vm.expectRevert("Components must not have a duplicate");
    createSetToken(_components, units, modules);
  }

  function testComponentLengthNotEqualUnit() external {
    int256[] memory _units = new int256[](1);
    _units[0] = int256(0);
    vm.expectRevert("Component and unit lengths must be the same");
    createSetToken(components, _units, modules);
  }

  function testNoModules() external {
    address[] memory _modules;
    vm.expectRevert("Must have at least 1 module");
    createSetToken(components, units, _modules);
  }

  function testWhenComponentEmpty() external {
    address[] memory _components = new address[](2);
    _components[0] = address(weth);
    _components[1] = address(0);
    vm.expectRevert("Component must not be null address");
    createSetToken(_components, units, modules);
  }

  function testWhenUnitIsEmpty() external {
    int256[] memory _units = new int256[](2);
    vm.expectRevert("Units must be greater than 0");
    createSetToken(components, _units, modules);
  }
}
