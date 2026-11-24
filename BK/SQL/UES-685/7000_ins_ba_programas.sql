begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('GPCTAIPS', 'GENERACION CUENTAS PARA IPS', 1, 3, 'xxx', 'xxx', 'GENERACION CUENTAS PARA IPS', null, null, 'N', null, null, 'Procesos/Pago de Sueldos/Generar Cuentas de IPS', null);

commit;
