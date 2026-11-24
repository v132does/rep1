begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('POR_UTI_SOL_CHE', 'PORCENTAJE SOLICITUD DE CHEQUES', 'GE_PAR_DINAMICOS', null, 'Indica cuanto es el porcentaje minimo de utilización de cheques para solicitar nuevas chequeras.', null, null, 'N', null);
/
commit;
