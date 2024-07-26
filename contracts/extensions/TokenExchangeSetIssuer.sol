// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISetToken} from "../interfaces/ISetToken.sol";
import {BasicIssuanceModule} from "../modules/BasicIssuanceModule.sol";

contract TokenExchangeSetIssuer is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    function approveToken(IERC20 token, address spender) external onlyOwner {
        token.approve(spender, uint256(-1));
    }

    function buyComponentsAndIssueSetToken(
        ISetToken setToken,
        uint256 setTokenQuantity,
        BasicIssuanceModule issuanceModule,
        IERC20 quoteAsset,
        uint256 totalQuoteAmount,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) external nonReentrant returns (uint256 extraQuoteBalance) {
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), totalQuoteAmount);
        _buyComponents(setToken, setTokenQuantity, quoteAsset, issuanceModule, exchanges, exchangePayloads);
        issuanceModule.issue(setToken, setTokenQuantity, msg.sender);
        uint256 afterQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        extraQuoteBalance = afterQuoteAssetBalance.sub(beforeQuoteAssetBalance);
        // refund extra quoteAsset
        if (extraQuoteBalance > 0) {
            SafeERC20.safeTransfer(quoteAsset, msg.sender, extraQuoteBalance);
        }
    }

    function redeemSetTokenAndExchangeTokens(
        ISetToken setToken,
        uint256 setTokenQuantity,
        BasicIssuanceModule issuanceModule,
        IERC20 quoteAsset,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) external nonReentrant returns (uint256) {
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(address(setToken)), msg.sender, address(this), setTokenQuantity);

        issuanceModule.redeem(setToken, setTokenQuantity, address(this));

        _sellComponents(setToken, setTokenQuantity, issuanceModule, quoteAsset, exchanges, exchangePayloads);
        uint256 quoteAssetBalanceAfterSell = quoteAsset.balanceOf(address(this)).sub(beforeQuoteAssetBalance);
        SafeERC20.safeTransfer(quoteAsset, msg.sender, quoteAssetBalanceAfterSell);
        return quoteAssetBalanceAfterSell;
    }

    function transferTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(token, to, amount);
    }

    function _sellComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        BasicIssuanceModule issuanceModule,
        IERC20 quoteAsset,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) internal {
        (address[] memory components, ) = issuanceModule.getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentLength = components.length;
        require(exchanges.length == componentLength, "array length mismatch");
        require(exchangePayloads.length == componentLength, "array length mismatch");
        bool success;
        uint256 oldQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        uint256 newQuoteAssetBalance;
        for (uint256 i = 0; i < componentLength; i++) {
            if (components[i] == address(quoteAsset)) continue;
            (success, ) = exchanges[i].call(exchangePayloads[i]);
            require(success, "exchange transaction failed");
            newQuoteAssetBalance = quoteAsset.balanceOf(address(this));
            require(newQuoteAssetBalance > oldQuoteAssetBalance, "QuoteAsset balance didn't increase");
            oldQuoteAssetBalance = newQuoteAssetBalance;
        }
    }

    function _buyComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        BasicIssuanceModule issuanceModule,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) internal {
        bool success;
        (address[] memory components, uint256[] memory componentQuantities) = issuanceModule
            .getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentQuantitiesLength = componentQuantities.length;
        require(exchanges.length == componentQuantitiesLength, "array length mismatch");
        require(exchangePayloads.length == componentQuantitiesLength, "array length mismatch");

        for (uint256 index = 0; index < componentQuantitiesLength; index++) {
            address componentAddress = components[index];
            if (componentAddress == address(quoteAsset)) continue;
            IERC20 component = IERC20(componentAddress);
            uint256 beforeComponentBalance = component.balanceOf(address(this));
            // Wont use native asset, so no need to pass msg.value
            (success, ) = exchanges[index].call(exchangePayloads[index]);
            require(success, "exchange transaction failed");
            uint256 afterComponentBalance = component.balanceOf(address(this));
            require(
                afterComponentBalance.sub(beforeComponentBalance) >= componentQuantities[index],
                "Quantity bought less than required quantity"
            );
        }
    }
}
