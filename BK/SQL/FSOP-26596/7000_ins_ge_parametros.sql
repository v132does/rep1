begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('TIP_MOD_CAV_CANCELA', 'TIP MODALIDAD INFORMAR CANCELACION', 'GE_PAR_DINAMICOS', null, 'ACASCO', to_date('18-12-2023 10:49:53', 'dd-mm-yyyy hh24:mi:ss'), 'ACASCO', to_date('18-12-2023 10:49:53', 'dd-mm-yyyy hh24:mi:ss'), 'Tipo de modalidades CAV a ser informados a CRC con estado Cancelados.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('TIP_OPE_CDA_CANCELA', 'TIP MODALIDAD NO INFORMAR CDA', 'GE_PAR_DINAMICOS', null, 'ACASCO', to_date('18-12-2023 10:49:53', 'dd-mm-yyyy hh24:mi:ss'), 'ACASCO', to_date('18-12-2023 10:49:53', 'dd-mm-yyyy hh24:mi:ss'), 'Tipo de operaciones CDA a no informar a CRC con estados de Cancelacion o Total_Pagado.', null, null, 'N', null);
commit;
