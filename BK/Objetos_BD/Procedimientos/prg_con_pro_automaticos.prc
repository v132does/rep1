CREATE OR REPLACE PROCEDURE IT.PRG_CON_PRO_AUTOMATICOS(P_COD_PROGRAMA     VARCHAR2,
                                                    P_COD_SUB_PROGRAMA VARCHAR2,
                                                    P_NRO_ORDEN        NUMBER,
                                                    P_FECHA            DATE,
                                                    P_TIPO             VARCHAR2,
                                                    P_HORA             VARCHAR2,
                                                    P_NRO_REFERENCIA   VARCHAR2 default null,
                                                    P_DES_REFERENCIA   VARCHAR2 default null,
                                                    P_OBSERVACION      VARCHAR2 default null,
                                                    P_ERROR            VARCHAR2 default null,
                                                    P_NRO_CUENTA       VARCHAR2 default null,
                                                    P_DES_OPERACION    VARCHAR2 default null) IS
-----------------------------------------------------------------
--Creado por : RPAVON--
--Uso: Control de Ejecucion de Proceso Automaticos--
-----------------------------------------------------------------
PRAGMA AUTONOMOUS_TRANSACTION;
V_GRA_LOG_EJECUCION GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
v_fecha date;

BEGIN
  V_GRA_LOG_EJECUCION := fug_obt_pardinamico('DEP_AUT_LOG_EJE_OPE');
  IF NVL(V_GRA_LOG_EJECUCION,'N') = 'S' THEN
      --Inserta o actualiza el registro recibido--
      IF P_TIPO = 'I' THEN --Hora Inicial--
         --INSERTAR REGISTRO Y REGISTRAR HORA DE INICIO--
         INSERT INTO GE_PRO_AUTOMATICOS_DET
         (COD_PROGRAMA, COD_SUB_PROGRAMA, NRO_ORDEN, FECHA,
          HOR_INICIO, NRO_REFERENCIA, DES_REFERENCIA, OBSERVACION)
          VALUES
         (P_COD_PROGRAMA, P_COD_SUB_PROGRAMA, P_NRO_ORDEN, P_FECHA,
          P_HORA, P_NRO_REFERENCIA, substr(P_DES_REFERENCIA,1,200), substr(P_OBSERVACION,1,2000));
      ELSIF P_TIPO = 'F' THEN --Hora Final--
         INSERT INTO GE_PRO_AUTOMATICOS_DET
         (COD_PROGRAMA, COD_SUB_PROGRAMA, NRO_ORDEN, FECHA,
          HOR_FIN, NRO_REFERENCIA, NRO_CUENTA, DES_OPERACION, 
          DES_REFERENCIA, OBSERVACION)
          VALUES
         (P_COD_PROGRAMA, P_COD_SUB_PROGRAMA, P_NRO_ORDEN, P_FECHA,
          P_HORA, P_NRO_REFERENCIA, P_NRO_CUENTA, P_DES_OPERACION,
          substr(P_DES_REFERENCIA,1,200), substr(P_OBSERVACION,1,2000));
      ELSE --E-Tipo Error u Otro--
         INSERT INTO GE_PRO_AUTOMATICOS_DET
         (COD_PROGRAMA, COD_SUB_PROGRAMA, NRO_ORDEN, FECHA,
          HOR_FIN, NRO_REFERENCIA, NRO_CUENTA, DES_OPERACION, 
          DES_REFERENCIA, OBSERVACION, ERROR)
          VALUES
         (P_COD_PROGRAMA, P_COD_SUB_PROGRAMA, P_NRO_ORDEN, P_FECHA,
          P_HORA, P_NRO_REFERENCIA, P_NRO_CUENTA, P_DES_OPERACION,
          substr(P_DES_REFERENCIA,1,200), substr(P_OBSERVACION,1,2000),
          substr(decode(P_NRO_CUENTA,null,P_ERROR,'Cta:'||p_nro_cuenta||'-'||P_ERROR),1,4000));
       END IF;
  END IF;
  --Para enviar emial en caso de algun error en DEPO--
  if (p_error is not null) then
     v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(1);
     pag_dom.pr_tra_env_email(pam_dep.g_gru_dir_correo,
                              'DEPO '||to_char(v_fecha,'dd/mm/yyyy')||' - Error en Ejecucion DEPO. Verififque', 
                              p_error);
  end if;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
       raise_application_error(-20003, 'Error en PRG_CON_PRO_PARALELOS: '||sqlerrm);
END PRG_CON_PRO_AUTOMATICOS;
/

