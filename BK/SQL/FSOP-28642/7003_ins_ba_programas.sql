begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('CMRECHBC', 'CHEQUES DEVUELTOS POR FORMALISTICA', 50, 4, 'xx', 'xx', 'Programa que lee el archivo RECHBC generado en Prodep con los cheques devueltos por formalística y realiza los créditos en las cuentas de los clientes', null, null, 'IT', to_date('08-05-2024 10:45:21', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('08-05-2024 10:45:21', 'dd-mm-yyyy hh24:mi:ss'), 'N', null, null, 'Cuentas Corrientes/Procesos', 'N');

commit;
/
