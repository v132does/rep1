Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IND_AUD_GENERAL', 'INDICADOR AUDITORIA GENERAL', 'GE_PAR_DINAMICOS', null, 'Se utiliza para activar o desactivar Auditoria General. Valor S o N.', null, null, 'N', null);

commit;
