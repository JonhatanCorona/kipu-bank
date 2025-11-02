// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title PriceOracle
/// @notice Maneja los oráculos Chainlink de ETH/USD y ETH/EUR para el ecosistema Kipu
contract PriceOracle {
    /// @notice Oráculo Chainlink ETH/USD
    AggregatorV3Interface public immutable ethUsdPriceFeed;

    /// @notice Oráculo Chainlink ETH/EUR
    AggregatorV3Interface public immutable ethEurPriceFeed;

    /// @param _ethUsdFeed Dirección del oráculo ETH/USD
    constructor(address _ethUsdFeed) {
        require(_ethUsdFeed != address(0), "Invalid feed");
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdFeed);
    }

    /// @notice Obtiene el precio ETH/USD del oráculo Chainlink
    /// @return price Precio ETH/USD con 8 decimales
    function getEthUsdPrice() public view returns (uint256 price) {
        (, int256 answer,,,) = ethUsdPriceFeed.latestRoundData();
        require(answer > 0, "Invalid price");
        price = uint256(answer);
    }
}
