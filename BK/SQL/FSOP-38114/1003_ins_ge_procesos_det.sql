BEGIN pre_ini_aplicacion; END;
/
insert into ge_procesos_det
  (COD_PROCESO,
   NRO_ORDEN,
   DESCRIPCION,
   COD_PROGRAMA,
   OBLIGATORIO,
   FRECUENCIA,
   ACTIVO,
   CON_CABECERA,
   SEP_CAMPOS,
   SEP_TEXTO)
values
  (6,
   1,
   'GENERA DATOS PARA REPORTE MT940',
   'PRC_GEN_EXT_MT940',
   'N',
   'D',
   'S',
   'S',
   ',',
   '"');

commit;
