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
import "../interfaces/external/IParaswapV6.sol";
import {IUniswapV2Router02} from "../interfaces/external/IUniswapV2Router02.sol";

enum ExchangeFunction {
    NO_OP, //0
    PARASWAP_SWAP_EXACT_AMOUNT_IN, // 1
    PARASWAP_SWAP_EXACT_AMOUNT_OUT, // 2
    PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_BALANCER_V2, // 3
    PARASWAP_SWAP_EXACT_AMOUNT_OUT_ON_BALANCER_V2, // 4
    PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_CURVE_V1, // 5
    PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_CURVE_V2, // 6
    PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_UNISWAP_V2, // 7
    PARASWAP_SWAP_EXACT_AMOUNT_OUT_ON_UNISWAP_V2, // 8
    PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_UNISWAP_V3, // 9
    PARASWAP_SWAP_EXACT_AMOUNT_OUT_ON_UNISWAP_V3, // 10
    UNISWAP_SWAP_EXACT_TOKENS_FOR_TOKENS, // 11
    UNISWAP_SWAP_TOKENS_FOR_EXACT_TOKENS, // 12
    UNISWAP_SWAP_EXACT_TOKENS_FOR_TOKENS_SUPPORTING_FEE_ON_TRANSFER_TOKENS // 13
}

struct ExchangeParams {
    ExchangeFunction exchangeFunction;
    bytes exchangeData;
}

