---
description: 'Guia para la implementación de estándares de codificación en PLSQL. Contiene mejores prácticas, convenciones de nomenclatura y pautas de diseño. Contiene nomenclaturas específicas del dominio bancario ITGF.'
applyTo: 'ueno_projects/ueno_core/GESTION_FINANCIERA/Aplicaciones_Principales/Objetos_BD/**'
---

# Manual ITGF - Nomenclaturas y Estándares de Desarrollo

## 🧭 Cómo orientarse en el código

**Nomenclatura del sistema (resumen):**

| Módulo | Código | Prefijo paquete | Prefijo función standalone |
|---|---|---|---|
| Banco / Balance | BA | `pab_` | `fub_` |
| General | GE | `pag_` | `fug_` |
| Ahorro | AH | `paa_` | `fua_` |
| Cuenta Corriente | CC | `pac_` | `fuc_` |
| Préstamos | PR | `pap_` | `fup_` |
| Leasing / Crédito | LC | `pal_` | `ful_` |
| Caja | CJ | `paj_` | `fuj_` |
| Cierre Bancario | CB | `pacb_` | `fucb_` |
| Tarjetas | TA | `pat_` | `fut_` |

- Abreviaciones de campos: COD, DES, FEC, MTO, NRO, CTA, SAL, MON, EST, IND

**Archivos del código fuente:**
- `.spc` → interfaz pública del paquete (qué expone)
- `.bdy` → implementación (lógica real, empezar aquí para análisis)
- `.fnc` → función standalone
- `.prc` → procedimiento standalone

**Para identificar el dominio de un objeto por prefijo:**
- Segunda letra del paquete (`pag_`, `paa_`, `pac_`, `pap_`...) → ver tabla de módulos arriba
- Tercera letra de funciones standalone (`fue_`, `fug_`, `fuj_`, `fup_`...) → mismo mapeo
