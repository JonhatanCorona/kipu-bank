// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./KipuUSD.sol";
import "./KipuEUR.sol";
import "./PriceOracle.sol";

/// @title KipuBank
/// @notice Banco descentralizado del ecosistema Kipu con bóvedas para ETH, KUSD y KEUR.
/// @dev Administra depósitos, retiros, compras/ventas y estadísticas globales de movimientos.
contract KipuBank is AccessControl, ReentrancyGuard, Pausable, PriceOracle {

// ============================
// ROLES
// ============================

/// @notice Rol de administrador
/// @dev Usuarios con este rol pueden gestionar ciertas operaciones del banco como actualizar límites, comprar/vender tokens, y consultar estadísticas.
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

/// @notice Rol de superadministrador
/// @dev Usuarios con este rol tienen todos los privilegios del banco, incluyendo la gestión de roles, actualización de precios, límites máximos y pausado del contrato.
bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");


// ============================
// ESTRUCTURAS
// ============================

/// @notice Información de actividad de un usuario dentro del banco
/// @dev Guarda contadores y totales de depósitos y retiros por tipo de activo
struct UserInfo {
    /// @notice Número total de depósitos realizados por el usuario (todos los activos)
    uint256 depositCount;

    /// @notice Número total de retiros realizados por el usuario (todos los activos)
    uint256 withdrawalCount;

    /// @notice Total de ETH depositado por el usuario en la bóveda
    uint256 ethDeposits;

    /// @notice Total de ETH retirado por el usuario de la bóveda
    uint256 ethWithdrawals;

    /// @notice Total de KUSD depositado por el usuario en la bóveda
    uint256 usdDeposits;

    /// @notice Total de KUSD retirado por el usuario de la bóveda
    uint256 usdWithdrawals;

    /// @notice Total de KEUR depositado por el usuario en la bóveda
    uint256 eurDeposits;

    /// @notice Total de KEUR retirado por el usuario de la bóveda
    uint256 eurWithdrawals;
}

/// @notice Totales globales del banco
/// @dev Guarda los balances, depósitos y retiros por tipo de activo y contadores de movimientos
struct BankTotals {
    /// @notice Balance total de ETH que posee el banco
    uint256 ethBalance;

    /// @notice Suma de todos los depósitos de ETH realizados por los usuarios
    uint256 ethDeposits;

    /// @notice Suma de todos los retiros de ETH realizados por los usuarios
    uint256 ethWithdrawals;

    /// @notice Balance total de KUSD que posee el banco
    uint256 usdBalance;

    /// @notice Suma de todos los depósitos de KUSD realizados por los usuarios
    uint256 usdDeposits;

    /// @notice Suma de todos los retiros de KUSD realizados por los usuarios
    uint256 usdWithdrawals;

    /// @notice Balance total de KEUR que posee el banco
    uint256 eurBalance;

    /// @notice Suma de todos los depósitos de KEUR realizados por los usuarios
    uint256 eurDeposits;

    /// @notice Suma de todos los retiros de KEUR realizados por los usuarios
    uint256 eurWithdrawals;

    /// @notice Número total de depósitos realizados en el banco (todos los activos)
    uint256 depositCount;

    /// @notice Número total de retiros realizados en el banco (todos los activos)
    uint256 withdrawalCount;
}

// ============================
// VARIABLES DE ESTADO
// ============================

/// @notice Mapeo de direcciones a sus balances de ETH en la bóveda del banco
mapping(address => uint256) public ethVaults;

/// @notice Mapeo de direcciones a sus balances de KUSD en la bóveda del banco
mapping(address => uint256) public usdVaults;

/// @notice Mapeo de direcciones a sus balances de KEUR en la bóveda del banco
mapping(address => uint256) public eurVaults;

/// @notice Información detallada de cada usuario (depósitos, retiros por tipo de activo)
mapping(address => UserInfo) private users;

/// @notice Contrato del token KUSD (KipuDolar)
KipuDolar public udsToken;

/// @notice Contrato del token KEUR (KipuEuro)
KipuEuro public eurToken;

/// @notice Límite máximo de retiro permitido por transacción en ETH
uint256 public immutable withdrawalLimit;

/// @notice Límite global máximo de depósitos permitidos en el banco
uint256 public bankCapUSD;

/// @notice Total de ETH actualmente depositado en el banco
uint256 public totalDeposits;

// --- Totales por tipo de moneda ---

/// @notice Total de ETH depositado por todos los usuarios
uint256 private totalEthDeposited;

/// @notice Total de ETH retirado por todos los usuarios
uint256 private totalEthWithdrawn;

/// @notice Total de KUSD depositado por todos los usuarios
uint256 private totalUsdDeposited;

/// @notice Total de KUSD retirado por todos los usuarios
uint256 private totalUsdWithdrawn;

/// @notice Total de KEUR depositado por todos los usuarios
uint256 private totalEurDeposited;

/// @notice Total de KEUR retirado por todos los usuarios
uint256 private totalEurWithdrawn;

// --- Totales de movimientos ---

/// @notice Número total de depósitos realizados en el banco
uint256 private totalDepositCount;

/// @notice Número total de retiros realizados en el banco
uint256 private totalWithdrawalCount;

// ============================
// EVENTOS
// ============================

/// @notice Emitido cuando un usuario deposita ETH exitosamente
/// @param user Dirección del usuario que realizó el depósito
/// @param amount Monto de ETH depositado en wei
event DepositETH(
    address indexed user,
    uint256 amount
);

/// @notice Emitido cuando un usuario retira ETH exitosamente
/// @param user Dirección del usuario que realizó el retiro
/// @param amount Monto de ETH retirado en wei
event WithdrawETH(
    address indexed user,
    uint256 amount
);

/// @notice Emitido cuando un usuario deposita KUSD exitosamente
/// @param user Dirección del usuario que realizó el depósito
/// @param amount Monto de KUSD depositado
event DepositUSD(
    address indexed user,
    uint256 amount
);

/// @notice Emitido cuando un usuario retira KUSD exitosamente
/// @param user Dirección del usuario que realizó el retiro
/// @param amount Monto de KUSD retirado
event WithdrawUSD(
    address indexed user,
    uint256 amount
);

/// @notice Emitido cuando un usuario deposita KEUR exitosamente
/// @param user Dirección del usuario que realizó el depósito
/// @param amount Monto de KEUR depositado
event DepositEUR(
    address indexed user,
    uint256 amount
);

/// @notice Emitido cuando un usuario retira KEUR exitosamente
/// @param user Dirección del usuario que realizó el retiro
/// @param amount Monto de KEUR retirado
event WithdrawEUR(
    address indexed user,
    uint256 amount
);

// ============================
// ERRORES
// ============================

/// @notice Error lanzado cuando se intenta operar con un monto inválido (por ejemplo, 0 ETH o 0 tokens)
error InvalidAmount();

/// @notice Error lanzado al intentar un depósito que exceda la capacidad máxima del banco
/// @param attempted Monto total que se intentó depositar incluyendo depósitos anteriores
/// @param cap Límite máximo de depósitos permitido en el banco
error BankCapExceeded(uint256 attempted, uint256 cap);

/// @notice Error lanzado al intentar retirar más de lo permitido por el límite de retiro
/// @param attempted Monto que se intentó retirar
/// @param limit Límite máximo de retiro por transacción
error ExceedsWithdrawalLimit(uint256 attempted, uint256 limit);

/// @notice Error lanzado cuando el usuario intenta retirar más ETH del que tiene disponible
/// @param requested Monto de ETH solicitado para retiro
/// @param available Saldo actual de ETH del usuario
error InsufficientETH(uint256 requested, uint256 available);

/// @notice Error lanzado cuando la transferencia de ETH falla (por ejemplo, si falla el `call`)
error TransferFailed();

/// @notice Error lanzado cuando se pasa una dirección inválida (por ejemplo, 0x0) al configurar tokens
error InvalidTokenAddress();

/// @notice Error lanzado al intentar reducir el límite máximo del banco por debajo de los depósitos existentes
/// @param newCap Nuevo límite propuesto
/// @param totalDeposits Total de depósitos actualmente en el banco
error NewCapBelowDeposits(uint256 newCap, uint256 totalDeposits);

/// @notice Error lanzado al intentar vender más tokens de los permitidos por el límite máximo de venta
/// @param attempted Cantidad de tokens que se intentó vender
/// @param maxAllowed Máximo permitido de tokens a vender
error ExceedsMaxSellAmount(uint256 attempted, uint256 maxAllowed);

// ============================
// CONSTRUCTOR
// ============================

/// @notice Inicializa el contrato KipuBank con límites de retiro, capacidad del banco y oráculo de precios ETH/USD
/// @param _withdrawalLimit Límite máximo de retiro permitido por transacción en wei
/// @param _bankCapInUSD_18decimals Límite global máximo de depósitos permitidos en el banco en dolares
/// @param _ethUsdFeed Dirección del contrato del oráculo de precio ETH/USD que se usará para conversiones
/// @dev Valida que los parámetros de límite y cap no sean cero. Asigna roles iniciales al deployer:
///      - DEFAULT_ADMIN_ROLE
///      - SUPER_ADMIN_ROLE
///      - ADMIN_ROLE
constructor(
    uint256 _withdrawalLimit,
    uint256 _bankCapInUSD_18decimals,
    address _ethUsdFeed
) PriceOracle(_ethUsdFeed) {
    // Revertir si los parámetros son inválidos
    if (_withdrawalLimit == 0 || _bankCapInUSD_18decimals == 0) revert InvalidAmount();

    // Asignación de variables de estado
    withdrawalLimit = _withdrawalLimit;
    bankCapUSD = _bankCapInUSD_18decimals;

    // Configuración de roles iniciales para el deployer
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(SUPER_ADMIN_ROLE, msg.sender);
    _grantRole(ADMIN_ROLE, msg.sender);
}

// ============================
// MODIFICADORES
// ============================

/// @notice Verifica que la cantidad proporcionada sea mayor que cero
/// @param amount Cantidad a validar
/// @dev Revertirá con `InvalidAmount` si amount es 0
modifier validAmount(uint256 amount) {
    if (amount == 0) revert InvalidAmount();
    _;
}

/// @notice Verifica que el depósito no supere la capacidad máxima del banco
/// @param amount Cantidad a depositar
/// @dev Revertirá con `BankCapExceeded` si el depósito excede `bankCap`
modifier underBankCap(uint256 amount) {
    // 1. Obtener el precio actual de ETH/USD (8 decimales)
    uint256 ethPrice_8decimals = getEthUsdPrice();
    if (ethPrice_8decimals == 0) revert InvalidAmount();

    // 2. Calcular el Límite de ETH (en wei, 18 decimales) que corresponde al bankCapUSD
    // bankCapUSD (18 dec) * 1e8 / ethPrice_8decimals (8 dec) = Max ETH (18 dec)
    uint256 maxEthAllowed = (bankCapUSD * 1e8) / ethPrice_8decimals;
    
    // 3. Comparar el total actual + el nuevo depósito (en ETH) con el límite dinámico de ETH
    if (totalDeposits + amount > maxEthAllowed) {
        // En el error, mostramos el total ETH actual y el límite ETH dinámico (maxEthAllowed)
        revert BankCapExceeded(totalDeposits + amount, maxEthAllowed);
    }
    _;
}

/// @notice Restringe funciones a administradores o super administradores
/// @dev Revertirá con mensaje "Not admin or super admin" si quien llama no tiene `ADMIN_ROLE` ni `SUPER_ADMIN_ROLE`
modifier onlyAdminOrSuper() {
    if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(SUPER_ADMIN_ROLE, msg.sender)) {
        revert("Not admin or super admin");
    }
    _;
}

