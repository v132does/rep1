CREATE OR REPLACE PROCEDURE it.prg_gen_met_cierre IS

  v_pri_dia_mes_habil    it.ge_calendarios.pri_dia_mes%type;
  v_fec_anterior         it.ge_calendarios.fec_anterior%type;
  v_par_can_mes_metricas number := to_number(nvl(fug_obt_pardinamico('CAN_MES_METRICAS'),0));
  v_cod_proceso          it.ge_procesos_det_his.cod_proceso%TYPE;
  v_duracion             it.ge_procesos_det_his.duracion%TYPE;
  v_dur_procesos         it.ge_procesos_det_his.duracion%TYPE;
  v_hor_operativa        VARCHAR2(8);
  v_dur_pre_cierre       VARCHAR2(8);
  v_dur_cierre           VARCHAR2(8);
  v_dur_pos_cierre       VARCHAR2(8);
  v_dur_inicio           VARCHAR2(8);
  v_tot_duracion         VARCHAR2(10);
  v_tot_dur_procesos     VARCHAR2(8);
  v_dif_duracion         VARCHAR2(8);
  v_dur_paralelo         VARCHAR2(8);    --CIE-242--
  V_SENTENCIA            VARCHAR2(4000); --CIE-242--
  v_jobs                 number;         --CIE-242--  
  v_fec_ant_aux          DATE;
  
CURSOR c_metricas IS 
SELECT decode(p.cod_proceso, 7, 0, 11, 1, 12, 2, 10, 3) nro_orden,
       p.fecha,
       p.cod_proceso,
       decode(p.cod_proceso, 7 , 'PRE CIERRE OPERATIVO',
                             11, 'CIERRE OPERATIVO', 
                             12, 'POST-CIERRE OPERATIVO', 
                             10, 'INICIO DE DIA OPERATIVO') des_proceso,
       (SELECT a.hor_inicio
          FROM it.ge_procesos_det_his a
         WHERE a.fecha       = p.fecha
           AND a.cod_proceso = p.cod_proceso
           AND a.nro_orden   =
                             (SELECT MIN(a1.nro_orden)
                                FROM ge_procesos_det_his a1
                               WHERE a1.fecha       = a.fecha
                                 AND a1.cod_proceso = a.cod_proceso)
          AND a.nro_secuencia = (SELECT MIN(p1.nro_secuencia) 
                                   FROM it.ge_procesos_det_his p1 
                                  WHERE p1.fecha       = a.fecha 
                                    AND p1.cod_proceso = a.cod_proceso
                                    AND p1.nro_orden   = a.nro_orden)) hora_inicio,
       (SELECT a.hor_fin
          FROM it.ge_procesos_det_his a
         WHERE a.fecha       = p.fecha
           AND a.cod_proceso = p.cod_proceso
           AND a.nro_orden   =
                              (SELECT MAX(a2.nro_orden)
                                 FROM it.ge_procesos_det_his a2
                                WHERE a2.fecha       = a.fecha  
                                  AND a2.cod_proceso = a.cod_proceso)
          AND a.nro_secuencia = 
                              (SELECT MAX(p2.nro_secuencia) 
                                 FROM it.ge_procesos_det_his p2 
                                WHERE p2.fecha = a.fecha 
                                  AND p2.cod_proceso = a.cod_proceso
                                  AND p2.nro_orden   = a.nro_orden)) hora_fin
  FROM ge_procesos_det_his p
 WHERE p.fecha = v_fec_anterior
   AND (p.cod_proceso = v_cod_proceso OR v_cod_proceso IS NULL)
 GROUP BY p.fecha, p.cod_proceso
 ORDER BY 2, 1;

-- Funcion para obtener la diferencia entre horas en formato HH24:MI:SS
FUNCTION lf_obt_tot_duracion(
 p_hor_uno     IN VARCHAR2,
 p_hor_dos     IN VARCHAR2,
 p_hor_tres    IN VARCHAR2
)
RETURN VARCHAR2
IS

  v_dif            INTERVAL DAY TO SECOND;
  v_tot_segundos NUMBER;
  v_horas          NUMBER;
  v_minutos        NUMBER;
  v_segundos       NUMBER;
  v_tiempo         VARCHAR2(10);

