begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/ 
update ge_con_tra_procesos a
set a.fecha = '04/02/2026',
    mensaje = 'Fecha Anterior'||a.fecha
where a.fecha > '04/02/2026'; 
commit;
