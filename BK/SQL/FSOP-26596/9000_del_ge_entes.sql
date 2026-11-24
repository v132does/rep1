begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
delete  ge_entes g
where g.cod_ente in(9822,9820,9818,9809,9823,9826,9815,9824,9819,9810,9935,9817,9811);
 
commit;
