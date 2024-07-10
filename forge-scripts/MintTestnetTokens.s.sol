// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.10;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {WETH9} from "contracts/mocks/WETH9.sol";
import {BasicIssuanceModule} from "contracts/modules/BasicIssuanceModule.sol";
import { ISetToken } from "contracts/interfaces/ISetToken.sol";

contract DeployCCIP is Script {
    address payable wethSepolia = 0x1E057193AC3f482E6794862a2EFfeB9FD0DbBD74;
    address wbtcSepolia = 0x9c96C544b225d2d94259dc56C64b05ca45D875Db;
    address basicIssuanceModule = 0xaaF93f789809694b7e4acB378b24bEab52cD412c;
    ISetToken setToken = ISetToken(0x2E62abc039EAE6933f93dd4B75BFA2cDAFD3E74d);
    MockERC20 wBTC = MockERC20(wbtcSepolia);
    WETH9 wETH = WETH9(wethSepolia);

    function run() external {
        uint256 managerPK = vm.envUint("MANAGER_PRIVATE_KEY");
        address manager = vm.addr(managerPK);
        vm.startBroadcast(managerPK);
        wBTC.mint(vm.addr(managerPK), 5 ether);
        wETH.deposit{value: 1 ether}();
        wBTC.approve(basicIssuanceModule, 1 ether);
        wETH.approve(basicIssuanceModule, 1 ether);
        BasicIssuanceModule(basicIssuanceModule).issue(setToken, 1 ether, manager);
        vm.stopBroadcast();
    }
}
