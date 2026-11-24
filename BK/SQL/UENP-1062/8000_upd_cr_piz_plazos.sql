begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
update cr_piz_plazos c set c.plz_hasta = '9999' where cod_modalidad = 663;

commit;
