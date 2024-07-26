// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IFlokiTaxHandler} from "../interfaces/external/IFlokiTaxHandler.sol";
import {IUniswapV2Router} from "../interfaces/external/IUniswapV2Router.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FlokiUniswapV2BuyTokens is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IFlokiTaxHandler public flokiTaxHandler;
    IUniswapV2Router public uniswapRouter;
    IERC20 public floki;

    constructor(address _flokiTaxHandler, address _uniswapRouter, address _floki) public {
        flokiTaxHandler = IFlokiTaxHandler(_flokiTaxHandler);
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
        floki = IERC20(_floki);
    }

    function buyExactFlokiTokens(
        uint256 amountOut,
        address uniSwapPoolAddress,
        address[] memory path
    ) external nonReentrant {
        IERC20 quoteAsset = IERC20(path[0]);
        uint256 tax = flokiTaxHandler.getTax(uniSwapPoolAddress, msg.sender, amountOut);
        uint256 taxAdjustedAmountOut = (amountOut * amountOut) / (amountOut - tax);
        uint256 amountIn = uniswapRouter.getAmountsIn(taxAdjustedAmountOut, path)[0];
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), amountIn);
        SafeERC20.safeApprove(quoteAsset, address(uniswapRouter), amountIn);
        uint256 beforeFlokiBalance = floki.balanceOf(msg.sender);
        uniswapRouter.swapTokensForExactTokens(taxAdjustedAmountOut, amountIn, path, msg.sender, block.timestamp);
        uint256 afterFlokiBalance = floki.balanceOf(msg.sender);
        require(afterFlokiBalance.sub(beforeFlokiBalance) >= amountOut, "returned less amount than desired");
    }

    function sellFlokiToken(uint256 amountIn, address[] memory path) external nonReentrant {
        IERC20 sellAsset = IERC20(path[0]);
        SafeERC20.safeTransferFrom(sellAsset, msg.sender, address(this), amountIn);
        SafeERC20.safeApprove(sellAsset, address(uniswapRouter), amountIn);
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            msg.sender,
            block.timestamp
        );
    }

    function transferTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(token, to, amount);
    }
}
