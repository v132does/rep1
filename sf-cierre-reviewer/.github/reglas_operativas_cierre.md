# 🏦 REGLAS OPERATIVAS Y CADENAS DE CIERRE (Bankitti)

> Fuente de verdad de negocio para el revisor de codigo CB. Define criticidad, volumetria, paralelismo y orden de ejecucion de las cadenas de cierre.

---

## 📜 REGLA 1: CRITICIDAD Y EXTRACCIÓN DE LA CADENA DE CIERRE (Campo: OBLIGATORIO)

Busca el programa en el "Catálogo Maestro" al final de este documento. Fíjate en su última columna (`OBLIGATORIO`):

### **🔴 Si es 'S' (Obligatorio - Proceso Crítico):**
- El cierre contable **NO puede finalizar** sin este programa. Es BLOQUEANTE.
- En el review: validar con criterio estricto idempotencia, error handling y dependencias. Un fallo aqui detiene el cierre del banco.

---

### **🟢 Si es 'N' (No Obligatorio - Candidato a Desacople):**
- No es bloqueante del cierre. Es candidato a extraccion o desacople.
- En el review: aplicar criterio normal. Notar si el proceso podria ejecutarse fuera de la ventana critica.

---

### **📊 Resumen de Enfoque:**
| OBLIGATORIO | Enfoque Principal | Complejidad de Análisis | Oportunidad de Desacople |
|-------------|-------------------|-------------------------|--------------------------|
| **'S' (Sí)** | Optimizar primero, luego evaluar extracción | 🔴 MUY ALTA (verificar exhaustivamente, cruzar info) | ⚠️ DELICADA (posible pero requiere validación de negocio) |
| **'N' (No)** | Extraer/desacoplar directamente | 🟢 MEDIA (más sencillo) | ✅ ALTA (Quick Win) |

---

## ⏱️ REGLA 2: VOLUMETRÍA CRÍTICA Y PERFORMANCE

Revisa si el programa analizado se encuentra en este Top de programas más pesados. Si está, **DEBES generar una ⚠️ ALERTA DE PERFORMANCE** en tu análisis, citando sus números exactos.

| PROGRAMA | PROMEDIO_DIARIO | PICO_MAXIMO | PICO_MINIMO | DIAS_EVALUADOS |
| :--- | :--- | :--- | :--- | :--- |
| `PRG_TRA_HISTORICO` | 7,528,794 | 19,973,598 | 4,633,376 | 42 |
| `PRA_CON_TRANSACCION` | 7,528,130 | 19,972,569 | 4,632,918 | 42 |
| `PAB_RES.PR_GEN_INV_CTA_RES`| 6,613,825 | 6,613,851 | 6,613,822 | 42 |
| `PRA_ACT_CUENTAS` | 6,416,197 | 17,895,656 | 3,775,174 | 51 |
| `PRB_GEN_SAL_INVENTARIOS` | 3,849,868 | 3,988,635 | 3,752,531 | 42 |
| `PRG_GEN_SAL_DIARIOS` | 3,723,369 | 3,794,009 | 3,666,906 | 42 |
| `PRA_ACT_SAL_MENSUAL` | 2,843,143 | 2,900,727 | 2,794,962 | 42 |
| `PRA_DEV_VIS_DIARIO` | 2,842,660 | 2,900,451 | 2,794,552 | 43 |
| `PRP_GEN_CTA_GARANTIA` | 1,666,981 | 1,704,524 | 1,619,384 | 51 |
| `PAP_CAT.PR_PRO_CAT_RES37` | 1,584,961 | 1,626,656 | 1,545,568 | 49 |

---

## 🔀 REGLA 3: ORQUESTACIÓN Y PARALELISMO (Fork/Join)

El cierre no es 100% secuencial. Identifica en la siguiente tabla si el programa analizado tiene reglas de paralelismo ('P' o 'F') y documenta su comportamiento exacto basándote en la columna "Notas".

- **Regla Tipo 'P' (Fork - Asíncrono):** El programa se lanza en paralelo y el orquestador avanza sin esperarlo. Aplica el tag `[CIERRE-RULE-PARALELISMO-ASINCRONO]`.
- **Regla Tipo 'F' (Join - Barrera):** El programa funciona como barrera de sincronización. NO inicia hasta que el hilo 'P' del que depende finalice. Aplica el tag `[CIERRE-RULE-BARRERA-SINCRONIZACION]`.

**MATRIZ COMPLETA DE PARALELISMO DE LAS CADENAS DE CIERRE:**

