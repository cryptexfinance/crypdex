// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IFlokiTaxHandler} from "../interfaces/external/IFlokiTaxHandler.sol";
import {IUniswapV2Router} from "../interfaces/external/IUniswapV2Router.sol";

contract FlokiUniswapV2BuyTokens {
    using SafeMath for uint256;

    IFlokiTaxHandler public flokiTaxHandler;
    IUniswapV2Router public uniswapRouter;
    IERC20 public floki;

    constructor(address _flokiTaxHandler, address _uniswapRouter, address _floki) public {
        flokiTaxHandler = IFlokiTaxHandler(_flokiTaxHandler);
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
        floki = IERC20(_floki);
    }

    function buyExactFlokiTokens(uint256 amountOut, address uniSwapPoolAddress, address[] memory paths) external {
        IERC20 quoteAsset = IERC20(paths[0]);
        uint256 tax = flokiTaxHandler.getTax(uniSwapPoolAddress, msg.sender, amountOut);
        uint256 taxAdjustedAmountOut = (amountOut * amountOut) / (amountOut - tax);
        uint256 amountIn = uniswapRouter.getAmountsIn(taxAdjustedAmountOut, paths)[0];
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), amountIn);
        SafeERC20.safeApprove(quoteAsset, address(uniswapRouter), amountIn);
        uint256 beforeFlokiBalance = floki.balanceOf(msg.sender);
        uniswapRouter.swapTokensForExactTokens(taxAdjustedAmountOut, amountIn, paths, msg.sender, block.timestamp);
        uint256 afterFlokiBalance = floki.balanceOf(msg.sender);
        require(afterFlokiBalance.sub(beforeFlokiBalance) >= amountOut, "returned less amount than desired");
    }
}
