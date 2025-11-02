require("dotenv").config();
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    const bankAddress = process.env.KIPUBANK_CONTRACT;
    const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, deployer);

    // Acción: "pause" o "unpause"
    const action = "unpause";

    console.log(`👤 Ejecutando como: ${deployer.address}`);
    console.log(`🏦 Contrato KipuBank en: ${bankAddress}`);

    // 1️⃣ Verificar rol SUPER_ADMIN
    const SUPER_ADMIN_ROLE = await bank.SUPER_ADMIN_ROLE();
    const isSuperAdmin = await bank.hasRole(SUPER_ADMIN_ROLE, deployer.address);
    if (!isSuperAdmin) {
        throw new Error("❌ No eres SUPER_ADMIN. No puedes pausar o reanudar el contrato.");
    }

    // 2️⃣ Verificar estado actual del contrato
    const paused = await bank.paused();
    let tx;

    if (action === "pause") {
        if (paused) {
            console.log("⚠️ Contrato ya está pausado");
            return;
        }
        tx = await bank.pause();
    } else if (action === "unpause") {
        if (!paused) {
            console.log("⚠️ Contrato ya está activo");
            return;
        }
        tx = await bank.unpause();
    } else {
        throw new Error("Acción inválida. Usa 'pause' o 'unpause'");
    }

    // 3️⃣ Esperar confirmación de la transacción
    await tx.wait();
    console.log(`✅ Contrato ${action === "pause" ? "pausado" : "reanudado"} correctamente.`);
}

main().catch(error => {
    console.error(error.message);
    process.exit(1);
});
