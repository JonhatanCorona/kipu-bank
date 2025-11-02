## 🏦 KipuBank

KipuBank es el banco de liquidez centralizado y descentralizado (Liquidity Hub) del ecosistema Kipu en la blockchain de Ethereum.
Actúa como una bóveda multi-activo que permite a los usuarios depositar ETH, intercambiar stablecoins (KUSD, KEUR) y gestionar liquidez dentro del ecosistema Kipu.
El contrato sigue buenas prácticas de seguridad, usa Chainlink Oracles para conversión de precios, RBAC de OpenZeppelin para control de acceso, y está documentado con NatSpec.


## 📌 Objetivos del Proyecto KipuBank

El contrato `KipuBank` está diseñado para ser el **núcleo financiero y de liquidez** del ecosistema Kipu, cumpliendo con los siguientes objetivos de funcionalidad, seguridad y gobernanza:

---

### 💰 Funcionalidad y Liquidez

* **Actuar como Bóveda Multi-Activo:** Permitir a los usuarios depositar y almacenar Ether (**ETH**), KipuDólar (**KUSD**) y KipuEuro (**KEUR**) en cuentas individuales (*vaults*).
* **Centralizar el Intercambio:** Servir como *hub* de liquidez para facilitar la **compra** (mint/emisión) y **venta** (burn/quema) de las *stablecoins* KUSD y KEUR a cambio de ETH, utilizando oráculos de precio.
* **Proveer Estadísticas:** Ofrecer funciones de consulta para que los usuarios y administradores obtengan sus **balances actuales** y un **historial detallado** de depósitos y retiros por tipo de activo.

---

### 🛡️ Seguridad y Control

* **Gobernanza de Roles:** Implementar un estricto **control de acceso basado en roles (RBAC)** con `SUPER_ADMIN_ROLE` y `ADMIN_ROLE` para segregar permisos y proteger funciones críticas de configuración y administración.
* **Limitar la Exposición:** Aplicar un **Límite Global de Depósitos (`bankCapUSD`)** controlado por un oráculo de Chainlink, asegurando que el valor total de la liquidez depositada (medida en USD) no exceda un máximo predefinido.
* **Gestión de Riesgos:** Emplear patrones de seguridad esenciales:
    * **Protección contra Reentrada** (`nonReentrant`).
    * **Mecanismo de Pausa** (`Pausable`) para emergencias.
    * **Manejo Seguro de Transferencias** de ETH.
* **Claridad y Observabilidad:** Utilizar **errores personalizados** y **eventos** para proporcionar información clara y depurable sobre el estado de las transacciones (ej. cuándo se excede un límite o falla una transferencia).

---

### ⚙️ Administración y Flexibilidad

* **Configuración Dinámica:** Permitir a los administradores **actualizar la capacidad máxima** del banco (`updateBankCap`) y **configurar los contratos de tokens** KUSD y KEUR (ej. asignar direcciones, establecer precios y límites de venta/tenencia) después del despliegue.
* **Contabilidad Precisa:** Mantener una contabilidad interna fidedigna de los totales depositados y retirados, así como de los **saldos de ETH** del contrato, para la verificación de solvencia.

## ⚙️ Instalación

1️⃣ Clonar el repositorio:

```bash
git clone <https://github.com/JonhatanCorona/kipu-bank.git>
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

| Tecnología | Versión Clave | Propósito |
| :--- | :--- | :--- |
| **Solidity** | `v0.8.28` | Lenguaje de programación para el contrato inteligente. |
| **Hardhat** | `^2.26.3` | Entorno de desarrollo para compilar, desplegar y testear contratos Ethereum. |
| **Ethers.js** | `^6.15.0` | Librería para la interacción con los contratos y la blockchain. |
| **Chai** | `^4.5.0` | Framework de aserciones utilizado para escribir tests. |
| **dotenv** | `^17.2.3` | Gestión segura de variables de entorno y claves privadas. |

---


### 🧩 Dependencias del Proyecto (`package.json`)

#### Dependencias Principales

Estas librerías son esenciales para la funcionalidad central del contrato:

* **`@openzeppelin/contracts`** (`^5.4.0`): Contratos probados y auditados para características de seguridad y estándar (AccessControl, Pausable, ReentrancyGuard).
* **`@chainlink/contracts`** (`^1.5.0`): Librerías para interactuar con los Data Feeds de Chainlink (Oráculos de precios ETH/USD).

---

## 🚀 Despliegue

Desplegar el contrato en Sepolia:

```bash
# Desplegar el contrato en Sepolia
npm run deploy
```


En el script de deploy se definen los parámetros principales:


 ---  Deploy KipuBank ---
  ```bash
const ethUsdFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306"; //  1. Chainlink feed real ETH/USD en Sepolia (8 decimales)

const bankCapInUSD = hre.ethers.parseEther("100");  // 100 Dolares, límite global de depósitos

const withdrawalLimit = ethers.parseEther("0.001"); // 0.001 ETH, límite máximo por retiro
```
--- Deploy KipuDolar --- 
  ```bash
 const kusdWalletLimit = hre.ethers.parseUnits("100", 18); // 100 KUSD Limite de KUSD que se pueden comprar

 const kusdPriceInETH = hre.ethers.parseEther("0.01");  // 0.01 ETH por KUSD (Valor del Camabio de KUSD por ETH)

 const kusdMaxSellAmount = hre.ethers.parseUnits("5", 18); // Limite maximo de retiro por transaccion de KUSD
