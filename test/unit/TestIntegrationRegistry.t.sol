// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Controller } from "contracts/protocol/Controller.sol";
import { IController } from "contracts/interfaces/IController.sol";
import { IntegrationRegistry } from "contracts/protocol/IntegrationRegistry.sol";

contract TestIntegrationRegistry is Test {
    IntegrationRegistry internal integrationRegistry;
    Controller internal controller;

    address owner = address(0x51);
    address mockFirstAdapter = address(0x51);
    address mockSecondAdapter = address(0x61);
    address mockFirstModule = address(0x62);
    address mockSecondModule = address(0x63);
    address mockThirdModule = address(0x64);

    string internal firstAdapterName = "COMPOUND";
    string internal secondAdapterName = "KYBER";
    string internal thirdAdapterName = "ONEINCH";
    address[] internal defaultModules = [mockFirstModule, mockSecondModule];
    string[] internal defaultAdapterNames = [firstAdapterName, secondAdapterName];
    address[] internal defaultAdapters = [mockFirstAdapter, mockSecondAdapter];

    function setUp() external {
        vm.startPrank(owner);
        controller = new Controller(owner);
        controller.initialize(new address[](0), defaultModules, new address[](0), new uint256[](0));
        integrationRegistry = new IntegrationRegistry(IController(address(controller)));
        vm.stopPrank();
    }

    function testAddIntegration() external {
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            address(0)
        );
        vm.prank(owner);
        integrationRegistry.addIntegration(
            mockFirstModule,
            firstAdapterName,
            mockFirstAdapter
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            mockFirstAdapter
        );
    }

    function testAddIntegrationEvent() external {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(integrationRegistry));
        emit IntegrationRegistry.IntegrationAdded(mockFirstModule, mockFirstAdapter, firstAdapterName);
        integrationRegistry.addIntegration(
            mockFirstModule,
            firstAdapterName,
            mockFirstAdapter
        );
    }

    function testAddIntegrationWhenModuleNotInitialised() external {
        vm.prank(owner);
        vm.expectRevert("Must be valid module.");
        integrationRegistry.addIntegration(
            mockThirdModule,
            firstAdapterName,
            mockFirstAdapter
        );
    }

    function testAddIntegrationWhenModuleAlreadyAdded() external {
        vm.startPrank(owner);
        integrationRegistry.addIntegration(
            mockFirstModule,
            firstAdapterName,
            mockFirstAdapter
        );
        vm.expectRevert("Integration exists already.");
        integrationRegistry.addIntegration(
            mockFirstModule,
            firstAdapterName,
            mockFirstAdapter
        );
        vm.stopPrank();
    }

    function testAddIntegrationWhenAdapterZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert("Adapter address must exist.");
        integrationRegistry.addIntegration(
            mockFirstModule,
            firstAdapterName,
            address(0)
        );
    }

    function testBatchAddIntegration() external {
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            address(0)
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockSecondModule, secondAdapterName),
            address(0)
        );
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(integrationRegistry));
        emit IntegrationRegistry.IntegrationAdded(mockFirstModule, mockFirstAdapter, firstAdapterName);
        emit IntegrationRegistry.IntegrationAdded(mockSecondModule, mockSecondAdapter, secondAdapterName);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            mockFirstAdapter
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockSecondModule, secondAdapterName),
            mockSecondAdapter
        );
    }

    function testBatchIntegrationWhenModuleNotInit() external {
        defaultModules[1] = mockThirdModule;
        vm.prank(owner);
        vm.expectRevert("Must be valid module.");
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
    }

    function testBatchIntegrationWhenIntegrationExists() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        vm.prank(owner);
        vm.expectRevert("Integration exists already.");
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
    }

    function testBatchIntegrationWhenAdapterZeroAddress() external {
        defaultAdapters[1] = address(0);
        vm.prank(owner);
        vm.expectRevert("Adapter address must exist.");
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
    }

    function testBatchIntegrationWhenModuleLengthMismatch() external {
        address[] memory adapters = new address[](1);
        adapters[0] = mockFirstAdapter;
        vm.prank(owner);
        vm.expectRevert("Module and adapter lengths mismatch");
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            adapters
        );
    }

    function testRemoveIntegration() external {
        vm.prank(owner);
        integrationRegistry.addIntegration(
            mockFirstModule,
            firstAdapterName,
            mockFirstAdapter
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            mockFirstAdapter
        );
        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(integrationRegistry));
        emit IntegrationRegistry.IntegrationRemoved(mockFirstModule, mockFirstAdapter, firstAdapterName);
        integrationRegistry.removeIntegration(
            mockFirstModule,
            firstAdapterName
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            address(0)
        );
    }

    function testRemoveIntegrationWhenAddressNotAdded() external {
        vm.prank(owner);
        integrationRegistry.addIntegration(
            mockFirstModule,
            firstAdapterName,
            mockFirstAdapter
        );
        vm.prank(owner);
        vm.expectRevert("Integration does not exist.");
        integrationRegistry.removeIntegration(
            mockFirstModule,
            secondAdapterName
        );
    }

    function testBatchEditIntegration() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        // swap
        (defaultAdapters[0], defaultAdapters[1]) = (defaultAdapters[1], defaultAdapters[0]);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(integrationRegistry));
        emit IntegrationRegistry.IntegrationEdited(mockFirstModule, mockSecondAdapter, firstAdapterName);
        emit IntegrationRegistry.IntegrationEdited(mockSecondModule, mockFirstAdapter, secondAdapterName);
        integrationRegistry.batchEditIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            mockSecondAdapter
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockSecondModule, secondAdapterName),
            mockFirstAdapter
        );
    }

    function testBatchEditIntegrationWhenModuleNotInit() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        defaultModules[1] = mockThirdModule;
        vm.prank(owner);
        vm.expectRevert("Must be valid module.");
        integrationRegistry.batchEditIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
    }

    function testBatchEditIntegrationWhenAdapterNotAdded() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        defaultAdapterNames[1] = thirdAdapterName;
        vm.prank(owner);
        vm.expectRevert("Integration does not exist.");
        integrationRegistry.batchEditIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
    }

    function testBatchEditIntegrationWhenAdapterZeroAddress() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        defaultAdapters[1] = address(0);
        vm.prank(owner);
        vm.expectRevert("Adapter address must exist.");
        integrationRegistry.batchEditIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
    }

    function testIsValidIntegration() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        assertTrue(integrationRegistry.isValidIntegration(mockFirstModule, firstAdapterName));
    }

    function testIsInValidIntegration() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        assertFalse(integrationRegistry.isValidIntegration(mockFirstModule, secondAdapterName));
    }

    function testGetIntegrationAdapter() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );
        assertEq(
            integrationRegistry.getIntegrationAdapter(mockFirstModule, firstAdapterName),
            mockFirstAdapter
        );
    }

    function testGetIntegrationHash() external {
        vm.prank(owner);
        integrationRegistry.batchAddIntegration(
            defaultModules,
            defaultAdapterNames,
            defaultAdapters
        );

        assertEq(
            integrationRegistry.getIntegrationAdapterWithHash(mockFirstModule, keccak256(bytes(firstAdapterName))),
            mockFirstAdapter
        );
    }
}
