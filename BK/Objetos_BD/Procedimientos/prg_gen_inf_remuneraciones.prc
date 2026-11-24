CREATE OR REPLACE PROCEDURE IT.PRG_GEN_INF_REMUNERACIONES is
  v_fec_inicio        date;
  v_fec_fin           date:= pag_cal.FU_OBT_FEC_ANTERIOR(1);
  v_periodo           varchar2(6)  := to_char(v_fec_fin, 'yyyymm');
  v_ent_pag_sal       varchar2(4):= fug_obt_pardinamico('COD_ENTE_PAG_SAL'); --ente pago de salario propio
  v_tra_can_atm       ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('TRA_CAN_ATM');
  v_tra_atm_nor       ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('TRA_ATM_NORMATIVO');
  v_nom_archivo 	  varchar2(100) := 'REMUNERACIONES_'||v_periodo;
  -- Variables conexion
  v_repositorio        VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_FTP');
  v_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  v_port               VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  v_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  v_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_obs                VARCHAR2(2000);
  v_file               UTL_FILE.FILE_TYPE;
  v_line               VARCHAR2(32767);
  v_buffer             VARCHAR2(32767);
  v_lines              PLS_INTEGER := 0;
  v_eol                CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen             CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline            CONSTANT PLS_INTEGER := 32767;
  -- Variables para FTP
  v_respuesta          VARCHAR2(4000);
  v_hini_ftp           ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp           ge_ra_log_ftp.hor_fin%type;

  /*Para parametros dinamicos*/
  v_ge_par_dinamicos it.typ_ge_par_dinamicos_tab;

/*RETORNA PARAMETRO DINAMICO*/
 FUNCTION LF_OBT_PARDINAMICO
  (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
  ,P_CACHED_DATA     IN it.typ_ge_par_dinamicos_tab
  ,P_COD_MODULO IN NUMBER DEFAULT NULL
  ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
  ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
  ,P_COD_OFICINA IN NUMBER  DEFAULT NULL
  ,P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL)
  RETURN VARCHAR2;

CURSOR C_INF_REMUNERACIONES IS
      SELECT periodo,
             round(saldo,0)saldo,
             nro_can_cuenta,
             nro_can_extr,
             can_pro_ext_sin_costo,
             nro_pag_elect,
             nro_can_instituciones,
             mto_min_com_atm,
             mto_max_com_atm,
             mto_pro_com_atm,
             can_tra_min_atm,
             can_tra_max_atm,
             can_tra_pro_atm
        FROM ge_inf_remuneraciones a
             WHERE periodo = v_periodo;

-- Obtiene el valor del parametro
FUNCTION LF_OBT_PARDINAMICO(
        P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE,
        P_CACHED_DATA IN it.typ_ge_par_dinamicos_tab,
        P_COD_MODULO IN NUMBER DEFAULT NULL,
        P_COD_MODALIDAD IN NUMBER DEFAULT NULL,
        P_COD_MONEDA IN VARCHAR2 DEFAULT NULL,
        P_COD_OFICINA IN NUMBER DEFAULT NULL,
        P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL
    )
     RETURN VARCHAR2
     IS
    v_val_parametro ge_par_dinamicos.val_parametro%type;
    begin
      FOR i IN 1 .. P_CACHED_DATA.COUNT LOOP
                IF P_CACHED_DATA(i).parametro = P_PARAMETRO
                  AND NVL(P_CACHED_DATA(i).COD_MODULO,NVL(P_COD_MODULO,-1)) = NVL(P_COD_MODULO,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_MODALIDAD,NVL(P_COD_MODALIDAD,-1)) = NVL(P_COD_MODALIDAD,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_SUB_MODALIDAD,NVL(P_COD_SUB_MODALIDAD,-1)) = NVL(P_COD_SUB_MODALIDAD,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_OFICINA,NVL(P_COD_OFICINA,-1)) = NVL(P_COD_OFICINA,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_MONEDA,NVL(P_COD_MONEDA,'x')) = NVL(P_COD_MONEDA,'x') THEN
                    v_val_parametro := P_CACHED_DATA(i).val_parametro;
                    RETURN v_val_parametro;
                    exit;
                END IF;
            END LOOP;
            if v_val_parametro is null then
             return null;
            end if;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,'Error al buscar en ge_par_dinamicos '||SQLERRM);
    END;

PROCEDURE LP_GEN_INF_REMUNERACIONES AS