BEGIN
     
 v_dif :=   TO_DSINTERVAL('0 ' || p_hor_uno) 
          + TO_DSINTERVAL('0 ' || p_hor_dos) 
          + TO_DSINTERVAL('0 ' || p_hor_tres);
           
 v_tot_segundos :=   EXTRACT(DAY    FROM v_dif) * 86400 +
                     EXTRACT(HOUR   FROM v_dif) * 3600 +
                     EXTRACT(MINUTE FROM v_dif) * 60 +
                     EXTRACT(SECOND FROM v_dif);
  
  v_horas    := FLOOR(v_tot_segundos / 3600);
  v_minutos  := FLOOR(MOD(v_tot_segundos, 3600) / 60);
  v_segundos := MOD(v_tot_segundos, 60);

  v_tiempo:= (LPAD(v_horas, 2, '0') || ':' || LPAD(v_minutos, 2, '0') || ':' || LPAD(v_segundos, 2, '0'));                     
  RETURN v_tiempo;
EXCEPTION
  WHEN OTHERS THEN
     v_tiempo:= NULL;
     RETURN v_tiempo;
END;

-- Funcion para obtener la diferencia entre horas en formato HH24:MI:SS
FUNCTION lf_obt_dif_hora(
 p_hor_inicio  IN it.ge_procesos_det_his.hor_inicio%TYPE,
 p_hor_fin     IN it.ge_procesos_det_his.hor_fin%TYPE,
 p_tipo        IN VARCHAR2
)
RETURN VARCHAR2
IS

 v_resultado    VARCHAR2(10);
 v_dif          INTERVAL DAY TO SECOND;
BEGIN
 IF p_tipo = 'C' THEN -- DIFERENCIA DE CIERRE 
  IF p_hor_fin > p_hor_inicio THEN
     v_dif:= TO_TIMESTAMP(p_hor_fin, 'HH24:MI:SS') - TO_TIMESTAMP(p_hor_inicio, 'HH24:MI:SS');
  ELSE
     v_dif:=(TO_TIMESTAMP(p_hor_fin, 'HH24:MI:SS') + INTERVAL '1' DAY) - TO_TIMESTAMP(p_hor_inicio, 'HH24:MI:SS');
  END IF;
  v_resultado := LPAD(EXTRACT(HOUR   FROM v_dif), 2, '0') || ':' ||
                 LPAD(EXTRACT(MINUTE FROM v_dif), 2, '0') || ':' ||
                 LPAD(EXTRACT(SECOND FROM v_dif), 2, '0');
  RETURN v_resultado;
 END IF;
 
 IF p_tipo = 'N' THEN -- DIFERENCIA NORMAL
  IF p_hor_inicio > p_hor_fin THEN 
   v_dif:= TO_TIMESTAMP(p_hor_inicio, 'HH24:MI:SS') - TO_TIMESTAMP(p_hor_fin, 'HH24:MI:SS');
  else
    v_dif:= TO_TIMESTAMP(p_hor_fin, 'HH24:MI:SS') - TO_TIMESTAMP(p_hor_inicio, 'HH24:MI:SS');
  end if; 
   v_resultado := LPAD(EXTRACT(HOUR   FROM v_dif), 2, '0') || ':' ||
                  LPAD(EXTRACT(MINUTE FROM v_dif), 2, '0') || ':' ||
                  LPAD(EXTRACT(SECOND FROM v_dif), 2, '0');               
  RETURN v_resultado;
 END IF;     
EXCEPTION
  WHEN OTHERS THEN
     v_resultado:= NULL;
     RETURN v_resultado;
END;

-- Funcion para totalizar la duracion de los procesos en formato HH24:MI:SS
FUNCTION lf_obt_dur_tot_proceso(
 p_cod_proceso  IN it.ge_procesos_det_his.cod_proceso%TYPE,
 p_fecha        IN it.ge_procesos_det_his.fecha%TYPE
)
return varchar2
IS

