BEGIN pre_ini_aplicacion; END;
/
insert into ba_programas
  (COD_PROGRAMA,
   DESCRIPCION,
   COD_TIP_PROGRAMA,
   COD_MODULO,
   UBI_EJECUTABLE,
   UBI_FISICO,
   UBI_MENU,
   DES_DETALLADA,
   OPE_MOD_CERRADO)
values
  ('PRC_GEN_EXT_MT940',
   'GENERACION DE DATOS PARA REPORTE MT940',
   4,
   1,
   'BASE DE DATOS',
   'BASE DE DATOS',
   'BASE DE DATOS',
   'Genera datos para reporte MT940',
   'S');

commit;
