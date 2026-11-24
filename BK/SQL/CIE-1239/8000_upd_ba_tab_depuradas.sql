begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
update ba_tab_depuradas a
   set nro_grupo = 1
 where a.nom_tabla in ('GE_CLA_OPERACIONES',
'GE_CLIENTES',
'TA_DET_CONCILIACIONES',
'TA_RES_CONCILIACIONES',
'TA_TOT_CONCILIACIONES',
'TA_MOV_EXTRACTO_TMP');
/
commit;
/
update ba_tab_depuradas a
   set nro_grupo = 2
 where a.nom_tabla in ('CB_SAL_INVENTARIOS',
'CB_SAL_INVENTARIOS_DET',
'GE_MOVIMIENTOS',
'CJ_LOG_GLO_PRO');
/
commit;
