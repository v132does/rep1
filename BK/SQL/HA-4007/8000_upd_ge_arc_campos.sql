Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_arc_tablas a 
set a.borrar = 'S'
where a.referencia = 'OFICIOS_JUDICIALES';
commit;

