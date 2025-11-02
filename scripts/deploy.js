const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("🚀 Deploying contracts with account:", deployer.address);

  // --- 1. Chainlink feed real ETH/USD en Sepolia (8 decimales)
  const ethUsdFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306";

  // --- 2. Deploy KipuBank ---
  const KipuBank = await hre.ethers.getContractFactory("KipuBank");
  const bank = await KipuBank.deploy(
    hre.ethers.parseEther("0.01"), // withdrawalLimit: 0.01 ETH
    hre.ethers.parseEther("10"),   // bankCap: 10 ETH
    ethUsdFeed                     // ETH/USD feed
  );
  await bank.waitForDeployment();
  console.log("🏦 KipuBank deployed at:", bank.target);

  // --- 3. Deploy KipuDolar ---
  const KipuDolar = await hre.ethers.getContractFactory("KipuDolar");
  const kusdWalletLimit = hre.ethers.parseUnits("100", 18); // 100 KUSD
  const kusdPriceInETH = hre.ethers.parseEther("0.01");     // 0.01 ETH por KUSD
  const kusdMinSellAmount = hre.ethers.parseUnits("5", 18);

  const uds = await KipuDolar.deploy(
    bank.target,          // Banco será SUPER_ADMIN
    kusdWalletLimit,
    kusdPriceInETH,
    kusdMinSellAmount
  );
  await uds.waitForDeployment();
  console.log("💵 KipuUSD deployed at:", uds.target);

  // --- 4. Deploy KipuEuro ----
  const KipuEuro = await hre.ethers.getContractFactory("KipuEuro");
  const keurWalletLimit = hre.ethers.parseUnits("100", 18);
  const keurPriceInETH = hre.ethers.parseEther("0.02");
  const keurMinSellAmount = hre.ethers.parseUnits("5", 18);

  const eur = await KipuEuro.deploy(
    bank.target,
    keurWalletLimit,
    keurPriceInETH,
    keurMinSellAmount
  );
  await eur.waitForDeployment();
  console.log("💶 KipuEUR deployed at:", eur.target);

  // --- 5. Configurar tokens en el banco ---
  await bank.setTokens(uds.target, eur.target);
  console.log("✅ Tokens configured in KipuBank");

  console.log("🎉 KipuBank assigned as SUPER_ADMIN for KUSD and KEUR");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error en el deploy:", error);
    process.exit(1);
  });
