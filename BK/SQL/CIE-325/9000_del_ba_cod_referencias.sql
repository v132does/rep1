begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;  
/
delete ba_cod_referencias b
WHERE b.dominio = 'TIP_OPE_INF_CRC'
AND b.val_minimo = 183;
commit;
