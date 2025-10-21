# 🏦 KipuBank

**KipuBank** es un banco descentralizado en Ethereum que permite a los usuarios depositar y retirar ETH respetando límites por transacción y un límite global de depósitos.  
El contrato sigue buenas prácticas de seguridad y está documentado con NatSpec.

---

## 📌 Objetivos del proyecto

- Aplicar conceptos de Solidity y patrones de seguridad.  
- Emitir eventos en depósitos y retiros exitosos.  
- Manejar errores personalizados para mejorar la experiencia del usuario.  
- Desplegar un contrato funcional en testnet (Sepolia).  
- Registrar métricas globales y balances individuales.

---

## ⚙️ Instalación

1️⃣ Clonar el repositorio:

```bash
git clone <REPO_URL>
cd Kipu-Bank
```

2️⃣ Instalar dependencias:

```bash
# Recomendado: Node.js >=18, NPM >=9
npm install
```

3️⃣ Crear un archivo .env siguiendo el ejemplo .env.example:

```bash
# URL de RPC de Sepolia en Infura
SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_INFURA_KEY"

# Private key de tu wallet de prueba (sin 0x)
PRIVATE_KEY="TU_PRIVATE_KEY"

# Dirección del contrato desplegado (llenar después del deploy)
KIPUBANK_CONTRACT="0x..."
```
⚠️ Importante: Primero se debe desplegar el contrato y luego actualizar KIPUBANK_CONTRACT con la dirección resultante.

---

## 🛠️ Tecnologías utilizadas

- Solidity v0.8.28

- Hardhat: entorno de desarrollo Ethereum

- Ethers.js v6: interacción con contratos

- Chai: testing framework

- dotenv: gestión de variables de entorno

---

## 🚀 Despliegue

Desplegar el contrato en Sepolia:

```bash
# Desplegar el contrato en Sepolia
npm run deploy-sepolia
```

En el script de deploy se definen los parámetros principales:

```bash
const withdrawalLimit = ethers.parseEther("0.001"); // 0.001 ETH, límite máximo por retiro

const bankCap = ethers.parseEther("10");           // 10 ETH, límite global de depósitos
```

Después de desplegar, copiar la dirección del contrato y actualizar la variable KIPUBANK_CONTRACT en tu archivo .env.

---

## 💻 Scripts de interacción

1️⃣ Depositar ETH

```bash
npm run deposit-sepolia
```

Editar el monto a depositar dentro del script para ejecutar pruebas:

```bash
const depositAmount = "0.004"; // Monto a Depositar
```

Errores manejados:

- Fondos insuficientes en wallet

- Depósito de 0 ETH (InvalidAmount)

- Exceder el límite global del banco (BankCapExceeded)

2️⃣ Retirar ETH

```bash
npm run withdraw-sepolia
```

Editar el monto a retirar dentro del script para ejecutar pruebas:

```bash
const amountToWithdraw = ethers.parseEther("0.001"); // Monto a Retirar
```

Errores manejados:

- Exceder withdrawalLimit por transacción (WithdrawalLimitExceeded)

- Saldo insuficiente en la bóveda (InsufficientFunds)

- Retirar 0 ETH (InvalidAmount)

3️⃣ Consultar balances y estadísticas

```bash
npm run check-balances-sepolia
```

Muestra:

- Balance individual del usuario en la bóveda

- Total de depósitos del banco

- Conteo de depósitos y retiros

---

## 🔒 Seguridad

- Uso de errores personalizados en lugar de require con strings

- Patrón checks-effects-interactions para transferencias seguras

- Variables de estado inmutables (withdrawalLimit, bankCap)

- Eventos para rastrear todas las transacciones exitosas

---

## 🧪 Testing

Ejecutar tests locales con Hardhat:


```bash
npx hardhat test
```

Prueba casos de:

- Depósitos dentro del límite

- Depósitos que exceden bankCap

- Retiros dentro del límite

- Retiros que exceden withdrawalLimit o saldo

Ejemplo de test exitoso:

```bash
Deposits
  ✓ Permite depositar ETH dentro del bankCap
  ✓ Revertir si se supera el bankCap
  ✓ Revertir si depositas 0 ETH

Withdrawals
  ✓ Permite retirar hasta el withdrawalLimit
  ✓ Revertir si se intenta retirar más que el withdrawalLimit
  ✓ Revertir si se intenta retirar más que el balance
  ✓ Revertir si se intenta retirar 0 ETH
```

## 🤝 Contribuciones
Pull requests son bienvenidos. Para cambios grandes, abrir un issue primero para discutir lo que quieres cambiar.

## 📄 Licencia
Autor: Jonhatan Corona
MIT License