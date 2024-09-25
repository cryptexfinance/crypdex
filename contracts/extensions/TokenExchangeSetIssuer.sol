// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin-contracts-5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin-contracts-5/contracts/access/Ownable.sol";
import {ISetToken} from "../interfaces/v0.8/ISetToken.sol";
import {IIssuanceModule} from "../interfaces/v0.8/IIssuanceModule.sol";

/// @title TokenExchangeSetIssuer
/// @author Cryptex Finance
/// @dev Note:
/// - This is a peripheral contract that helps users buy the underlying components
///   of the SetTokens and then issues the SetToken to the user.
///   It also allows users to redeem their SetTokens for a single asset.
/// - For buying and selling, exchanges like Paraswap or Uniswap will be used,
///   and the payload should be constructed by an interface, such as a UI.
/// @notice WARNING: Do not send funds directly to this contract. This contract does not handle
///         receiving ETH or ERC20 tokens directly. Sending funds here may result in a loss.
/// @notice WARNING: Any dust (small amounts) left over from the swap of components during
///         buy or sell operations will not be refunded. Users are advised to use swap functions
///         that avoid or minimize dust accumulation.
contract TokenExchangeSetIssuer is Ownable, ReentrancyGuard {
    /// @dev Maps each SetToken to its associated authorized IIssuanceModule.
    ///      This mapping serves two purposes:
    ///      1. To verify whether a SetToken is authorized.
    ///      2. To retrieve the corresponding IIssuanceModule for a given SetToken.
    mapping(address => address) public setTokenIssuanceModules;
    /// @dev Mapping of whitelisted function for a target contract.
    mapping(bytes24 => bool) public whitelistedFunctions;

    /// @notice Thrown when the quantity of the Set token for buying or selling is zero.
    error SetQuantityCannotBeZero();
    /// @notice Thrown when the quote asset amount for buying or selling is zero.
    error QuoteAmountCannotBeZero();
    /// @notice Thrown when the target address provided is the zero address.
    error TargetAddressCannotBeZero();
    /// @notice Thrown when the Set token address provided is the zero address.
    error SetAddressCannotBeZero();
    /// @notice Thrown when the issuance module address provided is the zero address.
    error IssuanceAddressCannotBeZero();
    /// @notice Thrown when the amount received from selling the Set token is less than expected.
    error ReceivedAmountLessThanExpected();
    /// @notice Thrown when attempting to call or revoke a non-whitelisted function.
    error FunctionNotWhitelisted();
    /// @notice Thrown when ETH is sent to the contract.
    error ETHNotAccepted();
    /// @notice Thrown when attempting to buy or sell a Set token that is not whitelisted.
    error SetTokenNotWhitelisted();
    /// @notice Thrown when the number of exchanges does not match the number of Set token components.
    error ExchangeLengthMismatch();
    /// @notice Thrown when the length of the exchange payload does not match the number of Set token components.
    error PayloadLengthMismatch();
    /// @notice Thrown when a call to an exchange fails.
    error ExchangeCallFailed();
    /// @notice Thrown when the amount of Set token components bought is insufficient for issuing the desired
    ///         quantity of the Set token.
    error QuantityBoughtLessThanMinimum();
    /// @notice Thrown when the length of the payload for buying or selling tokens is less than 4 bytes.
    error InvalidPayload();

    /// @notice Emitted when a function is whitelisted for a specific target contract.
    /// @param target The address of the target contract.
    /// @param selector The 4 byte function selector that has been whitelisted.
    event FunctionWhitelisted(address target, bytes4 selector);
    /// @notice Emitted when a previously whitelisted function is revoked for a specific target contract.
    /// @param target The address of the target contract.
    /// @param selector The 4 byte function selector that has been revoked.
    event FunctionRevoked(address target, bytes4 selector);
    /// @notice Emitted when an IssuanceModule is added to a SetToken.
    /// @param setToken The address of the SetToken.
    /// @param issuanceModule The address of the IssuanceModule that was added.
    event IssuanceModuleAdded(address setToken, address issuanceModule);
    /// @notice Emitted when an IssuanceModule is removed from a SetToken.
    /// @param setToken The address of the SetToken.
    /// @param issuanceModule The address of the IssuanceModule that was removed.
    event IssuanceModuleRemoved(address setToken, address issuanceModule);

    constructor(address owner) Ownable(owner) {}

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
    ///         and will not be refunded to the user. Users should use swap functions that do not leave dust.
    function buyComponentsAndIssueSetToken(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        uint256 totalQuoteAmount,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) external nonReentrant returns (uint256 extraQuoteBalance) {
        if (setTokenQuantity == 0) revert SetQuantityCannotBeZero();
        if (totalQuoteAmount == 0) revert QuoteAmountCannotBeZero();
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(quoteAsset, msg.sender, address(this), totalQuoteAmount);
        IIssuanceModule issuanceModule = _getIssuanceModule(setToken);
        _buyComponents(setToken, setTokenQuantity, quoteAsset, issuanceModule, exchanges, exchangePayloads);
        issuanceModule.issue(setToken, setTokenQuantity, msg.sender);
        uint256 afterQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        extraQuoteBalance = afterQuoteAssetBalance - beforeQuoteAssetBalance;
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
    ///         Users should ensure they use swap functions that do not leave dust.
    function redeemSetTokenAndExchangeTokens(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        uint256 minQuoteAmount,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) external nonReentrant returns (uint256 quoteAssetBalanceAfterSell) {
        if (setTokenQuantity == 0) revert SetQuantityCannotBeZero();
        uint256 beforeQuoteAssetBalance = quoteAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(address(setToken)), msg.sender, address(this), setTokenQuantity);

        IIssuanceModule issuanceModule = _getIssuanceModule(setToken);
        issuanceModule.redeem(setToken, setTokenQuantity, address(this));

        _sellComponents(setToken, setTokenQuantity, issuanceModule, quoteAsset, exchanges, exchangePayloads);
        quoteAssetBalanceAfterSell = quoteAsset.balanceOf(address(this)) - beforeQuoteAssetBalance;

        if (quoteAssetBalanceAfterSell < minQuoteAmount) revert ReceivedAmountLessThanExpected();

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
        if (target == address(0)) revert TargetAddressCannotBeZero();
        bytes24 identifier;
        for (uint256 i = 0; i < selectors.length; i++) {
            identifier = _calculateFunctionIdentifier(target, selectors[i]);
            whitelistedFunctions[identifier] = true;
            emit FunctionWhitelisted(target, selectors[i]);
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
        bytes24 identifier;
        for (uint256 i = 0; i < selectors.length; i++) {
            identifier = _calculateFunctionIdentifier(target, selectors[i]);
            if (!whitelistedFunctions[identifier]) revert FunctionNotWhitelisted();
            delete whitelistedFunctions[identifier];
            emit FunctionRevoked(target, selectors[i]);
        }
    }

    /// @notice Adds or updates the issuance module for a specified SetToken.
    /// @dev This function maps a SetToken address to its corresponding issuance module. Both addresses must be non-zero.
    /// @param setToken: The address of the SetToken for which the issuance module is being set.
    /// @param issuanceModule: The address of the issuance module to be associated with the SetToken.
    function addSetTokenIssuanceModules(address setToken, address issuanceModule) external onlyOwner {
        if (setToken == address(0)) revert SetAddressCannotBeZero();
        if (issuanceModule == address(0)) revert IssuanceAddressCannotBeZero();
        setTokenIssuanceModules[setToken] = issuanceModule;
        emit IssuanceModuleAdded(setToken, issuanceModule);
    }

    /// @notice Removes the issuance module associated with a specified SetToken.
    /// @dev This function deletes the mapping between a SetToken and its issuance module.
    /// @param setToken: The address of the SetToken for which the issuance module is being removed.
    function removeSetTokenIssuanceModules(address setToken) external onlyOwner {
        // _getIssuanceModule will revert if setToken is not whitelisted
        address issuanceModule = address(_getIssuanceModule(ISetToken(setToken)));
        delete setTokenIssuanceModules[setToken];
        emit IssuanceModuleRemoved(setToken, issuanceModule);
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
        revert ETHNotAccepted();
    }

    /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
    /*                                 private functions                                  */
    /*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

    function _getIssuanceModule(ISetToken setToken) private view returns (IIssuanceModule) {
        address issuanceModule = setTokenIssuanceModules[address(setToken)];
        if (address(issuanceModule) == address(0)) revert SetTokenNotWhitelisted();
        return IIssuanceModule(issuanceModule);
    }

    function _sellComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IIssuanceModule issuanceModule,
        IERC20 quoteAsset,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) private {
        (address[] memory components, ) = issuanceModule.getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentsLength = components.length;
        if (exchanges.length != componentsLength) revert ExchangeLengthMismatch();
        if (exchangePayloads.length != componentsLength) revert PayloadLengthMismatch();
        bool success;

        for (uint256 index = 0; index < componentsLength; index++) {
            if (components[index] == address(quoteAsset)) continue;
            address exchange = exchanges[index];
            bytes calldata exchangePayload = exchangePayloads[index];
            _requireWhitelistedFunction(exchange, exchangePayload);
            // Wont use native asset, so no need to pass msg.value
            (success, ) = exchange.call(exchangePayload);
            if (!success) revert ExchangeCallFailed();
        }
    }

    function _buyComponents(
        ISetToken setToken,
        uint256 setTokenQuantity,
        IERC20 quoteAsset,
        IIssuanceModule issuanceModule,
        address[] calldata exchanges,
        bytes[] calldata exchangePayloads
    ) private {
        bool success;
        (address[] memory components, uint256[] memory componentQuantities) = issuanceModule
            .getRequiredComponentUnitsForIssue(setToken, setTokenQuantity);
        uint256 componentsLength = components.length;
        if (exchanges.length != componentsLength) revert ExchangeLengthMismatch();
        if (exchangePayloads.length != componentsLength) revert PayloadLengthMismatch();

        for (uint256 index = 0; index < componentsLength; index++) {
            address componentAddress = components[index];
            if (componentAddress == address(quoteAsset)) continue;
            IERC20 component = IERC20(componentAddress);
            uint256 beforeComponentBalance = component.balanceOf(address(this));

            address exchange = exchanges[index];
            bytes calldata exchangePayload = exchangePayloads[index];
            _requireWhitelistedFunction(exchange, exchangePayload);
            // Wont use native asset, so no need to pass msg.value
            (success, ) = exchange.call(exchangePayload);
            if (!success) revert ExchangeCallFailed();

            uint256 afterComponentBalance = component.balanceOf(address(this));
            if (afterComponentBalance - beforeComponentBalance < componentQuantities[index])
                revert QuantityBoughtLessThanMinimum();
        }
    }

    function _requireWhitelistedFunction(address target, bytes calldata payload) private view {
        if (payload.length < 4) revert InvalidPayload();
        bytes4 selector = bytes4(payload[0:4]);
        bytes24 identifier = _calculateFunctionIdentifier(target, selector);
        if (!whitelistedFunctions[identifier]) revert FunctionNotWhitelisted();
    }

    function _calculateFunctionIdentifier(address target, bytes4 selector) private pure returns (bytes24 identifier) {
        bytes memory encodedData = abi.encodePacked(target, selector);
        identifier = bytes24(encodedData);
    }
}
