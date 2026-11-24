BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into wf_tip_circuitos (COD_TIP_CIRCUITO, DESCRIPCION, DETALLE, ESTADO, COD_OBJ_BASE, COD_TAR_INICIAL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, REFERENCIA, DET_SQL, COD_PROGRAMA, COD_MODULO, COD_MODALIDAD, NOM_PAR_REFERENCIA, REF_VAL_LIMITE)
values (14, 'VERIFICACION DE ESTADO DE CUENTA DE CRÉDITO', 'Verificación del estado de la cuenta para poder recibir créditos.', 'A', 'AH_CTA_VISTAS', null, 'IT', to_date('29-05-2024 16:01:50', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('29-05-2024 16:01:50', 'dd-mm-yyyy hh24:mi:ss'), 'NRO_CUENTA', null, 'EAMANCAV', 3, null, 'WK_NRCUENT', null);

commit;
