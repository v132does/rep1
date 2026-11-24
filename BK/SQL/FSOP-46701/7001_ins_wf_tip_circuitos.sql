begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into wf_tip_circuitos (COD_TIP_CIRCUITO, DESCRIPCION, DETALLE, ESTADO, COD_OBJ_BASE, COD_TAR_INICIAL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, REFERENCIA, DET_SQL, COD_PROGRAMA, COD_MODULO, COD_MODALIDAD, NOM_PAR_REFERENCIA, REF_VAL_LIMITE)
values (167, 'GESTION DE TOPE DE CUENTA BAJO RIESGO', null, 'A', 'AH_CTA_VISTAS', null, 'IT', to_date('03-02-2025 15:07:19', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-02-2025 15:07:19', 'dd-mm-yyyy hh24:mi:ss'), 'NRO_CUENTA', null, null, 3, null, null, null);

commit;