/// @title TokenExchangeSetIssuer
/// @author Cryptex Finance
/// @dev Note:
/// - This is a peripheral contract that helps users buy the underlying components
///   of the SetTokens and then issues the SetToken to the user.
///   It also allows users to redeem their SetTokens for a single asset.
/// - For buying and selling, exchanges like Paraswap or Uniswap will be used,
///   and the payload should be constructed by an interface, such as a UI.
contract TokenExchangeSetIssuer is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    /// @dev Mapping of setToken to its authorized BasicIssuanceModule.
    mapping(address => address) public setTokenIssuanceModules;

    IUniswapV2Router02 immutable uniswapRouterV2;
    IParaswapV6 immutable paraswapV6;

    constructor(address _paraswapV6, address _uniswapRouterV2) public {
        paraswapV6 = IParaswapV6(_paraswapV6);
        uniswapRouterV2 = IUniswapV2Router02(_uniswapRouterV2);
    }

    /// @notice Buys the underlying components of the SetToken and issues the SetToken.
    /// @dev To buy the underlying components, the payload needs to be constructed for the whitelisted exchanges.
    /// @param setToken: The instance of the SetToken contract.
    /// @param setTokenQuantity: The quantity of the SetToken to issue.
    /// @param quoteAsset: The instance of the IERC20 token used for buying the underlying components.
    /// @param totalQuoteAmount: The maximum amount the user pays for buying the underlying components.
    /// @param exchangeParams: An array of `ExchangeParams` containing data to buy each component.
    /// @return extraQuoteBalance The remaining quote balance after the purchase and issuance.
    function buyComponentsAndIssueSetToken(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        uint256 totalQuoteAmount,
        ExchangeParams[] calldata exchangeParams
    ) external nonReentrant returns (uint256 extraQuoteBalance) {
        require(setTokenQuantity > 0, "setTokenQuantity must be > 0");
        require(totalQuoteAmount > 0, "totalQuoteAmount must be > 0");
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), totalQuoteAmount);
        BasicIssuanceModule issuanceModule = _getIssuanceModule(setToken);
        _buyComponents(setToken, setTokenQuantity, quoteAsset, issuanceModule, exchangeParams);
        issuanceModule.issue(setToken, setTokenQuantity, msg.sender);
        uint256 afterQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        extraQuoteBalance = afterQuoteAssetBalance.sub(beforeQuoteAssetBalance);
        // refund extra quoteAsset
        if (extraQuoteBalance > 0) {
            SafeERC20.safeTransfer(quoteAsset, msg.sender, extraQuoteBalance);
        }
    }

    /// @notice Redeems the SetTokens for the underlying components and then sells them for `quoteAsset`.
    /// @dev To sell the underlying components, the payload needs to be constructed for the whitelisted exchanges.
    /// @param setToken: Instance of the SetToken contract.
    /// @param setTokenQuantity: Quantity of the SetToken to redeem.
    /// @param quoteAsset: Instance of the IERC20 token received after selling the underlying components.
    /// @param minQuoteAmount: The minimum `quoteAsset` amount the user expects to receive after selling the underlying components.
    /// @param exchangeParams: An array of `ExchangeParams` containing data to sell each component.
    /// @return quoteAssetBalanceAfterSell The `quoteAsset` balance obtained after selling the components.
    function redeemSetTokenAndExchangeTokens(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        uint256 minQuoteAmount,
        ExchangeParams[] calldata exchangeParams
    ) external nonReentrant returns (uint256 quoteAssetBalanceAfterSell) {
        require(setTokenQuantity > 0, "setTokenQuantity must be > 0");
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(address(setToken)), msg.sender, address(this), setTokenQuantity);

        BasicIssuanceModule issuanceModule = _getIssuanceModule(setToken);
        issuanceModule.redeem(setToken, setTokenQuantity, address(this));

        _sellComponents(setToken, setTokenQuantity, issuanceModule, quoteAsset, exchangeParams);
        quoteAssetBalanceAfterSell = quoteAsset.balanceOf(address(this)).sub(beforeQuoteAssetBalance);
        require(quoteAssetBalanceAfterSell >= minQuoteAmount, "Received amount less than minQuoteAmount");
        SafeERC20.safeTransfer(quoteAsset, msg.sender, quoteAssetBalanceAfterSell);
        return quoteAssetBalanceAfterSell;
    }

    /// @notice Approves a specified amount of multiple ERC20 tokens for a given spender.
    /// @dev Only the owner can call this function
    /// @param tokens: An array of ERC20 token instances to approve.
    /// @param spender: The address that is being approved to spend the tokens.
    /// @param amount: The amount of each token to approve for the spender.
    function approveTokens(IERC20[] memory tokens, address spender, uint256 amount) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].approve(spender, amount);
        }
    }

    /// @notice Adds or updates the issuance module for a specified SetToken.
    /// @dev This function maps a SetToken address to its corresponding issuance module. Both addresses must be non-zero.
    /// @param setToken: The address of the SetToken for which the issuance module is being set.
    /// @param issuanceModule: The address of the issuance module to be associated with the SetToken.
    function addSetTokenIssuanceModules(address setToken, address issuanceModule) external onlyOwner {
        require(setToken != address(0), "setToken can't be address(0)");
        require(issuanceModule != address(0), "issuanceModule can't be address(0)");
        setTokenIssuanceModules[setToken] = issuanceModule;
    }

    /// @notice Removes the issuance module associated with a specified SetToken.
    /// @dev This function deletes the mapping between a SetToken and its issuance module.
    /// @param setToken: The address of the SetToken for which the issuance module is being removed.
    function removeSetTokenIssuanceModules(address setToken) external onlyOwner {
        delete setTokenIssuanceModules[setToken];
    }

    /// @notice Allows the contract owner to recover any ERC20 tokens held by the contract.
    /// @dev Safely transfers the specified amount of the given ERC20 token to the provided address.
    /// @param token: The instance of the ERC20 token to be recovered.
    /// @param to: The address to which the tokens will be sent.
    /// @param amount: The amount of the token to recover and transfer.
    function recoverTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(token, to, amount);
    }

    /// @notice Fallback function to revert any ETH sent to the contract.
    receive() external payable {
        revert("ETH not accepted");
    }

    /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
    /*                                 private functions                                  */
    /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

    function _exchangeTokens(ExchangeParams calldata _exchangeParams) private {
        if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_IN) {
            (
                address executor,
                GenericData memory swapData,
                uint256 partnerAndFee,
                bytes memory permit,
                bytes memory executorData
            ) = abi.decode(_exchangeParams.exchangeData, (address, GenericData, uint256, bytes, bytes));
            paraswapV6.swapExactAmountIn(executor, swapData, partnerAndFee, permit, executorData);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_OUT) {
            (
                address executor,
                GenericData memory swapData,
                uint256 partnerAndFee,
                bytes memory permit,
                bytes memory executorData
            ) = abi.decode(_exchangeParams.exchangeData, (address, GenericData, uint256, bytes, bytes));
            paraswapV6.swapExactAmountOut(executor, swapData, partnerAndFee, permit, executorData);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_BALANCER_V2) {
            (BalancerV2Data memory balancerData, uint256 partnerAndFee, bytes memory permit, bytes memory data) = abi
                .decode(_exchangeParams.exchangeData, (BalancerV2Data, uint256, bytes, bytes));
            paraswapV6.swapExactAmountInOnBalancerV2(balancerData, partnerAndFee, permit, data);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_OUT_ON_BALANCER_V2) {
            (BalancerV2Data memory balancerData, uint256 partnerAndFee, bytes memory permit, bytes memory data) = abi
                .decode(_exchangeParams.exchangeData, (BalancerV2Data, uint256, bytes, bytes));
            paraswapV6.swapExactAmountOutOnBalancerV2(balancerData, partnerAndFee, permit, data);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_CURVE_V1) {
            (CurveV1Data memory curveV1Data, uint256 partnerAndFee, bytes memory permit) = abi.decode(
                _exchangeParams.exchangeData,
                (CurveV1Data, uint256, bytes)
            );
            paraswapV6.swapExactAmountInOnCurveV1(curveV1Data, partnerAndFee, permit);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_CURVE_V2) {
            (CurveV2Data memory curveV2Data, uint256 partnerAndFee, bytes memory permit) = abi.decode(
                _exchangeParams.exchangeData,
                (CurveV2Data, uint256, bytes)
            );
            paraswapV6.swapExactAmountInOnCurveV2(curveV2Data, partnerAndFee, permit);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_UNISWAP_V2) {
            (UniswapV2Data memory uniData, uint256 partnerAndFee, bytes memory permit) = abi.decode(
                _exchangeParams.exchangeData,
                (UniswapV2Data, uint256, bytes)
            );
            paraswapV6.swapExactAmountInOnUniswapV2(uniData, partnerAndFee, permit);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_OUT_ON_UNISWAP_V2) {
            (UniswapV2Data memory uniData, uint256 partnerAndFee, bytes memory permit) = abi.decode(
                _exchangeParams.exchangeData,
                (UniswapV2Data, uint256, bytes)
            );
            paraswapV6.swapExactAmountOutOnUniswapV2(uniData, partnerAndFee, permit);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_IN_ON_UNISWAP_V3) {
            (UniswapV3Data memory uniData, uint256 partnerAndFee, bytes memory permit) = abi.decode(
                _exchangeParams.exchangeData,
                (UniswapV3Data, uint256, bytes)
            );
            paraswapV6.swapExactAmountInOnUniswapV3(uniData, partnerAndFee, permit);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.PARASWAP_SWAP_EXACT_AMOUNT_OUT_ON_UNISWAP_V3) {
            (UniswapV3Data memory uniData, uint256 partnerAndFee, bytes memory permit) = abi.decode(
                _exchangeParams.exchangeData,
                (UniswapV3Data, uint256, bytes)
            );
            paraswapV6.swapExactAmountOutOnUniswapV3(uniData, partnerAndFee, permit);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.UNISWAP_SWAP_EXACT_TOKENS_FOR_TOKENS) {
            (uint amountIn, uint amountOutMin, address[] memory path, address to, uint deadline) = abi.decode(
                _exchangeParams.exchangeData,
                (uint, uint, address[], address, uint)
            );
            uniswapRouterV2.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
        } else if (_exchangeParams.exchangeFunction == ExchangeFunction.UNISWAP_SWAP_TOKENS_FOR_EXACT_TOKENS) {
            (uint amountOut, uint amountInMax, address[] memory path, address to, uint deadline) = abi.decode(
                _exchangeParams.exchangeData,
                (uint, uint, address[], address, uint)
            );
            uniswapRouterV2.swapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
        } else if (
            _exchangeParams.exchangeFunction ==
            ExchangeFunction.UNISWAP_SWAP_EXACT_TOKENS_FOR_TOKENS_SUPPORTING_FEE_ON_TRANSFER_TOKENS
        ) {
            (uint amountIn, uint amountOutMin, address[] memory path, address to, uint deadline) = abi.decode(
                _exchangeParams.exchangeData,
                (uint, uint, address[], address, uint)
            );
            uniswapRouterV2.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn,
                amountOutMin,
                path,
                to,
                deadline
            );
        } else {
            revert("Unknown exchange function");
        }
    }

    function _getIssuanceModule(ISetToken setToken) private view returns (BasicIssuanceModule) {
        address issuanceModule = setTokenIssuanceModules[address(setToken)];
        require(address(issuanceModule) != address(0), "setToken doesn't have issuanceModule");
        return BasicIssuanceModule(issuanceModule);
    }

    function _sellComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        BasicIssuanceModule issuanceModule,
        IERC20 quoteAsset,
        ExchangeParams[] calldata exchangeParams
    ) private {
        (address[] memory components, ) = issuanceModule.getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentsLength = components.length;
        require(exchangeParams.length == componentsLength, "exchangeParams length mismatch");

        for (uint256 index = 0; index < componentsLength; index++) {
            if (components[index] == address(quoteAsset)) continue;
            _exchangeTokens(exchangeParams[index]);
        }
    }

    function _buyComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        BasicIssuanceModule issuanceModule,
        ExchangeParams[] calldata exchangeParams
    ) private {
        (address[] memory components, uint256[] memory componentQuantities) = issuanceModule
            .getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentsLength = components.length;
        require(exchangeParams.length == componentsLength, "exchangeParams length mismatch");

        for (uint256 index = 0; index < componentsLength; index++) {
            address componentAddress = components[index];
            if (componentAddress == address(quoteAsset)) continue;
            IERC20 component = IERC20(componentAddress);
            uint256 beforeComponentBalance = component.balanceOf(address(this));
            _exchangeTokens(exchangeParams[index]);

            uint256 afterComponentBalance = component.balanceOf(address(this));
            require(
                afterComponentBalance.sub(beforeComponentBalance) >= componentQuantities[index],
                "Quantity bought less than required quantity"
            );
        }
    }
}
