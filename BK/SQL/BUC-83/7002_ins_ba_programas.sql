begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('GEBLOCRE', 'BLOQUEO DE CREDITOS', 50, 3, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB', 'Permite el bloqueo de créditos a cuentas de Ahorros a la Vista y Cuentas Corrientes de Clientes.', null, null, 'S', null, null, 'Operaciones/Bloqueo de Créditos ', 'N');

commit;
