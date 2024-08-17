# Documentation for `TokenExchangeSetIssuer`

## Overview

This document provides detailed information on the usage and expected behavior of two key functions in our system: `buyComponentsAndIssueSetToken` and `redeemSetTokenAndExchangeTokens`. It also specifies the scope of the audit, including the exchanges that are whitelisted.

## Function Descriptions

### `buyComponentsAndIssueSetToken`

#### Purpose

This function is used to purchase components and issue a Set Token. It interacts with decentralized exchanges to acquire the necessary tokens and then issues a Set Token based on the acquired components.

#### Parameters

- `componentAddresses`: An array of addresses for the tokens to be purchased.
- `amounts`: An array of amounts corresponding to each token address.
- `recipient`: The address where the issued Set Token will be sent.
- `exchange`: The address of the exchange to be used for purchasing components (currently only Paraswap v6 and Uniswap Router are supported).

#### Example Usage

Please refer to this [test]().

### `redeemSetTokenAndExchangeTokens`

#### Purpose

This function allows for the redemption of a Set Token and the exchange of its components. It converts the Set Token back into the underlying tokens and exchanges them on a decentralized exchange.

#### Parameters

- `setTokenAddress`: The address of the Set Token to be redeemed.
- `amount`: The amount of Set Token to be redeemed.
- `exchange`: The address of the exchange to be used for exchanging the components (currently only Paraswap v6 and Uniswap Router are supported).

#### Example Usage
Please refer to this [test]().

### Audit Scope

For the purposes of this audit, only the following exchanges are whitelisted for usage on mainnet:

- **Paraswap v6**
  - Address: `0x6A000F20005980200259B80c5102003040001068`

- **Uniswap Router**
  - Address: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`