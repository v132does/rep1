begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
-- 11 registros afectados
update ge_procesos_det_his a
   set a.hor_fin = substr(a.hor_fin,1,2)||':'||substr(a.hor_fin,3,2)||':'||substr(a.hor_fin,5,2)
 where hor_fin not like '%:%';
/
commit;
