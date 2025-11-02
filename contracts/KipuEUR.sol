// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title KipuEUR Token (KEUR)
/// @notice Token estable interno del banco Kipu, controlado únicamente por el contrato KipuBank
/// @dev Funciona como ERC20 estándar con roles de administración y restricciones de wallet/venta
contract KipuEuro is ERC20, AccessControl {

// --- Roles ---
/// @notice Rol de super administrador con permisos totales sobre el token
bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
/// @notice Rol de administrador con permisos limitados sobre el token
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

// --- Variables configurables ---
/// @notice Límite máximo de KEUR que un usuario puede tener en su wallet
uint256 public keurWalletLimit;

/// @notice Precio de 1 KEUR en ETH (expresado en wei)
uint256 public keurPriceInETH;

/// @notice Monto máximo de KEUR que un usuario puede vender de una sola vez
uint256 public keurMaxSellAmount;

// --- Errores personalizados ---
/// @notice Se lanza cuando se excede el límite de KEUR por wallet
error WalletKEURLimited();
/// @notice Se lanza cuando un monto es inválido (ej. cero)
error InvalidAmount();

// --- Constructor ---
/// @param kipuBank Dirección del contrato KipuBank que tendrá permisos de administración
/// @param _keurWalletLimit Límite inicial de KEUR por wallet
/// @param _keurPriceInETH Precio inicial de KEUR en ETH (wei)
/// @param _keurMaxSellAmount Monto máximo inicial de venta de KEUR
constructor(
    address kipuBank,
    uint256 _keurWalletLimit,
    uint256 _keurPriceInETH,
    uint256 _keurMaxSellAmount
) ERC20("KipuEuro", "KEUR") {
    // Asignar roles de administración al banco
    _grantRole(DEFAULT_ADMIN_ROLE, kipuBank);
    _grantRole(SUPER_ADMIN_ROLE, kipuBank);

    // Inicializar variables configurables
    keurWalletLimit = _keurWalletLimit;
    keurPriceInETH = _keurPriceInETH;
    keurMaxSellAmount = _keurMaxSellAmount;
}

// --- Modificador ---
/// @notice Restringe acceso a funciones solo a ADMIN o SUPER_ADMIN
modifier onlyAdminOrSuper() {
    if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(SUPER_ADMIN_ROLE, msg.sender)) {
        revert("Not admin or super admin");
    }
    _;
}

// --- Funciones del token ---

/// @notice Mintea nuevos tokens KEUR a una wallet específica
/// @dev Solo el SUPER_ADMIN puede llamar esta función
/// @param to Dirección del usuario que recibirá los tokens
/// @param amount Cantidad de tokens a mintear
/// @custom:revert Lanza WalletKEURLimited si se excede el límite de KEUR por wallet
function mint(address to, uint256 amount)
    external
    onlyRole(SUPER_ADMIN_ROLE)
{
    uint256 total = balanceOf(to) + amount;
    if (total > keurWalletLimit) revert WalletKEURLimited();
    _mint(to, amount);
}

/// @notice Elimina tokens KEUR de circulación desde una wallet
/// @dev Solo el SUPER_ADMIN puede llamar esta función
/// @param from Dirección del usuario desde la cual se quemarán los tokens
/// @param amount Cantidad de tokens a quemar
function burn(address from, uint256 amount)
    external
    onlyRole(SUPER_ADMIN_ROLE)
{
    _burn(from, amount);
}

/// @notice Actualiza el límite máximo de KEUR por wallet
/// @dev Puede ser llamado por ADMIN o SUPER_ADMIN
/// @param newLimit Nuevo límite de KEUR por wallet
function setWalletLimit(uint256 newLimit)
    external
    onlyAdminOrSuper
{
    keurWalletLimit = newLimit;
}

/// @notice Actualiza el precio de 1 KEUR en ETH
/// @dev Solo el SUPER_ADMIN puede modificarlo
/// @param newPriceInETH Nuevo precio de KEUR expresado en wei
function setPrice(uint256 newPriceInETH)
    external
    onlyRole(SUPER_ADMIN_ROLE)
{
    keurPriceInETH = newPriceInETH;
}

/// @notice Actualiza el monto máximo de venta de KEUR
/// @dev Puede ser llamado por ADMIN o SUPER_ADMIN
/// @param newMax Nuevo monto máximo de venta
function setMinSellAmount(uint256 newMax)
    external
    onlyAdminOrSuper
{
    keurMaxSellAmount = newMax;
}

}
