begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_CIR_ENV_MT999_SIPAP', 'Nro. circuito MT999 SIPAP', 'GE_PAR_DINAMICOS', null, 'IT', to_date('04-08-2025 09:35:43', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2025 09:35:43', 'dd-mm-yyyy hh24:mi:ss'), 'Indicador de circuito WF para envio de mt999 SIPAP', null, null, 'N', null);

commit;
