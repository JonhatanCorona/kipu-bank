const hre = require("hardhat");
const { ethers } = hre;

const ADDR = {
  bank: process.env.KIPUBANK_CONTRACT,
};

const ETH_TO_DEPOSIT = ethers.parseEther("0.001"); // solo un poquito de ETH
const MIN_USDC_RECEIVE = 1; // mínimo de USDC que aceptamos

async function main() {
  const [user] = await ethers.getSigners();
  console.log(`👤 Usuario: ${user.address}`);
  console.log(`\n🚀 Depositando ${ethers.formatEther(ETH_TO_DEPOSIT)} ETH para convertir a USDC...`);


  const bank = await ethers.getContractAt("KipuBank", ADDR.bank);

  // Mostrar balance actual de ETH y USDC
  const ethBalanceBefore = await ethers.provider.getBalance(user.address);
  const usdcVaultBefore = await bank.usdcVaults(user.address);

  console.log("\n📊 Balances antes del depósito:");
  console.log(`   - ETH en wallet: ${ethers.formatEther(ethBalanceBefore)} ETH`);
  console.log(`   - USDC en vault: ${ethers.formatUnits(usdcVaultBefore, 18)} USDC`);

  // Depositar ETH y comprar USDC en KipuBank
  console.log(`\n🚀 Depositando ${ethers.formatEther(ETH_TO_DEPOSIT)} ETH para comprar USDC...`);
  const tx = await bank.depositToken(
    ethers.ZeroAddress,   // indicamos que el depósito viene de ETH
    0,                    // monto ERC20 = 0 porque es ETH
    MIN_USDC_RECEIVE,     // mínimo de USDC a recibir
    { value: ETH_TO_DEPOSIT }
  );
  await tx.wait();

  // Mostrar balances después
  const ethBalanceAfter = await ethers.provider.getBalance(user.address);
  const usdcVaultAfter = await bank.usdcVaults(user.address);

  // Calcular cuánto USDC se compró en esta operación
  const usdcBought = usdcVaultAfter - usdcVaultBefore;

  console.log("\n✅ Depósito completado:");
  console.log(`   - ETH en wallet: ${ethers.formatEther(ethBalanceAfter)} ETH`);
  console.log(`   - USDC comprados en esta operación: ${ethers.formatUnits(usdcBought, 18)} USDC`);
  console.log(`   - USDC en vault ahora: ${ethers.formatUnits(usdcVaultAfter, 18)} USDC`);

  console.log("✅ Depósito ETH → USDC completado con éxito!");
}

main().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});
