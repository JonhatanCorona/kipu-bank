## ¿Qué es KipuBank?

KipuBank es un protocolo de "banca descentralizada" que actúa como un custodio y gestor de liquidez on-chain. Su arquitectura híbrida permite a los usuarios interactuar con tres tipos de activos principales: ETH (nativo), Stablecoins Internas (KUSD y KEUR minteados contra ETH) y USDC (obtenido mediante la liquidación automática de otros tokens).

El sistema integra oráculos de precios (Chainlink) y routers de intercambio (Uniswap V2) para automatizar conversiones y mantener la solvencia del banco mediante límites globales.

## Arquitectura y Lógica del Protocolo

El sistema se compone de un contrato principal (KipuBank) y contratos satélite para los tokens y oráculos. A continuación, describo los flujos:

###  El Motor de "Depósito Universal" (Auto-Swap a USDC)

Esta es la característica más avanzada del contrato. Permite a los usuarios depositar cualquier token ERC20 (o ETH) y que el banco lo convierta automáticamente en un balance de USDC para el usuario. 
  
El contrato KipuBank decide inteligentemente la ruta de conversión utilizando UniswapV2:

   - Si depositas ETH: Se hace un swap directo ETH $\rightarrow$ USDC.

   - Si depositas USDC: Se deposita directamente sin swap.

   - Si depositas otro Token (ej. UNI, LINK). 
    El contrato verifica la liquidez en Uniswap:
      * Ruta Directa: Si existe el par Token/USDC, hace un swap directo4.
      * Ruta Multi-salto: Si no hay liquidez directa, utiliza ETH como puente (Token -> WETH -> USDC)

###  Sistema de Bóvedas (Vaults)
  
El banco gestiona saldos internos para cada usuario, separados por activo. No mezcla los fondos de los usuarios en un solo "pool" contable, sino que rastrea:

   - ethVaults: Depósitos directos de Ether6.

   - usdVaults y eurVaults: Saldos de las monedas estables internas del ecosistema (KUSD y KEUR)7.

   - usdcVaults: Saldo resultante de los "Depósitos Universales" convertidos a USDC

###   Stablecoins Internas (KUSD y KEUR)

A diferencia del USDC (que es externo), el KipuDolar (KUSD) y el KipuEuro (KEUR) son tokens controlados por el banco.
    
   - Compra (Minting): Un usuario envía ETH al banco. El banco calcula el precio usando un oráculo interno (kusdPriceInETH) y mintea (crea) nuevos tokens KUSD/KEUR para el usuario9999.

   - Venta (Burning): El usuario devuelve KUSD/KEUR. El banco quema esos tokens y devuelve el equivalente en ETH al usuario.
   
   - Límites: Existen límites estrictos sobre cuánto puede tener una wallet (WalletLimit) y cuánto puede vender de golpe (MaxSellAmount) para proteger la liquidez del banco.
   
###  Gestión de Riesgos y Seguridad

El protocolo implementa varias capas de seguridad para evitar insolvencia o manipulación:

   - Bank Cap (Techo del Banco): Existe un límite global (bankCapUSD) de cuánto valor puede custodiar el banco. Antes de aceptar un depósito en ETH, el contrato consulta el oráculo de Chainlink para asegurar que el valor total (TVL) no exceda este techo.

   - Límites de Retiro: El contrato define un withdrawalLimit en ETH como tope máximo por transacción. Para mantener ese límite sin importar el token usado, el sistema calcula automáticamente cuántos KUSD o KEUR equivalen a ese valor en ETH usando:

      * kusdPriceInETH
      * keurPriceInETH

 Con estos precios se generan:

      * kusdMaxSellAmount
      * keurMaxSellAmount

Así, el usuario nunca puede retirar más del límite permitido en términos de ETH, garantizando coherencia y seguridad en todo el sistema.

   - Roles de Administración:

     - SUPER_ADMIN_ROLE: Puede configurar direcciones de tokens, precios internos, pausar el contrato y gestionar roles.
   
     - ADMIN_ROLE: Tiene permisos operativos limitados.
   
     - Pausable & Reentrancy: El contrato puede detenerse en caso de emergencia (whenNotPaused) y protege contra ataques de reentrada en todas las funciones que mueven fondos.
   

### Resumen Técnico del Flujo de Datos

| Componente | Función | Dependencia Externa |
|------------|----------|----------------------|
| KipuBank | Lógica principal, bóvedas, swaps | Uniswap V2, stablecoins Kipu |
| PriceOracle | Precio ETH/USD para Bank Cap | Chainlink Aggregator |
| KUSD / KEUR | Tokens ERC20 (mint/burn controlado) | Solo KipuBank |
| Uniswap Router | Swaps automáticos | Pools Uniswap V2 |

