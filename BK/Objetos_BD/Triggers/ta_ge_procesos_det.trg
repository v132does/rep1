CREATE OR REPLACE TRIGGER IT.TA_GE_PROCESOS_DET
 AFTER UPDATE OF ERROR, HOR_FIN
 ON "IT"."GE_PROCESOS_DET"
 FOR EACH ROW
DECLARE
  v_direccion              ba_cod_referencias.val_maximo%type;
  v_diferencia             ge_procesos_det.hor_fin%type;
  v_nro_secuencia          ge_procesos_det_his.nro_secuencia%type;
  v_fec_anterior           varchar2(30);
  v_fec_actual             varchar2(30);
  v_tiempo_transcurrido    varchar2(30);
  V_SENTENCIA              VARCHAR2(4000);
  v_jobs                   number;   
  V_FRECUENCIA             ge_procesos_det.frecuencia%type;
  V_FEC_ULT_DIA            GE_CALENDARIOS.ULT_DIA_MES_HABIL%type;  
  V_FECHA                  DATE;    
  V_FEC_CIERRE             DATE;
  V_INTERVAL               INTERVAL DAY TO SECOND;
  v_cod_programa           VARCHAR2(10);
  v_contador               NUMBER;
  v_existe                 VARCHAR2(1);
  v_msj_log                ge_log_procesos.observacion%type;  
  v_fec_aux                date := pag_cal.FU_OBT_FEC_ACTUAL(1);  
  
  -- Procedimiento autónomo, dinámico y reutilizable
  PROCEDURE pr_crear_job_dinamico(
      p_job_name_base     IN VARCHAR2, 
      p_proceso_principal IN VARCHAR2,
      p_fec_proceso       IN DATE
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_job_name_prefix VARCHAR2(100);
    v_job_name        VARCHAR2(128);
    v_sql_stmt        VARCHAR2(1000);
    v_ejecutado       NUMBER := 0;
  BEGIN
    /* Construimos el prefijo con la letra 'F' antes de la fecha y terminando en '_' para mejor control en casos de que se ejecute en el mismo dia (fecha servidor)
       PERO en cierres distintos (fecha ge_calendarios)
       Formato resultante: PRP_INI_PRE_F2906_ */
    v_job_name_prefix := UPPER(p_job_name_base) || 'F' || TO_CHAR(NVL(p_fec_proceso, SYSDATE), 'DDMM') ||'_';

    -- Evaluamos si ya se ejecutó o se está ejecutando para ESTA FECHA DE PROCESO específica
    SELECT COUNT(*)
      INTO v_ejecutado
      FROM DUAL
     WHERE EXISTS (
         -- Jobs ejecutados para la fecha de proceso
         SELECT 1 
           FROM all_scheduler_job_run_details
          WHERE job_name LIKE v_job_name_prefix || '%'
          AND CAST(log_date AS DATE) >= p_fec_proceso
         UNION ALL
         -- Jobs corriendo actualmente para la fecha de proceso
         SELECT 1 
           FROM all_scheduler_running_jobs
          WHERE job_name LIKE v_job_name_prefix || '%'
     );

    -- Si aun no se lanzó para este cierre de proceso, lo lanzamos
    IF v_ejecutado = 0 THEN
      -- Genera nombre único basado en el prefijo con fecha
      v_job_name := DBMS_SCHEDULER.GENERATE_JOB_NAME(v_job_name_prefix);
      
      v_sql_stmt := 'BEGIN ' ||
                    '  pre_ini_aplicacion; ' ||
                    '  pae_cnf.g_cod_modulo := 1; ' || 
                    '  pae_cnf.G_PROGRAMA := ''GPPROFIN''; ' ||
                    '  ' || p_proceso_principal || '; ' ||
                    'END;';
                    
      DBMS_SCHEDULER.CREATE_JOB (
         job_name   => v_job_name,
         job_type   => 'PLSQL_BLOCK',
         job_action => v_sql_stmt,
         enabled    => TRUE,
         auto_drop  => TRUE
      );
      
      COMMIT; -- Indispensable en PRAGMA AUTONOMOUS_TRANSACTION
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      null;--Se deja en nulo porque el programa 994 del cierre controla y loguea los estados y errores de los jobs
  END pr_crear_job_dinamico;
  
BEGIN
   if :new.hor_fin is not null and :old.hor_fin is null then
     if :new.cod_proceso = 10 then--inicio de dia
       if :new.nro_orden in (420) then
         pr_crear_job_dinamico(
            p_job_name_base     => 'PRA_ACT_SAL_', 
            p_proceso_principal => 'PRA_ACT_SAL_PROMEDIO',
            p_fec_proceso       => v_fec_aux); 
           
         pr_crear_job_dinamico(
            p_job_name_base     => 'PRP_ACT_FEC_', 
            p_proceso_principal => 'PRP_ACT_FEC_SOLICITUDES',
            p_fec_proceso       => v_fec_aux);
       end if;    
     elsif :new.cod_proceso = 11 then--cierre dia
       if :new.nro_orden in (80) then--CIE-1185: se elimina JOB de BD y se lanza desde aqui
         pr_crear_job_dinamico(
            p_job_name_base     => 'PRP_INI_PRE_', 
            p_proceso_principal => 'PRP_PRO_INI_PRE',
            p_fec_proceso       => v_fec_aux);
       elsif :new.nro_orden in (998) then
         --CIE-1082: se lanza PRP_ACT_DEV_DIARIOS DEVENGADO DIARIO PRESTAMOS por job al finalizar el cierre
         pr_crear_job_dinamico(
            p_job_name_base     => 'PRP_ACT_DEV_', 
            p_proceso_principal => 'PRP_ACT_DEV_DIARIOS',
            p_fec_proceso       => v_fec_aux);
       end if;
     end if;
     /* Se calcula la diferencia entre la hora_inicio y hora_fin de los procesos
       para almacenar en las referencias generales, este calculo se ve reflejado en la
       pantalla de Monitoreo de Procesos */
     IF :new.hor_inicio < :new.hor_fin or :new.hor_inicio = :new.hor_fin THEN
       BEGIN
         SELECT to_char( to_date((to_date(:new.hor_fin,'HH24:MI:SS') -to_date(:new.hor_inicio,'HH24:MI:SS'))* 86400,
                        'SSSSS'),
                     'HH24:MI:SS') Diferencia
         INTO v_diferencia
         FROM dual;
       EXCEPTION
         WHEN OTHERS THEN
           NULL;
       END;
       --Se guarda lo calculado en las referencias generales
       UPDATE ba_cod_referencias a
          SET a.val_maximo = v_diferencia
        WHERE dominio = 'PROMEDIO_PROCESO_'||:new.cod_proceso
          AND val_minimo = :new.nro_orden;

       IF sql%notfound THEN
         BEGIN
           INSERT INTO ba_cod_referencias
             (dominio,
              significado,
              val_minimo,
              val_maximo,
              abreviatura)
           VALUES
             ('PROMEDIO_PROCESO_'||:new.cod_proceso,
              'PROMEDIO DE TIEMPO',
              :new.nro_orden,
              v_diferencia,
              :new.frecuencia);
         EXCEPTION
           WHEN OTHERS THEN
             NULL;
         END;
       END IF;
     ELSE
       /*Si el proceso empezó a ejecutarse el día anterior pero terminó al día siguiente,
         calcula de esta manera*/
       v_fec_anterior := to_char(sysdate-1,'DD/MM/YYYY')||' '||:new.hor_inicio;
       v_fec_actual := to_char(sysdate,'DD/MM/YYYY')||' '||:new.hor_fin;
       BEGIN
         SELECT
              TO_TIMESTAMP(v_fec_actual, 'DD/MM/YYYY HH24:MI:SS') -
              TO_TIMESTAMP(v_fec_anterior, 'DD/MM/YYYY HH24:MI:SS') AS tiempo_transcurrido
           INTO v_tiempo_transcurrido
           FROM dual;
       EXCEPTION
         WHEN OTHERS THEN
           null;
       END;

       --Se guarda lo calculado en las referencias generales
       UPDATE ba_cod_referencias a
          SET a.val_maximo = substr(v_tiempo_transcurrido,12,8)
        WHERE dominio = 'PROMEDIO_PROCESO_'||:new.cod_proceso
          AND val_minimo = :new.nro_orden;

       IF sql%notfound THEN
         BEGIN
           INSERT INTO ba_cod_referencias
             (dominio,
              significado,
              val_minimo,
              val_maximo,
              abreviatura)
           VALUES
             ('PROMEDIO_PROCESO_'||:new.cod_proceso,
              'PROMEDIO DE TIEMPO',
              :new.nro_orden,
              substr(v_tiempo_transcurrido,12,8),
              :new.frecuencia);
         EXCEPTION
           WHEN OTHERS THEN
             NULL;
         END;
       END IF;
     END IF;
     /*CIE-35*/
     IF :NEW.COD_PROCESO IN (7, 10, 11, 12) THEN
       BEGIN
        --Inicializo variables.
        PAG_CAL.PR_OBT_DAT_CALENDAR(1);
        V_FEC_ULT_DIA  := PAG_CAL.G_ULT_DIA_MES_HABIL;
        V_FEC_ACTUAL   := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
        V_FEC_ANTERIOR := PAG_CAL.FU_OBT_FEC_ANTERIOR(1);
        V_FECHA        := V_FEC_ACTUAL;
        
       IF :NEW.COD_PROCESO IN (7, 11, 12) OR (:NEW.COD_PROCESO = 10 AND :NEW.NRO_ORDEN < 30)THEN 
        IF V_FEC_ULT_DIA = V_FEC_ACTUAL THEN
          V_FRECUENCIA := 'M'; -- MENSUAL
        ELSE 
          V_FRECUENCIA := 'D'; -- DIARIO
        END IF;
       END IF; 
       
       -- CIE-52.
       IF  :NEW.COD_PROCESO = 10 AND :NEW.NRO_ORDEN >= 30 THEN
           V_FECHA := V_FEC_ANTERIOR;
           BEGIN
             SELECT to_char(to_date(VAL_PARAMETRO, 'dd/mm/yyyy hh24:mi:ss'), 'dd/mm/yyyy') INTO V_FEC_CIERRE FROM GE_PAR_DINAMICOS WHERE PARAMETRO = 'FEC_CIE_MENSUAL';
           EXCEPTION 
            WHEN OTHERS THEN
              V_FEC_CIERRE := V_FEC_ANTERIOR;
           END; 
           IF V_FECHA = V_FEC_CIERRE THEN
             V_FRECUENCIA := 'M';
           ELSE 
             V_FRECUENCIA := 'D';
           END IF;
       END IF;    
       -- Ctrol para evitar duplicacion de reg con estado (F)inalizado
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
       -- Si no existe continua 
       IF nvl(v_existe, 'N') = 'N' THEN 
         -- Si la diferencia es nula realizar el calculo de diferencia nuevamente.  
         IF v_diferencia IS NULL THEN 
           IF :NEW.hor_fin >= :NEW.hor_inicio THEN
                -- Caso 1: hor_fin >= hor_inicio (mismo día o mismo tiempo)
                v_interval := TO_TIMESTAMP(:NEW.hor_fin, 'HH24:MI:SS') - TO_TIMESTAMP(:NEW.hor_inicio, 'HH24:MI:SS');
           ELSE
                -- Caso 2: hor_fin < hor_inicio (pasa al día siguiente)
                v_interval := (TO_TIMESTAMP(:NEW.hor_fin, 'HH24:MI:SS') + INTERVAL '1' DAY) - TO_TIMESTAMP(:NEW.hor_inicio, 'HH24:MI:SS');
           END IF;

           -- Convertir el INTERVAL a formato HH24:MI:SS y asignarlo a la variable v_diferencia
           v_diferencia := LPAD(EXTRACT(HOUR FROM v_interval), 2, '0') || ':' ||
                           LPAD(EXTRACT(MINUTE FROM v_interval), 2, '0') || ':' ||
                           LPAD(EXTRACT(SECOND FROM v_interval), 2, '0');
          END IF;
          -- Compara si hora_inicio es mayor que hora_fin
          IF :new.cod_proceso = 10 AND :new.nro_orden > 30 
             AND TO_TIMESTAMP(:new.hor_inicio, 'HH24:MI:SS') > TO_TIMESTAMP(:new.hor_fin, 'HH24:MI:SS') THEN
                 v_diferencia := '00:00:00';
            END IF;
        -- Ctrol de secuencia
        BEGIN
          SELECT nvl(max(d.nro_secuencia),0) 
           INTO v_nro_secuencia
           FROM it.ge_procesos_det_his d 
          where d.cod_proceso = :new.cod_proceso 
            and d.nro_orden   = :NEW.NRO_ORDEN 
            and d.cod_programa= :NEW.COD_PROGRAMA
            and d.fecha       = v_fecha;
            v_nro_secuencia:=v_nro_secuencia+1;
        EXCEPTION 
          WHEN no_data_found THEN 
           v_nro_secuencia:=1;
          when others then
           v_nro_secuencia:=1; 
          END;
          v_cod_programa := nvl(pae_cnf.fu_obt_cod_programa, user);
        INSERT INTO GE_PROCESOS_DET_HIS
          (FECHA,
           COD_PROCESO,
           NRO_ORDEN,
           COD_PROGRAMA,
           FRECUENCIA,
           HOR_INICIO,
           HOR_FIN,
           DURACION,
           NRO_SECUENCIA,
           ORIGEN,
           ESTADO)
        VALUES
          (V_FECHA,
           :NEW.COD_PROCESO,
           :NEW.NRO_ORDEN,
           :NEW.COD_PROGRAMA,
           V_FRECUENCIA,
           :NEW.HOR_INICIO,
           :NEW.HOR_FIN,
           V_DIFERENCIA,
           V_NRO_SECUENCIA,
           v_cod_programa,
           'F');
           ELSE -- Si ya existe se registra en Log para verificar caso por duplicacion
             v_msj_log := 'COD_PROCESO: '|| :new.cod_proceso || '-' ||
                          ' NRO_ORDEN: ' || :new.nro_orden   || '-' ||
                          ' FRECUENCIA: '|| v_frecuencia     || '-' ||
                          ' HORA_INCIO: '|| :new.hor_inicio  || '-' ||
                          ' HORA_FIN: '  || :new.hor_fin;
             PRG_ACT_LOG_PROCESOS('TA_GE_PROCESOS_DET',1, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),v_msj_log);
           END IF;
         EXCEPTION
           WHEN OTHERS THEN
             null;
         END;
         --
         IF :new.cod_proceso=10 and :new.cod_programa IN ('PRG_ACT_DEV_DIARIO') THEN
           it.prg_gen_met_cierre;
         END IF;
     END IF;
   end if;  
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error '||sqlerrm);
END;
/
