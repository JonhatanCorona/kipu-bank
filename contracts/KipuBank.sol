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
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");

    // ============================
    // ESTRUCTURAS
    // ============================
    struct UserInfo {
        uint256 depositCount;
        uint256 withdrawalCount;
        uint256 ethDeposits;
        uint256 ethWithdrawals;
        uint256 usdDeposits;
        uint256 usdWithdrawals;
        uint256 eurDeposits;
        uint256 eurWithdrawals;
    }

    // ============================
    // ESTADO
    // ============================
    mapping(address => uint256) public ethVaults;
    mapping(address => uint256) public usdVaults;
    mapping(address => uint256) public eurVaults;
    mapping(address => UserInfo) private users;

    KipuDolar public udsToken;
    KipuEuro public eurToken;

    uint256 public immutable withdrawalLimit;
    uint256 public bankCap;
    uint256 public totalDeposits;

    // Totales por tipo de moneda
    uint256 public totalEthDeposited;
    uint256 public totalEthWithdrawn;
    uint256 public totalUsdDeposited;
    uint256 public totalUsdWithdrawn;
    uint256 public totalEurDeposited;
    uint256 public totalEurWithdrawn;

    // Totales de movimientos
    uint256 private  totalDepositCount;
    uint256 private  totalWithdrawalCount;

    // ============================
    // ERRORES
    // ============================
    error InvalidAmount();
    error BankCapExceeded(uint256 attempted, uint256 cap);
    error ExceedsWithdrawalLimit(uint256 attempted, uint256 limit);
    error InsufficientETH(uint256 requested, uint256 available);
    error TransferFailed();
    error InvalidTokenAddress();
    error NewCapBelowDeposits(uint256 newCap, uint256 totalDeposits);
    error BelowMinSellAmount();

    // ============================
    // EVENTOS
    // ============================
    event DepositETH(address indexed user, uint256 amount);
    event WithdrawETH(address indexed user, uint256 amount);
    event DepositUSD(address indexed user, uint256 amount);
    event WithdrawUSD(address indexed user, uint256 amount);
    event DepositEUR(address indexed user, uint256 amount);
    event WithdrawEUR(address indexed user, uint256 amount);

    // ============================
    // CONSTRUCTOR
    // ============================
    constructor(
        uint256 _withdrawalLimit,
        uint256 _bankCap,
        address _ethUsdFeed
    ) PriceOracle(_ethUsdFeed) {
        if (_withdrawalLimit == 0 || _bankCap == 0) revert InvalidAmount();

        withdrawalLimit = _withdrawalLimit;
        bankCap = _bankCap;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SUPER_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // ============================
    // MODIFICADORES
    // ============================
    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    modifier underBankCap(uint256 amount) {
        if (totalDeposits + amount > bankCap) revert BankCapExceeded(totalDeposits + amount, bankCap);
        _;
    }

    /// @notice Modificador que permite ejecutar funciones a Admin o Super Admin
    modifier onlyAdminOrSuper() {
    if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(SUPER_ADMIN_ROLE, msg.sender)) {
        revert("Not admin or super admin");
    }
    _;
    }

    // ============================
    // CONFIGURACIÓN DE TOKENS
    // ============================
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
    function depositETH() external payable whenNotPaused nonReentrant validAmount(msg.value) underBankCap(msg.value) {
        ethVaults[msg.sender] += msg.value;
        totalDeposits += msg.value;

        totalDepositCount++;
        totalEthDeposited += msg.value;
        users[msg.sender].depositCount++;
        users[msg.sender].ethDeposits += msg.value;

        emit DepositETH(msg.sender, msg.value);
    }

    function withdrawETH(uint256 amount) external whenNotPaused nonReentrant validAmount(amount) {
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

    // ============================
    // COMPRAR Y VENDER KUSD
    // ============================
    function buyKUSD() external payable whenNotPaused nonReentrant validAmount(msg.value) {
        uint256 price = udsToken.kusdPriceInETH();
        if (price == 0) revert InvalidAmount();

        uint256 amountKUSD = (msg.value * 1e18) / price;

        usdVaults[msg.sender] += amountKUSD;
        totalDeposits += msg.value;

        totalDepositCount++;
        totalUsdDeposited += msg.value;
        users[msg.sender].depositCount++;
        users[msg.sender].usdDeposits += amountKUSD;

        udsToken.mint(address(this), amountKUSD);
        emit DepositUSD(msg.sender, amountKUSD);
    }

    function sellKUSD(uint256 amountKUSD) external whenNotPaused nonReentrant validAmount(amountKUSD) {
        uint256 minSell = udsToken.kusdMinSellAmount();
        if (amountKUSD < minSell) revert BelowMinSellAmount();

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
    function buyKEUR() external payable whenNotPaused nonReentrant validAmount(msg.value) {
        uint256 price = eurToken.keurPriceInETH();
        if (price == 0) revert InvalidAmount();

        uint256 amountKEUR = (msg.value * 1e18) / price;

        eurVaults[msg.sender] += amountKEUR;
        totalDeposits += msg.value;

        totalDepositCount++;
        totalEurDeposited += msg.value;
        users[msg.sender].depositCount++;
        users[msg.sender].eurDeposits += amountKEUR;

        eurToken.mint(address(this), amountKEUR);
        emit DepositEUR(msg.sender, amountKEUR);
    }

    function sellKEUR(uint256 amountKEUR) external whenNotPaused nonReentrant validAmount(amountKEUR) {
        uint256 minSell = eurToken.keurMinSellAmount();
        if (amountKEUR < minSell) revert BelowMinSellAmount();

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
    // CONSULTAS
    // ============================
    /// @notice Consulta tus propios balances
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

/// @notice Consulta tus estadísticas básicas
function getMyStats()
    external view
    returns (uint256 depositCount, uint256 withdrawalCount)
{
    UserInfo memory u = users[msg.sender];
    return (u.depositCount, u.withdrawalCount);
}

/// @notice Consulta tus estadísticas detalladas
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


/// @notice Consulta los balances de cualquier usuario
function getUserVaults(address user)
    external view
    onlyAdminOrSuper
    returns (
        uint256 ethBalance, uint256 usdBalance, uint256 eurBalance,
        uint256 ethInUsd
    )
{
    ethBalance = ethVaults[user];
    usdBalance = usdVaults[user];
    eurBalance = eurVaults[user];

    ethInUsd = (ethBalance * getEthUsdPrice()) / 1e8;
}

/// @notice Consulta estadísticas de cualquier usuario
function getUserStats(address user)
    external view
    onlyAdminOrSuper
    returns (uint256 depositCount, uint256 withdrawalCount)
{
    UserInfo memory u = users[user];
    return (u.depositCount, u.withdrawalCount);
}

/// @notice Consulta estadísticas detalladas de cualquier usuario
function getUserDetailedStats(address user)
    external view
    onlyAdminOrSuper
    returns (
        uint256 ethDeposited, uint256 ethWithdrawn,
        uint256 usdDeposited, uint256 usdWithdrawn,
        uint256 eurDeposited, uint256 eurWithdrawn
    )
{
    UserInfo memory u = users[user];
    return (
        u.ethDeposits, u.ethWithdrawals,
        u.usdDeposits, u.usdWithdrawals,
        u.eurDeposits, u.eurWithdrawals
    );
}

/// @notice Consulta totales del banco
function getBankTotals()
    external view
    onlyAdminOrSuper
    returns (
        uint256 ethBalance, uint256 ethDeposits, uint256 ethWithdrawals,
        uint256 usdBalance, uint256 usdDeposits, uint256 usdWithdrawals,
        uint256 eurBalance, uint256 eurDeposits, uint256 eurWithdrawals
    )
{
    ethBalance = address(this).balance;
    ethDeposits = totalEthDeposited;
    ethWithdrawals = totalEthWithdrawn;

    usdBalance = udsToken.balanceOf(address(this));
    usdDeposits = totalUsdDeposited;
    usdWithdrawals = totalUsdWithdrawn;

    eurBalance = eurToken.balanceOf(address(this));
    eurDeposits = totalEurDeposited;
    eurWithdrawals = totalEurWithdrawn;
}


    // ============================
    // ADMINISTRACIÓN
    // ============================
    function addAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { _grantRole(ADMIN_ROLE, account); }
    function removeAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { _revokeRole(ADMIN_ROLE, account); }
    function addSuperAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { _grantRole(SUPER_ADMIN_ROLE, account); }
    function removeSuperAdmin(address account) external onlyRole(SUPER_ADMIN_ROLE) { _revokeRole(SUPER_ADMIN_ROLE, account); }
    function updateBankCap(uint256 newCap) external onlyAdminOrSuper {
        if (newCap < totalDeposits) revert NewCapBelowDeposits(newCap, totalDeposits);
        bankCap = newCap;
    }
    function pause() external onlyRole(SUPER_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(SUPER_ADMIN_ROLE) { _unpause(); }
}