// ============================
// CONFIGURACIÓN DE TOKENS
// ============================

/// @notice Asigna los contratos de los tokens internos KUSD y KEUR al KipuBank
/// @param _udsToken Dirección del contrato KipuDolar (KUSD)
/// @param _eurToken Dirección del contrato KipuEuro (KEUR)
/// @dev Solo puede ser llamada por `SUPER_ADMIN_ROLE`. Revertirá con `InvalidTokenAddress` si alguna dirección es cero.
function setTokens(address _udsToken, address _eurToken)
    external
    onlyRole(SUPER_ADMIN_ROLE)
{
    if (_udsToken == address(0) || _eurToken == address(0)) revert InvalidTokenAddress();
    udsToken = KipuDolar(_udsToken);
    eurToken = KipuEuro(_eurToken);
}

// ============================
// DEPÓSITO Y RETIRO ETH
// ============================

/// @notice Permite a un usuario depositar ETH en su bóveda personal dentro del banco
/// @dev Aplica los modificadores `whenNotPaused`, `nonReentrant`, `validAmount` y `underBankCap`
///      Actualiza balances individuales y totales, así como contadores de depósitos
///      Emite el evento `DepositETH`
function depositETH()
    external
    payable
    whenNotPaused
    nonReentrant
    validAmount(msg.value)
    underBankCap(msg.value)
{
    // Actualiza el balance del usuario
    ethVaults[msg.sender] += msg.value;

    // Actualiza el total de depósitos del banco
    totalDeposits += msg.value;

    // Actualiza contadores globales y por usuario
    totalDepositCount++;
    totalEthDeposited += msg.value;
    users[msg.sender].depositCount++;
    users[msg.sender].ethDeposits += msg.value;

    // Emite evento de depósito
    emit DepositETH(msg.sender, msg.value);
}

