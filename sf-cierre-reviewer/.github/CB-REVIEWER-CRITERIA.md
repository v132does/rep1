# 🎯 Criterios Reforzados — CB PL/SQL Reviewer Agent

Versión: 2026-08-14 | Actualización: Revisión BKP (Antes) vs Objetos_BD (Después)

---

## 3 Reglas de Oro (Aplicar SIEMPRE)

### 1️⃣ **Compara BKP (antes) vs Objetos_BD (después)**
- **BKP:** Versión anterior (lo que estaba en producción)
- **Objetos_BD/:** Versión nueva que irá a producción
- **Revisión:** Diff entre ambos para ver QUÉ CAMBIÓ exactamente
- **Razón:** Objetos_BD es lo que se desplegará; BKP es referencia de cambios

### 2️⃣ **Revisa SOLO el ÚLTIMO COMMIT**
- Si el PR tiene múltiples commits: **revisar solo `headRefOid`**
- Si el PR tiene 1 commit: revisar ese nomas
- **No compares** commits intermedios

### 3️⃣ **CRITICAL ISSUES = CÓDIGO MODIFICADO (Diff BKP vs Objetos_BD)**
- Un hallazgo puede ser Critical **SOLO si está DIFERENTE entre BKP y Objetos_BD**
- Código IGUAL en BKP y Objetos_BD: reportar como **🟡 Improvement**
- Esto enfoca riesgo NEW introducido por el PR

---

## Matriz de Clasificación

| Hallazgo | BKP → Objetos_BD | Clasificación | Ejemplo |
|---|---|---|---|
| ✅ Nueva vulnerabilidad | NO EXISTS → ✅ NEW | 🔴 CRITICAL | `PRAGMA AUTONOMOUS_TRANSACTION` (nuevo) |
| ✅ Nuevo error handling incorrecto | NO EXISTS → ✅ NEW | 🔴 CRITICAL | `WHEN OTHERS THEN null` (nuevo) |
| ✅ Mejora positiva en código nuevo | NO EXISTS → ✅ NEW | 🟢 GOOD PRACTICE | Condición `:old.hor_fin is null` (mejora) |
| ❌ Código pre-existente sin cambios | ✅ EXISTS → ✅ EXISTS (igual) | 🟡 IMPROVEMENT | `g_cod_modulo := 1` (heredado) |
| ❌ Variable mal nombrada (heredada) | ✅ EXISTS → ✅ EXISTS (igual) | 🟡 IMPROVEMENT | Variable `v_job_name` (ya existía) |

---

## Ejemplo: Cómo Aplicar los Criterios

### PR#49 (CIE-1185) — Trigger `TA_GE_PROCESOS_DET`

**Comparación BKP → Objetos_BD:**
```
BKP (ANTES):
  if :new.nro_orden in (420) and :new.cod_proceso = 10 then
    V_SENTENCIA := '...';
    DBMS_JOB.submit(v_jobs, V_SENTENCIA);
  end if;

OBJETOS_BD (DESPUÉS):
  if :new.nro_orden in (420) and :new.cod_proceso = 10 then
    V_SENTENCIA := '...';
    DBMS_JOB.submit(v_jobs, V_SENTENCIA);
  elsif :new.nro_orden in (80) and :new.cod_proceso = 11 then  ← NUEVA RAMA
    PROCEDURE pr_crear_job_dinamico(...)  ← NUEVO PROCEDIMIENTO
      PRAGMA AUTONOMOUS_TRANSACTION;
      ...
      WHEN OTHERS THEN null;  ← NUEVA LÓGICA
    END;
  end if;
```

**Análisis:**
1. Nueva rama `elsif :new.nro_orden in (80)` → ✅ **Línea DIFERENTE**
   - Contiene `PRAGMA AUTONOMOUS_TRANSACTION` → ✅ **Puede ser Critical**
   - Valida si rompe atomicidad → Sí → 🔴 **CRITICAL-001**

2. `WHEN OTHERS THEN null` en nueva rama → ✅ **Línea DIFERENTE**
   - Suprime errores sin logging → ✅ **Puede ser Critical**
   - Valida si afecta gobernanza → Sí → 🔴 **CRITICAL-002**

3. `g_cod_modulo := 1` (visto en construcción SQL)
   - Está en ambas versiones (BKP y Objetos_BD) → NO CAMBIÓ
   - Si está igual en ambas → 🟡 **IMPROVEMENT** (mejora futura)

---

## Semáforo de Severidad (Orden de Prioridad)

| Color | Nivel | Bloquea Merge | Criterio |
|---|---|---|---|
| 🔴 | CRITICAL ISSUES | **SÍ** | **DIFERENTE entre BKP y Objetos_BD** |
| 🟡 | IMPROVEMENTS | NO | Puede ser pre-existente (IGUAL en ambas) |
| 🟢 | GOOD PRACTICES | NO | Patrones correctos en código nuevo |

---

## Cómo Invocar el Agente (Modo PR)

```bash
@CB PL/SQL Reviewer PR#49 | .github/reports/pr-49-cb-review.md
```

El agente automáticamente:
1. ✅ Resuelve el PR desde `headRefOid` (último commit)
2. ✅ Busca BKP como referencia (versión anterior)
3. ✅ Compara diff BKP vs Objetos_BD
4. ✅ Clasifica Critical SOLO si hay cambio visible en diff
5. ✅ Genera reporte enfocado en riesgo NEW

---

## Checklist para Revisores Humanos

Antes de hacer merge después de que el agente apruebe:

- [ ] ¿Todos los Critical Issues (cambios nuevos) fueron resueltos?
- [ ] ¿Se comparó BKP vs Objetos_BD correctamente?
- [ ] ¿Se validó que improvements futuras no bloquean merge?
- [ ] ¿Se verificó último commit (`headRefOid`) del PR?
- [ ] ¿Test funcional ejecutado en ambiente?

---

## Referencia Rápida: Cuándo es Critical

✅ **Marcar CRITICAL si:**
- **DIFERENTE entre BKP (antes) y Objetos_BD (después)**
- Está en línea/bloque que fue modificado en Objetos_BD
- Bloquea merge (atomicidad, idempotencia, gobernanza)
- Afecta tabla OBLIGATORIA del cierre
- Introduce vulnerabilidad nueva

❌ **NO marcar CRITICAL si:**
- **IGUAL en BKP y en Objetos_BD** (no cambió)
- Es patrón heredado que PR mantiene
- Es mejora sugerida (mejora = Improvement)
- Es reporte sobre código de dependencia externa

---

**Documento vigente desde:** 2026-08-14
**Próxima revisión:** Al cerrar PR#49 o próximo PR
