const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying contracts on Sepolia with mocks...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("👤 Deployer:", deployer.address);

  // =====================================================
  // 1️⃣ Deploy Mock USDC
  // =====================================================
  const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
  const usdc = await MockERC20.deploy("Mock USDC", "USDC", 6);
  await usdc.waitForDeployment();
  console.log("💵 MockUSDC deployed at:", usdc.target);

  // =====================================================
  // 2️⃣ Deploy Mock WETH
  // =====================================================
  const mockWETH = await MockERC20.deploy("Wrapped Ether", "WETH", 18);
  await mockWETH.waitForDeployment();
  console.log("🟣 Mock WETH deployed at:", mockWETH.target);

  // =====================================================
  // 3️⃣ Deploy Mock UniswapFactory
  // =====================================================
  const MockUniswapFactory = await hre.ethers.getContractFactory("MockUniswapFactory");
  const factory = await MockUniswapFactory.deploy();
  await factory.waitForDeployment();
  console.log("🏭 MockUniswapFactory deployed at:", factory.target);

  // =====================================================
  // 4️⃣ Deploy Mock UniswapRouter
  // =====================================================
  const MockUniswapRouter = await hre.ethers.getContractFactory("MockUniswapRouter");
  const mockRouter = await MockUniswapRouter.deploy(mockWETH.target, factory.target);
  await mockRouter.waitForDeployment();
  console.log("🔁 MockUniswapRouter deployed at:", mockRouter.target);

  // =====================================================
  // 5️⃣ ETH/USD oracle (Sepolia)
  // =====================================================
  const ethUsdFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306";

  // =====================================================
  // 6️⃣ Deploy KipuBank
  // =====================================================
  const KipuBank = await hre.ethers.getContractFactory("KipuBank");
  const withdrawalLimit = hre.ethers.parseEther("0.01");
  const bankCapInUSD = hre.ethers.parseEther("1000000");

  const bank = await KipuBank.deploy(
    withdrawalLimit,
    bankCapInUSD,
    ethUsdFeed,
    mockRouter.target
  );
  await bank.waitForDeployment();
  console.log("🏦 KipuBank deployed at:", bank.target);

  // =====================================================
  // 7️⃣ Deploy KipuUSD
  // =====================================================

  const kusdPriceInETH = hre.ethers.parseEther("0.01");  // 1 KUSD = 0.01 ETH

  // calcular kusdMaxSellAmount a partir del withdrawalLimit
  const kusdMaxSellAmount =
  (withdrawalLimit * hre.ethers.parseUnits("1", 18)) / kusdPriceInETH;

  const KipuDolar = await hre.ethers.getContractFactory("KipuDolar");
  const kusd = await KipuDolar.deploy(
    bank.target,
    hre.ethers.parseUnits("100", 18),
    kusdPriceInETH,
    kusdMaxSellAmount
  );
  await kusd.waitForDeployment();
  console.log("💲 KipuUSD deployed at:", kusd.target);

  // =====================================================
  // 8️⃣ Deploy KipuEUR
  // =====================================================
  const keurPriceInETH = hre.ethers.parseEther("0.02");  // Precio de 1 KEUR en ETH

  // Calcular el límite máximo de venta en KEUR equivalente a withdrawalLimit en ETH
  const keurMaxSellAmount =
  (withdrawalLimit * hre.ethers.parseUnits("1", 18)) / keurPriceInETH;

  const KipuEuro = await hre.ethers.getContractFactory("KipuEuro");
  const keur = await KipuEuro.deploy(
    bank.target,
    hre.ethers.parseUnits("100", 18),   // límite por wallet (ejemplo)
    keurPriceInETH,                      // precio KEUR/ETH
    keurMaxSellAmount                     // límite de venta en KEUR
  );
  await keur.waitForDeployment();
  console.log("💶 KipuEUR deployed at:", keur.target);

  // =====================================================
  // 9️⃣ Configure tokens in KipuBank
  // =====================================================
  await bank.setTokens(kusd.target, keur.target, usdc.target);
  console.log("✅ Tokens configured in KipuBank");

  // =====================================================
  // 🔟 Deploy Otro Token y crear pares
  // =====================================================
  const otherToken = await MockERC20.deploy("Test Token", "TTK", 18);
  await otherToken.waitForDeployment();
  console.log("🧪 Otro Token deployed at:", otherToken.target);

  // Crear pares en la factory
  await factory.createPair(otherToken.target, usdc.target);
  await factory.createPair(kusd.target, usdc.target);
  await factory.createPair(keur.target, usdc.target);
  console.log("🔹 Pairs TTK/KUSD/KUER ↔ USDC created in MockUniswapFactory");

  // =====================================================
  // 1️⃣1️⃣ Configurar tasas mock en el router
  // =====================================================
  await mockRouter.setRate(mockWETH.target, usdc.target, hre.ethers.parseUnits("3000", 6)); // 1 ETH = 3000 USDC
  await mockRouter.setRate(usdc.target, mockWETH.target, hre.ethers.parseUnits("0.000333", 18)); // 1 USDC = 0.000333 ETH
  await mockRouter.setRate(otherToken.target, usdc.target, hre.ethers.parseUnits("100", 6));
  await mockRouter.setRate(kusd.target, usdc.target, hre.ethers.parseUnits("1", 6));
  await mockRouter.setRate(keur.target, usdc.target, hre.ethers.parseUnits("1.1", 6));
  console.log("🔧 Mock router rates configured");

  // =====================================================
  // 1️⃣2️⃣ Mint inicial para liquidez en el router
  // =====================================================
  const initialUSDC = hre.ethers.parseUnits("100000000", 6); // 100 millones USDC
  const initialWETH = hre.ethers.parseEther("1000"); // 1000 WETH

  await usdc.mint(mockRouter.target, initialUSDC);
  console.log(`💵 Mint ${initialUSDC} USDC al MockRouter para swaps`);

  await mockWETH.mint(mockRouter.target, initialWETH);
  console.log(`🟣 Mint ${initialWETH} WETH al MockRouter para swaps`);

  console.log("\n🎉 Sepolia deploy with mocks complete!\n");
  console.log({
    bank: bank.target,
    kusd: kusd.target,
    keur: keur.target,
    usdc: usdc.target,
    otherToken: otherToken.target,
    router: mockRouter.target,
    weth: mockWETH.target,
    feed: ethUsdFeed,
    factory: factory.target
  });
}

main().catch((error) => {
  console.error("❌ Error in deploy:", error);
  process.exit(1);
});
