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

  // --- Balance ETH ---
  const userBalanceWei = await provider.getBalance(signer.address);
  const userBalanceEth = parseFloat(hre.ethers.formatEther(userBalanceWei));
  console.log(`💰 Balance actual: ${userBalanceEth.toFixed(6)} ETH`);

  const ethUsdPrice = await bank.getEthUsdPrice();
  const ethUsd = (Number(ethUsdPrice) / 1e8) * userBalanceEth;
  console.log(`💵 Equivalente en USD: $${ethUsd.toFixed(2)}\n`);

  // --- Comprar KEUR ---
  const ethToSpend = hre.ethers.parseEther("0.0001");
  console.log(`🛒 Comprando KEUR con ${hre.ethers.formatEther(ethToSpend)} ETH...`);

  const buyTx = await bank.buyKEUR({ value: ethToSpend });
  await buyTx.wait();
  console.log("✅ Compra de KEUR completada!\n");

  // --- Balance actualizado de KEUR en bóveda ---
  const vaults = await bank.getMyVaults();
  const vaultKeurBalance = parseFloat(hre.ethers.formatUnits(vaults.eurBalance, 18));

  // --- Calcular cantidad comprada usando precio del contrato ---
  const price = await eur.keurPriceInETH(); // BigInt
  const amountBoughtBN = (ethToSpend * 10n ** 18n) / price;
  const amountBought = parseFloat(hre.ethers.formatUnits(amountBoughtBN, 18));

  console.log(`💶 KEUR comprados en esta transacción: ${amountBought.toFixed(6)} KEUR`);

  // --- Stats del usuario ---
  const stats = await bank.getMyStats();

  console.log(`🏦 Wallet actualizado de ${signer.address}:`);
  console.log(`   • KEUR en bóveda: ${vaultKeurBalance.toFixed(6)} KEUR`);
  console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
  console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
