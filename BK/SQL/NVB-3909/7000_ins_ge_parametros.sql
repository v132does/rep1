Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('PRO_INH_COMPRAS', 'DESINHIBIR CLIENTES COMPRA CARTERA', 'GE_PAR_DINAMICOS', 'Permite deshinibir clientes en el proceso de compra de cartera.', 'N');
/
commit;