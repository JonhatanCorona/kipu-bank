// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Mock UniswapV2Factory
/// @notice Simula la creación de pares sin lógica interna
contract MockUniswapFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        pair = address(uint160(uint256(keccak256(abi.encodePacked(tokenA, tokenB, block.timestamp)))));
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
        allPairs.push(pair);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}