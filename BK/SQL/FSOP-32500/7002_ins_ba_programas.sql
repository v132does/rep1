begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, UBI_MENU)
values ('CLERRDEV', 'LISTADO DE ERRORES DE CHEQUES DEVUELTOS', 3, 4, 'Z:\GF10G\EXE', 'Z:\GF10G\RDF', 'Listado de errores del proceso de cheques devueltos', null, null, user, sysdate, user, sysdate, 'N', null, 'Informes => Cuentas Corrientes => Errores del Proceso de Formalistica');

commit;
