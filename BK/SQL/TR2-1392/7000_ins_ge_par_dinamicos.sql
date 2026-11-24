begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('WS_URL_TAR_WALLET', 'Ubi. de Wallet para Kong Tarjetas', 'GE_PAR_DINAMICOS', 'Esta URL se utiliza para ubicación del wallet para kong para tarjetas', 'N');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('WS_URL_TAR_WALLET', 'file:/var/opt/oracle/dbaas_acfs/prdcdb01/wallet_https');

commit;
