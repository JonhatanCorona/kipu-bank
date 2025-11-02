require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  console.log(`👤 Cuenta: ${signer.address}`);

  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  // --- Balance ETH ---
  const userBalanceWei = await provider.getBalance(signer.address);
  const userBalanceEth = parseFloat(hre.ethers.formatEther(userBalanceWei));
  console.log(`💰 Balance actual: ${userBalanceEth.toFixed(6)} ETH`);

  const ethUsdPrice = await bank.getEthUsdPrice();
  const ethUsd = (Number(ethUsdPrice) / 1e8) * userBalanceEth;
  console.log(`💵 Equivalente en USD: $${ethUsd.toFixed(2)}\n`);

  // --- Comprar KUSD ---
  const ethToSpend = hre.ethers.parseEther("0.0001");
  console.log(`🛒 Comprando KUSD con ${hre.ethers.formatEther(ethToSpend)} ETH...`);

  const buyTx = await bank.buyKUSD({ value: ethToSpend });
  await buyTx.wait();
  console.log("✅ Compra de KUSD completada!\n");

  // --- Obtener balance actualizado de KUSD en bóveda ---
  const vaultData = await bank.getMyVaults();
  const vaultKusdBalance = parseFloat(hre.ethers.formatUnits(vaultData.usdBalance, 18));

  // --- Obtener precio KUSD/ETH ---
  const udsAddress = await bank.udsToken();
  const uds = await hre.ethers.getContractAt("KipuDolar", udsAddress, signer);
  const price = await uds.kusdPriceInETH();
  const amountBoughtBN = (ethToSpend * 10n ** 18n) / price;
  const amountBought = parseFloat(hre.ethers.formatUnits(amountBoughtBN, 18));

  console.log(`💶 KUSD comprados en esta transacción: ${amountBought.toFixed(6)} KUSD`);

  // --- Stats y bóveda actualizada ---
  const stats = await bank.getMyStats();

  console.log(`🏦 Wallet actualizado de ${signer.address}:`);
  console.log(`   • KUSD en bóveda: ${vaultKusdBalance.toFixed(6)} KUSD`);
  console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
  console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
