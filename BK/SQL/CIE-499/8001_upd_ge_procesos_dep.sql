BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update ge_procesos_dep d
set d.cod_proceso = 12, d.cod_proceso_pre = 12, d.cod_programa_pre = 'PRG_VER_CONSISTENCIA'
where d.cod_proceso= 11
and d.cod_programa = 'PRG_GEN_ASI_CIE_TMP'
and d.cod_proceso_pre = 11
and d.cod_programa_pre = 'PAS_BCP.PR_GEN_ENCAJES';

update ge_procesos_dep d
set d.cod_proceso = 12, d.cod_proceso_pre = 12, d.cod_programa = 'PRS_GEN_ACCIONES'
where d.cod_proceso= 11
and d.cod_programa = 'PRG_AUD_TRIGGERS(''H'')'
and d.cod_proceso_pre = 11
and d.cod_programa_pre = 'PRG_GEN_ASI_CIE_TMP';

commit;