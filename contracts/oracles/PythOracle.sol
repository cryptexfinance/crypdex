// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";


contract PythOracle {
    IPyth pyth;
    bytes32 priceId;

    constructor(address pythContract, bytes32 _priceId) {
        pyth = IPyth(pythContract);
        priceId = _priceId;
    }

    function read() external view returns (uint256 price){
        PythStructs.Price memory pythPrice = pyth.getPrice(priceId);
        price = (uint(uint64(pythPrice.price)) * (10 ** 18)) / (10 ** uint8(uint32(-1 * pythPrice.expo)));
    }
}
