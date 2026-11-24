begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('FEC_VIG_DAS', 'FECHA VIGENCIA DAS', 'GE_PAR_DINAMICOS', null, 'Fecha Vigencia nuevo formato DAS', null, null, 'N', null);

commit;