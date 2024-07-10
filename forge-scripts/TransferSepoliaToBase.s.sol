// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {ProgrammableTokenTransfers} from "contracts/bridge/ProgrammableTokenTransfers.sol";


interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract TransferSepoliaToBase is Script {
    address sepoliaRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address baseSepoliaRouter = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;

    address payable sepoliaPTokenTransfers = payable(0x6F92a29E98F91e13Fb08BE00f509E7C6855eF1B0);
    address payable baseSepoliaPTokenTransfers = payable(0x303492327D68363BeB87073E5a5c18B9F04fc842);

    ProgrammableTokenTransfers ptokenTransfers = ProgrammableTokenTransfers(sepoliaPTokenTransfers);
    ProgrammableTokenTransfers baseSepoliaPtokenTransfers = ProgrammableTokenTransfers(baseSepoliaPTokenTransfers);

    ERC20 setToken = ERC20(0x2E62abc039EAE6933f93dd4B75BFA2cDAFD3E74d);

    uint64 SepoliaChainSelector = 16015286601757825753;
    uint64 baseSepoliaChainSelector = 10344971235874465080;

    address sepoliaccipLnMAddress = 0x466D489b6d36E7E3b824ef491C225F5830E81cC1;
    ERC20 sepoliaccipLnM = ERC20(sepoliaccipLnMAddress);

    address baseSepoliaLnMAddress = 0xA98FA8A008371b9408195e52734b1768c0d1Cb5c;
    ERC20 baseSepoliaccipLnM = ERC20(baseSepoliaLnMAddress);

    function run() external {
        uint256 managerPK = vm.envUint("MANAGER_PRIVATE_KEY");
        address manager = vm.addr(managerPK);
        uint256 amount = 0.5 ether;
        vm.startBroadcast(managerPK);
//        setToken.approve(address(ptokenTransfers), amount);
        baseSepoliaccipLnM.approve(address(baseSepoliaPtokenTransfers), amount);

        baseSepoliaPtokenTransfers.sendMessage{value: 0.01 ether}(
            SepoliaChainSelector,
            manager,
            string(""),
            baseSepoliaLnMAddress,
            amount
        );
        vm.stopBroadcast();
    }
}