v_mto_min_uso_atm   ge_par_dinamicos.val_parametro%type := LF_OBT_PARDINAMICO('MTO_MIN_USO_ATM', v_ge_par_dinamicos);
v_mto_max_uso_atm   ge_par_dinamicos.val_parametro%type := LF_OBT_PARDINAMICO('MTO_MAX_USO_ATM', v_ge_par_dinamicos);
v_pro_ext_sin_costo ge_par_dinamicos.val_parametro%type := LF_OBT_PARDINAMICO('PRO_EXT_SIN_COSTO', v_ge_par_dinamicos);
v_mto_pro_uso_atm   ge_par_dinamicos.val_parametro%type := LF_OBT_PARDINAMICO('MTO_PRO_USO_ATM', v_ge_par_dinamicos);
v_can_uso_min_atm   ge_par_dinamicos.val_parametro%type := LF_OBT_PARDINAMICO('CAN_MIN_USO_ATM', v_ge_par_dinamicos);
v_can_uso_max_atm   ge_par_dinamicos.val_parametro%type := LF_OBT_PARDINAMICO('CAN_MAX_USO_ATM', v_ge_par_dinamicos);
v_can_uso_pro_atm   ge_par_dinamicos.val_parametro%type := LF_OBT_PARDINAMICO('CAN_PRO_USO_ATM', v_ge_par_dinamicos);
v_sal_tot_cta       number;
v_tot_nro_cta       number;
v_can_ext_atm       number;
v_can_pag_ele       number;
v_ente_pag_sal      number;

BEGIN

  v_fec_inicio := trunc(pag_cal.FU_OBT_FEC_ANTERIOR(1), 'mm');

  BEGIN
      SELECT SUM(g.sal_total),
           COUNT(g.nro_cuenta)
      INTO v_sal_tot_cta,
           v_tot_nro_cta
      FROM ah_cta_vistas g,
           ge_entes      e
     WHERE g.cod_ente IS NOT NULL
       AND g.cod_ente = e.cod_ente
       AND e.tipo = 'SU'
       AND nvl(e.cod_ente,0) != nvl(v_ent_pag_sal,0);
  EXCEPTION
    WHEN OTHERS THEN
      v_sal_tot_cta := 0;
      v_tot_nro_cta := 0;
  END;

  BEGIN
    --cantidad de extracciones por atm de las cuentas que reciben salario
     SELECT COUNT(g.nro_cuenta)
         INTO v_can_ext_atm
       FROM ah_movimientos_his g, ah_cta_vistas a, ge_entes e
      WHERE g.nro_cuenta = a.nro_cuenta
         AND a.cod_ente = e.cod_ente
         AND a.cod_ente IS NOT NULL
         AND e.tipo = 'SU'
         AND g.reversado = 'N'
         AND nvl(e.cod_ente,0) != nvl(v_ent_pag_sal,0)
         AND instr(v_tra_can_atm,',' || cod_transaccion || ',') > 0
         AND g.fecha BETWEEN v_fec_inicio AND v_fec_fin;
  EXCEPTION
    WHEN OTHERS THEN
      v_can_ext_atm := 0;
  END;

  BEGIN
     SELECT COUNT(a.NRO_CUENTA)
         INTO v_can_pag_ele
        FROM gv_movimientos a
       WHERE instr(v_tra_atm_nor,',' || a.cod_transaccion || ',') > 0
         AND a.fecha BETWEEN v_fec_inicio and v_fec_fin;
  EXCEPTION
    WHEN OTHERS THEN
      v_can_pag_ele := 0;
  END;

  BEGIN
     SELECT COUNT(DISTINCT e.cod_ente)
         INTO v_ente_pag_sal
        FROM ah_movimientos_his g, ah_cta_vistas a, ge_entes e
       WHERE g.nro_cuenta = a.nro_cuenta
         AND a.cod_ente = e.cod_ente
         AND e.tipo = 'SU'
         AND g.reversado = 'N'
         AND nvl(e.cod_ente,0) != nvl(v_ent_pag_sal,0)
         AND g.fecha BETWEEN v_fec_inicio AND v_fec_fin;
  EXCEPTION
    WHEN OTHERS THEN
      v_ente_pag_sal := 0;
  END;


  --Eliminar registros del periodo
  DELETE FROM ge_inf_remuneraciones WHERE periodo = v_periodo;
  --Insertar registros del periodo
  INSERT INTO ge_inf_remuneraciones
    (periodo, saldo, nro_can_cuenta, nro_can_extr, nro_pag_elect, nro_can_instituciones, mto_min_com_atm, mto_max_com_atm, mto_pro_com_atm, can_tra_min_atm, can_tra_max_atm, can_tra_pro_atm, can_pro_ext_sin_costo)
  VALUES
    (v_periodo, v_sal_tot_cta, v_tot_nro_cta, v_can_ext_atm, v_can_pag_ele, v_ente_pag_sal, v_mto_min_uso_atm, v_mto_max_uso_atm, v_mto_pro_uso_atm, v_can_uso_min_atm, v_can_uso_max_atm, v_can_uso_pro_atm, v_pro_ext_sin_costo);
  COMMIT;
