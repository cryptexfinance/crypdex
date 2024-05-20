// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {PreciseUnitMath} from "contracts/lib/PreciseUnitMath.sol";

contract TestPreciseUnitMath is Test {
    using PreciseUnitMath for uint256;
    using PreciseUnitMath for int256;

    struct UintInputUintResult {
        uint256 input1;
        uint256 input2;
        uint256 result;
    }

    struct IntInputIntResult {
        int256 input1;
        int256 input2;
        int256 result;
    }

    function testPreciseMulUint() external {
        UintInputUintResult[5] memory testCases = [
            UintInputUintResult(0, 2, 0),
            UintInputUintResult(2, 0, 0),
            UintInputUintResult(1e18, 2, 2),
            UintInputUintResult(66e17, 2, 13),
            UintInputUintResult(1e17, 2, 0)
        ];
        for (uint256 i = 0; i < testCases.length; i++) {
            UintInputUintResult memory testCase = testCases[i];
            assertEq(
                testCase.input1.preciseMul(testCase.input2),
                testCase.result
            );
        }
    }

    function testPreciseMulInt() external {
        IntInputIntResult[4] memory testCases = [
            IntInputIntResult(0, 2, 0),
            IntInputIntResult(2, 0, 0),
            IntInputIntResult(1e18, 2, 2),
            IntInputIntResult(66e17, 2, 13)
        ];
        for (uint256 i = 0; i < testCases.length; i++) {
            IntInputIntResult memory testCase = testCases[i];
            assertEq(
                testCase.input1.preciseMul(testCase.input2),
                testCase.result
            );
        }
    }

    function testPreciseMulCeil() external {
        UintInputUintResult[5] memory testCases = [
            UintInputUintResult(0, 2, 0),
            UintInputUintResult(2, 0, 0),
            UintInputUintResult(1e18, 2, 2),
            UintInputUintResult(66e17, 2, 14),
            UintInputUintResult(1e17, 2, 1)
        ];
        for (uint256 i = 0; i < testCases.length; i++) {
            UintInputUintResult memory testCase = testCases[i];
            assertEq(
                testCase.input1.preciseMulCeil(testCase.input2),
                testCase.result
            );
        }
    }
}
