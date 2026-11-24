begin 
pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1;
end;
/

insert into BA_PER_DAT_ADICIONALES (COD_PERSONA, PARAMETRO, VAL_PARAMETRO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('8282047', 'SNP_HAB_BCO_PTE_HB', 'S', user, sysdate, user, sysdate);


/
commit;