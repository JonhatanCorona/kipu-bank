## 🏦 KipuBankV3

KipuBankV3 es el centro de liquidez (Liquidity Hub) del ecosistema Kipu en la blockchain de Ethereum.

Actúa como una bóveda multi-activo avanzada que no solo permite a los usuarios depositar ETH y intercambiar las stablecoins del ecosistema (KUSD, KEUR), sino que también funciona como un agregador de depósitos. Los usuarios pueden depositar ETH, USDC, o cualquier otro token ERC20, que el contrato convertirá automáticamente a USDC utilizando un router de Uniswap V2.

El contrato sigue buenas prácticas de seguridad, usa Chainlink Oracles para conversión de precios , RBAC de OpenZeppelin para control de acceso, y está documentado con NatSpec.

## 📌 Objetivos del Proyecto KipuBank

El contrato `KipuBank` está diseñado para ser el núcleo financiero y de liquidez del ecosistema Kipu, cumpliendo con los siguientes objetivos de funcionalidad, seguridad y gobernanza:

---

### 💰 Funcionalidad y Liquidez

* **Actuar como Bóveda Multi-Activo:** Almacenar valor en bóvedas individuales (vaults) para múltiples activos:
 - Bóvedas Tradicionales: Para ETH , KipuDólar (KUSD) y KipuEuro (KEUR)  adquiridos mediante ETH.
 - Bóveda de Depósito Principal (USDC): Almacenar USDC obtenido a través del nuevo flujo de depósito genérico.
 - Bóveda de Registro de Tokens: Mantener un registro del token original depositado (ej. WETH, DAI) antes de su conversión a USDC.
*  **Facilitar Intercambio de Stablecoins (ETH ‹-› Kipu)**: Servir como hub para la compra (mint/emisión) y venta (burn/quema)  de las stablecoins KUSD y KEUR a cambio de ETH, utilizando oráculos de precio internos. 
*  **Agregar Liquidez Externa (Cualquier Token -> USDC)**: Integrarse con Uniswap V2 para aceptar depósitos en ETH, USDC, o cualquier token ERC20. El contrato rutea inteligentemente estos depósitos para convertirlos a USDC, manejando las rutas:
 - ETH $\rightarrow$ USDC
 - USDC $\rightarrow$ USDC (Depósito directo)
 - Token $\rightarrow$ USDC (Ruta directa)
 - Token $\rightarrow$ WETH $\rightarrow$ USDC (Ruta triangular)
* **Proveer Estadísticas:** Ofrecer funciones de consulta para que los usuarios y administradores obtengan sus balances actuales (incluyendo ETH, KUSD, KEUR y el nuevo saldo de USDC) y un historial detallado de depósitos y retiros por tipo de activo.

---

### 🛡️ Seguridad y Control

* **Gobernanza de Roles:** Implementar un estricto **control de acceso basado en roles (RBAC)** con `SUPER_ADMIN_ROLE` y `ADMIN_ROLE` para segregar permisos y proteger funciones críticas de configuración y administración.
* **Limitar la Exposición:** Aplicar un **Límite Global de Depósitos (`bankCapUSD`)** controlado por un oráculo de Chainlink, asegurando que el valor total de la liquidez depositada (medida en USD) no exceda un máximo predefinido. Este límite se verifica de dos maneras:
 - Para depósitos directos en ETH (usados para la bóveda de ETH o para comprar KUSD/KEUR), el cap en USD se convierte a un límite equivalente en ETH usando el oráculo .
 - Para los nuevos depósitos genéricos (que se convierten a USDC), el monto de USDC recibido se compara directamente con el **(`bankCapUSD`)**.
* **Gestión de Riesgos:** Emplear patrones de seguridad esenciales:
    * **Protección contra Reentrada** (`nonReentrant`).
    * **Mecanismo de Pausa** (`Pausable`) para emergencias.
    * **Manejo Seguro de Transferencias** de ETH.
* **Claridad y Observabilidad:** Utilizar **errores personalizados** y **eventos** para proporcionar información clara y depurable sobre el estado de las transacciones (ej. cuándo se excede un límite o falla una transferencia).

---

### ⚙️ Administración y Flexibilidad

* **Configuración Dinámica:** Permitir a los administradores actualizar la capacidad máxima del banco (updateBankCap) y configurar los contratos de tokens KUSD, KEUR y, crucialmente, USDC (setTokens) , además de gestionar los parámetros de los tokens (precios, límites) .
* **Contabilidad Precisa:** Mantener una contabilidad interna fidedigna de los totales depositados y retirados por activo (ETH, KUSD, KEUR) , así como de los saldos de USDC del contrato y los depósitos de usuarios en la bóveda de USDC.
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

