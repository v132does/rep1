begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('CMCHRECH', 'VINCULOS Y CAUSAS SECUNDARIAS', 50, 4, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB', 'Permite el registro de Vínculos o causas secundarias de los rechazos CNB', null, null, 'LMENDOZA', to_date('26-07-2024 13:26:00', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', to_date('26-07-2024 13:26:00', 'dd-mm-yyyy hh24:mi:ss'), 'N', null, null, 'Operaciones => Cuentas Corrientes => Devolución de Cheques c/Ntro.Bco => Vinculos y Causas Secundarias', 'N');
commit;
