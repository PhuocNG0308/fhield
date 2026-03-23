// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

library FHELendingMath {
    function mulByPlaintext(euint64 encrypted, uint256 plaintext) internal returns (euint64) {
        return FHE.mul(encrypted, FHE.asEuint64(uint64(plaintext)));
    }

    function divByPlaintext(euint64 encrypted, uint256 plaintext) internal returns (euint64) {
        return FHE.div(encrypted, FHE.asEuint64(uint64(plaintext)));
    }

    function encryptedMin(euint64 a, euint64 b) internal returns (euint64) {
        return FHE.select(FHE.lte(a, b), a, b);
    }

    function encryptedMax(euint64 a, euint64 b) internal returns (euint64) {
        return FHE.select(FHE.gte(a, b), a, b);
    }

    function isZero(euint64 value) internal returns (ebool) {
        return FHE.eq(value, FHE.asEuint64(0));
    }

    function encryptedZero() internal returns (euint64) {
        return FHE.asEuint64(0);
    }
}
