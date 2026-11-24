CREATE OR REPLACE PROCEDURE IT.PRG_ACT_LOG_PROCESOS(P_COD_PROGRAMA  VARCHAR2,
                                                 P_COD_PROCESO   VARCHAR2,
                                                 P_FECHA         DATE,
                                                 P_HOR_INICIO    VARCHAR2,
                                                 P_HOR_FIN       VARCHAR2,
                                                 P_OBSERVACION   VARCHAR2 default null) IS
-------------------------------------------------------------------------------------
--Creado por : LCABRERA--
--Uso: Programa que registra en la tabla de ge_log_procesos la duracion de
--procesos internos de programas, y puede ser llamado desde cualquier programa
---DE-2320 - Optimización del proceso PAB_INV.PR_GEN_SAL_INVENTARIOS - DYD-SDSL-3367
-------------------------------------------------------------------------------------
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN
  --Inserta el registro recibido--
  INSERT INTO GE_LOG_PROCESOS
  (COD_PROGRAMA, COD_PROCESO, FECHA,  HOR_INICIO, HOR_FIN, OBSERVACION)
   VALUES
  (UPPER(P_COD_PROGRAMA), UPPER(P_COD_PROCESO), P_FECHA , P_HOR_INICIO, P_HOR_FIN, P_OBSERVACION);
  commit;
EXCEPTION
  WHEN OTHERS THEN
       raise_application_error(-20003, 'Error en PRG_ACT_LOG_PROCESOS: '||sqlerrm);
END PRG_ACT_LOG_PROCESOS;
/

