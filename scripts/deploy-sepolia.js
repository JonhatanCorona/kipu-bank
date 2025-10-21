const { ethers } = require("hardhat");

async function main() {
  const withdrawalLimit = ethers.parseEther("0.001"); // 0.001 ETH maximo por retiro
  const bankCap = ethers.parseEther("10");       // Cap global 10 ETH

  const KipuBank = await ethers.getContractFactory("KipuBank");
  const kipuBank = await KipuBank.deploy(withdrawalLimit, bankCap);

  await kipuBank.waitForDeployment(); // Ethers v6

  console.log("KipuBank desplegado en Sepolia:", await kipuBank.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