/// @notice Permite a un usuario retirar ETH de su bóveda personal
/// @param amount Cantidad de ETH a retirar en wei
/// @dev Aplica los modificadores `whenNotPaused`, `nonReentrant` y `validAmount`
///      Revertirá si el monto excede `withdrawalLimit` o el balance del usuario
///      Actualiza balances individuales y totales, así como contadores de retiros
///      Emite el evento `WithdrawETH`
function withdrawETH(uint256 amount)
    external
    whenNotPaused
    nonReentrant
    validAmount(amount)
{
    // Verifica límite de retiro
    if (amount > withdrawalLimit) revert ExceedsWithdrawalLimit(amount, withdrawalLimit);

    // Obtiene balance del usuario
    uint256 userBalance = ethVaults[msg.sender];
    if (userBalance < amount) revert InsufficientETH(amount, userBalance);

    // Actualiza balances
    ethVaults[msg.sender] -= amount;
    totalDeposits -= amount;

    // Actualiza contadores globales y por usuario
    totalWithdrawalCount++;
    totalEthWithdrawn += amount;
    users[msg.sender].withdrawalCount++;
    users[msg.sender].ethWithdrawals += amount;

    // Transferencia segura de ETH al usuario
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    if (!success) revert TransferFailed();

    // Emite evento de retiro
    emit WithdrawETH(msg.sender, amount);
}