# Direccion del token creado de prueba o cualquier token desee probar para convertir en USDC
TOKEN_ADDRESS="0x..."
```
⚠️ Importante: Primero se debe desplegar el contrato y luego actualizar KIPUBANK_CONTRACT con la dirección resultante, y el TOKEN_ADDRESS con el token desee utilizar para convertir a USDC

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
* **`@uniswap/v2-periphery/contracts`**: Interfaces esenciales para la integración con el exchange descentralizado:

---

## 🚀 Despliegue

Desplegar el contrato en Sepolia:

```bash
# Desplegar el contrato en Sepolia
npm run deploy
```

### 🚀 Parámetros Principales del Despliegue

En el script de deploy (ya sea de prueba con *mocks* o de producción) se definen los parámetros principales:

--- Deploy KipuBank ---
```bash
// 1. Oráculo Chainlink ETH/USD en Sepolia (8 decimales)
const ethUsdFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306"; 

// 2. Dirección del Router (en el script de prueba, es 'mockRouter.target')
const uniswapRouterAddress = mockRouter.target; 

// 3. Límite global de depósitos (1 Millón de Dólares)
const bankCapInUSD = hre.ethers.parseEther("1000000"); 

// 4. Límite máximo por retiro de ETH
const withdrawalLimit = ethers.parseEther("0.01"); // 0.01 ETH


--- Deploy KipuDolar ---

// Límite de 100 KUSD que se pueden tener por wallet
const kusdWalletLimit = hre.ethers.parseUnits("100", 18); 

// 0.01 ETH por KUSD (Valor del Cambio de KUSD por ETH)
const kusdPriceInETH = hre.ethers.parseEther("0.01"); 

// Límite máximo de venta por transacción de KUSD
const kusdMaxSellAmount = hre.ethers.parseUnits("5", 18); 

--- Deploy KipuEuro ----


// Límite de 100 KEUR que se pueden tener por wallet
const keurWalletLimit = hre.ethers.parseUnits("100", 18); 

// 0.02 ETH por KEUR (Valor del Cambio de KEUR por ETH)
const keurPriceInETH = hre.ethers.parseEther("0.02"); 

// Límite máximo de venta por transacción de KEUR
const keurMaxSellAmount = hre.ethers.parseUnits("5", 18);

```

## 💻 Scripts de Interacción (Sepolia)

Para ejecutar estas operaciones, debes haber desplegado previamente los contratos y llenado la variable `KIPUBANK_CONTRACT` en tu archivo `.env`.

---

### 🏦 Operaciones de Bóveda (ETH)

| Operación | Comando | Nota de Edición |
| :--- | :--- | :--- |
| **Depositar ETH** | `npm run deposit-eth` | Editar `depositAmount` dentro del script `scripts/bank/deposit-eth.js` para modificar el monto. |
| **Retirar ETH** | `npm run withdraw-eth` | Editar `ethToWithdraw` dentro del script `scripts/bank/withdraw-eth.js` para modificar el monto. |

---

### 💳 Depósitos Genéricos (Swap a USDC)

| Operación | Comando | Nota de Edición |
| :--- | :--- | :--- |
| **Depositar ETH → USDC** | `npm run deposit-Eth-Usdc` | Editar `ETH_TO_DEPOSIT y MIN_USDC_RECEIVE ` ETH a enviar y mínimo de USDC en `scripts/bank/deposit-Eth-Usd` para modificar el monto. |
| **Depositar Token → USDC** | `npm run deposit-Eth-Usdc` | Editar `OTHER_TOKEN_TO_DEPOSIT y MIN_USDC_TOKEN_SWAP ` cantidad de tokens dentro del script `scripts/bank/deposit-Token-Usdc.js` Requiere TOKEN_ADDRESS en el .env. |
| **Depositar Token → WETH → USDC** | `npm run deposit-Token-Weth-Usdc` | Editar `OTHER_TOKEN_TO_DEPOSIT y MIN_USDC_TOKEN_SWAP` en script `scripts/bank/deposit-Token-Weth-Usdc.js` Se usa para tokens sin liquidez directa con USDC. |

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
| **Mis Balances** | `npm run check-balances` | Consulta los balances de ETH, KUSD, KEUR y USDC del `msg.sender` (deployer). |
| **Balance por Usuario** | `npm run check-balance-user` | Editar `const userAddress` (Cuenta de Ususario) Consulta balances de un usuario específico (requiere el rol ADMIN/SUPER_ADMIN). (Incluye USDC) |
| **Totales del Banco** | `npm run check-bank-totals` | Consulta las estadísticas globales de depósitos, retiros y saldos (requiere el rol ADMIN/SUPER_ADMIN).(Incluye USDC) |

---


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