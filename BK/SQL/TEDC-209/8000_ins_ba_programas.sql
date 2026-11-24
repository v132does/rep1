BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('AMLIBDEP', 'LIBERAR RETENCIONES DE DEP EFECTIVO', 50, 3, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB
', 'Permite confirmar depositos efectivo antes de la finalización de su retención.', null, null, 'IT', to_date('13-05-2026 14:11:01', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('13-05-2026 14:11:01', 'dd-mm-yyyy hh24:mi:ss'), 'N', null, null, 'Operaciones/Liberación de depositos EFE', 'N');

commit;
