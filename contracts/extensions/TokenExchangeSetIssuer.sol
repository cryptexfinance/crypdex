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
        SafeERC20.safeApprove(token, spender, uint256(-1));
    }

    function buyComponentsAndIssueSetToken(
        ISetToken setToken,
        uint256 setTokenQuantity,
        BasicIssuanceModule issuanceModule,
        IERC20 quoteAsset,
        uint256 totalQuoteAmount,
        address[] calldata exchanges,
        bytes[] calldata aggregatorPayloads
    ) external nonReentrant returns (uint256 extraQuoteBalance) {
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), totalQuoteAmount);
        _buyComponents(setToken, setTokenQuantity, issuanceModule, exchanges, aggregatorPayloads);

        uint256 afterQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        extraQuoteBalance = afterQuoteAssetBalance.sub(beforeQuoteAssetBalance);
        // refund extra quoteAsset
        if (extraQuoteBalance > 0) {
            SafeERC20.safeTransfer(quoteAsset, msg.sender, extraQuoteBalance);
        }
        issuanceModule.issue(setToken, setTokenQuantity, msg.sender);
    }

    function _buyComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        BasicIssuanceModule issuanceModule,
        address[] calldata exchanges,
        bytes[] calldata aggregatorPayloads
    ) internal {
        bool success;
        (address[] memory components, uint256[] memory componentQuantities) = issuanceModule
            .getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentQuantitiesLength = componentQuantities.length;
        require(exchanges.length == componentQuantitiesLength, "array length mismatch");
        require(aggregatorPayloads.length == componentQuantitiesLength, "array length mismatch");

        for (uint256 index = 0; index < componentQuantitiesLength; index++) {
            IERC20 component = IERC20(components[index]);
            uint256 beforeComponentBalance = component.balanceOf(address(this));
            // Wont use native asset, so no need to pass msg.value
            (success, ) = exchanges[index].call(aggregatorPayloads[index]);
            require(success, "AggregatorDex transaction failed");
            uint256 afterComponentBalance = component.balanceOf(address(this));
            require(
                afterComponentBalance.sub(beforeComponentBalance) >= componentQuantities[index],
                "Quantity bought less than required quantity"
            );
        }
    }
}
