require("dotenv").config();
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    // Dirección de KipuBank desde .env
    const bankAddress = process.env.KIPUBANK_CONTRACT;
    const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, deployer);

    // Token a actualizar: "KUSD" o "KEUR"
    const tokenType = "KUSD"; // cambiar a "KEUR" para KEUR
    const newMaxSell = hre.ethers.parseUnits("5", 18); // Nuevo monto máximo de venta

    console.log(`👤 Ejecutando como: ${deployer.address}`);
    console.log(`🏦 Contrato KipuBank en: ${bankAddress}`);
    console.log(`🔹 Actualizando monto máximo de venta para ${tokenType} a ${hre.ethers.formatUnits(newMaxSell, 18)} tokens`);

    let tx;
    if (tokenType === "KUSD") {
        tx = await bank.setUSDMaxSellAmount(newMaxSell);
    } else if (tokenType === "KEUR") {
        tx = await bank.setEURMaxSellAmount(newMaxSell);
    } else {
        throw new Error("Tipo de token inválido. Usa 'KUSD' o 'KEUR'.");
    }

    await tx.wait();
    console.log(`✅ Monto máximo de venta para ${tokenType} actualizado correctamente vía KipuBank`);
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
