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
const userBalanceUsd = (Number(ethUsdPrice) / 1e8) * userBalanceEth;
console.log(`💵 Equivalente en USD: $${userBalanceUsd.toFixed(2)}\n`);

// --- 4️⃣ Realizar depósito ETH ---
const depositAmount = hre.ethers.parseEther("0.001");
console.log(`🚀 Intentando depositar ${hre.ethers.formatEther(depositAmount)} ETH en la bóveda...`);

try {
const tx = await bank.depositETH({ value: depositAmount });
await tx.wait();
console.log("✅ Depósito completado!\n");
} catch (error) {
if (error.data) {
try {
const iface = new hre.ethers.Interface([
"error BankCapExceeded(uint256 attempted, uint256 cap)"
]);
const decoded = iface.parseError(error.data);
console.error(`❌ Depósito fallido: intentaste depositar ${hre.ethers.formatEther(decoded.args.attempted)} ETH, pero el límite del banco es ${hre.ethers.formatEther(decoded.args.cap)} ETH`);
} catch (parseErr) {
console.error("❌ Error desconocido al depositar ETH:", error);
}
} else {
console.error("❌ Error desconocido al depositar ETH:", error);
}
}

// --- 5️⃣ Consultar bóveda del usuario ---
const vaults = await bank.getMyVaults();
const stats = await bank.getMyStats();

const vaultEth = parseFloat(hre.ethers.formatEther(vaults[0]));
const vaultUsd = (Number(ethUsdPrice) / 1e8) * vaultEth;

console.log(`🏦 Bóveda actualizada:`);
console.log(`   • ETH en bóveda: ${vaultEth.toFixed(6)} ETH ($${vaultUsd.toFixed(2)})`);
console.log(`   • Total depósitos/compras: ${stats.depositCount}`);
console.log(`   • Total retiros/ventas: ${stats.withdrawalCount}`);
}

main()
.then(() => process.exit(0))
.catch((error) => {
console.error(error);
process.exit(1);
});
