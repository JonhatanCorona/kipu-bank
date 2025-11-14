require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const provider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const signer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, provider);

  const bankAddress = process.env.KIPUBANK_CONTRACT;
  const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, signer);

  const userAddress = "0x3C7698AED48862C137FC6F0BaE2da689E059f05e";

  // Llamada a la función y destructuring
  const { ethBalance, usdBalance, eurBalance, ethInUsd, usdcBalance } = await bank.getUserVaults(userAddress);

  const stats = await bank.getUserStats(userAddress);
  const detailedStats = await bank.getUserDetailedStats(userAddress);

  console.log(`\n👤 Usuario: ${userAddress}`);
  console.log(`💰 Balances: 
  ETH: ${hre.ethers.formatEther(ethBalance)}, 
  KUSD: ${hre.ethers.formatUnits(usdBalance, 18)}, 
  KEUR: ${hre.ethers.formatUnits(eurBalance, 18)}, 
  USDC: ${hre.ethers.formatUnits(usdcBalance, 18)}`);

  console.log(`\n📊 Stats básicos: Depósitos ${stats.depositCount}, Retiros ${stats.withdrawalCount}`);
  console.log(`\n📈 Stats detalladas:`);
  console.log(`   • ETH depositado: ${hre.ethers.formatEther(detailedStats.ethDeposited)}, retirado: ${hre.ethers.formatEther(detailedStats.ethWithdrawn)}`);
  console.log(`   • KUSD comprado: ${hre.ethers.formatUnits(detailedStats.usdDeposited,18)}, vendido: ${hre.ethers.formatUnits(detailedStats.usdWithdrawn,18)}`);
  console.log(`   • KEUR comprado: ${hre.ethers.formatUnits(detailedStats.eurDeposited,18)}, vendido: ${hre.ethers.formatUnits(detailedStats.eurWithdrawn,18)}`);
  console.log(`   • USDC comprado: ${hre.ethers.formatUnits(usdcBalance, 18)}`);
}

main()
  .then(() => process.exit(0))
  .catch(console.error);
