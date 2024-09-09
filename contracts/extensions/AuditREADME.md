# Documentation for `TokenExchangeSetIssuer`

## Overview

This document provides detailed information on the usage and expected behavior of two key functions in our system: `buyComponentsAndIssueSetToken` and `redeemSetTokenAndExchangeTokens`. It also specifies the scope of the audit, including the exchanges that are whitelisted.

## Contract to Audit
There's only one contract to audit: `contracts/extensions/TokenExchangeSetIssuer.sol` 

## Function Descriptions

### `buyComponentsAndIssueSetToken`

#### Purpose

This function is used to purchase components and issue a Set Token. It interacts with decentralized exchanges to acquire the necessary tokens and then issues a Set Token based on the acquired components.

#### Parameters

- `setToken`: The instance of the SetToken contract.
- `setTokenQuantity`: The quantity of the SetToken to issue.
- `quoteAsset`: The instance of the IERC20 token used for buying the underlying components.
- `totalQuoteAmount`: The maximum amount the user pays for buying the underlying components.
- `exchangeParams`: An array of containing data to buy each component.

#### Example Usage

Please refer to this [test](https://github.com/cryptexfinance/crypdex/blob/d0de0f9a85bc632fd88fd42c2028705b089836fe/test/unit/ForkTestTokenExchangeSetIssuer.t.sol#L168-L215).

### `redeemSetTokenAndExchangeTokens`

#### Purpose

This function allows for the redemption of a Set Token and the exchange of its components. It converts the Set Token back into the underlying tokens and exchanges them on a decentralized exchange.

#### Parameters

- `setToken`: Instance of the SetToken contract.
- `setTokenQuantity`: Quantity of the SetToken to redeem. 
- `quoteAsset`: Instance of the IERC20 token received after selling the underlying components. 
- `minQuoteAmount`: The minimum `quoteAsset` amount the user expects to receive after selling the underlying components. 
- `exchangeParams`: An array of containing data to sell each component. 


#### Example Usage
Please refer to this [test](https://github.com/cryptexfinance/crypdex/blob/d0de0f9a85bc632fd88fd42c2028705b089836fe/test/unit/ForkTestTokenExchangeSetIssuer.t.sol#L335-L370).
