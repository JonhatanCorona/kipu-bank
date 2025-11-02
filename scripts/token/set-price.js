require("dotenv").config();
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    // Dirección de KipuBank desde .env
    const bankAddress = process.env.KIPUBANK_CONTRACT;
    const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, deployer);

    // Token a actualizar: "KUSD" o "KEUR"
    const tokenType = "KUSD"; // cambiar a "KEUR" para KEUR
    const newPrice = hre.ethers.parseUnits("0.012", 18); // Nuevo precio en ETH

    console.log(`👤 Ejecutando como: ${deployer.address}`);
    console.log(`🏦 Contrato KipuBank en: ${bankAddress}`);
    console.log(`🔹 Actualizando precio ${tokenType} a ${hre.ethers.formatEther(newPrice)} ETH`);

    let tx;
    if (tokenType === "KUSD") {
        tx = await bank.setUSDPrice(newPrice);
    } else if (tokenType === "KEUR") {
        tx = await bank.setEURPrice(newPrice);
    } else {
        throw new Error("Tipo de token inválido. Usa 'USD' o 'EUR'.");
    }

    await tx.wait();
    console.log(`✅ Precio ${tokenType} actualizado correctamente vía KipuBank`);
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
