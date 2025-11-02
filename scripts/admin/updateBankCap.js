require("dotenv").config();
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    // Reemplaza con la dirección de tu contrato en Sepolia
    const bankAddress = process.env.KIPUBANK_CONTRACT; 
    const bank = await hre.ethers.getContractAt("KipuBank", bankAddress, deployer);

    // Nuevo límite en USD: $120 USD (con 18 decimales)
    const newCapUSD = hre.ethers.parseEther("120"); 

    console.log(`👤 Ejecutando como: ${deployer.address}`);
    console.log(`🏦 Contrato KipuBank en: ${bankAddress}`);
    console.log(`📈 Intentando actualizar bankCap a: $${hre.ethers.formatEther(newCapUSD)} USD`);

    // --- Verificar roles ---
    const ADMIN_ROLE = await bank.ADMIN_ROLE();
    const SUPER_ADMIN_ROLE = await bank.SUPER_ADMIN_ROLE();

    const isAdminOrSuper = await bank.hasRole(ADMIN_ROLE, deployer.address) || await bank.hasRole(SUPER_ADMIN_ROLE, deployer.address);
    if (!isAdminOrSuper) {
        throw new Error("❌ No eres ADMIN o SUPER_ADMIN. No puedes actualizar el bankCap.");
    }

    // --- Ejecutar actualización ---
    // NOTA CLAVE: La función sigue llamándose 'updateBankCap', pero el valor 'newCap' 
    // representa USD. El contrato se encarga de asignarlo a 'bankCapUSD'.
    const tx = await bank.updateBankCap(newCapUSD);
    await tx.wait();

    // --- Verificar el resultado usando el nuevo nombre de la variable de estado ---
    // Si renombraste 'bankCap' a 'bankCapUSD', usa el nuevo nombre aquí:
    const updatedCap = await bank.bankCapUSD(); 

    console.log(`✅ bankCap actualizado correctamente.`);
    console.log(`💵 Nuevo límite en USD (variable de estado): $${hre.ethers.formatEther(updatedCap)} USD`);
}

main().catch(error => {
    console.error(error.message);
    process.exit(1);
});
