// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Controller} from "contracts/protocol/Controller.sol";

contract TestController is Test {
    address internal deployer = address(0x51);
    address internal owner = address(0x52);
    address internal protocolFeeRecipient = address(0x53);
    address mockBasicIssuanceModule = address(0x54);
    address mockSetTokenFactory = address(0x55);
    address mockPriceOracle = address(0x56);
    address mockSetToken = address(0x57);
    address mockUser = address(0x58);

    address[] internal defaultFactories = [mockSetTokenFactory];
    address[] internal defaultModules = [mockBasicIssuanceModule];
    address[] internal defaultResources = [mockPriceOracle];
    uint256[] internal defaultResourceIds = [0];

    Controller internal controller;

    function setUp() external {
        vm.prank(deployer);
        controller = new Controller(protocolFeeRecipient);
    }

    function initializeController(
        address[] memory _factories,
        address[] memory _modules,
        address[] memory _resources,
        uint256[] memory _resourceIds
    ) internal {
//        address[] memory _factories = new address[](1);
//        address[] memory _modules = new address[](2);
//        address[] memory _resources = new address[](3);
//        uint256[] memory _resourceIds = new uint256[](3);
//        _factories[0] = address(setTokenCreator);
//        _modules[0] = address(basicIssuanceModule);
//        _modules[1] = address(streamingFeeModule);
//        _resources[0] = address(integrationRegistry);
//        _resources[1] = address(priceOracle);
//        _resources[2] = address(setValuer);
//        _resourceIds[0] = 0;
//        _resourceIds[1] = 1;
//        _resourceIds[2] = 2;
        vm.prank(deployer);
        controller.initialize(_factories, _modules, _resources, _resourceIds);
    }

    function testFeeReceipentAddress() external {
        assertEq(controller.feeRecipient(), protocolFeeRecipient);
    }

    function testIsSystemContract() external {
        assertTrue(controller.isSystemContract(address(controller)));
    }

    function testModuleLength() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        address[] memory _modules = controller.getModules();
        assertEq(_modules.length, 1);
    }

    function testFactoriesLength() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        address[] memory _factories = controller.getFactories();
        assertEq(_factories.length, 1);
    }

    function testResourcesLength() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        address[] memory _resources = controller.getResources();
        assertEq(_resources.length, 1);
    }

    function testValidModule() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        assertTrue(controller.isModule(mockBasicIssuanceModule));
    }

    function testValidFactory() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        assertTrue(controller.isFactory(mockSetTokenFactory));
    }

    function testValidResource() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        assertTrue(controller.isResource(mockPriceOracle));
    }

    function testResourceMapping() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        assertEq(controller.resourceId(0), address(mockPriceOracle));
    }

    function testZeroAddressFactory() external {
        address[] memory _factories = new address[](1);
        vm.expectRevert("Zero address submitted.");
        initializeController(_factories, defaultModules, defaultResources, defaultResourceIds);
    }

    function testZeroAddressModule() external {
        address[] memory _modules = new address[](1);
        vm.expectRevert("Zero address submitted.");
        initializeController(defaultFactories, _modules, defaultResources, defaultResourceIds);
    }

    function testZeroAddressResource() external {
        address[] memory _resources = new address[](1);
        vm.expectRevert("Zero address submitted.");
        initializeController(defaultFactories, defaultModules, _resources, defaultResourceIds);
    }

    function testResourceLengthResourceIdMismatch() external {
        uint256[] memory _resourceIds = new uint256[](2);
        _resourceIds[0] = 0;
        _resourceIds[1] = 1;
        vm.expectRevert("Array lengths do not match.");
        initializeController(defaultFactories, defaultModules, defaultResources, _resourceIds);
    }

    function testWhenControllerAlreadyInitialized() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.expectRevert("Controller is already initialized");
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
    }

    function testRecourceIdDuplicate() external {
        address[] memory _resources = new address[](2);
        uint256[] memory _resourceIds = new uint256[](2);
        _resources[0] = mockPriceOracle;
        _resources[1] = address(0x61);
        _resourceIds[0] = 1;
        _resourceIds[1] = 1;
        vm.expectRevert("Resource ID already exists");
        initializeController(defaultFactories, defaultModules, _resources, _resourceIds);
    }

    function testAddSet() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        controller.addSet(mockSetToken);
        address[] memory sets = controller.getSets();
        assertEq(sets.length, 1);
    }

    function testValidSet() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        controller.addSet(mockSetToken);
        assertTrue(controller.isSet(mockSetToken));
    }

    function testSetAddedSystemContract() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        controller.addSet(mockSetToken);
        assertTrue(controller.isSystemContract(mockSetToken));
    }

    function testSetAddedEevnt() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        vm.expectEmit(true, false, false, true, address(controller));
        emit Controller.SetAdded(mockSetToken, mockSetTokenFactory);
        controller.addSet(mockSetToken);
    }

    function testSetAlreadyAdded() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        controller.addSet(mockSetToken);
        vm.prank(mockSetTokenFactory);
        vm.expectRevert("Set already exists");
        controller.addSet(mockSetToken);
    }

    function testAddSetWhenCallerInvalid() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.expectRevert("Only valid factories can call");
        controller.addSet(mockSetToken);
    }

    function testRemoveSet() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        controller.addSet(mockSetToken);
        address[] memory sets = controller.getSets();
        assertEq(sets.length, 1);
        vm.prank(deployer);
        controller.removeSet(mockSetToken);
        sets = controller.getSets();
        assertEq(sets.length, 0);
    }

    function testRemoveSetIsValid() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        controller.addSet(mockSetToken);
        vm.prank(deployer);
        controller.removeSet(mockSetToken);
        assertFalse(controller.isSet(mockSetToken));
    }

    function testSetRemovedEvent() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(mockSetTokenFactory);
        controller.addSet(mockSetToken);
        vm.prank(deployer);
        vm.expectEmit(true, false, false, true, address(controller));
        emit Controller.SetRemoved(mockSetToken);
        controller.removeSet(mockSetToken);
    }

    function testRemoveSetDoesntExist() external {
        initializeController(defaultFactories, defaultModules, defaultResources, defaultResourceIds);
        vm.prank(deployer);
        vm.expectRevert("Set does not exist");
        controller.removeSet(mockSetToken);
    }
}
