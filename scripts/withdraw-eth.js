require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  console.log(`👤 Cuenta: ${signer.address}`);

  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  // --- 1️⃣ Balance actual en wallet ---
  const userBalanceWei = await provider.getBalance(signer.address);
  const userBalanceEth = parseFloat(hre.ethers.formatEther(userBalanceWei));
  console.log(`💰 Balance actual: ${userBalanceEth.toFixed(6)} ETH`);

  // --- 2️⃣ Precio ETH/USD ---
  const ethUsdPrice = await bank.getEthUsdPrice();
  const ethUsd = (Number(ethUsdPrice) / 1e8) * userBalanceEth;
  console.log(`💵 Equivalente en USD: $${ethUsd.toFixed(2)}\n`);

  // --- 3️⃣ Balances en bóveda del usuario ---
  const vaultData = await bank.getMyVaults();
  const vaultEthBalance = parseFloat(hre.ethers.formatEther(vaultData.ethBalance));
  console.log(`🏦 ETH en bóveda: ${vaultEthBalance.toFixed(6)} ETH\n`);

  // --- 4️⃣ Monto a retirar ---
  const ethToWithdraw = hre.ethers.parseEther("0.005");
  if (parseFloat(hre.ethers.formatEther(ethToWithdraw)) > vaultEthBalance) {
    console.log("❌ No tienes suficiente ETH en la bóveda para retirar esa cantidad");
    return;
  }

  console.log(`💸 Retirando ${hre.ethers.formatEther(ethToWithdraw)} ETH de la bóveda...`);

  // --- 5️⃣ Ejecutar retiro ---
  const withdrawTx = await bank.withdrawETH(ethToWithdraw);
  await withdrawTx.wait();
  console.log("✅ Retiro completado!\n");

  // --- 6️⃣ Mostrar balances actualizados ---
  const newVaultData = await bank.getMyVaults();
  const newVaultEthBalance = parseFloat(hre.ethers.formatEther(newVaultData.ethBalance));
  const newUserBalanceWei = await provider.getBalance(signer.address);
  const newUserBalanceEth = parseFloat(hre.ethers.formatEther(newUserBalanceWei));
  const stats = await bank.getMyStats();

  console.log(`💰 ETH actualizado en wallet: ${newUserBalanceEth.toFixed(6)} ETH`);
  console.log(`🏦 ETH restante en bóveda: ${newVaultEthBalance.toFixed(6)} ETH`);
  console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
  console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}\n`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("❌ Error ejecutando script:", error);
    process.exit(1);
  });
