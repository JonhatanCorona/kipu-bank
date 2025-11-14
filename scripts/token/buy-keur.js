require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  console.log(`👤 Cuenta: ${signer.address}`);

  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  // --- Instancia del token KEUR ---
  const eurAddress = await bank.eurToken();
  const eur = await hre.ethers.getContractAt("KipuEuro", eurAddress, signer);

  // --- Balance ETH del usuario ---
  const userBalanceWei = await provider.getBalance(signer.address);
  const userBalanceEth = parseFloat(hre.ethers.formatEther(userBalanceWei));
  console.log(`💰 Balance actual: ${userBalanceEth.toFixed(6)} ETH`);

  // --- Cantidad a mintar ---
  const amountToMint = hre.ethers.parseUnits("1", 18); // 100 KEUR
  console.log(`🛠 Mintando ${hre.ethers.formatUnits(amountToMint, 18)} KEUR para ${signer.address}...`);

  const tx = await bank.mintToken(eurAddress, signer.address, amountToMint);
  await tx.wait();

  console.log("✅ Mint completado!");

  // --- Consultar balance actualizado de KEUR ---
  const balance = await eur.balanceOf(signer.address);
  console.log(`🏦 Balance de KEUR en wallet: ${hre.ethers.formatUnits(balance, 18)} KEUR`);

  // --- Stats del usuario en KipuBank ---
  const stats = await bank.getMyStats();
  console.log(`📊 Stats de usuario:`);
  console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
  console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });

