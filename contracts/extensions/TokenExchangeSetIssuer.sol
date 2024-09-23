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

/// @title TokenExchangeSetIssuer
/// @author Cryptex Finance
/// @dev Note:
/// - This is a periphery contract that helps users buy the underlying components
///   of the SetTokens and then issues the SetToken to the user.
///   It also allows users to redeem their SetTokens for a single asset.
/// - For buying and selling, exchanges like Paraswap or Uniswap will be used,
///   and the payload should be constructed by an interface, such as a UI.
/// @notice WARNING: Do not send funds directly to this contract. This contract does not handle
///   receiving ETH or ERC20 tokens directly. Sending funds here may result in a loss.
/// @notice WARNING: Any dust (small amounts) left over from the swap of components during
///   buy or sell operations will not be refunded. Users are advised to use swap functions
///   that avoid or minimize dust accumulation.
contract TokenExchangeSetIssuer is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    /// @dev Mapping of setToken to its authorized BasicIssuanceModule.
    mapping(address => address) public setTokenIssuanceModules;
    /// @dev Mapping of whitelisted function for a target contract.
    mapping(bytes24 => bool) public whitelistedFunctions;

    /// @notice Buys the underlying components of the SetToken and issues the SetToken.
    /// @dev To buy the underlying components, the payload needs to be constructed for the whitelisted exchanges.
    /// @param setToken: The instance of the SetToken contract.
    /// @param setTokenQuantity: The quantity of the SetToken to issue.
    /// @param quoteAsset: The instance of the IERC20 token used for buying the underlying components.
    /// @param totalQuoteAmount: The maximum amount the user pays for buying the underlying components.
    /// @param exchanges: An array of addresses used to buy each component.
    /// @param exchangePayloads: Payloads targeted towards each exchange for buying the corresponding component.
    /// @return extraQuoteBalance The remaining quote balance after the purchase and issuance.
    /// @notice WARNING: Dust (small amounts) of the `quoteAsset` may remain after the operation
    ///   and will not be refunded to the user. Users should use swap functions that do not leave dust.
    function buyComponentsAndIssueSetToken(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        uint256 totalQuoteAmount,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) external nonReentrant returns (uint256 extraQuoteBalance) {
        require(setTokenQuantity > 0, "setTokenQuantity must be > 0");
        require(totalQuoteAmount > 0, "totalQuoteAmount must be > 0");
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), totalQuoteAmount);
        BasicIssuanceModule issuanceModule = _getIssuanceModule(setToken);
        _buyComponents(setToken, setTokenQuantity, quoteAsset, issuanceModule, exchanges, exchangePayloads);
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
    /// @param exchanges: An array of addresses used to sell each component.
    /// @param exchangePayloads: Payloads targeted towards each exchange for selling the corresponding component.
    /// @return quoteAssetBalanceAfterSell The `quoteAsset` balance obtained after selling the components.
    /// @notice WARNING: Any dust accumulated during the selling of components will not be refunded.
    ///   Users should ensure they use swap functions that do not leave dust.
    function redeemSetTokenAndExchangeTokens(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        uint256 minQuoteAmount,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) external nonReentrant returns (uint256 quoteAssetBalanceAfterSell) {
        require(setTokenQuantity > 0, "setTokenQuantity must be > 0");
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(address(setToken)), msg.sender, address(this), setTokenQuantity);

        BasicIssuanceModule issuanceModule = _getIssuanceModule(setToken);
        issuanceModule.redeem(setToken, setTokenQuantity, address(this));

        _sellComponents(setToken, setTokenQuantity, issuanceModule, quoteAsset, exchanges, exchangePayloads);
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


     /// @notice Whitelists multiple functions for the specified target contract.
     /// @dev This function allows the contract owner to whitelist multiple functions identified
     ///      by their target address and function selectors. Only whitelisted functions can
     ///      be called through the `call` function, ensuring that only approved
     ///      functions are executed.
     /// @param target The address of the contract that contains the functions to be whitelisted.
     ///               Must be a valid contract address (non-zero).
     /// @param selectors An array of function selectors (4-byte signatures) belonging to the target address.
     ///                  Each selector represents a specific function within the target contract that is
     ///                  being whitelisted.
    function whitelistFunctions(address target, bytes4[] calldata selectors) external onlyOwner {
        require(target != address(0), "Invalid target address");
        bytes24 signature;
        for(uint256 i=0; i < selectors.length; i++) {
            signature = _calculateFunctionSignature(target, selectors[i]);
            whitelistedFunctions[signature] = true;
        }
    }

     /// @notice Removes multiple functions from the whitelist for the specified target contract.
     /// @dev This function allows the contract owner to remove multiple functions, identified
     ///      by their target address and function selectors, from the whitelist. Once a function
     ///      is removed from the whitelist, it can no longer be called via the `call` function.
     /// @param target The address of the contract that contains the functions to be removed from the whitelist.
     /// @param selectors An array of function selectors (4-byte signatures) belonging to the target address,
     ///                  representing the functions to be removed from the whitelist.
    function revokeWhitelistedFunctions(address target, bytes4[] calldata selectors) external onlyOwner {
        bytes24 signature;
        for(uint256 i=0; i < selectors.length; i++) {
            signature = _calculateFunctionSignature(target, selectors[i]);
            require(whitelistedFunctions[signature], "function not whitelisted");
            delete whitelistedFunctions[signature];
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
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) private {
        (address[] memory components, ) = issuanceModule.getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentsLength = components.length;
        require(exchanges.length == componentsLength, "exchanges length mismatch");
        require(exchangePayloads.length == componentsLength, "payloads length mismatch");
        bool success;

        for (uint256 index = 0; index < componentsLength; index++) {
            if (components[index] == address(quoteAsset)) continue;
            address exchange = exchanges[index];
            bytes memory exchangePayload = exchangePayloads[index];
            _requireWhitelistedFunction(exchange, exchangePayload);
            (success, ) = exchange.call(exchangePayload);
            require(success, "exchange transaction failed");
        }
    }

    function _buyComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        BasicIssuanceModule issuanceModule,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) private {
        bool success;
        (address[] memory components, uint256[] memory componentQuantities) = issuanceModule
            .getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentsLength = components.length;
        require(exchanges.length == componentsLength, "exchanges length mismatch");
        require(exchangePayloads.length == componentsLength, "payloads length mismatch");

        for (uint256 index = 0; index < componentsLength; index++) {
            address componentAddress = components[index];
            if (componentAddress == address(quoteAsset)) continue;
            IERC20 component = IERC20(componentAddress);
            uint256 beforeComponentBalance = component.balanceOf(address(this));

            address exchange = exchanges[index];
            bytes memory exchangePayload = exchangePayloads[index];
            _requireWhitelistedFunction(exchange, exchangePayload);
            // Wont use native asset, so no need to pass msg.value
            (success, ) = exchange.call(exchangePayload);
            require(success, "exchange transaction failed");

            uint256 afterComponentBalance = component.balanceOf(address(this));
            require(
                afterComponentBalance.sub(beforeComponentBalance) >= componentQuantities[index],
                "Quantity bought less than required quantity"
            );
        }
    }

    function _requireWhitelistedFunction(address target, bytes memory payload) private view {
        require(payload.length >= 4, "Invalid payload");
        bytes4 selector;
        assembly {
            selector := mload(add(payload, 32))
        }
        bytes24 signature = _calculateFunctionSignature(target, selector);
        require(whitelistedFunctions[signature], "function not whitelisted");
    }

    function _calculateFunctionSignature(address target, bytes4 selector) private pure returns(bytes24 signature) {
        bytes memory encodedData = abi.encodePacked(target, selector);
        assembly {
            signature := mload(add(encodedData, 32))
        }
    }
}
