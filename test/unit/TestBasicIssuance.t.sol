// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "../fixtures/SystemFixture.sol";

contract TestBasicIssuance is SystemFixture {
    ISetToken singleSetToken;
    ISetToken wETHWBTCSetToken;

    function setUp() external {
        setUpSystem();
    }

    function setupSingleSetToken(address module) internal {
        address[] memory _components = new address[](1);
        int256[] memory _units = new int256[](1);
        address[] memory _modules = new address[](1);
        _components[0] = address(weth);
        _units[0] = 1 ether;
        _modules[0] = module;
        singleSetToken = createSetToken(_components, _units, _modules);
    }

    function setupWETHWBTCSetToken() internal {
        address[] memory _components = new address[](2);
        int256[] memory _units = new int256[](2);
        address[] memory _modules = new address[](1);
        _components[0] = address(weth);
        _components[1] = address(wbtc);
        _units[0] = toWETHUnits(1);
        _units[1] = toWBTCUnits(2);
        _modules[0] = address(basicIssuanceModule);
        wETHWBTCSetToken = createSetToken(_components, _units, _modules);
        vm.prank(owner);
        basicIssuanceModule.initialize(wETHWBTCSetToken, IManagerIssuanceHook(address(0)));
    }

    function testInitialize() external {
        setupSingleSetToken(address(basicIssuanceModule));
        vm.startPrank(owner);
        basicIssuanceModule.initialize(singleSetToken, IManagerIssuanceHook(randomAddress));
        assertTrue(singleSetToken.isInitializedModule(address(basicIssuanceModule)));
        vm.stopPrank();
    }

    function testIssuanceHooks() external {
        setupSingleSetToken(address(basicIssuanceModule));
        vm.startPrank(owner);
        basicIssuanceModule.initialize(singleSetToken, IManagerIssuanceHook(randomAddress));
        assertEq(address(basicIssuanceModule.managerIssuanceHook(singleSetToken)), randomAddress);
        vm.stopPrank();
    }

    function testCallerNotSetManager() external {
        setupSingleSetToken(address(basicIssuanceModule));

        vm.expectRevert("Must be the SetToken manager");
        basicIssuanceModule.initialize(singleSetToken, IManagerIssuanceHook(randomAddress));
    }

    function testSteNotInPending() external {
        address newModule = randomAddress;
        vm.startPrank(deployer);
        Controller(address(controller)).addModule(newModule);
        vm.stopPrank();
        setupSingleSetToken(newModule);

        vm.startPrank(owner);
        vm.expectRevert("Must be pending initialization");
        basicIssuanceModule.initialize(singleSetToken, IManagerIssuanceHook(randomAddress));
        vm.stopPrank();
    }

    function testRemoveModule() external {
        vm.prank(owner);
        vm.expectRevert("The BasicIssuanceModule module cannot be removed");
        basicIssuanceModule.removeModule();
    }

    function testIssueQuantity() external {
        setupWETHWBTCSetToken();
        setUpBalance(user1);
        vm.prank(user1);
        basicIssuanceModule.issue(wETHWBTCSetToken, 2 ether, user1);

        assertEq(wETHWBTCSetToken.balanceOf(user1), 2 ether);
    }

    function testIssueComponentsDeposited() external {
        setupWETHWBTCSetToken();
        setUpBalance(user1);
        uint256 issueQuantity = 2 ether;
        vm.prank(user1);
        basicIssuanceModule.issue(wETHWBTCSetToken, issueQuantity, user1);

        uint256 depositedBTCBalance = wbtc.balanceOf(address(wETHWBTCSetToken));
        uint256 expectedBalance = (issueQuantity * uint256(toWBTCUnits(2))) / uint256(toWETHUnits(1));
        assertEq(depositedBTCBalance, expectedBalance);
    }

    function testRedeemQuantity() external {
        setupWETHWBTCSetToken();
        setUpBalance(user1);
        uint256 issueQuantity = 2 ether;
        vm.startPrank(user1);
        basicIssuanceModule.issue(wETHWBTCSetToken, issueQuantity, user1);

        assertEq(wETHWBTCSetToken.balanceOf(user1), issueQuantity);
        basicIssuanceModule.redeem(wETHWBTCSetToken, issueQuantity, user1);
        assertEq(wETHWBTCSetToken.balanceOf(user1), 0);
        vm.stopPrank();
    }

    function testRedeemComponents() external {
        setupWETHWBTCSetToken();
        setUpBalance(user1);
        uint256 issueQuantity = 2 ether;
        uint256 beforeIssueBalance = wbtc.balanceOf(user1);
        vm.startPrank(user1);
        basicIssuanceModule.issue(wETHWBTCSetToken, issueQuantity, user1);

        uint256 beforeRedeemBalance = wbtc.balanceOf(user1);
        basicIssuanceModule.redeem(wETHWBTCSetToken, issueQuantity, user1);
        uint256 afterRedeemBalance = wbtc.balanceOf(user1);
        assertTrue(afterRedeemBalance > beforeRedeemBalance);
        assertEq(beforeIssueBalance, afterRedeemBalance);
        vm.stopPrank();
    }
}
