begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;  
/
insert into ge_cta_def_adicionales(parametro, cod_modulo, cod_modalidad, tip_dato, lon_maxima)
     values ('CAR_CANCELACION',3,33,'A',1);
commit;
