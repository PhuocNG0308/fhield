// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../tokens/FHERC20Wrapper.sol";

contract AssetConfig is Ownable {
    struct AssetInfo {
        address underlying;
        address wrapper;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 reserveFactor;
        uint8 decimals;
        bool isActive;
    }

    uint256 public constant PERCENTAGE_PRECISION = 10000;

    mapping(address => AssetInfo) public assets;
    address[] public assetList;

    event AssetAdded(address indexed underlying, address wrapper, uint256 ltv, uint256 liquidationThreshold);
    event AssetUpdated(address indexed underlying, uint256 ltv, uint256 liquidationThreshold);
    event AssetToggled(address indexed underlying, bool isActive);

    constructor() Ownable(msg.sender) {}

    function addAsset(
        address underlying,
        address wrapper,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 reserveFactor,
        uint8 decimals_
    ) external onlyOwner {
        require(assets[underlying].underlying == address(0), "Already added");
        require(ltv <= liquidationThreshold, "LTV > threshold");
        require(liquidationThreshold <= PERCENTAGE_PRECISION, "Threshold > 100%");
        require(reserveFactor <= PERCENTAGE_PRECISION, "RF > 100%");

        assets[underlying] = AssetInfo({
            underlying: underlying,
            wrapper: wrapper,
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            reserveFactor: reserveFactor,
            decimals: decimals_,
            isActive: true
        });

        assetList.push(underlying);
        emit AssetAdded(underlying, wrapper, ltv, liquidationThreshold);
    }

    function updateAsset(
        address underlying,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 reserveFactor
    ) external onlyOwner {
        require(assets[underlying].underlying != address(0), "Not found");
        require(ltv <= liquidationThreshold, "LTV > threshold");
        require(reserveFactor <= PERCENTAGE_PRECISION, "RF > 100%");

        assets[underlying].ltv = ltv;
        assets[underlying].liquidationThreshold = liquidationThreshold;
        assets[underlying].liquidationBonus = liquidationBonus;
        assets[underlying].reserveFactor = reserveFactor;
        emit AssetUpdated(underlying, ltv, liquidationThreshold);
    }

    function toggleAsset(address underlying, bool isActive) external onlyOwner {
        require(assets[underlying].underlying != address(0), "Not found");
        assets[underlying].isActive = isActive;
        emit AssetToggled(underlying, isActive);
    }

    function getAsset(address underlying) external view returns (AssetInfo memory) {
        require(assets[underlying].underlying != address(0), "Not found");
        return assets[underlying];
    }

    function getAssetCount() external view returns (uint256) {
        return assetList.length;
    }

    function isSupported(address underlying) external view returns (bool) {
        return assets[underlying].underlying != address(0) && assets[underlying].isActive;
    }
}
