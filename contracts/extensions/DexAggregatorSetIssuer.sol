// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISetToken } from "../interfaces/ISetToken.sol";
import {BasicIssuanceModule} from "../modules/BasicIssuanceModule.sol";


contract DexAggregatorSetIssuer is Ownable, ReentrancyGuard {

    function approveToken(IERC20 token, address spender) external onlyOwner {
        SafeERC20.safeApprove(token, spender, uint256(-1));
    }

    function buyComponentsAndIssue(
        ISetToken setToken,
//        BasicIssuanceModule issuanceModule,
        IERC20 quoteAsset,
        address aggregatorDex,
        uint256 totalQuoteAmount,
        uint256[] memory componentQuantities,
        bytes[] calldata aggregatorPayloads
    ) external nonReentrant {
        bool success;
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), totalQuoteAmount);
        // TODO: fetch this data from basicIssuanceModule.getRequiredComponentUnitsForIssue
        address[] memory components = setToken.getComponents();
        // TODO: Check length of arrays equal to lenth of components
        uint256 componentQuantitiesLength = componentQuantities.length;
        for(uint256 index=0; index < componentQuantitiesLength; index ++) {
            IERC20 component = IERC20(components[index]);
            uint256 beforeComponentBalance = component.balanceOf(address(this));
            // Wont use native asset, so no need to pass msg.value
            (success,) = aggregatorDex.call(aggregatorPayloads[index]);
            require(
              success,
              "AggregatorDex transaction failed"
            );
            uint256 afterComponentBalance = component.balanceOf(address(this));
            require(
                (afterComponentBalance - beforeComponentBalance) >= componentQuantities[index],
                "Quantity bought less than required quantity"
            );
        }
        uint256 afterQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        // TODO: use safe add
        uint256 extraQuoteBalance = afterQuoteAssetBalance - beforeQuoteAssetBalance;
        // refund extra quoteAsset
        if(extraQuoteBalance > 0) {
            SafeERC20.safeTransfer(quoteAsset, msg.sender, extraQuoteBalance);
        }
        // TODO: emit event with purchase details
    }
}
