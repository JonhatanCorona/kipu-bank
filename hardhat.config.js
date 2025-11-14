require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200 // Un valor bajo (ej. 200) optimiza para el TAMAÑO del deploy.
      }
    }
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL, // RPC de Sepolia
      accounts: [process.env.PRIVATE_KEY], // Clave privada de tu cuenta con ETH Sepolia
    },
  },
};
