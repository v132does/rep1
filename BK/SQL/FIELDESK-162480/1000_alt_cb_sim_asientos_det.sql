begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

alter table it.cb_sim_asientos_det modify ref_movimiento number(10);

commit;
