begin 
pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1;
end;
/ 
insert into BA_COD_REFERENCIAS (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('SNP_CIR_WORKFLOW', 'APROBACION ENVIO MT999 SIPAP', sysdate, user, user, sysdate, '995', 'E', null, 'S');

commit;
