SET DEFINE OFF;

BEGIN  
  PRE_INI_APLICACION;  
  PAE_CNF.G_COD_MODULO := 1;  
END;
/

-- =====================================================================================
-- NOR-548 | Informe de Liquidez - Incidencias en saldos y plazos - IMPLEMENTAR Parte 1
-- Objetivo : generar parametros dinamicos para ser usados en el Informe de Liquidez
-- =====================================================================================

-- Verificación previa -- los parametros no deben existir
SELECT COUNT (*)
  FROM IT.GE_PARAMETROS
 WHERE parametro IN ('REP_LIQUIDEZ_EXCLUSION','REP_LIQUIDEZ_RUBRO_CERO');

SELECT COUNT (*)
  FROM IT.ge_par_dinamicos
 WHERE parametro IN ('REP_LIQUIDEZ_EXCLUSION','REP_LIQUIDEZ_RUBRO_CERO');
 
-- Creo parametro REP_LIQUIDEZ_EXCLUSION
INSERT INTO IT.GE_PARAMETROS (parametro, descripcion, tab_relacion, referencia, observacion)
       VALUES ('REP_LIQUIDEZ_EXCLUSION', 'REP. LIQUIDEZ RUBROS EXCLUIDOS', 'GE_PAR_DINAMICOS', NULL,'Reporte Liquidez Rubros Excluidos del Rep. de Liquidez');
  
-- Creo parametro REP_LIQUIDEZ_RUBRO_CERO
INSERT INTO IT.GE_PARAMETROS (parametro, descripcion, tab_relacion, referencia, observacion)
   VALUES ('REP_LIQUIDEZ_RUBRO_CERO', 'REPORTE LIQUIDEZ RUBROS EN 0', 'GE_PAR_DINAMICOS', NULL,'Rubros utilizados en reporte de Liquidez para palazo 0');
 
-- genero valores para el parametro  REP_LIQUIDEZ_EXCLUSION   
INSERT INTO IT.ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda)
    VALUES ('REP_LIQUIDEZ_EXCLUSION', '1701000000, 1709000000, 1709031700, 1401045300, 1401045302, 1408045500, 1408045582, 1408045594, 1408045592, 1401040500', null, null, null, null);

-- genero valores para el parametro  REP_LIQUIDEZ_RUBRO_CERO  
 INSERT INTO IT.ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda)
    VALUES ('REP_LIQUIDEZ_RUBRO_CERO', '1701029300, 1701029302, 1701029304, 1706000000, 1709031706, 1901034100, 3106041801, 5104069500, 5104069502, 5104069503, 5104069504, 5104069505, 5204069400, 5204069402, 5204069403, 5204069404, 5204069405, 6108077200, 7105000000', null, null, null, null);

-- Verificación previa -- los parametros no deben existir
SELECT COUNT (*)
  FROM IT.GE_PARAMETROS
 WHERE parametro IN ('REP_LIQUIDEZ_EXCLUSION','REP_LIQUIDEZ_RUBRO_CERO');

SELECT COUNT (*)
  FROM IT.ge_par_dinamicos
 WHERE parametro IN ('REP_LIQUIDEZ_EXCLUSION','REP_LIQUIDEZ_RUBRO_CERO');
 
/

PROMPT === SCRIPT 8000_creacion_parametros_liquidez.sql COMPLETADO OK ===
