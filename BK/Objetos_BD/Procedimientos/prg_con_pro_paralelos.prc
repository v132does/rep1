CREATE OR REPLACE PROCEDURE IT.PRG_CON_PRO_PARALELOS(P_COD_PROGRAMA     VARCHAR2,
                                                  P_COD_SUB_PROGRAMA VARCHAR2,
                                                  P_NRO_ORDEN        NUMBER,
                                                  P_FECHA            DATE,
                                                  P_TIPO             VARCHAR2,
                                                  P_HORA             VARCHAR2,
                                                  P_NRO_REFERENCIA   NUMBER default null,
                                                  P_DES_REFERENCIA   VARCHAR2 default null,
                                                  P_OBSERVACION      VARCHAR2 default null,
                                                  P_ERROR            VARCHAR2 default null,
                                                  P_NRO_CUENTA       VARCHAR2 default null) IS
-----------------------------------------------------------------
--Creado por : RPAVON--
--Uso: Control de Ejecucion de Proceso de Devengado en Paralelo--
-----------------------------------------------------------------
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN
  --Inserta o actualiza el registro recibido--
  IF P_TIPO = 'I' THEN --Hora Inicial--
     --INSERTAR REGISTRO Y REGISTRAR HORA DE INICIO--
     INSERT INTO GE_PRO_PARALELOS_DET
     (COD_PROGRAMA, COD_SUB_PROGRAMA, NRO_ORDEN, FECHA,
      HOR_INICIO, NRO_REFERENCIA, DES_REFERENCIA, OBSERVACION)
      VALUES
     (P_COD_PROGRAMA, P_COD_SUB_PROGRAMA, P_NRO_ORDEN, P_FECHA,
      P_HORA, P_NRO_REFERENCIA, P_DES_REFERENCIA, P_OBSERVACION);
  ELSIF P_TIPO = 'F' THEN --Hora Final--
     --ACTUALIZAR CON LA HORA DE FIN--
     UPDATE GE_PRO_PARALELOS_DET X
        SET X.HOR_FIN = P_HORA
      WHERE X.COD_PROGRAMA = P_COD_PROGRAMA
        AND X.COD_SUB_PROGRAMA = P_COD_SUB_PROGRAMA
        AND X.NRO_ORDEN = P_NRO_ORDEN
        AND X.FECHA = P_FECHA;
  ELSIF P_TIPO = 'R' THEN --Reproceso--
     --ACTUALIZAR CON LA HORA DE FIN--
     UPDATE GE_PRO_PARALELOS_DET X
        SET X.HOR_INICIO = P_HORA,
            X.NRO_REFERENCIA = P_NRO_REFERENCIA
      WHERE X.COD_PROGRAMA = P_COD_PROGRAMA
        AND X.COD_SUB_PROGRAMA = P_COD_SUB_PROGRAMA
        AND X.NRO_ORDEN = P_NRO_ORDEN
        AND X.FECHA = P_FECHA;
  ELSE --E-Tipo Error--
     UPDATE GE_PRO_PARALELOS_DET X
        SET X.ERROR = P_ERROR,
            X.OBSERVACION = DECODE(P_OBSERVACION,NULL,X.OBSERVACION,P_OBSERVACION)
      WHERE X.COD_PROGRAMA = P_COD_PROGRAMA
        AND X.COD_SUB_PROGRAMA = P_COD_SUB_PROGRAMA
        AND X.NRO_ORDEN = P_NRO_ORDEN
        AND X.FECHA = P_FECHA;
  END IF;

  --Marcar cuenta con error devengado--
  IF ((P_TIPO = 'E') AND (P_COD_PROGRAMA = 'PRA_DEV_VIS_PARALELO') AND (P_NRO_CUENTA IS NOT NULL)) THEN
     UPDATE AH_CTA_VIS_DEV_TMP Z
        SET Z.COD_PARALELO = Z.COD_PARALELO||'-ERROR'
      WHERE Z.NRO_CUENTA = P_NRO_CUENTA;
  END IF;
  
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
       raise_application_error(-20003, 'Error en PRG_CON_PRO_PARALELOS: '||sqlerrm);
END PRG_CON_PRO_PARALELOS;
/

