require("dotenv").config();
const hre = require("hardhat");

async function main() {
  // --- 1️⃣ Configurar provider y signer desde env ---
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  // --- 2️⃣ Balance actual del usuario ---
  const userBalanceWei = await provider.getBalance(signer.address);
  const userBalanceEth = parseFloat(hre.ethers.formatEther(userBalanceWei));

  console.log(`👤 Cuenta: ${signer.address}`);
  console.log(`💰 Balance actual: ${userBalanceEth.toFixed(6)} ETH`);

  // --- 3️⃣ Mostrar precio ETH/USD (Sepolia feed) ---
  const ethUsdPrice = await bank.getEthUsdPrice();
  const ethUsd = (Number(ethUsdPrice) / 1e8) * userBalanceEth;
  console.log(`💵 Equivalente en USD: $${ethUsd.toFixed(2)}\n`);

  // --- 4️⃣ Realizar depósito ETH ---
  const depositAmount = hre.ethers.parseEther("0.0001");
  console.log(`🚀 Depositando ${hre.ethers.formatEther(depositAmount)} ETH en la bóveda...`);

  const tx = await bank.depositETH({ value: depositAmount });
  await tx.wait();

  console.log("✅ Depósito completado!\n");

  // --- 5️⃣ Consultar bóveda del usuario ---
  const vaults = await bank.getMyVaults();
  const stats = await bank.getMyStats();

  const vaultEth = parseFloat(hre.ethers.formatEther(vaults[0]));

  console.log(`🏦 Bóveda actualizada:`);
  console.log(`   • ETH en bóveda: ${vaultEth.toFixed(6)} ETH`);
  console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
  console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
