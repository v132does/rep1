CREATE OR REPLACE PACKAGE IT.PAL_CIE is

  -- Author  : Valeria Capra
  -- Created : 08/05/2006 05:05:51 p.m.
  -- Purpose : Procesos de cambios a correr en el cierre

  -- Venta de divisas por devengamiento de cartera pasiva
  PROCEDURE PR_PRO_DEV_AHORROS;
  -- Compra de divisas por devengamiento de prestamos
  PROCEDURE PR_PRO_DEV_PRESTAMOS;
  -- Venta de divisas automática por operaciones diarias
  PROCEDURE PR_PRO_VENTAS;
  -- Compra de divisas automática por operaciones diarias
  PROCEDURE PR_PRO_COMPRAS;
  -- Venta de divisas automática por operaciones diarias por Clientes
  PROCEDURE PR_PRO_VTA_CLIENTES;
  -- Compra de divisas automática por operaciones diarias por Clientes
  PROCEDURE PR_PRO_COM_CLIENTES;
  -- Compra de divisas por devengamiento de Mesa de Dinero
  PROCEDURE PR_PRO_DEV_MESA ;
  -- Inserción de movimientos de Posición de Cambios
  PROCEDURE PR_INS_BOL_AUTOMATICAS
   (RP_RPOCA IN lc_bol_automaticos_res%ROWTYPE);
  -- CNFLPCAM-1 -- CN: 11/2015 --
  -- Verificación del Límite de Posición de Cambios --
  PROCEDURE PR_VER_LIM_POS_CAMBIOS;
  -- Reversion de Boleta inversa por Verificación del Límite de Posición de Cambios --
  PROCEDURE PR_REV_BOL_INVERSA;
  --
end PAL_CIE;
/

