CREATE OR REPLACE TRIGGER IT.TA_GE_PRO_PROGRAMAS_LOG
 AFTER INSERT ON "IT"."GE_PRO_PROGRAMAS_LOG"
 FOR EACH ROW
DECLARE
  v_diferencia             ge_procesos_det.hor_fin%type;
  v_cod_proceso            ge_pro_programas_log.cod_proceso%type;
  v_nro_orden              ge_pro_programas_log.nro_orden%type;
  v_nro_secuencia          ge_procesos_det_his.nro_secuencia%type:=1;
  v_fec_anterior           VARCHAR2(30);
  v_fec_actual             VARCHAR2(30);
  v_frecuencia             ge_procesos_det.frecuencia%type;
  v_fec_ult_dia            ge_calendarios.ult_dia_mes_habil%type;
  v_fecha                  DATE;
  v_fec_cierre             DATE;
  v_interval               INTERVAL DAY TO SECOND;
  v_cod_programa           VARCHAR2(10);
  v_cod_procedimiento      VARCHAR2(40);
  v_hor_inicio             ge_procesos_det.hor_inicio%type;
  v_hor_error              ge_procesos_det.hor_fin%type;
  --
  v_contador               NUMBER;
  v_existe                 VARCHAR2(1);
  v_msj_log                ge_log_procesos.observacion%type; 

BEGIN
  --Inicializo variables 