// ============================
// COMPRAR Y VENDER KUSD
// ============================

/// @notice Permite a un usuario comprar KUSD usando ETH
/// @dev Aplica los modificadores `whenNotPaused`, `nonReentrant` y `validAmount`
///      Calcula la cantidad de KUSD según el precio actual del oráculo `kusdPriceInETH`
///      Actualiza balances individuales y totales de USD y ETH
///      Minta los tokens KUSD al contrato y emite el evento `DepositUSD`
function buyKUSD()
    external
    payable
    whenNotPaused
    nonReentrant
    validAmount(msg.value)
    underBankCap(msg.value)
{
    // Obtiene precio actual de KUSD en ETH
    uint256 price = udsToken.kusdPriceInETH();
    if (price == 0) revert InvalidAmount();

    // Calcula cantidad de KUSD a otorgar
    uint256 amountKUSD = (msg.value * 1e18) / price;

    // Actualiza balances
    usdVaults[msg.sender] += amountKUSD;
    totalDeposits += msg.value;

    // Actualiza contadores globales y por usuario
    totalDepositCount++;
    totalUsdDeposited += amountKUSD;
    users[msg.sender].depositCount++;
    users[msg.sender].usdDeposits += amountKUSD;

    // Minta los KUSD al contrato
    udsToken.mint(address(this), amountKUSD);

    // Emite evento de depósito en USD
    emit DepositUSD(msg.sender, amountKUSD);
}

