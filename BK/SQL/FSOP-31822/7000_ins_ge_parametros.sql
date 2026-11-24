BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_PLA_20_ANHOS', 'PLAZO DIFERIMIENTO', 'GE_PAR_DINAMICOS', null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'Plazo máximo de diferimiento cartera Vision Banco', null, null, null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_REQ_FUSION', 'PREV. 100% FUSION S/N', 'GE_PAR_DINAMICOS', null, 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('16-09-2023 14:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'Indica si se va previsionar el 100% la cartera diferida en el dia de la fusión', null, null, null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('FEC_INI_DIF', 'FECHA INICIO DIF', 'GE_PAR_DINAMICOS', null, 'EVERA', to_date('20-06-2024 15:40:54', 'dd-mm-yyyy hh24:mi:ss'), 'EVERA', to_date('20-06-2024 15:40:54', 'dd-mm-yyyy hh24:mi:ss'), 'Plazo máximo de diferimiento cartera Vision Banco', null, null, null, null);

commit; 
