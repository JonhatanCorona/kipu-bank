// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title KipuEUR Token (KEUR)
/// @notice Token estable interno del banco Kipu, controlado únicamente por el contrato KipuBank
contract KipuEuro is ERC20, AccessControl {
    // --- Roles ---
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE"); // añadirlo


    // --- Variables configurables ---
    /// @notice Límite máximo de KEUR que un usuario puede tener en su wallet
    uint256 public keurWalletLimit;

    /// @notice Precio de 1 KEUR en ETH (por ejemplo, 0.02 ETH por 1 KEUR)
    uint256 public keurPriceInETH; // en wei

    /// @notice Monto mínimo de venta de KEUR (por ejemplo, 5 KEUR)
    uint256 public keurMinSellAmount;

    // --- Errores personalizados ---
    error WalletKEURLimited();
    error InvalidAmount();

    // --- Constructor ---
    // --- Constructor ---
    constructor(
        address kipuBank,
        uint256 _keurWalletLimit,
        uint256 _keurPriceInETH,
        uint256 _keurMinSellAmount
    ) ERC20("KipuEuro", "KEUR") {
        _grantRole(DEFAULT_ADMIN_ROLE, kipuBank);
        _grantRole(SUPER_ADMIN_ROLE, kipuBank);

        keurWalletLimit = _keurWalletLimit;
        keurPriceInETH = _keurPriceInETH;
        keurMinSellAmount = _keurMinSellAmount;
    }

    // --- Modificador para ADMIN o SUPER_ADMIN ---
    modifier onlyAdminOrSuper() {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(SUPER_ADMIN_ROLE, msg.sender)) {
            revert("Not admin or super admin");
        }
        _;
    }

    // --- Funciones del token ---

    /// @notice Mintea nuevos tokens (solo el banco puede hacerlo)
    function mint(address to, uint256 amount)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        uint256 total = balanceOf(to) + amount;
        if (total > keurWalletLimit) revert WalletKEURLimited();
        _mint(to, amount);
    }

    /// @notice Quita tokens de circulación (solo el banco)
    function burn(address from, uint256 amount)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        _burn(from, amount);
    }

    /// @notice Permite actualizar el límite máximo de KEUR por wallet
     function setWalletLimit(uint256 newLimit)
        external
        onlyAdminOrSuper
    {
        keurWalletLimit = newLimit;
    }
    
    /// @notice Permite actualizar el precio ETH → KEUR
    function setPrice(uint256 newPriceInETH)
        external
        onlyRole(SUPER_ADMIN_ROLE)
    {
        keurPriceInETH = newPriceInETH;
    }

    /// @notice Permite actualizar el monto mínimo de venta
   function setMinSellAmount(uint256 newMin)
        external
        onlyAdminOrSuper
    {
        keurMinSellAmount = newMin;
    }


}
