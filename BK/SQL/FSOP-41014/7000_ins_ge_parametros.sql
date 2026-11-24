begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('ACT_COB_CTA_OPERATIVA', 'PERMITIR COBROS IVA CTA OPERATIVA', 'GE_PAR_DINAMICOS', null, 'Permitir realizar cobros del crédito del IVA a una cta operativa (S) ACTIVA (N) INACTIVA', null, null, 'N', null);
/
commit;
