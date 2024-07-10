// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ProgrammableTokenTransfers} from "contracts/bridge/ProgrammableTokenTransfers.sol";

contract DeployCCIP is Script {
    address sepoliaRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address baseSepoliaRouter = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;
    function run() external {
        uint256 managerPK = vm.envUint("MANAGER_PRIVATE_KEY");
        vm.startBroadcast(managerPK);
        ProgrammableTokenTransfers ptokenTransfers = new ProgrammableTokenTransfers(baseSepoliaRouter);
        console.log("deployed contract");
        console.log(address(ptokenTransfers));
        vm.stopBroadcast();
    }
}