v_valor varchar2(8);
BEGIN
      SELECT LPAD(FLOOR(suma_segundos / 3600), 2, '0') || ':' ||
         LPAD(FLOOR(MOD(suma_segundos, 3600) / 60), 2, '0') || ':' ||
         LPAD(MOD(suma_segundos, 60), 2, '0') AS duracion_total
      INTO v_valor
      FROM (
          SELECT SUM(
                  EXTRACT(HOUR   FROM TO_TIMESTAMP((p.duracion), 'HH24:MI:SS')) * 3600 +
                  EXTRACT(MINUTE FROM TO_TIMESTAMP((p.duracion), 'HH24:MI:SS')) * 60 +
                  EXTRACT(SECOND FROM TO_TIMESTAMP((p.duracion), 'HH24:MI:SS'))
              ) AS suma_segundos
          FROM it.ge_procesos_det_his p
          WHERE p.fecha = p_fecha AND (p.cod_proceso = p_cod_proceso or p_cod_proceso is null)) t;
          return v_valor;
EXCEPTION
  when others then
     PRG_ACT_LOG_PROCESOS('PRG_GEN_MET_CIERRE',1, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),sqlerrm);
     v_valor:= '00:00:00';
     return v_valor;
END;

PROCEDURE lp_eli_mes_metrica IS
 
 v_meses        NUMBER; 
 v_fec_eliminar DATE;
BEGIN
  -- se verifica la cantidad de meses minimo 6 meses de registro
  -- el trunc retorna el primer dia de cada mes
 BEGIN
  SELECT nvl(COUNT(DISTINCT to_char(fecha, 'MM')),0) meses 
    INTO v_meses
   FROM it.ge_cie_metricas g 
  WHERE last_day(g.fecha)<trunc(v_fec_anterior);
 EXCEPTION
  WHEN OTHERS THEN
   v_meses:=0;
 END;
    
 IF v_meses >= v_par_can_mes_metricas THEN
  BEGIN
   SELECT last_day(max(ADD_MONTHS(TRUNC(w.fecha, 'MM'), -v_par_can_mes_metricas))) AS fecha_limite 
    INTO v_fec_eliminar
    FROM it.ge_cie_metricas w;
  EXCEPTION
    WHEN OTHERS THEN
      v_fec_eliminar:=NULL;
    END;        
 END IF;
   
 IF v_fec_eliminar IS NOT NULL THEN 
  DELETE FROM it.ge_cie_metricas w WHERE w.fecha<=v_fec_eliminar;
 END IF; 

EXCEPTION
 WHEN OTHERS THEN
   NULL;
 END;
---CIE-242
function lf_obt_dur_paralelo(
 p_cod_proceso  IN it.ge_procesos_det_his.cod_proceso%TYPE
) 
  return varchar2
is
    v_dur_paralelo varchar2(8);
begin
    select lpad(floor(sum(to_number(substr(h.duracion, 1, 2))) + 
                      (sum(to_number(substr(h.duracion, 4, 2))) / 60) + 
                      (sum(to_number(substr(h.duracion, 7, 2))) / 3600)), 2, '0') || ':' ||
           lpad(mod(floor(sum(to_number(substr(h.duracion, 4, 2))) + 
                          (sum(to_number(substr(h.duracion, 7, 2))) / 60)), 60), 2, '0') || ':' ||
           lpad(mod(sum(to_number(substr(h.duracion, 7, 2))), 60), 2, '0') 
    into v_dur_paralelo
    from ge_procesos_det_his h
    join ge_procesos_dep p on h.cod_programa = p.cod_programa
    where p.tipo = 'P'
      and h.fecha = v_fec_anterior
      and h.cod_proceso = p_cod_proceso
      group by h.cod_proceso;
    
    return v_dur_paralelo;
exception
    when others then
        return null;  -- retornar null en caso de error --cie-242 --
end lf_obt_dur_paralelo;
---

