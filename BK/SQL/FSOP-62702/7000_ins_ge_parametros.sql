Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_MAD_ACT_FEC_INICIO', 'MODALIDADES P/ ACT. FECHA INICIO', 'GE_PAR_DINAMICOS', null, 'Define las Modalidades que permite actualizar fecha de inicio de las solicitudes de préstamos no desembolsadas ni canceladas en el proceso de inicio diario prp_act_fec_solicitudes.', null, null, null, null);

commit;
