begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_modalidades
set descripcion = 'CDA DESMATERIALIZADO',
    sigla       = 'CDAD'
where cod_modulo = 3
and cod_modalidad = 34;

commit;
