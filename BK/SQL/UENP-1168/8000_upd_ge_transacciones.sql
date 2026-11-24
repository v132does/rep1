Begin
  pre_ini_aplicacion;
end;
/ 

update ge_transacciones t set t.cod_tasa = 580 where t.cod_transaccion = 1270 and t.cod_modulo = 6;

commit;
