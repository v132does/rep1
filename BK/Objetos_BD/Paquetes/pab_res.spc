CREATE OR REPLACE PACKAGE IT.PAB_RES is

  -- Author  : XPY8413 - RB
  -- Created : 22/02/2012 11:46:19 a.m.
  -- Purpose : Procedimiento que genera el saldo del Inventario de Cuentas de Resultados

 /* ***************************************************************************** */
 -- TIPOS DE SALDOS EN TABLA HISTORICA (CB_SAL_INV_RES_HIS)
  -- DE = DEVENGADOS (Prestamos, Mesa de Dinero, Caja de Ahorro)
  -- DS = DEVENGADO EN SUSPENSO
  -- CO = COMISIONES (Pagadas, Cobradas)
  -- CD = COMISIONES DIFERIDAS
  -- OC = OPERACIONES DE CAMBIO
  -- PR = PREVISIONES
  -- VL = VALUACIONES
  -- AM = ASIENTOS MANUALES
  -- AC = AJUSTE DE SALDOS DE RUBROS CONTABLES
  -- AJ = AJUSTE DE RECALCULO DE SALDOS HISTORICOS
  -- OI = OTROS INGRESOS
  -- GA = GASTOS
  -- OE = OTROS EGRESOS
  -- IM = IMPUESTOS
  -- DI = DEPOSITOS INTERNOS
  -- TA = TRADING
 /* ***************************************************************************** */

-- Proceso principal para realizar inventario de cuentas de resultado
   PROCEDURE PR_GEN_INV_CTA_RES;

-- Proceso principal para realizar inventario Contable de cuentas de resultado
   PROCEDURE PR_INV_CTA_CONTABLE;
------------------------------------------------------------

-- obtiene el codigo de rubro que corresponde a una cuenta
  FUNCTION FU_OBT_RUBRO
   (
      p_cod_modulo       IN NUMBER,
      p_cod_modalidad    IN NUMBER,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2,
      p_cod_sec_contable IN VARCHAR2,
      p_cod_tip_deudor   IN NUMBER,
      p_residente        IN VARCHAR2,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   )
   RETURN VARCHAR2;
------------------------------------------------------------
FUNCTION FU_OBT_NRO_CUENTA(p_cod_persona ge_movimientos.cod_persona%type)
  RETURN VARCHAR2;
------------------------------------------------------------  
-- Montos Devengados de Prestamos (DE)
  PROCEDURE PR_ACU_DEV_PRESTAMOS;
------------------------------------------------------------

-- Montos Devengados de Mesa de Dinero (DE)
  PROCEDURE PR_ACU_DEV_MESA_DINERO;
------------------------------------------------------------

-- Intereses Devengados de Caja de Ahorros (DE)
  PROCEDURE PR_ACU_DEV_CAJA_AHORRO;
------------------------------------------------------------

-- Insteres Devengado en Suspenso (DS)
   PROCEDURE PR_ACU_DEV_SUSPENSO;
------------------------------------------------------------

-- Comisiones Cobradas y Pagadas (CO)
  PROCEDURE PR_ACU_COMISIONES;
------------------------------------------------------------

-- Comisiones Diferidas (devengado) (CD)
  PROCEDURE PR_ACU_COM_DIFERIDAS;
------------------------------------------------------------

-- Operaciones de cambios (OC)
  PROCEDURE PR_ACU_OPE_CAMBIOS;
------------------------------------------------------------

  -- Previsiones (PR)
  PROCEDURE PR_ACU_PREVISIONES;
------------------------------------------------------------

  -- Valuaciones (VL)
  PROCEDURE PR_ACU_VALUACIONES;
------------------------------------------------------------

-- Otros Ingresos (OI)
PROCEDURE PR_ACU_OTR_INGRESOS;
------------------------------------------------------------

-- Gastos (GA)
PROCEDURE PR_ACU_GASTOS;
------------------------------------------------------------

-- Otros Egresos (OE)
PROCEDURE PR_ACU_OTR_EGRESOS;
------------------------------------------------------------

-- Impuestos (IM)
PROCEDURE PR_ACU_IMPUESTOS;
------------------------------------------------------------

-- Requerimiento: CNFDEEVO-1.
-- Fecha: 09/11/2015.
-- Actualiza la Fecha de Cierre Contable - Fin de Año para la Generación del Inventario de DI y Trading.
  PROCEDURE PR_ACT_FEC_CIE_CONTABLE(v_fecha date);

end PAB_RES;
/

