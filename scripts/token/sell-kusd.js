require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  console.log(`👤 Cuenta: ${signer.address}`);

  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  // --- Balance KUSD en bóveda ---
  const vaults = await bank.getMyVaults();
  const vaultKusdBalance = parseFloat(hre.ethers.formatUnits(vaults.usdBalance, 18));
  console.log(`🏦 Balance inicial KUSD en el banco: ${vaultKusdBalance.toFixed(6)} KUSD`);

  if (vaultKusdBalance === 0) {
    console.log("⚠️ No tienes KUSD para vender");
    return;
  }

  // --- Vender KUSD ---
  const amountToSell = hre.ethers.parseUnits("0.01", 18);
  if (amountToSell > vaults.usdBalance) {
    console.log("❌ No tienes suficiente KUSD para vender esa cantidad");
    return;
  }

  console.log(`💸 Vendiendo ${hre.ethers.formatUnits(amountToSell, 18)} KUSD...`);

  const sellTx = await bank.sellKUSD(amountToSell);
  await sellTx.wait();
  console.log("✅ Venta de KUSD completada!\n");

  // --- Nuevo balance en bóveda ---
  const vaultsAfter = await bank.getMyVaults();
  const vaultKusdBalanceAfter = parseFloat(hre.ethers.formatUnits(vaultsAfter.usdBalance, 18));
  console.log(`🏦 Balance KUSD actualizado: ${vaultKusdBalanceAfter.toFixed(6)} KUSD`);

  // --- Balance ETH después de recibir ETH ---
  const ethBalanceAfter = parseFloat(hre.ethers.formatEther(await provider.getBalance(signer.address)));
  console.log(`💰 ETH actual: ${ethBalanceAfter.toFixed(6)} ETH`);

  // --- Stats del usuario ---
  const stats = await bank.getMyStats();
  console.log(`📊 Stats del usuario:`);
  console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
  console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