## 📘 Evaluación de Madurez del Protocolo

El análisis se basa en la revisión del código, arquitectura, dependencias y roles definidos en el contrato.

###  Nivel de Madurez del Protocolo

Actualmente, KipuBank V3 se encuentra en etapa:

🟢 Experimental / Pre-Alpha

Aunque la arquitectura del contrato es sólida y sigue buenas prácticas (NatSpec, OpenZeppelin, Chainlink, RBAC), el protocolo no cuenta con pruebas, depende fuertemente de la administración y necesita mayor blindaje económico y técnico antes de ser considerado seguro.

###  Debilidades Identificadas

-  Ausencia Total de Pruebas.

  - Cobertura de pruebas actual: 0%.
  - No existen tests de Hardhat ni Foundry.
  - Los mocks incluidos (MockRouter, MockERC20) no se utilizan.
  - Ningún flujo crítico está verificado mediante testing:

    * Depósito universal (token → USDC)
    * Swaps multi-ruta
    * Manejo de errores con try/catch
    * Límites (bankCapUSD, walletLimit, withdrawalLimit)
    * Mint/Burn de las stablecoins (KUSD/KEUR)

➡ Conclusión: No hay garantías de seguridad, solvencia ni comportamiento determinista.


-  Centralización de Precios (Riesgo Crítico).

Las stablecoins KUSD y KEUR dependen de precios definidos manualmente mediante:
 ```bash
setPrice(token, newPriceInETH)
```

Esto significa:

  -  SUPER_ADMIN puede establecer el precio arbitrariamente.
  - Es posible manipular el precio para:

    * Comprar tokens extremadamente baratos.
    * Subir su precio.
    * Venderlos para drenar el ETH del banco.

➡ Riesgo sistémico: Ataque económico que compromete todos los fondos.

-  Fragilidad en Swaps y Rutas.

El contrato usa Uniswap V2 para convertir tokens a USDC, pero:
  
   - No se valida si existe liquidez suficiente.
   - No hay fallback si la ruta falla.
   - El manejo de errores (catch) puede dejar ETH atrapado o revertir parcialmente.

➡ Sin pruebas, no hay seguridad de que los depósitos universales funcionen en redes reales.

-  Dependencia de V2 Exclusivamente.

Si una red no tiene Uniswap V2 o tiene liquidez migrada a V3, los swaps fallarán.

➡ El protocolo debe admitir múltiples DEX o fallback routers.

###  Cobertura de Pruebas

El estado actual es 0% de cobertura.
Para alcanzar un nivel adecuado de madurez, se requiere:

  - Pruebas unitarias de todos los flujos principales (depósitos, retiros, swaps, mint/burn, límites).

  - Pruebas de integración mediante mainnet forking para validar swaps reales y oráculos reales.

  - Fuzzing e invariants testing para garantizar comportamiento estable ante entradas adversas o inesperadas.

La cobertura recomendada para producción es superior al 95%.

-  Pruebas Unitarias

Casos mínimos obligatorios:

  - depositETH() incrementa correctamente la bóveda.

  - withdrawETH() respeta withdrawalLimit.

  - Compra y venta de KUSD/KEUR respetan:
    * Precios
    * walletLimit
    * maxSellAmount

  - Depósito universal:
    * ETH → USDC
    * Token → USDC (ruta directa)
    * Token → WETH → USDC (ruta triangular)

  - Manejo de errores en swaps.

-  Pruebas de Integración (Mainnet Forking)

Usando contratos reales de mainnet:

  - Swaps reales con tokens como:
    * LINK
    * WETH  
    * USDT
    * DAI

  - Verificar que las rutas existen.

  - Validar precios reales en Chainlink.

  - Confirmar que el contrato recibe los USDC finales.

- Fuzzing / Invariant Testing

Probar miles de escenarios aleatorios:

  - Depósitos masivos

  - Depósitos mínimos (1 wei)

  - Ventas repetidas de stablecoins

  - Secuencias de compra/venta + retiros

  - Manipulación de límites

➡ Verificar que nunca se rompen las invariantes financieras.

###  Documentación

Estado actual:

  - Buena documentación interna (NatSpec).

  - README principal bien estructurado.

  - No existe documentación económica del sistema.

