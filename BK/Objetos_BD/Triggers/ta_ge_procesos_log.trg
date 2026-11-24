CREATE OR REPLACE TRIGGER IT.TA_GE_PROCESOS_LOG
 AFTER INSERT ON "IT"."GE_PROCESOS_LOG"
 FOR EACH ROW
DECLARE
  v_diferencia             ge_procesos_det.hor_fin%type;
  v_cod_proceso            ge_procesos_log.cod_proceso%type;
  v_nro_orden              ge_procesos_log.nro_orden%type;
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
  

BEGIN
  --Inicializo variables  .
  pag_cal.pr_obt_dat_calendar(1);
  v_fec_ult_dia  := pag_cal.g_ult_dia_mes_habil;
  v_fec_actual   := pag_cal.fu_obt_fec_actual(1);
  v_fec_anterior := pag_cal.fu_obt_fec_anterior(1);
  v_fecha        := v_fec_actual;
  v_cod_proceso  := :new.cod_proceso;
  v_nro_orden    := :new.nro_orden;
  
  BEGIN
    SELECT p.cod_programa
      INTO v_cod_procedimiento
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

       --Si la diferencia es nula realizar el calculo de diferencia nuevamente .
       IF v_diferencia IS NULL THEN
         IF :new.hor_error >= :new.hor_inicio THEN
              -- Caso 1: hor_fin >= hor_inicio (mismo día o mismo tiempo)
              v_interval := TO_TIMESTAMP(:new.hor_error, 'HH24:MI:SS') - TO_TIMESTAMP(:new.hor_inicio, 'HH24:MI:SS');
         ELSE
              -- Caso 2: hor_fin < hor_inicio (pasa al día siguiente)
              v_interval := (TO_TIMESTAMP(:new.hor_error, 'HH24:MI:SS') + INTERVAL '1' DAY) - TO_TIMESTAMP(:new.hor_inicio, 'HH24:MI:SS');
         END IF;

         -- Convertir el INTERVAL a formato HH24:MI:SS y asignarlo a la variable v_diferencia
         v_diferencia := LPAD(EXTRACT(HOUR FROM v_interval), 2, '0') || ':' ||
                         LPAD(EXTRACT(MINUTE FROM v_interval), 2, '0') || ':' ||
                         LPAD(EXTRACT(SECOND FROM v_interval), 2, '0');
        END IF;
        BEGIN
          SELECT nvl(max(d.nro_secuencia),0)
           INTO v_nro_secuencia
           FROM it.ge_procesos_det_his d
          where d.cod_proceso = :new.cod_proceso
            and d.nro_orden   = :new.nro_orden
            and d.cod_programa= v_cod_procedimiento
            and d.fecha       = v_fecha;
            v_nro_secuencia:=v_nro_secuencia+1;
        EXCEPTION
          WHEN no_data_found THEN
           v_nro_secuencia:=1;
          when others then
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
           :new.hor_inicio,
           :new.hor_error,
           v_diferencia,
           v_nro_secuencia,
           v_cod_programa,
           'E');
         EXCEPTION
           WHEN OTHERS THEN
            null;
         END;
     END IF;

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error '||sqlerrm);
END;
/
