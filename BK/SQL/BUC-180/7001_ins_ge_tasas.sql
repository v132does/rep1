Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_tasas (COD_TASA, DESCRIPCION, TIP_VALOR, TIPO, APLICAR, COD_MON_BASE)
values (520, 'COMISION POR DEPOSITO ME (SEGMENTO)', 'P', 'V', 'RE', null);

commit;
