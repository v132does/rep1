BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update wf_tip_cir_tar_sig c
set c.descripcion = 'Verificación de estado o saldo de cuenta'
where cod_tip_circuito = 14;

commit;
