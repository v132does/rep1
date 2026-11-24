begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CAN_CTA_CAN_CHE', 'CANTIDAD P/ DEVOLVER CTA. CANCELADA', 'GE_PAR_DINAMICOS', null, 'IT', to_date('16-07-2024 09:30:10', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('16-07-2024 09:40:43', 'dd-mm-yyyy hh24:mi:ss'), 'Cantidad (MESES) para devolver cheques con cuenta cancelada por chequeras', null, null, 'N', null);

commit;
