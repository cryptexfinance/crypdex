// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface UniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface DynamicTaxHandler {
    function getTax(
        address benefactor,
        address beneficiary,
        uint256 amount
    ) external view returns (uint256);
}

contract ForkTestFloki is Test {
    address flokiAddress = 0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E;
    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IERC20 floki = IERC20(flokiAddress);
    IERC20 weth = IERC20(wethAddress);
    address user = address(0x52);
    address to = address (0x53);
    UniswapV2Pair wethFlokiPair = UniswapV2Pair(0xca7c2771D248dCBe09EABE0CE57A62e18dA178c0);
    DynamicTaxHandler flokiTaxHandler = DynamicTaxHandler(0x834F96fD4fE9147a2a647D957FBbE67FEc62B67b);

    function setUp() external {
        deal({token: flokiAddress, to: user, give: 1000000e9});
        deal({token: wethAddress, to: user, give: 1000000e18});
    }

    function test() external {
        bytes memory data;
//        console.log(floki.balanceOf(to));
        vm.startPrank(user);
        uint256 flokiAmount = 110e9;
        uint256 tax = flokiTaxHandler.getTax(address(wethFlokiPair), to, flokiAmount);
        uint256 adjustedAmount = (flokiAmount * flokiAmount) / (flokiAmount - tax);
        console.log(tax);
        console.log(adjustedAmount);
        uint256 adjustedTax = flokiTaxHandler.getTax(address(wethFlokiPair), to, adjustedAmount);
        console.log(adjustedTax);
        console.log(adjustedAmount - adjustedTax);
//        weth.transfer(address(wethFlokiPair), 10000e18);
//        wethFlokiPair.swap(0, flokiAmount, to, data);
//        console.log(floki.balanceOf(to));
    }
}
