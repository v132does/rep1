CREATE OR REPLACE PROCEDURE IT.PRB_ACT_LOG_PROCESOS(FECHA            CB_LOG_PROCESOS.FECHA%TYPE,
                                                 NOM_PAQUETE      CB_LOG_PROCESOS.NOM_PAQUETE%TYPE, 
                                                 NOM_PRO_INTERNO  CB_LOG_PROCESOS.NOM_PRO_INTERNO%TYPE, 
                                                 COD_RUBRO        CB_LOG_PROCESOS.COD_RUBRO%TYPE, 
                                                 HOR_INICIO       CB_LOG_PROCESOS.HOR_INICIO%TYPE, 
                                                 HOR_FIN          CB_LOG_PROCESOS.HOR_FIN%TYPE, 
                                                 DET_SQL          CB_LOG_PROCESOS.DET_SQL%TYPE) IS
---------------------------------------------------------------------------------------------------------
--Creado por : LCABRERA--
--Uso: Programa que registra en la tabla de PRB_ACT_LOG_PROCESOS la duracion de
--procesos internos de programas, y puede ser llamado desde cualquier programa utilizado en Contabilidad
---DYDMR-6535 - Incidencia SAU - ITGF - Diferencia Cuenta Contable - Seguro en Transito MAPFRE
---------------------------------------------------------------------------------------------------------
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN
  --Inserta el registro recibido--
  INSERT INTO CB_LOG_PROCESOS
  (FECHA, NOM_PAQUETE, NOM_PRO_INTERNO, COD_RUBRO, HOR_INICIO, HOR_FIN, DET_SQL)
   VALUES
  (FECHA, UPPER(NOM_PAQUETE), UPPER(NOM_PRO_INTERNO), COD_RUBRO, HOR_INICIO, HOR_FIN, DET_SQL);
  commit;
EXCEPTION
  WHEN OTHERS THEN
       raise_application_error(-20003, 'Error en PRB_ACT_LOG_PROCESOS: '||sqlerrm);
END PRB_ACT_LOG_PROCESOS;
/

