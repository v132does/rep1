CREATE OR REPLACE PROCEDURE IT.PRF_GEN_ASI_AUTOMATICOS
IS
BEGIN
  begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=13;end;
  --- Consolida la transaccion
  prf_con_transaccion;
  commit;
  ---
  --- Genera los Asientos
  pra_gen_asientos;
  commit;
  ---
END;
/