| CICLO | PROGRAMA (Analizado) | DEPENDE_DE (Finalización de) | TIPO | NOTAS ARQUITECTÓNICAS |
|---|---|---|---|---|
| 11 | `PRA_CON_TRANSACCION` | `PRG_CIE_MODULOS` | **P** | Hilo de consolidación. Se lanza paralelo al terminar módulos. |
| 11 | `PRA_GEN_ASI_AUTOMATICOS` | `PRA_CON_TRANSACCION` | **F** | Barrera: Espera el fin de la consolidación transaccional. |
| 11 | `PRG_TRA_HISTORICO` | `PAG_NOM.PR_CAN_NOMINA` | **P** | Hilo de históricos. |
| 11 | `PRC_ELI_LIN_SOB_CANCELADO` | `PRG_TRA_HISTORICO` | **F** | Barrera: Garantiza fin de PRG_TRA_HISTORICO antes del inventario para mantener Nivel Paralelismo = 2. |
| 11 | `PRA_CAP_CTA_PREVIO_CIERRE` | `PRA_ACT_SAL_MENSUAL` | **P** | Se lanza inmediatamente al finalizar la actualización mensual. |
| 11 | `PRA_CAP_CTA_VISTA_CIERRE` | `PRA_CAP_CTA_PREVIO_CIERRE` | **F** | Barrera: No debe empezar sin que previo cierre finalice. |
| 11 | `PRA_CAP_CTA_VISTA_CIERRE` | `PRA_DEV_VIS_DIARIO` | **P** | Doble dependencia. |
| 11 | `PRG_CIE_MODULOS` | `PRA_CAP_CTA_VISTA_CIERRE` | **F** | Barrera para cerrar módulos. |
| 11 | `PRP_DEV_PRE_FIN` | `PRP_CAM_ESTADOS` | **P** | Hilo de préstamos. |
| 11 | `PRP_CAL_ATRASOS` | `PRP_DEV_PRE_FIN` | **F** | Barrera de atrasos de préstamos. |
| 11 | `PRE_EJE_DEPURACION` | `PAB_RES.PR_GEN_INV_CTA_RES` | **P** | Hilo de depuración. |
| 11 | `PRG_AUD_TRIGGERS('H')` | `PRE_EJE_DEPURACION` | **F** | Barrera final de triggers de auditoría. |
| 12 | `PRG_GEN_ASI_CIE_TMP` | `PRG_VER_CONSISTENCIA` | **P** | Hilo asíncrono de consistencia ciclo 12. |
| 12 | `PRS_GEN_ACCIONES` | `PRG_GEN_ASI_CIE_TMP` | **F** | Barrera final post-cierre. |
---

## 🏁 REGLA 4: CADENA DE CIERRE Y MARCA DE FIN

Las Cadenas de Cierre se dividen en Ciclos Operativos que se ejecutan en el siguiente **ORDEN OPERATIVO** (no secuencial por número):

### **🔁 ORDEN DE EJECUCIÓN CORRECTO:**
1. **Ciclo 7 (Pre-Cierre):** Preparación de datos y débitos al final del día. Impacto ALTO.
2. **Ciclo 11 (Cierre Diario):** Consolidación contable estricta. Impacto CRÍTICO.
3. **Ciclo 12 (Post-Cierre):** Reportes regulatorios BCP. Impacto ALTO.
4. **Ciclo 10 (Inicio de Día):** Inicialización del nuevo día de operaciones. Impacto MEDIO.

⚠️ **IMPORTANTE:** El ciclo 10 (Inicio de Día) se ejecuta DESPUÉS del Post-Cierre (12), preparando el sistema para el nuevo día operativo.

**ÚLTIMO ARCHIVO / FIN DE CIERRE:**
El programa **`10,999,GENERACIÓN DE EXTRACTOS MENSUAL,PAG_EXT.PR_GEN_EXT_MENSUAL,D,S,S`** marca el fin definitivo de la cadena operativa (Hito de Fin de Cierre). Este es el último proceso del Ciclo 10 (Inicio de Día), que se ejecuta después del Post-Cierre (Ciclo 12). Todo programa posterior se considera "Fuera de la Cadena de Cierre Crítica".

---

## 📜 REGLA 5: LINAJE DE DATOS, CONCURRENCIA Y DEPENDENCIAS EN LAS CADENAS DE CIERRE (Data Lineage & Concurrency)
La base de datos compartida y los bloqueos concurrentes son los mayores obstáculos para la modernización. Para este programa, debes documentar de forma unificada:
- **Mapeo de Operaciones:** Lista las tablas principales que utiliza especificando si son de lectura (READ) o modificación (WRITE: INSERT/UPDATE/DELETE).
- **Riesgo de Concurrencia y Paralelismo:** Analiza las tablas críticas modificadas (ej. `GE_MOVIMIENTOS`). Advierte strictly si el programa **no puede correr en paralelo** con otros procesos debido al riesgo de colisiones, bloqueos mutuos (Deadlocks) o condiciones de carrera.
- **Dependencia de Secuencia Lógica:** Deduce en qué orden estricto debe ejecutarse dentro de la cadena de cierre (ej. *"Debe ejecutarse estrictamente después de los procesos de inserción de transacciones y antes de la consolidación contable"*).
- **Acoplamiento de Dominio:** Identifica si estas tablas son accedidas transversalmente por otros dominios del banco (ej. Préstamos, Tarjetas, Cuentas) y el riesgo arquitectónico de extraerlas.