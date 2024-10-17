// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

interface IFlokiTaxHandler {
    function getTax(address benefactor, address beneficiary, uint256 amount) external view returns (uint256);
}
