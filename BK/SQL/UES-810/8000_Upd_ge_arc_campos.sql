begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

update ge_arc_campos t
   set t.tip_dato = 'VARCHAR2'
 where referencia = 'REGISTRO_PLANES'
   and t.nro_secuencia = 3;

commit;
