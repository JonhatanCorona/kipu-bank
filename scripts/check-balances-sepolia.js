const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const contractAddress = process.env.KIPUBANK_CONTRACT;
  if (!contractAddress) {
    throw new Error("❌ Falta la variable KIPUBANK_CONTRACT en el archivo .env");
  } 

  // Conexión a Sepolia usando RPC y wallet
  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  const KipuBank = await ethers.getContractFactory("KipuBank");
  const kipuBank = KipuBank.attach(contractAddress).connect(wallet);

  console.log("Cuenta usada:", wallet.address);

  try {
    // 1️⃣ Ver balance del usuario
    const balance = await kipuBank.getBalance();
    console.log("Balance del usuario en la bóveda:", ethers.formatEther(balance), "ETH");

    // 2️⃣ Ver estadísticas globales del banco
    const [totalDeposits, totalDepositCount, totalWithdrawalCount] = await kipuBank.getBankStats();
    console.log("Estadísticas globales del banco:");
    console.log("Total depósitos:", ethers.formatEther(totalDeposits), "ETH");
    console.log("Número de depósitos:", totalDepositCount.toString());
    console.log("Número de retiros:", totalWithdrawalCount.toString());

  } catch (error) {
    console.error("Error al consultar balances o estadísticas:", error);
  }
}

main().catch((error) => {
  console.error("Error fatal:", error);
  process.exitCode = 1;
});