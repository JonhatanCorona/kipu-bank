require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  console.log(`👤 Cuenta: ${signer.address}`);

  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  const keurAddress = await bank.eurToken();
  const keur = await hre.ethers.getContractAt("KipuEuro", keurAddress, signer);

  // --- Balance KEUR en bóveda ---
  const vaults = await bank.getMyVaults();
  const vaultKeurBalance = parseFloat(hre.ethers.formatUnits(vaults.eurBalance, 18));
  console.log(`🏦 Balance inicial KEUR en el banco: ${vaultKeurBalance.toFixed(6)} KEUR`);

  if (vaultKeurBalance === 0) {
    console.log("⚠️ No tienes KEUR para vender");
    return;
  }

  // --- Vender KEUR ---
  const amountToSell = hre.ethers.parseUnits("5", 18);
  if (amountToSell > vaults.eurBalance) {
    console.log("❌ No tienes suficiente KEUR para vender esa cantidad");
    return;
  }

  console.log(`💸 Vendiendo ${hre.ethers.formatUnits(amountToSell, 18)} KEUR...`);
  const sellTx = await bank.sellKEUR(amountToSell);
  await sellTx.wait();
  console.log("✅ Venta de KEUR completada!\n");

  // --- Calcular ETH recibido ---
  const price = await keur.keurPriceInETH();
  const ethReceivedBN = (amountToSell * price) / 10n ** 18n;
  const ethReceived = parseFloat(hre.ethers.formatEther(ethReceivedBN));
  console.log(`💰 ETH recibido en esta transacción: ${ethReceived.toFixed(6)} ETH`);

  // --- Balance KEUR actualizado ---
  const vaultsAfter = await bank.getMyVaults();
  const vaultKeurBalanceAfter = parseFloat(hre.ethers.formatUnits(vaultsAfter.eurBalance, 18));
  console.log(`🏦 Balance KEUR actualizado: ${vaultKeurBalanceAfter.toFixed(6)} KEUR`);

  // --- Balance ETH total en wallet ---
  const ethBalanceAfter = parseFloat(hre.ethers.formatEther(await provider.getBalance(signer.address)));
  console.log(`💰 ETH total en wallet: ${ethBalanceAfter.toFixed(6)} ETH`);

  // --- Stats del usuario ---
  const stats = await bank.getMyStats();
  console.log(`📊 Stats del usuario:`);
  console.log(`   • Total compras: ${stats.depositCount}`);
  console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
