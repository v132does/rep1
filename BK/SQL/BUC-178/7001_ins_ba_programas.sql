Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRG_BLO_VEN_SOBREGIROS', 'BLOQUEA LAS CUENTAS EN SOBREGIROS VENCIDAS', 4, 1, '.', '.', 'Bloquea las cuentas que se encuentran en sobregiros vencidas.', null, null, 'N', null, null, 'PROCESO INDEPENDIENTE', 'N');

commit;
