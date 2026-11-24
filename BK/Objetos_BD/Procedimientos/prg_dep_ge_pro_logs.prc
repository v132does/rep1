create or replace procedure IT.PRG_DEP_GE_PRO_LOGS is
--- Proceso de depuración de tablas para Optimización de espacio
--- Realizado por Fabiola Dávalos - 04/02/2026 - CIE-743

-- variables
   v_fec_anual  ge_calendarios.fec_actual%type;
   v_fec_trimestral  ge_calendarios.fec_actual%type;
   v_mov_fila VARCHAR2(100);
   v_lim_max NUMBER := FUG_OBT_PARDINAMICO('LIM_MAX_DEP_GE_PRO_LOGS');
   v_lim_min NUMBER := FUG_OBT_PARDINAMICO('LIM_MIN_DEP_GE_PRO_LOGS');

-- tipos de datos para colecciones
   TYPE t_mov_fila_tab IS TABLE OF ROWID;  -- Para ROWID de GE_PRO_PROGRAMAS_LOG
   v_mov_fila_tab t_mov_fila_tab;

   Cursor c_eli_programas_log is
   select rowid
     from ge_pro_programas_log
    where (trunc(fecha) < v_fec_anual
      and nivel in ('ERROR','INFO','WARN'))
      or (trunc(fecha) < v_fec_trimestral
      and nivel in ('DEBUG','TRACE'));

     TYPE t_list_log IS TABLE OF c_eli_programas_log%ROWTYPE;
     v_programas_log t_list_log;
     v_limite CONSTANT PLS_INTEGER := 10000;
begin
   v_fec_anual := add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),v_lim_max);
   v_fec_trimestral := add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),v_lim_min);

   -- Limpiar las colecciones
   v_mov_fila_tab := t_mov_fila_tab();

 OPEN c_eli_programas_log;
  LOOP
        FETCH c_eli_programas_log BULK COLLECT
           INTO v_programas_log LIMIT v_limite;
        EXIT WHEN v_programas_log.COUNT = 0;

   FOR i IN 1 .. v_programas_log.COUNT LOOP
      -- Cargar de valores
       v_mov_fila        := v_programas_log(i).rowid;
       BEGIN
           v_mov_fila_tab.EXTEND;
           v_mov_fila_tab(v_mov_fila_tab.COUNT) := v_mov_fila;
       END;
   END LOOP;
   EXIT WHEN c_eli_programas_log%NOTFOUND;
  END LOOP;
  CLOSE c_eli_programas_log;
  -- Uso de forall para la elimianación masiva
   FORALL i IN 1..v_mov_fila_tab.COUNT
     delete ge_pro_programas_log
        where rowid = v_mov_fila_tab(i);

END PRG_DEP_GE_PRO_LOGS;
