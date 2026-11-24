BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
delete ge_procesos_dep d 
 where d.cod_programa = 'PRG_GEN_ASI_CIE_TMP' 
    or d.cod_programa_pre = 'PRG_GEN_ASI_CIE_TMP';
commit;