/// @notice Permite a un usuario vender KUSD y recibir ETH a cambio
/// @param amountKUSD Cantidad de KUSD a vender
/// @dev Aplica los modificadores `whenNotPaused`, `nonReentrant` y `validAmount`
///      Valida que no se exceda el máximo de venta `kusdMaxSellAmount`
///      Calcula el ETH equivalente según `kusdPriceInETH`
///      Actualiza balances individuales y totales, quema los KUSD y emite `WithdrawUSD`
function sellKUSD(uint256 amountKUSD)
    external
    whenNotPaused
    nonReentrant
    validAmount(amountKUSD)
{
    // Verifica que no se exceda el máximo de venta
    uint256 maxSell = udsToken.kusdMaxSellAmount();
    if (amountKUSD > maxSell) revert ExceedsMaxSellAmount(amountKUSD, maxSell);

    // Obtiene precio actual de KUSD en ETH
    uint256 price = udsToken.kusdPriceInETH();
    if (price == 0) revert InvalidAmount();

    // Calcula ETH a enviar al usuario
    uint256 ethToSend = (amountKUSD * price) / 1e18;
    if (address(this).balance < ethToSend) revert InsufficientETH(ethToSend, address(this).balance);

    // Actualiza balances
    usdVaults[msg.sender] -= amountKUSD;
    totalDeposits -= ethToSend;

    // Actualiza contadores globales y por usuario
    totalWithdrawalCount++;
    totalUsdWithdrawn += amountKUSD;
    users[msg.sender].withdrawalCount++;
    users[msg.sender].usdWithdrawals += amountKUSD;

    // Quema los KUSD vendidos
    udsToken.burn(address(this), amountKUSD);

    // Transferencia segura de ETH al usuario
    (bool success, ) = payable(msg.sender).call{value: ethToSend}("");
    if (!success) revert TransferFailed();

    // Emite evento de retiro en USD
    emit WithdrawUSD(msg.sender, amountKUSD);
}

// ============================
// COMPRAR Y VENDER KEUR
// ============================

/// @notice Permite a un usuario comprar KEUR usando ETH
/// @dev Aplica los modificadores `whenNotPaused`, `nonReentrant` y `validAmount`
///      Calcula la cantidad de KEUR según el precio actual del oráculo `keurPriceInETH`
///      Actualiza balances individuales y totales de EUR y ETH
///      Minta los tokens KEUR al contrato y emite el evento `DepositEUR`
function buyKEUR()
    external
    payable
    whenNotPaused
    nonReentrant
    validAmount(msg.value)
    underBankCap(msg.value)
{
    // Obtiene precio actual de KEUR en ETH
    uint256 price = eurToken.keurPriceInETH();
    if (price == 0) revert InvalidAmount();

    // Calcula cantidad de KEUR a otorgar
    uint256 amountKEUR = (msg.value * 1e18) / price;

    // Actualiza balances
    eurVaults[msg.sender] += amountKEUR;
    totalDeposits += msg.value;

    // Actualiza contadores globales y por usuario
    totalDepositCount++;
    totalEurDeposited += amountKEUR;
    users[msg.sender].depositCount++;
    users[msg.sender].eurDeposits += amountKEUR;

    // Minta los KEUR al contrato
    eurToken.mint(address(this), amountKEUR);

    // Emite evento de depósito en EUR
    emit DepositEUR(msg.sender, amountKEUR);
}