BEGIN
  
  v_fec_anterior      := pag_cal.fu_obt_fec_anterior(1); 
  v_pri_dia_mes_habil := pag_cal.fu_obt_fec_pri_dia_mes_habil(1);
  

 FOR c_reg in c_metricas LOOP
  
    -- si se cerro el primer dia habil y existe igualdad
    -- se procede a verificar los meses y si existe seis meses 
    -- se elimina todos los registros del primer mes registrado 
   IF v_fec_anterior = v_pri_dia_mes_habil and v_par_can_mes_metricas > 0 THEN
     lp_eli_mes_metrica;
   END IF;
   
   -- Por cada cambio de fecha se setea la fecha
   IF v_fec_ant_aux IS NULL THEN
     v_fec_ant_aux := c_reg.fecha;
   ELSIF c_reg.fecha <> v_fec_ant_aux THEN -- en caso de Gen. masiva  
     v_dur_cierre       := NULL;
     v_dur_pos_cierre   := NULL;
     v_dur_inicio       := NULL;
     v_tot_duracion     := NULL;
     v_tot_dur_procesos := NULL;
     v_dif_duracion     := NULL;
     v_hor_operativa    := NULL;
     v_fec_ant_aux      := c_reg.fecha;
   END IF;  
   
   -- se obtiene la diferencia entre hor_fin y el hor_inicio del proceso
   -- que sera la duracion 
   v_duracion     := lf_obt_dif_hora(c_reg.hora_inicio, c_reg.hora_fin, 'C');
   
   -- se obtiene el la duracion de los procesos 
   v_dur_procesos := lf_obt_dur_tot_proceso(c_reg.cod_proceso, c_reg.fecha);
  
    -- pre cierre operativo 
   IF c_reg.cod_proceso = 7  THEN
     v_dur_pre_cierre := v_duracion;
   end if;
    
   -- cierre operativo 
   IF c_reg.cod_proceso = 11 THEN
     v_dur_cierre := v_duracion;
   end if;
   
   -- post cierre operativo
   IF c_reg.cod_proceso = 12 THEN
     v_dur_pos_cierre := v_duracion;
   end if;
   
   -- inicio operativo
   IF c_reg.cod_proceso = 10 THEN
     BEGIN
      SELECT w.hor_fin 
        INTO v_hor_operativa
        FROM it.ge_procesos_det_his w
       WHERE w.fecha       = c_reg.fecha 
         and w.cod_proceso = c_reg.cod_proceso
         and w.nro_orden   = 100;  
     EXCEPTION
      WHEN OTHERS THEN
       v_hor_operativa := NULL;     
     END;
      
      v_dur_inicio       := v_duracion;
      v_tot_duracion     := lf_obt_tot_duracion(v_dur_cierre, v_dur_pos_cierre, v_dur_inicio);
      v_tot_dur_procesos := lf_obt_dur_tot_proceso(null, c_reg.fecha);      
      v_dif_duracion     := lf_obt_dif_hora(v_tot_duracion, v_tot_dur_procesos, 'N');
    END IF;
      v_dur_paralelo     := lf_obt_dur_paralelo(c_reg.cod_proceso); --CIE-242 --
  
   
   -- insert en la tabla
   BEGIN
     INSERT INTO it.ge_cie_metricas
      (nro_orden, fecha, cod_proceso, hor_inicio, hor_fin,
       duracion, dur_procesos, tot_duracion, tot_dur_procesado, hor_operativa, dif_duracion,
       dur_paralelo)
      VALUES
      (c_reg.nro_orden, c_reg.fecha, c_reg.cod_proceso, c_reg.hora_inicio, c_reg.hora_fin,
       v_duracion, v_dur_procesos, v_tot_duracion, v_tot_dur_procesos, v_hor_operativa, v_dif_duracion,
       v_dur_paralelo);
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000,'Error al insertar en GE_CIE_METRICAS '|| SQLERRM);
     END;
 END LOOP;  
     V_SENTENCIA := 'begin begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; it.prg_act_pro_volumen; end;';
     DBMS_JOB.submit(v_jobs,V_SENTENCIA);
END;
/
