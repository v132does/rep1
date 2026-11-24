## 0. Verificacion de Origen (obligatorio en Modo PR)

| Campo | Valor |
|---|---|
| SHA del HEAD leido en esta corrida | [headRefOid real obtenido en este turno, ej: f1b5e7f9...] |
| Fecha/hora `updated_at` del PR (segun GitHub) | [timestamp real de la respuesta de la API/fetch de este turno] |
| Fuente de datos usada | [Opcion A: fetch en vivo / Opcion B: cache local `.github/pr-cache/pr-<N>.diff` / Opcion C: terminal `gh`] |
| SHA anterior (si existe reporte previo en este mismo archivo) | [SHA citado en la version anterior del reporte, o "N/A - primera revision"] |

[Si el SHA actual es igual al SHA del reporte anterior, indicar explicitamente: "Sin cambios de commit desde la ultima revision". Si es distinto, indicar: "PR actualizado: SHA anterior -> SHA actual".]

## 1. Resumen Ejecutivo

[Resumen corto del alcance y conclusion general]

| Metrica | Valor |
|---|---:|
| Critical Issues | [N] |
| Improvements | [N] |
| Good Practices | [N] |
| Riesgo general | [Alto/Medio/Bajo] |

| Dimension | Estado | Observacion |
|---|---|---|
| Registro en malla (GE_PROCESOS_DET) | [🔴/🟡/🟢] | COD_PROCESO=[X] \| ORDEN=[X] \| OBLIGATORIO=[S/N] \| ACTIVO=[S/N] |
| Impacto cruzado | [🔴/🟡/🟢] | [...] |
| Paralelismo Fork/Join | [🔴/🟡/🟢] | [...] |
| Naming & Style (ITGF) | [🔴/🟡/🟢] | [...] |
| Error handling | [🔴/🟡/🟢] | [...] |
| Performance / Volumetria | [🔴/🟡/🟢] | [...] |
| Hardcode de negocio | [🔴/🟡/🟢] | [...] |
| Higiene de variables y parametros | [🔴/🟡/🟢] | [...] |
| Cambios DDL/DML (.sql) | [🔴/🟡/🟢/N/A] | [...] |

## 2. Trazabilidad Jira (Modo PR)

| Campo | Valor |
|---|---|
| Ticket | [CIE-XXXX] |
| Titulo | [summary de Jira] |
| Status | [status de Jira] |
| Labels / Components | [...] |
| Trazabilidad Ticket vs Cambio | [Alineado / Parcial / Desalineado] |

**Criterios de aceptacion vs codigo (validacion 1 a 1):**

| # | Criterio de aceptacion (Jira) | Estado | Evidencia en el diff |
|---|---|---|---|
| 1 | [texto del criterio] | [Cumple/Parcial/No cumple/No verificable] | [fragmento o referencia] |

[Si no hay criterios de aceptacion explicitos en el ticket, usar `description` y validar contra el alcance funcional descrito. Si no se pudo obtener contexto Jira y `jira=off`, escribir: "jira=off: seccion omitida a pedido del usuario".]

**Desvio de alcance (scope creep):** [Si el diff modifica archivos/logica no relacionados al ticket, listarlos aqui con el archivo/bloque afectado. Si no hay desvio: "Sin desvio de alcance detectado".]

## 3. Semaforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | [N] | [Estado] |
| Improvements | 🟡 | [N] | [Estado] |
| Good Practices | 🟢 | [N] | [Estado] |

## 4. Critical Issues

### 🔴 Item [N]

- 📦 Objeto o bloque afectado: [...]
- 🔎 Evidencia (linea o fragmento):

	Antes:
	```sql
	[...]
	```

	Despues:
	```sql
	[...]
	```

	Referencia de lineas (opcional): [...]
- 📏 Regla validada o incumplida: [...]
- ⚠️ Riesgo: [...]
- 💡 Recomendacion concreta: [...]

## 5. Improvements

### 🟡 Item [N]

- 📦 Objeto o bloque afectado: [...]
- 🔎 Evidencia (linea o fragmento):

	Antes:
	```sql
	[...]
	```

	Despues:
	```sql
	[...]
	```

	Referencia de lineas (opcional): [...]
- 📏 Regla validada o incumplida: [...]
- ⚠️ Riesgo: [...]
- 💡 Recomendacion concreta: [...]

## 6. Good Practices

### 🟢 Item [N]

- 📦 Objeto o bloque afectado: [...]
- 🔎 Evidencia (linea o fragmento):

	Antes:
	```sql
	[...]
	```

	Despues:
	```sql
	[...]
	```

	Referencia de lineas (opcional): [...]
- 📏 Regla validada o incumplida: [...]
- 💡 Patron correcto: [...]

## 7. Impacto Cruzado

| Tabla (WRITE) | Programas en malla que la usan | Ciclo | OBLIGATORIO | Riesgo |
|---|---|---|---|---|
| [TABLA] | [PROG1, PROG2] | [X] | [S/N] | [🔴/🟡] |

[Descripcion del riesgo si aplica, o "Sin impacto cruzado identificado"]

## 8. Comentarios de Revisores (GitHub)

| Canal | Resultado | Evidencia |
|---|---|---|
| Comentarios generales (`/issues/<N>/comments`) | [N comentarios / Error] | [detalle] |
| Comentarios inline (`/pulls/<N>/comments`) | [N comentarios / Error] | [detalle] |
| Reviews (`/pulls/<N>/reviews`) | [N reviews / Error] | [detalle] |

| Autor | Solicitud (resumen) | Estado | Evidencia |
|---|---|---|---|
| [usuario] | [...] | [Aplicado/Parcial/Pendiente] | [fragmento o "N/A"] |

[Si los tres canales respondieron correctamente y no contienen comentarios: "Sin comentarios de revisores en el PR". Si algun canal fallo: "No se pudo verificar comentarios de revisores humanos del PR", indicando canal y error tambien en Supuestos.]

**Nota:** Esta seccion es informativa. Los pedidos `Pendiente` se documentan como seguimiento, pero no alteran el veredicto final de merge, que depende exclusivamente del semaforo tecnico (seccion 2).

## Supuestos
- [...]