/// @notice Permite a un usuario vender KEUR y recibir ETH a cambio
/// @param amountKEUR Cantidad de KEUR a vender
/// @dev Aplica los modificadores `whenNotPaused`, `nonReentrant` y `validAmount`
///      Valida que no se exceda el máximo de venta `keurMaxSellAmount`
///      Calcula el ETH equivalente según `keurPriceInETH`
///      Actualiza balances individuales y totales, quema los KEUR y emite `WithdrawEUR`
function sellKEUR(uint256 amountKEUR)
    external
    whenNotPaused
    nonReentrant
    validAmount(amountKEUR)
{
    // Verifica que no se exceda el máximo de venta
    uint256 maxSell = eurToken.keurMaxSellAmount();
    if (amountKEUR > maxSell) revert ExceedsMaxSellAmount(amountKEUR, maxSell);

    // Obtiene precio actual de KEUR en ETH
    uint256 price = eurToken.keurPriceInETH();
    if (price == 0) revert InvalidAmount();

    // Calcula ETH a enviar al usuario
    uint256 ethToSend = (amountKEUR * price) / 1e18;
    if (address(this).balance < ethToSend) revert InsufficientETH(ethToSend, address(this).balance);

    // Actualiza balances
    eurVaults[msg.sender] -= amountKEUR;
    totalDeposits -= ethToSend;

    // Actualiza contadores globales y por usuario
    totalWithdrawalCount++;
    totalEurWithdrawn += amountKEUR;
    users[msg.sender].withdrawalCount++;
    users[msg.sender].eurWithdrawals += amountKEUR;

    // Quema los KEUR vendidos
    eurToken.burn(address(this), amountKEUR);

    // Transferencia segura de ETH al usuario
    (bool success, ) = payable(msg.sender).call{value: ethToSend}("");
    if (!success) revert TransferFailed();

    // Emite evento de retiro en EUR
    emit WithdrawEUR(msg.sender, amountKEUR);
}

// ============================
// CONSULTAS DE USUARIO
// ============================

/// @notice Obtiene los balances actuales de ETH, KUSD y KEUR de un usuario
/// @dev También calcula el equivalente de ETH en USD usando el oráculo interno
/// @return ethBalance Balance de ETH del usuario en wei
/// @return usdBalance Balance de KUSD del usuario
/// @return eurBalance Balance de KEUR del usuario
/// @return ethInUsd Valor equivalente del ETH en USD (basado en el oráculo)
function getMyVaults()
    external view
    returns (
        uint256 ethBalance,
        uint256 usdBalance,
        uint256 eurBalance,
        uint256 ethInUsd    
    )
{
    ethBalance = ethVaults[msg.sender];
    usdBalance = usdVaults[msg.sender];
    eurBalance = eurVaults[msg.sender];
    ethInUsd = (ethBalance * getEthUsdPrice()) / 1e8;
}

/// @notice Obtiene estadísticas básicas de un usuario
/// @dev Devuelve el número total de depósitos y retiros realizados
/// @return depositCount Número total de depósitos del usuario
/// @return withdrawalCount Número total de retiros del usuario
function getMyStats()
    external view
    returns (uint256 depositCount, uint256 withdrawalCount)
{
    UserInfo memory u = users[msg.sender];
    return (u.depositCount, u.withdrawalCount);
}

/// @notice Obtiene estadísticas detalladas de depósitos y retiros por tipo de moneda
/// @dev Devuelve ETH, KUSD y KEUR depositados y retirados por el usuario
/// @return ethDeposited Total de ETH depositado
/// @return ethWithdrawn Total de ETH retirado
/// @return usdDeposited Total de KUSD depositado
/// @return usdWithdrawn Total de KUSD retirado
/// @return eurDeposited Total de KEUR depositado
/// @return eurWithdrawn Total de KEUR retirado
function getMyDetailedStats()
    external view
    returns (
        uint256 ethDeposited, uint256 ethWithdrawn,
        uint256 usdDeposited, uint256 usdWithdrawn,
        uint256 eurDeposited, uint256 eurWithdrawn
    )
{
    UserInfo memory u = users[msg.sender];
    return (
        u.ethDeposits, u.ethWithdrawals,
        u.usdDeposits, u.usdWithdrawals,
        u.eurDeposits, u.eurWithdrawals
    );
}

