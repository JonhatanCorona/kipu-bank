require("dotenv").config();
const hre = require("hardhat");

async function main() {
  // --- 1️⃣ Configurar provider y signer desde .env ---
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  console.log(`👤 Ejecutando como: ${signer.address}`);

  // --- 2️⃣ Obtener instancia de KipuBank ---
  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  // --- 3️⃣ Totales globales usando función protegida solo para admin ---
  try {
    const totals = await bank.getBankTotals();
    console.log("\n🏦 Totales globales del banco (solo admin):");
    console.log(`   • ETH:  depositado ${hre.ethers.formatEther(totals.ethDeposits)} ETH, retirado ${hre.ethers.formatEther(totals.ethWithdrawals)} ETH`);
    console.log(`   • KUSD: comprado ${hre.ethers.formatUnits(totals.usdDeposits, 18)} KUSD, vendido ${hre.ethers.formatUnits(totals.usdWithdrawals, 18)} KUSD`);
    console.log(`   • KEUR: comprado ${hre.ethers.formatUnits(totals.eurDeposits, 18)} KEUR, vendido ${hre.ethers.formatUnits(totals.eurWithdrawals, 18)} KEUR`);
  } catch (error) {
    console.error("❌ No eres admin o super admin, no se pueden mostrar los totales");
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
