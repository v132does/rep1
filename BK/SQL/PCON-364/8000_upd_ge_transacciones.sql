begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
/
update ge_transacciones s
   set s.descripcion = 'COMISION FOGAVI'
 where cod_transaccion = 703
   and cod_modalidad = 668;

commit;
