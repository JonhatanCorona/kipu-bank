// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title KipuBank - Banco descentralizado seguro
/// @author 
/// @notice Permite a los usuarios depositar y retirar ETH dentro de límites definidos
contract KipuBank {

    // --- Variables de estado ---

    /// @notice Mapeo de direcciones a sus balances personales en wei
    mapping(address => uint256) private balances;

    /// @notice Límite máximo de retiro permitido por transacción
    uint256 public immutable withdrawalLimit;

    /// @notice Límite global máximo de depósitos en el banco
    uint256 public immutable bankCap;

    /// @notice Total de ETH actualmente depositado en el banco
    uint256 public totalDeposits;

    /// @notice Número total de depósitos realizados
    uint256 public totalDepositCount;

    /// @notice Número total de retiros realizados
    uint256 public totalWithdrawalCount;

    // --- Errores personalizados ---
    error InvalidAmount();
    error WithdrawalLimitExceeded(uint256 requested, uint256 limit);
    error InsufficientFunds(uint256 requested, uint256 available);
    error BankCapExceeded(uint256 attempted, uint256 cap);
    error TransferFailed();

    // --- Eventos ---
    /// @notice Emitido cuando un usuario deposita ETH exitosamente
    event Deposit(
        address indexed user,
        uint256 amount,
        uint256 newTotalDeposits,
        uint256 totalDepositCount
    );

    /// @notice Emitido cuando un usuario retira ETH exitosamente
    event Withdrawal(
        address indexed user,
        uint256 amount,
        uint256 remainingBalance,
        uint256 totalWithdrawalCount
    );

    // --- Modificadores ---

    /// @notice Valida que la cantidad sea mayor a cero
    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    /// @notice Valida que el depósito no supere el límite global del banco
    modifier underBankCap(uint256 amount) {
        if (totalDeposits + amount > bankCap)
            revert BankCapExceeded(totalDeposits + amount, bankCap);
        _;
    }

    // --- Constructor ---
    /// @param _withdrawalLimit Límite máximo de retiro por transacción
    /// @param _bankCap Límite global de depósitos del banco
    constructor(uint256 _withdrawalLimit, uint256 _bankCap) {
        if (_withdrawalLimit == 0 || _bankCap == 0) revert InvalidAmount();
        withdrawalLimit = _withdrawalLimit;
        bankCap = _bankCap;
    }

    // --- Funciones externas ---

    /// @notice Deposita ETH en la bóveda personal del usuario
    /// @dev Llama a función privada para actualizar balances y contadores
    function deposit(uint256 amount) external payable validAmount(amount) underBankCap(amount) {
        // Verifica que el valor enviado coincida con el parámetro
        if (msg.value != amount) revert InvalidAmount();
        _updateDeposit(msg.sender, amount);
        emit Deposit(msg.sender, amount, totalDeposits, totalDepositCount);
    }
    
    /// @notice Retira ETH de la bóveda personal respetando límites
    /// @param amount Monto a retirar en wei
    function withdraw(uint256 amount) external validAmount(amount) {
        if (amount > withdrawalLimit)
            revert WithdrawalLimitExceeded(amount, withdrawalLimit);

        uint256 balance = balances[msg.sender];
        if (balance < amount)
            revert InsufficientFunds(amount, balance);

        // --- Checks → Effects → Interactions ---
        balances[msg.sender] = balance - amount;
        totalDeposits -= amount;
        totalWithdrawalCount += 1;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, amount, balances[msg.sender], totalWithdrawalCount);
    }

    // --- Función privada ---
    /// @notice Actualiza balances y contadores de depósitos
    /// @param user Dirección del usuario
    /// @param amount Monto depositado
    function _updateDeposit(address user, uint256 amount) private {
        balances[user] += amount;
        totalDeposits += amount;
        totalDepositCount += 1;
    }

    // --- Funciones de vista ---

    /// @notice Devuelve el balance del usuario
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    /// @notice Devuelve métricas globales del banco
    /// @return totalDepositsActual Total ETH depositado
    /// @return depositCount Número total de depósitos
    /// @return withdrawalCount Número total de retiros
    function getBankStats()
        external
        view
        returns (
            uint256 totalDepositsActual,
            uint256 depositCount,
            uint256 withdrawalCount
        )
    {
        return (totalDeposits, totalDepositCount, totalWithdrawalCount);
    }
}