IF :new.nivel = 'ERROR' THEN
  pag_cal.pr_obt_dat_calendar(1);
  v_fec_ult_dia  := pag_cal.g_ult_dia_mes_habil;
  v_fec_actual   := pag_cal.fu_obt_fec_actual(1);
  v_fec_anterior := pag_cal.fu_obt_fec_anterior(1);
  v_fecha        := v_fec_actual;
  v_cod_proceso  := :new.cod_proceso;
  v_nro_orden    := :new.nro_orden;

  BEGIN
    SELECT p.hor_inicio, p.cod_programa
      INTO v_hor_inicio, v_cod_procedimiento
      FROM ge_procesos_det p
     WHERE p.hor_inicio  IS NOT NULL
       AND p.cod_proceso = v_cod_proceso
       AND p.nro_orden   = v_nro_orden;
    EXCEPTION
      WHEN OTHERS THEN
       v_cod_proceso := NULL;
      END;

   IF :new.cod_proceso IN (10, 11, 12) THEN
     BEGIN
      IF :new.cod_proceso IN (11,12) OR (:new.cod_proceso = 10 AND :new.nro_orden < 30)THEN
        IF v_fec_ult_dia = v_fec_actual THEN
          v_frecuencia := 'M'; -- MENSUAL
        ELSE
          v_frecuencia := 'D'; -- DIARIO
        END IF;
      END IF;

      IF :new.cod_proceso = 10 AND :new.nro_orden >= 30 THEN
         v_fecha := v_fec_anterior;

         BEGIN
          SELECT to_char(to_date(val_parametro, 'dd/mm/yyyy hh24:mi:ss'), 'dd/mm/yyyy') INTO v_fec_cierre FROM ge_par_dinamicos WHERE parametro = 'FEC_CIE_MENSUAL';
         EXCEPTION
          WHEN OTHERS THEN
           v_fec_cierre := v_fec_anterior;
          END;

          IF v_fecha = v_fec_cierre THEN
           v_frecuencia := 'M';
          ELSE
           v_frecuencia := 'D';
          END IF;
       END IF;
        -- Ctrol para evitar duplicacion de reg con estado (E)rror
         BEGIN
          SELECT COUNT(*)
           INTO v_contador
           FROM it.ge_procesos_det_his d 
          WHERE d.cod_proceso = :new.cod_proceso 
            AND d.nro_orden   = :new.nro_orden 
            AND d.cod_programa= :new.cod_programa
            AND d.fecha       = v_fecha
            AND d.estado      = 'F';

            IF v_contador = 0 THEN
                v_existe := 'N';
            ELSE
                v_existe := 'S';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_existe := 'N';   
        END; 
        v_hor_error := to_char(sysdate,'HH24:MI:SS');
         -- Si no existe estado F para nro_orden continua 
       IF nvl(v_existe, 'N') = 'N' THEN 
         --Si la diferencia es nula realizar el calculo de diferencia nuevamente .
         IF v_diferencia IS NULL THEN  
           IF v_hor_error >= v_hor_inicio THEN
                -- Caso 1: hor_fin >= hor_inicio (mismo día o mismo tiempo)
                v_interval := TO_TIMESTAMP(v_hor_error, 'HH24:MI:SS') - TO_TIMESTAMP(v_hor_inicio, 'HH24:MI:SS');
           ELSE
                -- Caso 2: hor_fin < hor_inicio (pasa al día siguiente)
                v_interval := (TO_TIMESTAMP(v_hor_error, 'HH24:MI:SS') + INTERVAL '1' DAY) - TO_TIMESTAMP(v_hor_inicio, 'HH24:MI:SS');
           END IF;

           -- Convertir el INTERVAL a formato HH24:MI:SS y asignarlo a la variable v_diferencia
           v_diferencia := LPAD(EXTRACT(HOUR FROM v_interval), 2, '0') || ':' ||
                           LPAD(EXTRACT(MINUTE FROM v_interval), 2, '0') || ':' ||
                           LPAD(EXTRACT(SECOND FROM v_interval), 2, '0');
          END IF;
          -- Compara si hora_inicio es mayor que hora_fin
          IF :new.cod_proceso =10 and :new.nro_orden > 30 
             and TO_TIMESTAMP(v_hor_inicio, 'HH24:MI:SS') > TO_TIMESTAMP(v_hor_error, 'HH24:MI:SS') THEN
            v_diferencia := '00:00:00';
          END IF;
         --
        BEGIN
          SELECT nvl(max(d.nro_secuencia),0)
           INTO v_nro_secuencia
           FROM it.ge_procesos_det_his d
          where d.cod_proceso  = :new.cod_proceso
            and d.nro_orden    = :new.nro_orden
            and d.cod_programa = v_cod_procedimiento
            and d.fecha        = v_fecha;
            v_nro_secuencia:=v_nro_secuencia+1;
        EXCEPTION
          WHEN no_data_found THEN
           v_nro_secuencia:=1;
          WHEN OTHERS THEN
           v_nro_secuencia:=1;
          END;
        v_cod_programa := nvl(pae_cnf.fu_obt_cod_programa, user);

        INSERT INTO ge_procesos_det_his
          (fecha,
           cod_proceso,
           nro_orden,
           cod_programa,
           frecuencia,
           hor_inicio,
           hor_fin,
           duracion,
           nro_secuencia,
           origen,
           estado)
        VALUES
          (v_fecha,
           v_cod_proceso,
           :new.nro_orden,
           v_cod_procedimiento,
           v_frecuencia,
           v_hor_inicio,
           v_hor_error,
           v_diferencia,
           v_nro_secuencia,
           v_cod_programa,
           'E');
           ELSE -- Si ya existe se registra en Log para verificar caso por duplicacion
             v_msj_log := 'COD_PROCESO: '|| :new.cod_proceso || '-' ||
                          ' NRO_ORDEN: ' || :new.nro_orden   || '-' ||
                          ' FRECUENCIA: '|| v_frecuencia     || '-' ||
                          ' ORIGEN: '    || v_cod_programa   || '-' ||
                          ' HORA_INCIO: '|| v_hor_inicio     || '-' ||
                          ' HORA_FIN: '  || v_hor_error;
             PRG_ACT_LOG_PROCESOS('TA_GE_PRO_PROGRAMAS_LOG',1, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),v_msj_log);
           END IF;
         EXCEPTION
           WHEN OTHERS THEN
            NULL;
         END;
     END IF;
END IF;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error '||sqlerrm);
END;
/
