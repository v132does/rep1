Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('FEC_CIE_MENSUAL', 'GUARDA FECHA DEL CIERRE MENSUAL', 'GE_PAR_DINAMICOS', 'Guarga la ultima fecha habil del cierre mensual.', 'N');

commit;
