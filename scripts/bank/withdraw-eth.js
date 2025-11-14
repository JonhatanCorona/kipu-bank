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
const userBalanceUsd = (Number(ethUsdPrice) / 1e8) * userBalanceEth;
console.log(`💵 Equivalente en USD: $${userBalanceUsd.toFixed(2)}\n`);

// --- 3️⃣ Balances en bóveda del usuario ---
const vaultData = await bank.getMyVaults();
const vaultEthBalance = parseFloat(hre.ethers.formatEther(vaultData.ethBalance));
const vaultUsdBalance = (Number(ethUsdPrice) / 1e8) * vaultEthBalance;
console.log(`🏦 ETH en bóveda: ${vaultEthBalance.toFixed(6)} ETH ($${vaultUsdBalance.toFixed(2)})\n`);

// --- 4️⃣ Monto a retirar ---
const ethToWithdraw = hre.ethers.parseEther("0.01");
if (parseFloat(hre.ethers.formatEther(ethToWithdraw)) > vaultEthBalance) {
console.log("❌ No tienes suficiente ETH en la bóveda para retirar esa cantidad");
return;
}

console.log(`💸 Retirando ${hre.ethers.formatEther(ethToWithdraw)} ETH de la bóveda...`);

// --- 5️⃣ Ejecutar retiro ---
try {
const withdrawTx = await bank.withdrawETH(ethToWithdraw);
await withdrawTx.wait();
console.log("✅ Retiro completado!\n");
} catch (error) {
if (error.data) {
try {
const iface = new hre.ethers.Interface([
"error InsufficientETH(uint256 requested, uint256 available)",
"error ExceedsWithdrawalLimit(uint256 attempted, uint256 limit)"
]);
const decoded = iface.parseError(error.data);
console.error(`❌ Error al retirar: ${decoded.name} -`, decoded.args);
} catch (parseErr) {
console.error("❌ Error desconocido al retirar ETH:", error);
}
} else {
console.error("❌ Error desconocido al retirar ETH:", error);
}
return;
}

// --- 6️⃣ Mostrar balances actualizados ---
const newVaultData = await bank.getMyVaults();
const newVaultEthBalance = parseFloat(hre.ethers.formatEther(newVaultData.ethBalance));
const newVaultUsdBalance = (Number(ethUsdPrice) / 1e8) * newVaultEthBalance;

const newUserBalanceWei = await provider.getBalance(signer.address);
const newUserBalanceEth = parseFloat(hre.ethers.formatEther(newUserBalanceWei));
const newUserBalanceUsd = (Number(ethUsdPrice) / 1e8) * newUserBalanceEth;

const stats = await bank.getMyStats();

console.log(`💰 ETH actualizado en wallet: ${newUserBalanceEth.toFixed(6)} ETH ($${newUserBalanceUsd.toFixed(2)})`);
console.log(`🏦 ETH restante en bóveda: ${newVaultEthBalance.toFixed(6)} ETH ($${newVaultUsdBalance.toFixed(2)})`);
console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}\n`);
}

main()
.then(() => process.exit(0))
.catch(error => {
console.error("❌ Error ejecutando script:", error);
process.exit(1);
});
