require("dotenv").config();
const hre = require("hardhat");

async function main() {
  // 1️⃣ Configurar provider y signer desde .env
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);
  console.log(`👤 Ejecutando como: ${signer.address}`);

  // 2️⃣ Instanciar contrato KipuBank
  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);
  console.log(`🏦 Contrato conectado en: ${bankAddress}\n`);

  // 3️⃣ Obtener totales globales (solo Admin/SuperAdmin)
  try {
    const totals = await bank.getBankTotals();

    console.log("🌐 --- TOTALES GLOBALES DEL BANCO ---");
    console.log(`   💰 ETH depositado:        ${hre.ethers.formatEther(totals.ethDeposits)} ETH`);
    console.log(`   💸 ETH retirado:          ${hre.ethers.formatEther(totals.ethWithdrawals)} ETH`);

    console.log(`   💰 KUSD comprado:         ${hre.ethers.formatUnits(totals.usdDeposits, 18)} KUSD`);
    console.log(`   💸 KUSD vendido:          ${hre.ethers.formatUnits(totals.usdWithdrawals, 18)} KUSD`);

    console.log(`   💰 KEUR comprado:         ${hre.ethers.formatUnits(totals.eurDeposits, 18)} KEUR`);
    console.log(`   💸 KEUR vendido:          ${hre.ethers.formatUnits(totals.eurWithdrawals, 18)} KEUR`);
    
    const usdcDeposits = Number(hre.ethers.formatUnits(totals.usdcDeposits, 6));
    console.log(`   💰 USDC comprado:         ${usdcDeposits.toFixed(1)} USDC`);

    console.log(`   📊 Total depósitos:       ${totals.depositCount.toString()}`);
    console.log(`   📉 Total retiros:         ${totals.withdrawalCount.toString()}\n`);
  } catch (error) {
    console.error("❌ No eres admin o super admin, no se pueden mostrar los totales.");
    console.error(error);
  }
}

// Ejecutar script
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