// ============================
// CONSULTAS ADMIN / SUPER ADMIN
// ============================

/// @notice Obtiene los balances de ETH, KUSD y KEUR de un usuario específico
/// @dev Solo accesible por Admin o Super Admin
/// @param user Dirección del usuario a consultar
/// @return ethBalance Balance de ETH del usuario en wei
/// @return usdBalance Balance de KUSD del usuario
/// @return eurBalance Balance de KEUR del usuario
/// @return ethInUsd Valor equivalente del ETH en USD (basado en el oráculo)
function getUserVaults(address user)
    external
    view
    onlyAdminOrSuper
    returns (uint256 ethBalance, uint256 usdBalance, uint256 eurBalance, uint256 ethInUsd)
{
    ethBalance = ethVaults[user];
    usdBalance = usdVaults[user];
    eurBalance = eurVaults[user];
    ethInUsd = (ethBalance * getEthUsdPrice()) / 1e8;
}

/// @notice Obtiene estadísticas básicas de un usuario específico
/// @dev Solo accesible por Admin o Super Admin
/// @param user Dirección del usuario a consultar
/// @return depositCount Número total de depósitos del usuario
/// @return withdrawalCount Número total de retiros del usuario
function getUserStats(address user)
    external
    view
    onlyAdminOrSuper
    returns (uint256 depositCount, uint256 withdrawalCount)
{
    UserInfo memory u = users[user];
    return (u.depositCount, u.withdrawalCount);
}

/// @notice Obtiene estadísticas detalladas de depósitos y retiros de un usuario específico
/// @dev Solo accesible por Admin o Super Admin
/// @param user Dirección del usuario a consultar
/// @return ethDeposited Total de ETH depositado
/// @return ethWithdrawn Total de ETH retirado
/// @return usdDeposited Total de KUSD depositado
/// @return usdWithdrawn Total de KUSD retirado
/// @return eurDeposited Total de KEUR depositado
/// @return eurWithdrawn Total de KEUR retirado
function getUserDetailedStats(address user)
    external
    view
    onlyAdminOrSuper
    returns (
        uint256 ethDeposited,
        uint256 ethWithdrawn,
        uint256 usdDeposited,
        uint256 usdWithdrawn,
        uint256 eurDeposited,
        uint256 eurWithdrawn
    )
{
    UserInfo memory u = users[user];
    return (
        u.ethDeposits, u.ethWithdrawals,
        u.usdDeposits, u.usdWithdrawals,
        u.eurDeposits, u.eurWithdrawals
    );
}

/// @notice Devuelve los totales globales del banco
/// @dev Incluye balances, depósitos, retiros y contadores de transacciones; solo Admin o Super Admin
/// @return BankTotals Estructura con totales de ETH, KUSD, KEUR y conteos de depósitos/retiros
function getBankTotals()
    external
    view
    onlyAdminOrSuper
    returns (BankTotals memory)
{
    return BankTotals({
        ethBalance: address(this).balance,
        ethDeposits: totalEthDeposited,
        ethWithdrawals: totalEthWithdrawn,
        usdBalance: udsToken.balanceOf(address(this)),
        usdDeposits: totalUsdDeposited,
        usdWithdrawals: totalUsdWithdrawn,
        eurBalance: eurToken.balanceOf(address(this)),
        eurDeposits: totalEurDeposited,
        eurWithdrawals: totalEurWithdrawn,
        depositCount: totalDepositCount,
        withdrawalCount: totalWithdrawalCount
    });
}

// ============================
// ADMINISTRACIÓN DE TOKENS DESDE EL BANCO
// ============================

/// @notice Actualiza el precio de KEUR en el contrato KEUR
/// @dev Solo accesible por Super Admin
/// @param newPrice Nuevo precio de KEUR en ETH (con 18 decimales)
function setEURPrice(uint256 newPrice) external onlyRole(SUPER_ADMIN_ROLE) {
    eurToken.setPrice(newPrice);
}