END;

BEGIN

  BEGIN
   SELECT typ_ge_par_dinamicos(
         parametro,
         cod_modulo,
         cod_modalidad,
         cod_moneda,
         cod_oficina,
         cod_sub_modalidad,
         val_parametro
      )
    BULK COLLECT INTO v_ge_par_dinamicos
    FROM ge_par_dinamicos
    WHERE parametro IN ('MTO_MIN_USO_ATM',
                        'MTO_MAX_USO_ATM',
                        'PRO_EXT_SIN_COSTO',
                        'MTO_PRO_USO_ATM',
                        'CAN_MIN_USO_ATM',
                        'CAN_MAX_USO_ATM',
                        'CAN_PRO_USO_ATM')
    ORDER BY decode(cod_modulo, NULL, 0, 1) +
             decode(cod_modalidad, NULL, 0, 1) +
             decode(cod_sub_modalidad, NULL, 0, 1) +
             decode(cod_oficina, NULL, 0, 1) +
             decode(cod_moneda, NULL, 0, 1) DESC;
  END;
-- Se invoca procedimiento interno
  LP_GEN_INF_REMUNERACIONES;
-- verificar conexiones abiertas anteriormente
  IF UTL_FILE.IS_OPEN(v_file) THEN
    UTL_FILE.FCLOSE(v_file);
    UTL_FILE.FCLOSE_ALL;
  END IF;
  -- Abrir archivo
  v_file := UTL_FILE.FOPEN(v_repositorio,v_nom_archivo||'.csv','W',32767);
  --Definir un cursor for loop que recorre los datos obtenidos
  FOR arc in c_inf_remuneraciones LOOP
    --Generar la linea
    v_line := arc.periodo||';'||
              arc.saldo||';'||
              arc.nro_can_cuenta||';'||
              arc.nro_can_extr||';'||
              arc.can_pro_ext_sin_costo||';'||
              arc.nro_pag_elect||';'||
              arc.nro_can_instituciones||';'||
              arc.mto_min_com_atm||';'||
              arc.mto_max_com_atm||';'||
              arc.mto_pro_com_atm||';'||
              arc.can_tra_min_atm||';'||
              arc.can_tra_max_atm||';'||
              arc.can_tra_pro_atm;

    IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
      v_buffer := v_buffer || v_eol || v_line;
    ELSE
      IF v_buffer IS NOT NULL THEN
        --Escribes la linea en el fichero
        UTL_FILE.PUT_LINE(v_file, v_buffer);
      END IF;
      v_buffer := v_line;
    END IF;
      v_lines := v_lines + 1;
  END LOOP;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);
  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);
  IF UTL_FILE.IS_OPEN(v_file) THEN
    UTL_FILE.FCLOSE(v_file);
    UTL_FILE.FCLOSE_ALL;
  END IF;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                          v_port,
                                          v_user,
                                          v_pass,
                                          v_repositorio,
                                          v_nom_archivo||'.csv',
                                          v_nom_archivo||'.csv');
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
  IF v_respuesta <> 'OK' Then
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      INSERT INTO ge_ra_log_ftp
      (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
      (SYSDATE,
      v_nom_archivo|| '.csv',
      v_respuesta,
      v_hini_ftp,
      v_hfin_ftp);
      COMMIT;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
       UTL_FILE.FCLOSE(v_file);
       UTL_FILE.FCLOSE_ALL;
       v_obs :=substr(trim(SQLERRM || ' ' ||'-'||' '||v_respuesta),1,400);
       IT.pag_cie.PR_AT_INS_LOG(10,103,'PRG_GEN_INF_REMUNERACIONES', v_obs, it.pag_cie.c_log_ERROR,'OUT',SYSDATE);
END;
