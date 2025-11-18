// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./KipuUSD.sol";
import "./KipuEUR.sol";
import "./PriceOracle.sol";

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IMockUniswapRouter {
    function WETH() external view returns (address);
    function swapExactTokensForTokens3(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address weth,
        address usdc,
        address to
    ) external returns (uint256[] memory amounts);
}

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


    IUniswapV2Router02 public uniswapRouter;
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

        uint256 usdcBalance;      
        uint256 usdcDeposits; 
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
    /// @notice Mapeo de direccion a sus balance por token por usuario
    mapping(address => mapping(address => uint256)) public userTokenVaults;
    // userTokenVaults[user][token] = balance
    // En las Variables de Estado (cerca de la línea 29-31)
    mapping(address => uint256) public usdcVaults;
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
    IERC20 public usdcToken;
    uint256 public totalUsdcDeposited;


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
    event DepositETH(address indexed user, uint256 amount);
    /// @notice Emitido cuando un usuario retira ETH exitosamente
    /// @param user Dirección del usuario que realizó el retiro
    /// @param amount Monto de ETH retirado en wei
    event WithdrawETH(address indexed user, uint256 amount);
    /// @notice Emitido cuando un usuario deposita KUSD exitosamente
    /// @param user Dirección del usuario que realizó el depósito
    /// @param amount Monto de KUSD depositado
    event DepositUSD(address indexed user, uint256 amount);
    /// @notice Emitido cuando un usuario retira KUSD exitosamente
    /// @param user Dirección del usuario que realizó el retiro
    /// @param amount Monto de KUSD retirado
    event WithdrawUSD(address indexed user, uint256 amount);
    /// @notice Emitido cuando un usuario deposita KEUR exitosamente
    /// @param user Dirección del usuario que realizó el depósito
    /// @param amount Monto de KEUR depositado
    event DepositEUR(address indexed user, uint256 amount);
    /// @notice Emitido cuando un usuario retira KEUR exitosamente
    /// @param user Dirección del usuario que realizó el retiro
    /// @param amount Monto de KEUR retirado
    event WithdrawEUR(address indexed user, uint256 amount);
    event DepositCompleted(address indexed user, address indexed token, uint256 tokenAmount,uint256 usdcReceived);

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
    /// @param totalDepositsInUSD Total de depósitos actualmente en el banco
    error NewCapBelowDeposits(uint256 newCap, uint256 totalDepositsInUSD);
    /// @notice Error lanzado al intentar vender más tokens de los permitidos por el límite máximo de venta
    /// @param attempted Cantidad de tokens que se intentó vender
    /// @param maxAllowed Máximo permitido de tokens a vender
    error ExceedsMaxSellAmount(uint256 attempted, uint256 maxAllowed);
    /// @notice Error lanzado cuando el usuario intenta operar con más tokens de los que tiene disponibles
    /// @param requested Cantidad de tokens solicitada
    /// @param available Saldo actual del usuario
    error InsufficientToken(uint256 requested, uint256 available);
    error NoLiquidityForToken(address token);
    error SwapFailed();
    error BankCapExceededDeposit(uint256 attempted, uint256 cap);
    error TransferFailedToken(address token);

    // ============================
    // CONSTRUCTOR
    // ============================
    /// @notice Inicializa el contrato KipuBank con límites de retiro, capacidad del banco y oráculo de precios ETH/USD
    /// @param _withdrawalLimit Límite máximo de retiro permitido por transacción en wei
    /// @param _bankCapInUSD_18decimals Límite global máximo de depósitos permitidos en el banco en dolares
    /// @param _ethUsdFeed Dirección del contrato del oráculo de precio ETH/USD que se usará para conversiones
    /// @dev Valida que los parámetros de límite y cap no sean cero.
    ///      Asigna roles iniciales al deployer: DEFAULT_ADMIN_ROLE, SUPER_ADMIN_ROLE, ADMIN_ROLE
    constructor(
        uint256 _withdrawalLimit,
        uint256 _bankCapInUSD_18decimals,
        address _ethUsdFeed,
        address _uniswapRouter
    ) PriceOracle(_ethUsdFeed) {
        if (_withdrawalLimit == 0 || _bankCapInUSD_18decimals == 0) revert InvalidAmount();
        withdrawalLimit = _withdrawalLimit;
        bankCapUSD = _bankCapInUSD_18decimals;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SUPER_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
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
        uint256 ethPrice_8decimals = getEthUsdPrice();
        if (ethPrice_8decimals == 0) revert InvalidAmount();
        // bankCapUSD (18 dec) * 1e8 / ethPrice_8decimals (8 dec) = Max ETH (18 dec)
        uint256 maxEthAllowed = (bankCapUSD * 1e8) / ethPrice_8decimals;
        if (totalDeposits + amount > maxEthAllowed) {
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
    /// @notice Asigna los contratos de los tokens internos KUSD, KEUR y USDC al KipuBank
    /// @param _udsToken Dirección del contrato KipuDolar (KUSD)
    /// @param _eurToken Dirección del contrato KipuEuro (KEUR)
    /// @param _usdcToken Dirección del contrato USDC
    /// @dev Solo puede ser llamada por `SUPER_ADMIN_ROLE`.
    ///      Revertirá con `InvalidTokenAddress` si alguna dirección es cero.
    function setTokens(
        address _udsToken, 
        address _eurToken, 
        address _usdcToken
    ) external onlyRole(SUPER_ADMIN_ROLE) {
        if (_udsToken == address(0) || _eurToken == address(0) || _usdcToken == address(0))
            revert InvalidTokenAddress();
        udsToken = KipuDolar(_udsToken);
        eurToken = KipuEuro(_eurToken);
        usdcToken = IERC20(_usdcToken);
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
        ethVaults[msg.sender] += msg.value;
        totalDeposits += msg.value;
        totalDepositCount++;
        totalEthDeposited += msg.value;
        users[msg.sender].depositCount++;
        users[msg.sender].ethDeposits += msg.value;
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
        if (amount > withdrawalLimit) revert ExceedsWithdrawalLimit(amount, withdrawalLimit);
        uint256 userBalance = ethVaults[msg.sender];
        if (userBalance < amount) revert InsufficientETH(amount, userBalance);
        ethVaults[msg.sender] -= amount;
        totalDeposits -= amount;
        totalWithdrawalCount++;
        totalEthWithdrawn += amount;
        users[msg.sender].withdrawalCount++;
        users[msg.sender].ethWithdrawals += amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit WithdrawETH(msg.sender, amount);
    }

    // ------------------------------------------------------------
    // 🔹 FUNCIÓN PRINCIPAL
    // ------------------------------------------------------------
    function depositToken(
        address token, 
        uint256 amount, 
        uint256 minUSDC
    )
        external
        payable
        whenNotPaused
        nonReentrant
        validAmount(token == address(0) ? msg.value : amount)
    {
        uint256 usdcReceived6Dec = _handleDepositRoute(token, amount, minUSDC);
        totalUsdcDeposited += usdcReceived6Dec;
        uint256 usdcReceived18Dec = usdcReceived6Dec * 1e12;

       _registerDeposit(msg.sender, usdcReceived18Dec);
    }

    // ------------------------------------------------------------
    // 🔹 RUTEO DE DEPÓSITO
    // ------------------------------------------------------------
function _handleDepositRoute(
    address token,
    uint256 amount,
    uint256 minUSDC
) internal returns (uint256 usdcReceived6Dec) {
    if (token == address(0)) {
        // ETH
        usdcReceived6Dec = _swapETHForUSDC(minUSDC);
        require(usdcReceived6Dec >= minUSDC, "Slippage too high");
        // Registrar ETH original solo si swap tuvo éxito
        userTokenVaults[msg.sender][address(0)] += amount;
    } else if (token == address(usdcToken)) {
        // USDC
        usdcReceived6Dec = _depositUSDC(amount);
        require(usdcReceived6Dec >= minUSDC, "USDC below minUSDC");
        userTokenVaults[msg.sender][token] += amount;
    } else {
        // Otro token: decidir ruta según liquidez
        address directPair = IUniswapV2Factory(uniswapRouter.factory()).getPair(token, address(usdcToken));
        if (directPair != address(0)) {
            // Swap directo token → USDC
            usdcReceived6Dec = _swapTokenForUSDC(token, amount, minUSDC);
        } else {
            // Swap vía WETH token → WETH → USDC
            usdcReceived6Dec = _swapTokenToWETHtoUSDC(token, amount, minUSDC);
        }

        // Verificar slippage
        require(usdcReceived6Dec >= minUSDC, "Slippage too high");

        // Registrar token original solo si swap tuvo éxito
        userTokenVaults[msg.sender][token] += amount;
    }
}


    // ------------------------------------------------------------
    // 🔹 RUTA 1: ETH → USDC
    // ------------------------------------------------------------
    function _swapETHForUSDC(uint256 minUSDC)
        internal
        returns (uint256 usdcReceived6Dec)
    {
        address[] memory path = new address[](2); 
        path[0] = uniswapRouter.WETH();
        path[1] = address(usdcToken);

        try uniswapRouter.swapExactETHForTokens{value: msg.value}(
            minUSDC,
            path,
            address(this),
            block.timestamp + 300
        ) returns (uint[] memory amounts) {
            usdcReceived6Dec = amounts[amounts.length - 1];
        } catch {
            // Si el swap falla, revertimos y devolvemos ETH
            (bool sent, ) = msg.sender.call{value: msg.value}("");
            if (!sent) revert TransferFailedToken(address(0));
            revert SwapFailed();
        }
    }

    // ------------------------------------------------------------
    // 🔹 RUTA 2: USDC directo
    // ------------------------------------------------------------
    function _depositUSDC(uint256 amount)
        internal
        returns (uint256 usdcReceived6Dec)
    {
        bool success = IERC20(address(usdcToken)).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailedToken(address(usdcToken));

        usdcReceived6Dec = amount;
    }

    // ------------------------------------------------------------
    // 🔹 RUTA 3: Otro token → USDC
    // ------------------------------------------------------------
    function _swapTokenForUSDC(
        address token,
        uint256 amount,
        uint256 minUSDC
    ) internal returns (uint256 usdcReceived6Dec) {
        // Verificar liquidez
        address pair = IUniswapV2Factory(uniswapRouter.factory()).getPair(token, address(usdcToken));
        if (pair == address(0)) revert NoLiquidityForToken(token);

        // Transferir token al contrato
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailedToken(token);

        // Aprobar al router
        IERC20(token).approve(address(uniswapRouter), amount);

        // Ejecutar swap
        address[] memory path = new address[](2); 
        path[0] = token;
        path[1] = address(usdcToken);

        try uniswapRouter.swapExactTokensForTokens(
            amount,
            minUSDC,
            path,
            address(this),
            block.timestamp + 300
        ) returns (uint[] memory amounts) {
            usdcReceived6Dec = amounts[amounts.length - 1];
        } catch {
            revert SwapFailed();
        }
    }

function _swapTokenToWETHtoUSDC(
    address token,
    uint256 amount,
    uint256 minUSDC
) internal returns (uint256 usdcReceived6Dec) {

    // Verificar liquidez
    address pair1 = IUniswapV2Factory(uniswapRouter.factory()).getPair(token, uniswapRouter.WETH());
    if (pair1 == address(0)) revert NoLiquidityForToken(token);

    address pair2 = IUniswapV2Factory(uniswapRouter.factory()).getPair(uniswapRouter.WETH(), address(usdcToken));
    if (pair2 == address(0)) revert NoLiquidityForToken(uniswapRouter.WETH());

    // Transferir token
    bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
    if (!success) revert TransferFailedToken(token);

    // Aprobar al router
    IERC20(token).approve(address(uniswapRouter), amount);

    // Llamar al mock 3 pasos
    try IMockUniswapRouter(address(uniswapRouter)).swapExactTokensForTokens3(
        amount,
        minUSDC,
        token,
        uniswapRouter.WETH(),
        address(usdcToken),
        address(this)
    ) returns (uint256[] memory amounts) {
        usdcReceived6Dec = amounts[2]; // USDC es el último paso
    } catch {
        revert SwapFailed();
    }
}


    // ------------------------------------------------------------
    // 🔹 ACTUALIZACIÓN DEL ESTADO
    // ------------------------------------------------------------
    function _registerDeposit(
    address user, 
    uint256 usdcReceived18Dec 
) internal {
    if (totalUsdDeposited + usdcReceived18Dec > bankCapUSD) {
        revert BankCapExceededDeposit(totalUsdDeposited + usdcReceived18Dec, bankCapUSD);
    }

    // Registrar USDC recibido
    usdcVaults[user] += usdcReceived18Dec;
    totalDepositCount++;

    users[user].depositCount++;

    emit DepositUSD(user, usdcReceived18Dec);
}


    function withdrawUSDC(uint256 amount) external nonReentrant validAmount(amount) whenNotPaused {
        uint256 userBalance = usdVaults[msg.sender];
        if (amount > userBalance) revert InsufficientToken(amount, userBalance);
        usdVaults[msg.sender] -= amount;
        totalUsdWithdrawn += amount;
        users[msg.sender].withdrawalCount++;
        users[msg.sender].usdWithdrawals += amount;

        // --- CORRECCIÓN DE DECIMALES ---
        // Se escala el monto del vault (18 decimales) a 6 decimales para la transferencia
        uint256 amountToTransfer = amount / 1e12; // 18 dec -> 6 dec

        bool success = IERC20(usdcToken).transfer(msg.sender, amountToTransfer);
        if (!success) revert TransferFailedToken(address(usdcToken));
        emit WithdrawUSD(msg.sender, amount);
    }
    // ============================
    // COMPRAR Y VENDER KUSD
    // ============================
    /// @notice Permite a un usuario comprar KUSD usando ETH
    /// @dev Aplica los modificadores `whenNotPaused`, `nonReentrant`, `validAmount`
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
        uint256 price = udsToken.kusdPriceInETH();
        if (price == 0) revert InvalidAmount();
        uint256 amountKUSD = (msg.value * 1e18) / price;
        usdVaults[msg.sender] += amountKUSD;
        totalDeposits += msg.value;
        totalDepositCount++;
        totalUsdDeposited += amountKUSD;
        users[msg.sender].depositCount++;
        users[msg.sender].usdDeposits += amountKUSD;
        udsToken.mint(address(this), amountKUSD);
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
        uint256 maxSell = udsToken.kusdMaxSellAmount();
        if (amountKUSD > maxSell) revert ExceedsMaxSellAmount(amountKUSD, maxSell);
        uint256 price = udsToken.kusdPriceInETH();
        if (price == 0) revert InvalidAmount();
        uint256 ethToSend = (amountKUSD * price) / 1e18;
        if (address(this).balance < ethToSend) revert InsufficientETH(ethToSend, address(this).balance);
        usdVaults[msg.sender] -= amountKUSD;
        totalDeposits -= ethToSend;
        totalWithdrawalCount++;
        totalUsdWithdrawn += amountKUSD;
        users[msg.sender].withdrawalCount++;
        users[msg.sender].usdWithdrawals += amountKUSD;
        udsToken.burn(address(this), amountKUSD);
        (bool success, ) = payable(msg.sender).call{value: ethToSend}("");
        if (!success) revert TransferFailed();
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
        uint256 price = eurToken.keurPriceInETH();
        if (price == 0) revert InvalidAmount();
        uint256 amountKEUR = (msg.value * 1e18) / price;
        eurVaults[msg.sender] += amountKEUR;
        totalDeposits += msg.value;
        totalDepositCount++;
        totalEurDeposited += amountKEUR;
        users[msg.sender].depositCount++;
        users[msg.sender].eurDeposits += amountKEUR;
        eurToken.mint(address(this), amountKEUR);
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
        uint256 maxSell = eurToken.keurMaxSellAmount();
        if (amountKEUR > maxSell) revert ExceedsMaxSellAmount(amountKEUR, maxSell);
        uint256 price = eurToken.keurPriceInETH();
        if (price == 0) revert InvalidAmount();
        uint256 ethToSend = (amountKEUR * price) / 1e18;
        if (address(this).balance < ethToSend) revert InsufficientETH(ethToSend, address(this).balance);
        eurVaults[msg.sender] -= amountKEUR;
        totalDeposits -= ethToSend;
        totalWithdrawalCount++;
        totalEurWithdrawn += amountKEUR;
        users[msg.sender].withdrawalCount++;
        users[msg.sender].eurWithdrawals += amountKEUR;
        eurToken.burn(address(this), amountKEUR);
        (bool success, ) = payable(msg.sender).call{value: ethToSend}("");
        if (!success) revert TransferFailed();
        emit WithdrawEUR(msg.sender, amountKEUR);
    }

    // ============================
    // CONSULTAS DE USUARIO
    // ============================

    /// @notice Obtiene el balance actual de USDC swapeado/depositado del usuario
    /// @return Balance de USDC del usuario (en 18 decimales)
    function getMyUSDCVaultBalance() external view returns (uint256) {
    return usdcVaults[msg.sender];
    }
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
            uint256 ethInUsd, 
            uint256 usdcBalance   
        )
    {
        ethBalance = ethVaults[msg.sender];
        usdBalance = usdVaults[msg.sender];
        eurBalance = eurVaults[msg.sender];
        usdcBalance = usdcVaults[msg.sender];
        
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
        returns (uint256 ethBalance, uint256 usdBalance, uint256 eurBalance, uint256 ethInUsd, uint256 usdcBalance)
    {
        ethBalance = ethVaults[user];
        usdBalance = usdVaults[user];
        eurBalance = eurVaults[user];
        usdcBalance = usdcVaults[user];
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

    function getMyTokenBalance(address token) external view returns (uint256) {
        return userTokenVaults[msg.sender][token];
    }

    /// @notice Devuelve los totales globales del banco
    /// @dev Incluye balances, depósitos, retiros y contadores de transacciones;
    ///      solo Admin o Super Admin
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
            usdcBalance: usdcToken.balanceOf(address(this)), 
            usdcDeposits: totalUsdcDeposited,   
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
    function setKEURMaxSellAmount(uint256 newMax) external onlyRole(SUPER_ADMIN_ROLE) {
        eurToken.setMaxSellAmount(newMax);
    }

    /// @notice Actualiza la cantidad máxima de KUSD que un usuario puede vender en una sola transacción
    /// @dev Solo accesible por Super Admin
    /// @param newMax Nueva cantidad máxima de venta de KUSD
    function setKUSDMaxSellAmount(uint256 newMax) external onlyRole(SUPER_ADMIN_ROLE) {
        udsToken.setMaxSellAmount(newMax);
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
    /// @dev Solo accesible por Admin o Super Admin.
    ///      No puede ser menor al total de depósitos actuales (convertidos a USD).
    /// @param newCap Nueva capacidad máxima del banco (USD, 18 decimales)
    function updateBankCap(uint256 newCap) external onlyAdminOrSuper {
    // obtener precio ETH/USD (8 decimales)
    uint256 ethPrice_8dec = getEthUsdPrice();
    if (ethPrice_8dec == 0) revert InvalidAmount();

    // totalDeposits está en wei (1e18). Convertir a USD (18 decimales):
    // totalDepositsInUSD = totalDeposits * ethPrice / 1e8
    uint256 totalDepositsInUSD = (totalDeposits * ethPrice_8dec) / 1e8;

    if (newCap < totalDepositsInUSD) revert NewCapBelowDeposits(newCap, totalDepositsInUSD);
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