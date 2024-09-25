// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin-contracts-5/contracts/token/ERC20/IERC20.sol";
import { ISetToken } from "./ISetToken.sol";

interface IIssuanceModule {

    event SetTokenIssued(
        address indexed _setToken,
        address indexed _issuer,
        address indexed _to,
        address _hookContract,
        uint256 _quantity
    );

    event SetTokenRedeemed(
        address indexed _setToken,
        address indexed _redeemer,
        address indexed _to,
        uint256 _quantity
    );

    function issue(
        ISetToken _setToken,
        uint256 _quantity,
        address _to
    ) external;

    function redeem(
        ISetToken _setToken,
        uint256 _quantity,
        address _to
    ) external;

    function removeModule() external;

    function getRequiredComponentUnitsForIssue(
        ISetToken _setToken,
        uint256 _quantity
    ) external view returns (address[] memory, uint256[] memory);
}
