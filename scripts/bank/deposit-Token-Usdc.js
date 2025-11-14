const hre = require("hardhat");

async function main() {
  const [tester] = await hre.ethers.getSigners();
  console.log("👤 Usuario:", tester.address);

  // ===============================
  // ⚡ CONFIGURA ESTO CON SEPÓLIA
  // ===============================
  const CONTRACTS = {
    bank: process.env.KIPUBANK_CONTRACT,
    otherToken: process.env.TOKEN_ADDRESS
  };

  const OTHER_TOKEN_TO_DEPOSIT = hre.ethers.parseEther("0.05"); // 0,05 TTK
  const MIN_USDC_TOKEN_SWAP = 1;

  // ===============================
  // 🔹 Conectar contratos
  // ===============================
  const Bank = await hre.ethers.getContractAt("KipuBank", CONTRACTS.bank);
  const otherToken = await hre.ethers.getContractAt("MockERC20", CONTRACTS.otherToken);

  // ===============================
  // ✅ Aprobar token para el banco
  // ===============================
  const approveTx = await otherToken.connect(tester).approve(
    CONTRACTS.bank,
    OTHER_TOKEN_TO_DEPOSIT
  );
  await approveTx.wait();


  // ===============================
  // 🔹 Vault antes
  // ===============================
  const ethBalanceBefore = await ethers.provider.getBalance(tester.address);
  let vaultBefore = await Bank.usdcVaults(tester.address);
  console.log("\n📊 Balances antes del depósito:");
  console.log(`   - ETH en wallet: ${ethers.formatEther(ethBalanceBefore)} ETH`);
  console.log(`   - USDC en vault: ${ethers.formatUnits(vaultBefore, 18)} USDC`);

  // ===============================
  // 🚀 Depositar TTK → USDC
  // ===============================
  console.log(`\n🚀 Depositando ${ethers.formatEther(OTHER_TOKEN_TO_DEPOSIT)} TOKENS para convertir a USDC...`);

  try {
    const depositTx = await Bank.connect(tester).depositToken(
      CONTRACTS.otherToken,
      OTHER_TOKEN_TO_DEPOSIT,
      MIN_USDC_TOKEN_SWAP
    );
    await depositTx.wait();

    const vaultAfter = await Bank.usdcVaults(tester.address);

    // Calcular cuánto USDC se compró en esta operación
    const usdcBought = vaultAfter - vaultBefore;

    console.log("\n✅ Depósito completado:");
    console.log(`   - USDC comprados en esta operación: ${ethers.formatUnits(usdcBought, 18)} USDC`);
    console.log(`   - USDC en vault ahora: ${ethers.formatUnits(vaultAfter, 18)} USDC`);

    console.log("✅ Depósito TOKEN → USDC completado con éxito!");

  } catch (error) {
    console.error("❌ Error al depositar Token:", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
