begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('CMCHDECM', 'DEVOLUCIÓN CHEQUES C/NTRO BCO', 50, 4, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB
', 'Permite la modificación de los motivos de cheques rechazados/devueltos.', null, 'Permite la modificación de los motivos de cheques rechazados/devueltos.', 'N', null, null, 'Operaciones/Cuentas Corrientes/Devolución cheques c/Ntro Bco', null);
/
commit;
