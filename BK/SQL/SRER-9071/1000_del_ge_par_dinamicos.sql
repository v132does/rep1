begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;

/ 

delete from ge_par_dinamicos where parametro = 'PRE_MAD_INF_FOGAPY' and cod_modalidad = 668;

commit;
