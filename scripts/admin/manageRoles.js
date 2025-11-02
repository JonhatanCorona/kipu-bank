require("dotenv").config();
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    const bankAddress = process.env.KIPUBANK_CONTRACT;
    const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, deployer);

    // --- Configura la acción y el objetivo ---
    const action = "addSuperAdmin"; // "addAdmin" | "removeAdmin" | "addSuperAdmin" | "removeSuperAdmin"
    const target = "0x3C7698AED48862C137FC6F0BaE2da689E059f05e";    // Dirección objetivo

    console.log(`👤 Ejecutando como: ${deployer.address}`);
    console.log(`🏦 Contrato KipuBank en: ${bankAddress}`);
    console.log(`🔹 Acción: ${action} sobre ${target}`);

    // --- Verificar rol SUPER_ADMIN ---
    const SUPER_ADMIN_ROLE = await bank.SUPER_ADMIN_ROLE();
    const isSuperAdmin = await bank.hasRole(SUPER_ADMIN_ROLE, deployer.address);
    if (!isSuperAdmin) {
        throw new Error("❌ No eres SUPER_ADMIN. No puedes ejecutar acciones administrativas.");
    }

    // --- Ejecutar acción ---
    let tx;
    switch(action) {
        case "addAdmin":
            tx = await bank.addAdmin(target);
            break;
        case "removeAdmin":
            tx = await bank.removeAdmin(target);
            break;
        case "addSuperAdmin":
            tx = await bank.addSuperAdmin(target);
            break;
        case "removeSuperAdmin":
            tx = await bank.removeSuperAdmin(target);
            break;
        default:
            throw new Error("Acción inválida. Usa: addAdmin, removeAdmin, addSuperAdmin, removeSuperAdmin");
    }

    await tx.wait();
    console.log(`✅ Acción '${action}' sobre ${target} ejecutada correctamente.`);
}

main().catch(error => {
    console.error(error.message);
    process.exit(1);
});