Documentación faltante:

  - Modelo financiero de respaldo de KUSD/KEUR.

  - Riesgos del sistema.

  - Fórmulas de colateralización en ETH.

  - Explicación formal del “depósito universal”.

  - Diseño de la gobernanza y justificación de roles.

➡ Recomendación: elaborar un Gitbook o Whitepaper.

###  Roles y Poderes del Sistema.

El SUPER_ADMIN posee poderes excesivos que representan un riesgo sistémico, especialmente en la fijación de precios de KUSD/KEUR.

| Rol             | Permisos Críticos | Riesgo |
|-----------------|-------------------|--------|
| SUPER_ADMIN     | Fija precios, pausa, mintea, cambia direcciones | 🔴 Alto |
| ADMIN           | Actualiza límites, consulta estadísticas         | 🟡 Medio |
| Usuario         | Deposita, retira, compra/vende tokens            | 🟢 Bajo |


###  Invariantes del Protocolo.

Para garantizar solvencia y seguridad, el sistema debe mantener los siguientes invariantes:

  -  Solvencia del Banco

El ETH del contrato debe ser ≥ obligaciones en ETH:
```bash
ETH_Contrato ≥ Σ(EthVaults) + Σ(KUSD_supply × precioKUSD) + Σ(KEUR_supply × precioKEUR)
```

  - Consistencia de Depósitos
```bash
totalDeposits == depósitos_totales - retiros_totales
```

  -  Límites de Usuario
```bash
usdVaults ≤ kusdWalletLimit
eurVaults ≤ keurWalletLimit
```

  -  Máximo de Venta por Transacción
```bash
venta_KUSD ≤ kusdMaxSellAmount
venta_KEUR ≤ keurMaxSellAmount
```

  -  Límite de Retiro ETH
```bash
retiro ≤ withdrawalLimit
```

## Modelo de Amenazas y Vectores de Ataque

Esta sección describe los principales escenarios de ataque identificados para KipuBank, considerando lógica de negocio, supuestos del protocolo, riesgos económicos y control de acceso.

###  Arbitraje por Latencia de Oráculo (Stale Price Exploit)
Tipo: Estrategia económica / Abuso de supuestos

Severidad: Crítica

Descripción:

El protocolo utiliza un precio de ETH/USD de Chainlink para validar el bank cap, pero las operaciones de compra/venta de KUSD y KEUR usan precios internos estáticos (kusdPriceInETH / keurPriceInETH). Si estos precios no se actualizan a tiempo, quedan desfasados respecto al mercado.

Escenario de ataque:

 - El precio real de ETH cae abruptamente.

 - El precio interno no se actualiza a tiempo.

 - Un atacante ejecuta sellKUSD, recibiendo más ETH del que realmente vale el KUSD.

 - Se extrae ETH del contrato por encima del respaldo real.

Impacto: Pérdida directa de fondos y riesgo de insolvencia del banco.

###  Error de Lógica: Insolvencia por Mezcla de Fondos (Commingling)
Tipo: Lógica de negocio

Severidad: Crítica

Descripción:

El contrato mezcla todo el ETH en address(this).balance, sin separar:

 - ETH depositado por usuarios (ethVaults)

 - ETH que respalda la emisión de KUSD/KEUR

Escenario de ataque:

Usuarios de KUSD pueden retirar ETH usando sellKUSD aun si ese ETH pertenece realmente a los depositantes directos.

Consecuencia:
Los usuarios con depósitos reales en ETH pueden quedar sin fondos a pesar de que su saldo interno indica lo contrario.

###   Ataque de Sandwich en depositToken

Tipo: MEV / Front‑running

Severidad: Alta

Descripción:

depositToken permite convertir cualquier token ERC20 a USDC vía Uniswap, usando un parámetro minUSDC controlado por el usuario. Muchos usuarios pueden dejarlo en 0 o valores bajos.

Escenario de ataque:

 - Un bot detecta una operación grande con minUSDC bajo en la mempool.

 - Front‑run: El bot compra USDC, subiendo su precio.

 - El usuario ejecuta el swap y recibe muy pocos USDC.

 - Back‑run: El bot vende los USDC caros obteniendo beneficio.

Impacto:
Pérdida de valor para el usuario y transferencia económica al bot MEV.

###  Problemas de Permisos: Riesgo de Centralización (Rug Pull Administrativo)

Tipo: Control de Acceso

Severidad: Alta

Descripción:

El SUPER_ADMIN_ROLE tiene autoridad total sobre la configuración del sistema, incluyendo minting y configuración de direcciones.

