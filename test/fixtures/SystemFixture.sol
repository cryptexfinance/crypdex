// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {BasicIssuanceModule} from "contracts/modules/BasicIssuanceModule.sol";
import {StreamingFeeModule} from "contracts/modules/StreamingFeeModule.sol";

import {Controller} from "contracts/protocol/Controller.sol";
import {IntegrationRegistry} from "contracts/protocol/IntegrationRegistry.sol";
import {SetTokenCreator} from "contracts/protocol/SetTokenCreator.sol";
import {PriceOracle} from "contracts/protocol/PriceOracle.sol";
import {SetValuer} from "contracts/protocol/SetValuer.sol";
import {SetToken} from "contracts/protocol/SetToken.sol";

import {IController} from "contracts/interfaces/IController.sol";
import {IOracle} from "contracts/interfaces/IOracle.sol";
import {ISetToken} from "contracts/interfaces/ISetToken.sol";
import {IManagerIssuanceHook} from "contracts/interfaces/IManagerIssuanceHook.sol";

import {WETH9} from "contracts/mocks/WETH9.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {MockOracle} from "contracts/mocks/MockOracle.sol";

contract SystemFixture is Test {
    address internal deployer = address(0x51);
    address internal owner = address(0x52);
    address internal protocolFeeRecipient = address(0x53);
    address internal user1 = address(0x61);
    address internal randomAddress = address(0x8F);

    string internal defaultName = "SetToken";
    string internal defaultSymbol = "SET";

    IController internal controller;
    IntegrationRegistry internal integrationRegistry;
    BasicIssuanceModule internal basicIssuanceModule;
    SetTokenCreator internal setTokenCreator;
    PriceOracle internal priceOracle;
    SetValuer internal setValuer;
    StreamingFeeModule internal streamingFeeModule;

    WETH9 internal weth;
    MockERC20 internal usdc;
    MockERC20 internal wbtc;
    MockERC20 internal dai;

    IOracle internal ETH_USD_Oracle;
    IOracle internal USD_USD_Oracle;
    IOracle internal BTC_USD_Oracle;
    IOracle internal DAI_USD_Oracle;

    uint256 ONE_YEAR_IN_SECONDS = 365.25 days;
    uint256 PRECISE_UNIT = 10 ** 18;

    function setUpSystem() internal {
        vm.startPrank(deployer);
        controller = IController(address(new Controller(protocolFeeRecipient)));
        basicIssuanceModule = new BasicIssuanceModule(controller);
        integrationRegistry = new IntegrationRegistry(controller);
        setTokenCreator = new SetTokenCreator(controller);
        setValuer = new SetValuer(controller);
        streamingFeeModule = new StreamingFeeModule(controller);
        setUpTokensAndOracles();
        initializeController();
        vm.stopPrank();
    }

    function setUpTokensAndOracles() internal {
        weth = new WETH9();
        wbtc = new MockERC20(
            deployer,
            10000000 ether,
            "Wrapped BTC",
            "WBTC",
            8
        );
        usdc = new MockERC20(deployer, 10000000 ether, "USDC", "USDC", 6);
        dai = new MockERC20(deployer, 10000000 ether, "DAI", "DAI", 18);

        ETH_USD_Oracle = IOracle(address(new MockOracle(230 ether)));
        BTC_USD_Oracle = IOracle(address(new MockOracle(9000 ether)));
        USD_USD_Oracle = IOracle(address(new MockOracle(1 ether)));
        DAI_USD_Oracle = IOracle(address(new MockOracle(1 ether)));

        deal(deployer, 5000 ether);
        weth.deposit{value: 5000 ether}();
        weth.approve(address(basicIssuanceModule), 10000 ether);
        wbtc.approve(address(basicIssuanceModule), 10000 ether);
        usdc.approve(address(basicIssuanceModule), 10000 ether);
        dai.approve(address(basicIssuanceModule), 10000 ether);

        address[] memory _adapters;
        address[] memory _assetOnes = new address[](4);
        address[] memory _assetTwos = new address[](4);
        IOracle[] memory _oracles = new IOracle[](4);
        _assetOnes[0] = address(weth);
        _assetOnes[1] = address(usdc);
        _assetOnes[2] = address(wbtc);
        _assetOnes[3] = address(dai);
        _assetTwos[0] = address(usdc);
        _assetTwos[1] = address(usdc);
        _assetTwos[2] = address(usdc);
        _assetTwos[3] = address(usdc);
        _oracles[0] = ETH_USD_Oracle;
        _oracles[1] = USD_USD_Oracle;
        _oracles[2] = BTC_USD_Oracle;
        _oracles[3] = DAI_USD_Oracle;
        priceOracle = new PriceOracle(
            controller,
            address(usdc),
            _adapters,
            _assetOnes,
            _assetTwos,
            _oracles
        );
    }

    function initializeController() internal {
        address[] memory _factories = new address[](1);
        address[] memory _modules = new address[](2);
        address[] memory _resources = new address[](3);
        uint256[] memory _resourceIds = new uint256[](3);
        _factories[0] = address(setTokenCreator);
        _modules[0] = address(basicIssuanceModule);
        _modules[1] = address(streamingFeeModule);
        _resources[0] = address(integrationRegistry);
        _resources[1] = address(priceOracle);
        _resources[2] = address(setValuer);
        _resourceIds[0] = 0;
        _resourceIds[1] = 1;
        _resourceIds[2] = 2;
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
    ) internal returns (ISetToken) {
        address setToken = setTokenCreator.create(
            _components,
            _units,
            _modules,
            owner,
            defaultName,
            defaultSymbol
        );
        return ISetToken(setToken);
    }

    function approveAndIssueSetToken(
        ISetToken _setToken,
        uint256 quantity,
        address to
    ) internal {
        ISetToken.Position[] memory positions = _setToken.getPositions();
        for (uint256 i = 0; i < positions.length; i++) {
            address component = positions[i].component;
            MockERC20(component).approve(
                address(basicIssuanceModule),
                type(uint256).max
            );
        }
        vm.prank(owner);
        basicIssuanceModule.issue(_setToken, quantity, to);
    }

    function setUpBalance(address user) internal {
        deal(user, 5000 ether);
        vm.startPrank(deployer);
        wbtc.transfer(user, 10000 ether);
        usdc.transfer(user, 10000 ether);
        dai.transfer(user, 10000 ether);
        vm.stopPrank();

        vm.startPrank(user);
        weth.deposit{value: 5000 ether}();
        weth.approve(address(basicIssuanceModule), 10000 ether);
        wbtc.approve(address(basicIssuanceModule), 10000 ether);
        usdc.approve(address(basicIssuanceModule), 10000 ether);
        dai.approve(address(basicIssuanceModule), 10000 ether);
        vm.stopPrank();
    }

    function toDAIUnits(uint256 amount) internal pure returns (int256) {
        return int256(amount * 10 ** 18);
    }

    function toUSDCUnits(uint256 amount) internal pure returns (int256) {
        return int256(amount * 10 ** 6);
    }

    function toWBTCUnits(uint256 amount) internal pure returns (int256) {
        return int256(amount * 10 ** 8);
    }

    function toWETHUnits(uint256 amount) internal pure returns (int256) {
        return int256(amount * 10 ** 18);
    }
}
