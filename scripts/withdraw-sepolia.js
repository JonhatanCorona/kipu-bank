const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  // Dirección del contrato desplegado en Sepolia
  const contractAddress = process.env.KIPUBANK_CONTRACT;
  if (!contractAddress) {
    throw new Error("❌ Falta la variable KIPUBANK_CONTRACT en el archivo .env");
  } 

  // Conectar a Sepolia
  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  // Conectarse al contrato
  const KipuBank = await ethers.getContractFactory("KipuBank");
  const kipuBank = KipuBank.attach(contractAddress).connect(wallet);

  // Mostrar cuenta usada
  console.log("Cuenta usada para retirar:", wallet.address);

  // Consultar balance inicial
  const balanceInicial = await kipuBank.getBalance();
  console.log("Balance inicial en bóveda:", ethers.formatEther(balanceInicial), "ETH");

  // Intentar retirar un monto
  const amountToWithdraw = ethers.parseEther("0.001"); // Ejemplo: 0.001 ETH

  try {
    const tx = await kipuBank.withdraw(amountToWithdraw);
    const receipt = await tx.wait();
    console.log("Retiro exitoso, transacción:", tx.hash);
    console.log("Confirmado en block:", receipt.blockNumber);

    // Consultar balance final
    const balanceFinal = await kipuBank.getBalance();
    console.log("Balance después del retiro:", ethers.formatEther(balanceFinal), "ETH");
  } catch (error) {
    // Capturar errores de custom errors
    if (error.data) {
      const errorSelector = error.data.substring(0, 10); // primeros 4 bytes del selector
      switch (errorSelector) {
        case "0x31728a05": // BankCapExceeded (ejemplo de tu error)
          console.error("Error: No se puede depositar, excede el límite global del banco.");
          break;
        case "0xb945e2d8": // WithdrawalLimitExceeded
          console.error("Error: No se puede retirar, excede el límite por transacción.");
          break;
        case "0x2e1a7d4d": // InsufficientFunds
          console.error("Error: No se puede retirar, saldo insuficiente en la bóveda.");
          break;
        default:
          console.error("Error desconocido:", error);
      }
    } else {
      console.error("Error desconocido:", error);
    }
  }

  // Mostrar estadísticas globales
  const stats = await kipuBank.getBankStats();
  console.log("Estadísticas globales del banco:", {
    totalDeposits: ethers.formatEther(stats[0]),
    totalDepositCount: stats[1].toString(),
    totalWithdrawalCount: stats[2].toString(),
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
