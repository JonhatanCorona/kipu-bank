require("dotenv").config();
const hre = require("hardhat");

async function main() {
  // --- 1️⃣ Configurar provider y signer desde .env ---
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  console.log(`👤 Usuario: ${signer.address}\n`);

  // --- 2️⃣ Obtener instancia de KipuBank ---
  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  // --- 3️⃣ Obtener instancias de KUSD y KEUR ---
  const udsAddress = await bank.udsToken();
  const eurAddress = await bank.eurToken();
  const uds = await hre.ethers.getContractAt("KipuDolar", udsAddress, signer);
  const eur = await hre.ethers.getContractAt("KipuEuro", eurAddress, signer);

  // --- 4️⃣ Obtener balances y valor ETH en USD usando la view getMyVaults ---
  const vaults = await bank.getMyVaults();
  const ethBalance = vaults.ethBalance;
  const usdBalance = vaults.usdBalance;
  const eurBalance = vaults.eurBalance;
  const ethInUsd = vaults.ethInUsd;

  console.log("💰 Balances actuales:");
  console.log(`   • ETH:  ${hre.ethers.formatEther(ethBalance)} ETH (~$${(Number(hre.ethers.formatEther(ethInUsd))).toFixed(2)} USD)`);
  console.log(`   • KUSD: ${hre.ethers.formatUnits(usdBalance, 18)} KUSD`);
  console.log(`   • KEUR: ${hre.ethers.formatUnits(eurBalance, 18)} KEUR`);

  // --- 5️⃣ Estadísticas básicas ---
  const basicStats = await bank.getMyStats();
  console.log("\n📊 Estadísticas básicas:");
  console.log(`   • Total depósitos: ${basicStats.depositCount}`);
  console.log(`   • Total retiros:   ${basicStats.withdrawalCount}`);

  // --- 6️⃣ Estadísticas detalladas ---
  const detailedStats = await bank.getMyDetailedStats();
  console.log("\n📈 Estadísticas detalladas por moneda:");
  console.log(`   • ETH:  depositado ${hre.ethers.formatEther(detailedStats.ethDeposited)} ETH, retirado ${hre.ethers.formatEther(detailedStats.ethWithdrawn)} ETH`);
  console.log(`   • KUSD: comprado ${hre.ethers.formatUnits(detailedStats.usdDeposited, 18)} KUSD, vendido ${hre.ethers.formatUnits(detailedStats.usdWithdrawn, 18)} KUSD`);
  console.log(`   • KEUR: comprado ${hre.ethers.formatUnits(detailedStats.eurDeposited, 18)} KEUR, vendido ${hre.ethers.formatUnits(detailedStats.eurWithdrawn, 18)} KEUR`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