Vectores posibles:

 - Minting ilimitado: Puede acuñar KUSD/KEUR sin respaldo y drenar ETH mediante sellKUSD.

 - Cambio malicioso de tokens: Puede cambiar la dirección de USDC a un token fraudulento.

 - Manipulación del router o oráculos: Puede desviar fondos o romper las rutas de swap.

Consecuencia:
Riesgo sistémico y dependencia absoluta del administrador.

###  Denegación de Servicio en Swaps Fallidos (refund revertido)

Tipo: Lógica / DoS

Severidad: Media

Descripción:

En errores de swap, el contrato intenta devolver ETH usando call.
Si el atacante usa un contrato que revierte en receive(), puede impedir la devolución del ETH y generar fallas operativas.

Uso malicioso:

Un actor puede interrumpir flujos automatizados o producir congestión al forzar fallas controladas.

### Tabla Resumen de Severidad - KipuBank 

| # | Vector de Ataque | Tipo | Severidad | Descripción Corta |
|---|-----------------|------|-----------|-----------------|
| 1 | Arbitraje de Latencia de Oráculo | Estrategia Económica / Abuso de Supuestos | 🔴 Crítica | Precio de KUSD/KEUR manual puede permitir drenar ETH si el mercado cambia rápidamente y el oráculo no se actualiza. |
| 2 | Insolvencia por Fondos Mezclados (Commingling) | Lógica de Negocio / Integridad Contable | 🔴 Crítica | ETH de depositETH se mezcla con ETH que respalda KUSD/KEUR, riesgo de fallos en retiros legítimos. |
| 3 | Ataque de Sandwich en depositToken | Front-Running / MEV | 🟠 Alta | Usuarios con minUSDC bajo pueden ser víctimas de bots MEV que reducen el valor recibido en USDC. |
| 4 | Centralización y "Rug Pull" Administrativo | Control de Acceso | 🟠 Alta | SUPER_ADMIN puede mintear KUSD/KEUR arbitrariamente o cambiar direcciones de tokens, comprometiendo fondos. |
| 5 | Denegación de Servicio (DoS) en Reembolsos de Swap | Lógica de Contrato | 🟡 Media | Si el swap falla y msg.sender.consume/gas falla, se puede bloquear reembolsos y transacciones. |


# Especificación de Invariantes y Evaluación de Impacto

Este documento describe las propiedades invariantes del protocolo KipuBank y el impacto de sus violaciones. Estas propiedades son fundamentales para garantizar la seguridad, solvencia y funcionalidad del sistema.

---

## Especificación de Invariantes

### Invariante A: Solvencia de la Bóveda de ETH (Solvency Constraint)
**Definición Formal:**
$$
Balance_{ETH}(Contract) \ge \sum_{i=0}^{n} ethVaults[user_i]
$$

**Descripción:**
El ETH almacenado en el contrato debe ser suficiente para cubrir los depósitos directos de los usuarios que realizaron `depositETH`. Garantiza que todos los retiros de ETH puedan procesarse correctamente.

**Evidencia en Código:**
El contrato mantiene un registro individual de `ethVaults` y permite retiros basados en este balance.


### Invariante B: Integridad del Techo de Depósitos (Bank Cap Integrity)
**Definición Formal:**
$$
TotalDeposits_{USD} \le BankCap_{USD}
$$

**Descripción:**
El valor total de los activos custodios (en USD) no debe superar el límite de seguridad definido por el `bankCapUSD`. Esto protege contra sobreexposición y asegura la liquidez mínima para operaciones.

**Evidencia en Código:**
Se implementa mediante el modificador `underBankCap`, que revierte cualquier depósito o compra de tokens que supere el límite.


### Invariante C: Consistencia de Emisión de Stablecoins (Minting Collateralization)
**Definición Formal:**
$$
TotalSupply_{KUSD} \approx \frac{ETH_{locked\_for\_usd} \times Price_{ETH}}{Price_{KUSD}}
$$

**Descripción:**
Cada unidad de KUSD o KEUR en circulación debe estar respaldada por ETH equivalente. Evita que los tokens se creen sin colateral, manteniendo la paridad y solvencia del sistema.

**Evidencia en Código:**
Las funciones `buyKUSD` y `buyKEUR` calculan los tokens a mintear estrictamente en función del ETH entrante (`msg.value`) y el precio del activo.


## Impacto de las Violaciones de Invariantes

### Violación del Invariante A: Solvencia de ETH
**Escenario Adverso:**
El precio de KUSD es manipulado por el admin para sobrevalorar la cantidad de ETH a retirar.

