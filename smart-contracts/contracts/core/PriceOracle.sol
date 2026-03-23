// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PriceOracle is Ownable {
    mapping(address => uint256) private _prices;

    event PriceUpdated(address indexed asset, uint256 price);

    constructor() Ownable(msg.sender) {}

    function setPrice(address asset, uint256 price) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        require(price > 0, "Invalid price");
        _prices[asset] = price;
        emit PriceUpdated(asset, price);
    }

    function setBatchPrices(
        address[] calldata assets,
        uint256[] calldata prices
    ) external onlyOwner {
        require(assets.length == prices.length, "Length mismatch");
        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != address(0), "Invalid asset");
            require(prices[i] > 0, "Invalid price");
            _prices[assets[i]] = prices[i];
            emit PriceUpdated(assets[i], prices[i]);
        }
    }

    function getPrice(address asset) external view returns (uint256) {
        uint256 price = _prices[asset];
        require(price > 0, "Price not set");
        return price;
    }
}
