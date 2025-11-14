// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapRouter {
    address public immutable WETH;
    address public immutable FACTORY;

    // mockRates[tokenIn][tokenOut] = rate
    // La tasa es la cantidad de tokenOut que se obtiene por 1 tokenIn, en 18 decimales
    mapping(address => mapping(address => uint256)) public mockRates;

    constructor(address _weth, address _factory) {
        WETH = _weth;
        FACTORY = _factory;
    }

    /// @notice Setea una tasa mock entre dos tokens (18 decimales)
    function setRate(address tokenIn, address tokenOut, uint256 rate) external {
        mockRates[tokenIn][tokenOut] = rate;
    }

    /// @notice Devuelve la factory
    function factory() external view returns (address) {
        return FACTORY;
    }

    /// @notice Simula swap ETH → token
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external payable returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        uint256 rate = mockRates[path[0]][path[1]];
        require(rate > 0, "Rate not set");

        // ETH en wei, rate en 18 decimales
        uint256 amountOut = (msg.value * rate) / 1e18;
        require(amountOut >= amountOutMin, "Insufficient output amount");

        IERC20(path[1]).transfer(to, amountOut);

        amounts = new uint256[](2) ;
        amounts[0] = msg.value;
        amounts[1] = amountOut;
    }

    /// @notice Simula swap token → token
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");

        // Transferir token de entrada al contrato
        bool ok = IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        require(ok, "TransferFrom failed");

        uint256 rate = mockRates[path[0]][path[1]];
        require(rate > 0, "Rate not set");

        // amountIn en 18 decimales, rate en 18 decimales → output en 18 decimales
        uint256 amountOut = (amountIn * rate) / 1e18;
        require(amountOut >= amountOutMin, "Insufficient output amount");

        IERC20(path[1]).transfer(to, amountOut);

        // Array de amounts (solo path[0] y path[1] son necesarios)
        amounts = new uint256[](2) ;
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    /// @notice Simula swap de token → WETH → USDC
    function swapExactTokensForTokens3(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address weth,
        address usdc,
        address to
    ) external returns (uint256[] memory amounts) {
        // Transferir token de entrada al contrato
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amountIn);
        require(ok, "TransferFrom failed");

        // Crear array con tamaño 3 para los pasos
        amounts = new uint256[](3) ;
        amounts[0] = amountIn;

        // Paso 1: token → WETH
        uint256 amountWETH = (amountIn * mockRates[token][weth]) / 1e18;
        require(amountWETH > 0, "Rate token to WETH not set");
        amounts[1] = amountWETH;

        // Paso 2: WETH → USDC
        uint256 amountUSDC = (amountWETH * mockRates[weth][usdc]) / 1e18;
        require(amountUSDC >= amountOutMin, "Insufficient output amount");
        amounts[2] = amountUSDC;

        // Transferir USDC al destinatario
        IERC20(usdc).transfer(to, amountUSDC);
    }
}
