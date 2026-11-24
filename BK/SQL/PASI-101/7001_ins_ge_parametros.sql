Begin pre_ini_aplicacion; end; 
/
insert into GE_PARAMETROS (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_COD_CAU_BLO_CTA', 'COD. CAUSA BLOQ. SALDO POR DESEMB.', 'GE_PAR_DINAMICOS', null, 'IT', to_date('07-10-2024 14:58:49', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('07-10-2024 14:58:49', 'dd-mm-yyyy hh24:mi:ss'), 'Parametro de causa para el bloqueo de saldo de cuenta de ahorro por desembolso de prestamos.', null, null, 'N', null);

commit;