/// @notice Actualiza el precio de KUSD en el contrato KUSD
/// @dev Solo accesible por Super Admin
/// @param newPrice Nuevo precio de KUSD en ETH (con 18 decimales)
function setUSDPrice(uint256 newPrice) external onlyRole(SUPER_ADMIN_ROLE) {
    udsToken.setPrice(newPrice);
}

/// @notice Actualiza el límite máximo de tokens KEUR que un usuario puede tener en su wallet
/// @dev Solo accesible por Super Admin
/// @param newLimit Nuevo límite máximo de KEUR por wallet
function setEURWalletLimit(uint256 newLimit) external onlyRole(SUPER_ADMIN_ROLE) {
    eurToken.setWalletLimit(newLimit);
}

/// @notice Actualiza el límite máximo de tokens KUSD que un usuario puede tener en su wallet
/// @dev Solo accesible por Super Admin
/// @param newLimit Nuevo límite máximo de KUSD por wallet
function setUSDWalletLimit(uint256 newLimit) external onlyRole(SUPER_ADMIN_ROLE) {
    udsToken.setWalletLimit(newLimit);
}

/// @notice Actualiza la cantidad máxima de KEUR que un usuario puede vender en una sola transacción
/// @dev Solo accesible por Super Admin
/// @param newMax Nueva cantidad máxima de venta de KEUR
function setEURMaxSellAmount(uint256 newMax) external onlyRole(SUPER_ADMIN_ROLE) {
    eurToken.setMinSellAmount(newMax);
}

/// @notice Actualiza la cantidad máxima de KUSD que un usuario puede vender en una sola transacción
/// @dev Solo accesible por Super Admin
/// @param newMax Nueva cantidad máxima de venta de KUSD
function setUSDMaxSellAmount(uint256 newMax) external onlyRole(SUPER_ADMIN_ROLE) {
    udsToken.setMinSellAmount(newMax);
}

// ============================
// ADMINISTRACIÓN
// ============================

/// @notice Concede el rol de ADMIN a una cuenta
/// @dev Solo accesible por Super Admin
/// @param account Dirección a la que se le otorgará el rol
function addAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { 
    _grantRole(ADMIN_ROLE, account); 
}

/// @notice Revoca el rol de ADMIN de una cuenta
/// @dev Solo accesible por Super Admin
/// @param account Dirección de la que se revocará el rol
function removeAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { 
    _revokeRole(ADMIN_ROLE, account); 
}

/// @notice Concede el rol de SUPER_ADMIN a una cuenta
/// @dev Solo accesible por Super Admin
/// @param account Dirección a la que se le otorgará el rol
function addSuperAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { 
    _grantRole(SUPER_ADMIN_ROLE, account); 
}

/// @notice Revoca el rol de SUPER_ADMIN de una cuenta
/// @dev Solo accesible por Super Admin
/// @param account Dirección de la que se revocará el rol
function removeSuperAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { 
    _revokeRole(SUPER_ADMIN_ROLE, account); 
}

/// @notice Actualiza la capacidad máxima total del banco
/// @dev Solo accesible por Admin o Super Admin. No puede ser menor al total de depósitos actuales.
/// @param newCap Nueva capacidad máxima del banco
function updateBankCap(uint256 newCap) external onlyAdminOrSuper {
    if (newCap < totalDeposits) revert NewCapBelowDeposits(newCap, totalDeposits);
    bankCapUSD = newCap;
}

/// @notice Pausa todas las operaciones críticas del banco
/// @dev Solo accesible por Super Admin
function pause() external onlyRole(SUPER_ADMIN_ROLE) { 
    _pause(); 
}

/// @notice Reanuda las operaciones del banco después de una pausa
/// @dev Solo accesible por Super Admin
function unpause() external onlyRole(SUPER_ADMIN_ROLE) { 
    _unpause(); 
}
}