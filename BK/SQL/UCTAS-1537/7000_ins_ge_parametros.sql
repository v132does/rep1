begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into GE_PARAMETROS (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('WS_URL_INH_BCP', 'CONECTOR CRC BCP', 'GE_PAR_DINAMICOS', 'Indica el url de personas inhibidas de BCP', 'N');

insert into GE_PARAMETROS (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('ACT_SER_BCP', 'ACTIVAR/DESACTIVAR CONSULTA BCP', 'GE_PAR_DINAMICOS', 'Indica habilitar/deshabilitar validacion de clientes inhabilitados por BCP', 'S');

commit;
