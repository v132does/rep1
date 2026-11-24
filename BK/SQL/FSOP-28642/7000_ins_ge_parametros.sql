BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into GE_PARAMETROS (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION)
values ('SNP_TRA_CLE_USD_P', 'TRX.CLEARING USD', 'GE_PAR_DINAMICOS', 'Transaccion para movimiento de pérdida para el clearing de cheques en USD.');

insert into GE_PARAMETROS (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION)
values ('SNP_TRA_CLE_USD_G', 'TRX.CLEARING USD', 'GE_PAR_DINAMICOS', 'Transaccion para movimiento de ganancia para el clearing de cheques en USD.');

COMMIT;

