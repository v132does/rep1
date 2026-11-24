begin
  pre_ini_aplicacion;
  pae_cnf.G_COD_MODULO :=1;
  end;
  /
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRP_ACT_ORI_FONDOS', 'ACT. BATCH ORIGEN DE FONDOS.', 4, 6, 'BASE DE DATOS', 'BASE DE DATOS', 'Actualización de origen de fondos en batch', null, 'Se ejecuta luego del inicio de dia.', 'IT', to_date('23-06-2025 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('23-06-2025 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), 'N', null,null, 'Inicio de dia', 'N');

commit;
