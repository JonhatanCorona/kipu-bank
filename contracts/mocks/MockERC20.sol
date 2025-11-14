// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Mock ERC20 Token
/// @notice Token ERC20 genérico para pruebas
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
        _mint(msg.sender, 1_000_000 * 10 ** decimals_); // Mint inicial al deployer
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Permite mintear tokens de prueba
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}