// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title KipuUSD Token (KUSD)
/// @notice Token estable interno del ecosistema Kipu, solo gestionado por el KipuBank
contract KipuDolar is ERC20, AccessControl {

    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
        bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");


    /// @notice Límite máximo de KUSD que un usuario puede tener en su wallet
    uint256 public kusdWalletLimit;

    /// @notice Precio de 1 KUSD en ETH (ejemplo: 0.01 ETH por 1 KUSD)
    uint256 public kusdPriceInETH; // en wei

    /// @notice Monto mínimo de venta de KUSD (por ejemplo, 5 KUSD)
    uint256 public kusdMinSellAmount;

    // --- Errores personalizados ---
    error WalletKUSDLimited();
    error InvalidAmount();

    constructor(
        address kipuBank,
        uint256 _kusdWalletLimit,
        uint256 _kusdPriceInETH,
        uint256 _kusdMinSellAmount
    ) ERC20("KipuDolar", "KUSD") {
        _grantRole(DEFAULT_ADMIN_ROLE, kipuBank);
        _grantRole(SUPER_ADMIN_ROLE, kipuBank);

        kusdWalletLimit = _kusdWalletLimit;
        kusdPriceInETH = _kusdPriceInETH;
        kusdMinSellAmount = _kusdMinSellAmount;
    }

    /// @notice Mintea nuevos tokens (solo el banco puede hacerlo)
    function mint(address to, uint256 amount)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        uint256 total = balanceOf(to) + amount;
        if (total > kusdWalletLimit) revert WalletKUSDLimited();
        _mint(to, amount);
    }

    /// @notice Quita tokens del usuario (solo el banco)
    function burn(address from, uint256 amount)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        _burn(from, amount);
    }

    /// @notice Permite actualizar el límite máximo por wallet
    function setWalletLimit(uint256 newLimit)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        kusdWalletLimit = newLimit;
    }

    /// @notice Permite actualizar el precio ETH → KUSD
    function setPrice(uint256 newPriceInETH)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        kusdPriceInETH = newPriceInETH;
    }

    /// @notice Permite actualizar el monto mínimo de venta
    function setMinSellAmount(uint256 newMin)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        kusdMinSellAmount = newMin;
    }
}
