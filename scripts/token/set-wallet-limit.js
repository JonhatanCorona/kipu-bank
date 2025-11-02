require("dotenv").config();
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();


    // Dirección de KipuBank desde .env
    const bankAddress = process.env.KIPUBANK_CONTRACT;
    const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, deployer);

    // Token a actualizar: "KUSD" o "KEUR"
    const tokenType = "KUSD"; // cambiar a "KEUR" para KEUR
    const newLimit = hre.ethers.parseUnits("120", 18); // Nuevo límite

    console.log(`👤 Ejecutando como: ${deployer.address}`);
    console.log(`🏦 Contrato KipuBank en: ${bankAddress}`);
    console.log(`🔹 Actualizando límite de wallet para ${tokenType} a ${hre.ethers.formatUnits(newLimit, 18)} tokens`);

    let tx;
    if (tokenType === "KUSD") {
        tx = await bank.setUSDWalletLimit(newLimit);
    } else if (tokenType === "KEUR") {
        tx = await bank.setEURWalletLimit(newLimit);
    } else {
        throw new Error("Tipo de token inválido. Usa 'KUSD' o 'KEUR'.");
    }

    await tx.wait();
    console.log(`✅ Límite de wallet para ${tokenType} actualizado correctamente vía KipuBank`);
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});