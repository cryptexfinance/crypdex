// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;


struct GenericData {
    address srcToken;
    address destToken;
    uint256 fromAmount;
    uint256 toAmount;
    uint256 quotedAmount;
    bytes32 metadata;
    address payable beneficiary;
}

struct BalancerV2Data {
    uint256 fromAmount;
    uint256 toAmount;
    uint256 quotedAmount;
    bytes32 metadata;
    uint256 beneficiaryAndApproveFlag;
}

struct CurveV1Data {
    uint256 curveData;
    uint256 curveAssets;
    address srcToken;
    address destToken;
    uint256 fromAmount;
    uint256 toAmount;
    uint256 quotedAmount;
    bytes32 metadata;
    address payable beneficiary;
}

struct CurveV2Data {
    uint256 curveData;
    uint256 i;
    uint256 j;
    address poolAddress;
    address srcToken;
    address destToken;
    uint256 fromAmount;
    uint256 toAmount;
    uint256 quotedAmount;
    bytes32 metadata;
    address payable beneficiary;
}

struct UniswapV2Data {
    address srcToken;
    address destToken;
    uint256 fromAmount;
    uint256 toAmount;
    uint256 quotedAmount;
    bytes32 metadata;
    address payable beneficiary;
    bytes pools;
}

struct UniswapV3Data {
    address srcToken;
    address destToken;
    uint256 fromAmount;
    uint256 toAmount;
    uint256 quotedAmount;
    bytes32 metadata;
    address payable beneficiary;
    bytes pools;
}

interface IParaswapV6 {
    function swapExactAmountIn(
        address executor,
        GenericData calldata swapData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata executorData
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountOut(
        address executor,
        GenericData calldata swapData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata executorData
    )
        external
        payable
        returns (uint256 spentAmount, uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountInOnBalancerV2(
        BalancerV2Data calldata balancerData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata data
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountOutOnBalancerV2(
        BalancerV2Data calldata balancerData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata data
    )
        external
        payable
        returns (uint256 spentAmount, uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountInOnCurveV1(
        CurveV1Data calldata curveV1Data,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountInOnCurveV2(
        CurveV2Data calldata curveV2Data,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountInOnUniswapV2(
        UniswapV2Data calldata uniData,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountOutOnUniswapV2(
        UniswapV2Data calldata uniData,
        uint256 partnerAndFee,
        bytes calldata permit
    )
        external
        payable
        returns (uint256 spentAmount, uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountInOnUniswapV3(
        UniswapV3Data calldata uniData,
        uint256 partnerAndFee,
        bytes calldata permit
    ) external payable returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);

    function swapExactAmountOutOnUniswapV3(
        UniswapV3Data calldata uniData,
        uint256 partnerAndFee,
        bytes calldata permit
    )
        external
        payable
        returns (uint256 spentAmount, uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);
}
