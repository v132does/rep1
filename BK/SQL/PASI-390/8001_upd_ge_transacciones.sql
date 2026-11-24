Begin pre_ini_aplicacion; end; 
/
UPDATE ge_transacciones a
   SET a.cod_tasa = 343
WHERE a.cod_modulo = 10
  and a.cod_modalidad = 150
  and a.cod_transaccion = 518;
  
commit;  