```
--- Deploy KipuEuro ----
```bash
const keurWalletLimit = hre.ethers.parseUnits("100", 18); // 100 KEUR Limite de KUSD que se pueden 

  const keurPriceInETH = hre.ethers.parseEther("0.02"); // 0.01 ETH por KUSD (Valor del Camabio de KEUR por ETH)

  const keurMaxSellAmount = hre.ethers.parseUnits("5", 18); // Limite maximo de retiro por transaccion de KEUR
```
Después de desplegar, copiar la dirección del contrato y actualizar la variable KIPUBANK_CONTRACT en tu archivo .env.

---

## 💻 Scripts de Interacción (Sepolia)

Para ejecutar estas operaciones, debes haber desplegado previamente los contratos y llenado la variable `KIPUBANK_CONTRACT` en tu archivo `.env`.

---

### 🏦 Operaciones de Bóveda (ETH)

| Operación | Comando | Nota de Edición |
| :--- | :--- | :--- |
| **Depositar ETH** | `npm run deposit-eth` | Editar `depositAmount` dentro del script `scripts/bank/deposit-eth.js` para modificar el monto. |
| **Retirar ETH** | `npm run withdraw-eth` | Editar `ethToWithdraw` dentro del script `scripts/bank/withdraw-eth.js` para modificar el monto. |

---

### 🔄 Compra y Venta de Tokens

| Operación | Comando | Nota de Edición |
| :--- | :--- | :--- |
| **Comprar KUSD** | `npm run buy-kusd` | Editar `const ethToSpend` (ETH a cambiar por KUSD) en el script `scripts/token/buy-kusd.js`. |
| **Vender KUSD** | `npm run sell-kusd` | Editar `const amountToSell` (KUSD a retirar) en el script `scripts/token/sell-kusd.js`. |
| **Comprar KEUR** | `npm run buy-keur` | Editar `const ethToSpend` (ETH a cambiar por KEUR) en el script `scripts/token/buy-keur.js` |
| **Vender KEUR** | `npm run sell-keur` | Editar `const amountToSell` (KEUR a retirar) en el script `scripts/token/sell-keur.js` necesita definir la cantidad de KEUR a vender. |

---

### 📈 Consultas y Estadísticas

| Consulta | Comando | Descripción |
| :--- | :--- | :--- |
| **Mis Balances** | `npm run check-balances` | Consulta los balances de ETH, KUSD y KEUR del `msg.sender` (deployer). |
| **Balance por Usuario** | `npm run check-balance-user` | Editar `const userAddress` (Cuenta de Ususario) Consulta balances de un usuario específico (requiere el rol ADMIN/SUPER_ADMIN). |
| **Totales del Banco** | `npm run check-bank-totals` | Consulta las estadísticas globales de depósitos, retiros y saldos (requiere el rol ADMIN/SUPER_ADMIN). |

---

### 👑 Funciones Administrativas (Admin/Super Admin)

### 👑 Funciones Administrativas (Admin/Super Admin)

| Función | Comando | Rol Requerido | Descripción |
| :--- | :--- | :--- | :--- |
| **Gestionar Roles** | `npm run manage-roles` | `SUPER_ADMIN_ROLE` | Ejecuta acciones administrativas sobre los roles de la plataforma. Permite **añadir o remover** las cuentas como **Admin** o **SuperAdmin** (`addAdmin`, `removeAdmin`, `addSuperAdmin`, `removeSuperAdmin`). El script objetivo es la cuenta del usuario: `0x3C76...f05e`. |
| **Actualizar Límite Global** | `npm run update-bank-cap` | `ADMIN_ROLE` o `SUPER_ADMIN_ROLE` | Establece un nuevo límite máximo global para los depósitos en el banco, el cual se mide en USD utilizando el oráculo. El ejemplo establece el nuevo límite en **$120 USD** (`parseEther("120")`). |
| **Pausar/Reanudar** | `npm run pause-unpause` | `SUPER_ADMIN_ROLE` | Permite detener (`"pause"`) o reactivar (`"unpause"`) las operaciones críticas del banco (depósitos, retiros, compra/venta de tokens) en caso de emergencia. |
| **Establecer Precios (KUSD/KEUR)** | `npm run set-price` | `SUPER_ADMIN_ROLE` | Modifica el precio al que se compran o venden los tokens. El ejemplo actualiza el precio del token especificado (`"KUSD"` o `"KEUR"`) a **$0.012 ETH** por token. |
| **Establecer Límite Wallet (KUSD/KEUR)** | `npm run set-wallet-limit` | `SUPER_ADMIN_ROLE` | Define la cantidad máxima de tokens (KUSD o KEUR) que un usuario puede mantener en su *wallet* (externa al banco). El ejemplo establece el nuevo límite en **120 tokens**. |
| **Establecer Máximo de Venta (KUSD/KEUR)** | `npm run set-max-sell-amount` | `SUPER_ADMIN_ROLE` | Define la cantidad máxima de tokens (KUSD o KEUR) que un usuario puede vender en una sola transacción. El ejemplo establece el nuevo máximo de venta por transaccion en **5 tokens**. |

---

## 🤝 Contribuciones
Pull requests son bienvenidos. Para cambios grandes, abrir un issue primero para discutir lo que quieres cambiar.

## 📄 Licencia
- Autor: Jonhatan Corona
- MIT License