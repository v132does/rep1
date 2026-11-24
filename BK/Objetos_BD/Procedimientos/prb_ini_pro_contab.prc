create or replace procedure it.PRB_INI_PRO_CONTAB(p_cod_proceso number default 330)
 IS
BEGIN
   update ge_procesos
   set hor_inicio = null, hor_fin = null, cod_usuario = null, error = null
   where cod_proceso = p_cod_proceso
     and cod_proceso not in (10,11,12,813,814); -- se excluyen los procesos operativos y reportes automaticos
   update ge_procesos_det d
   set d.hor_inicio = null, d.hor_fin = null, d.cod_usuario = null, error = null
   where cod_proceso = p_cod_proceso
     and cod_proceso not in (10,11,12,813,814); -- se excluyen los procesos operativos y reportes automaticos
END;
/