**Consecuencias:**
- Corralito técnico: Los usuarios que depositaron ETH legítimamente no pueden retirar sus fondos.
- Pérdida permanente: Los últimos usuarios en retirar podrían perder la totalidad de sus depósitos.


### Violación del Invariante B: Integridad del Bank Cap
**Escenario Adverso:**
El valor total de depósitos excede `bankCapUSD` debido a desincronización de precios o reducción manual del cap.

**Consecuencias:**
- Exposición a riesgo financiero no controlado.
- Bloqueo operativo: nuevas funciones de depósito y compra de tokens fallarán hasta corregir el cap.


### Violación del Invariante C: Consistencia de Emisión de Stablecoins
**Escenario Adverso:**
El SUPER_ADMIN mintea KUSD/KEUR sin respaldo de ETH.

**Consecuencias:**
- Hiperinflación y despeg (de-pegging) del valor de las stablecoins.
- Drenado de liquidez: ETH legítimo del banco puede ser extraído de manera inmediata, dejando los tokens sin respaldo y sin valor.


##  Recomendaciones

Para garantizar que las propiedades invariantes del protocolo (A, B y C) nunca se rompan, se recomienda implementar una estrategia de **Testing Basado en Propiedades (Fuzzing)** combinada con pruebas unitarias e integración.

### A. Validación de Solvencia (Invariante A)
**Riesgo:** `address(this).balance` menor a la suma de los depósitos de los usuarios (`ethVaults`).

**Estrategia:** Stateful Fuzzing con herramientas como **Foundry** o **Echidna**.

**Prueba Recomendada:**
- Simular 100 usuarios que realizan transacciones aleatorias de `depositETH`, `withdrawETH`, `buyKUSD` y `sellKUSD`.
- Después de cada operación, verificar:
```solidity
assert(address(KipuBank).balance >= suma(ethVaults[usuarios]));
```

Objetivo: Detectar secuencias de transacciones que drenen el ETH reservado para retiros simples.

### B. Validación del Techo de Depósitos (Invariante B)

**Riesgo**: La volatilidad de ETH/USD puede permitir exceder bankCapUSD.

**Estrategia**: Unit Testing con mocks de oráculo y manipulación de tiempo.

**Prueba Recomendada**:

 - Llenar el banco hasta el 99.9% del bankCapUSD.

 - Simular un aumento repentino del precio de ETH.

 - Intentar un depósito mínimo (1 wei).

Resultado Esperado: La transacción debe revertir si el depósito supera el límite tras la revalorización del ETH.

### C. Validación de Emisión Consistente (Invariante C)

**Riesgo**: Creación de KUSD/KEUR sin respaldo de ETH por permisos administrativos.

**Estrategia**: Pruebas de Control de Acceso Negativo.

**Prueba Recomendada**:

 - Intentar llamar a mint de KipuDolar/KipuEuro desde una cuenta externa al contrato KipuBank, incluso la del SUPER_ADMIN.

 - Modificar los contratos para que solo KipuBank tenga el MINTER_ROLE.

Objetivo: Asegurar que no se puedan crear tokens sin respaldo de ETH.

##  Conclusión y Próximos Pasos

### Evaluación Final de Madurez

 - El protocolo está en fase Experimental.

 - Código limpio y con buenas prácticas, pero vulnerable a insolvencia y arbitraje debido a:

    * Precios estáticos para KUSD/KEUR.

    * Ausencia de pruebas automatizadas.

    * Dependencia de actualizaciones manuales por SUPER_ADMIN.

### Hoja de Ruta hacia Auditoría (Audit Readiness)

 - Corrección del Oráculo

 - Eliminar precios estáticos (kusdPriceInETH, keurPriceInETH).

 - Integrar Chainlink para obtener precios USD/ETH dinámicos en transacciones de compra/venta de tokens.

 - Segregación de Fondos

 - Separar contablemente ETH de depósitos directos (ethVaults) del ETH que respalda KUSD/KEUR.

 - Garantizar que un retiro masivo de KUSD no afecte depósitos de ETH puros.

 - Implementación de Suite de Tests

 - Crear carpeta /test.

 - Cobertura de código >95%.

 - Incluir pruebas de integración con fork de Mainnet para validar swaps reales (_swapTokenToWETHtoUSDC) en Uniswap.

 - Descentralización de Roles

 - Implementar Timelock para funciones críticas (setTokens, updateBankCap) para dar margen a usuarios ante cambios maliciosos.

**Objetivo Final**: Alcanzar un nivel de madurez suficiente para una auditoría externa segura, asegurando que los invariantes del protocolo se mantengan bajo cualquier escenario de estrés o manipulación.