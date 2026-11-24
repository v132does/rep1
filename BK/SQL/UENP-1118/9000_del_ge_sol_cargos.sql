BEGIN pre_ini_aplicacion; END; 
/
DELETE FROM ge_sol_cargos a where a.cod_modulo = 6 and a.cod_modalidad = 668 and a.cod_transaccion = 701;

commit;
