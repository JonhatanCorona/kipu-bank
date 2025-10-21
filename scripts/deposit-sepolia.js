const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  // Dirección de tu contrato desplegado en Sepolia
  const contractAddress = process.env.KIPUBANK_CONTRACT;
  if (!contractAddress) {
    throw new Error("❌ Falta la variable KIPUBANK_CONTRACT en el archivo .env");
  }

  // Conectar a Sepolia usando RPC y tu wallet
  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  // Conectarse al contrato
  const KipuBank = await ethers.getContractFactory("KipuBank");
  const kipuBank = KipuBank.attach(contractAddress).connect(wallet);

  console.log("Cuenta usada:", wallet.address);

  // Balance de ETH disponible en tu wallet
  const ethBalance = await provider.getBalance(wallet.address);
  console.log("ETH disponible en wallet:", ethers.formatEther(ethBalance), "ETH");

  // Monto a depositar
  const depositAmount = "0.004"; // en ETH
  const depositWei = ethers.parseEther(depositAmount);

  try {
    // Intentar el depósito
    const tx = await kipuBank.deposit(depositWei, { value: depositWei });
    console.log("Transacción enviada:", tx.hash);

    // Esperar a que se mine
    const receipt = await tx.wait();
    console.log("Depósito confirmado en block:", receipt.blockNumber);

    // Balance después del depósito
    let balanceFinal = await kipuBank.getBalance();
    console.log("Balance en bóveda después del depósito:", ethers.formatEther(balanceFinal), "ETH");

    // Estadísticas globales del banco
    const stats = await kipuBank.getBankStats();
    console.log("Estadísticas globales del banco:", {
      totalDeposits: ethers.formatEther(stats[0]),
      totalDepositCount: stats[1].toString(),
      totalWithdrawalCount: stats[2].toString(),
    });

  } catch (error) {
    // Error por fondos insuficientes en la wallet
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.error(`Error: No tienes suficiente ETH para cubrir el depósito + gas. Tienes ${ethers.formatEther(ethBalance)} ETH, quieres depositar ${depositAmount} ETH.`);
    }
    // Error personalizado del contrato (Ethers v6)
    else if (error.code === 'CALL_EXCEPTION') {
      const data = error.data;
      if (data === "0x2c5211c6") console.error("Error: El monto a depositar debe ser mayor a 0 ETH.");
      else if (data === "0x4c7e29ab") console.error("Error: No se puede depositar, excede el límite global del banco.");
      else console.error("Error desconocido del contrato:", error);
    }
    // Otro error
    else {
      console.error("Error desconocido:", error);
    }
  }
}

main().catch((error) => {
  console.error("Error fatal:", error);
  process.exitCode = 1;
});
