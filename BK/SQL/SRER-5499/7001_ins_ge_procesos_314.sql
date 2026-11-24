-- =============================================================================
-- SRER-5499: BA_PROGRAMAS + GE_PROCESOS 314 (CF_ALTA_PERSONAS - proceso independiente)
-- =============================================================================
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  MERGE INTO IT.BA_PROGRAMAS tgt
  USING (SELECT 'PAS_CF.PR_GENERAR' cod FROM DUAL) src
  ON (tgt.COD_PROGRAMA = src.cod)
  WHEN NOT MATCHED THEN
    INSERT (COD_PROGRAMA, DESCRIPCION, DES_DETALLADA, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, UBI_MENU)
    VALUES ('PAS_CF.PR_GENERAR', 'GENERA PADRON ALTA PERSONAS BCP',
            'GENERA ARCHIVO ALTA PERSONAS BCP', 4, 1, 'BASE DE DATOS', 'BASE DE DATOS', 'ARCHIVO CF BCP')
  WHEN MATCHED THEN
    UPDATE SET tgt.DESCRIPCION   = 'GENERA PADRON ALTA PERSONAS BCP',
               tgt.DES_DETALLADA = 'GENERA ARCHIVO ALTA PERSONAS BCP',
               tgt.UBI_MENU      = 'ARCHIVO CF BCP';

  MERGE INTO IT.GE_PROCESOS tgt
  USING (SELECT 'CF_ALTA_PERSONAS' descripcion FROM DUAL) src
  ON (tgt.DESCRIPCION = src.descripcion)
  WHEN NOT MATCHED THEN
    INSERT (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, COD_USUARIO, PERMISO)
    VALUES (314, 'CF_ALTA_PERSONAS', 1, 'N', 'N', USER,
            'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS o USUARIOHML-USUARIO HOMOLOGACION')
  WHEN MATCHED THEN
    UPDATE SET tgt.NRO_ORDEN   = 1,
               tgt.OBLIGATORIO = 'N',
               tgt.TIPO        = 'N',
               tgt.COD_USUARIO = USER,
               tgt.PERMISO     = 'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS o USUARIOHML-USUARIO HOMOLOGACION';

  MERGE INTO IT.GE_PROCESOS_DET tgt
  USING (
    SELECT 314 cod_proceso, 1 nro_orden, 'Generacion CF Alta Personas' descripcion,
           'PAS_CF.PR_GENERAR' cod_programa FROM DUAL
  ) src
  ON (tgt.COD_PROCESO = src.cod_proceso AND tgt.NRO_ORDEN = src.nro_orden)
  WHEN NOT MATCHED THEN
    INSERT (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, ACTIVO)
    VALUES (src.cod_proceso, src.nro_orden, src.descripcion, src.cod_programa, 'S', 'D', 'S')
  WHEN MATCHED THEN
    UPDATE SET tgt.DESCRIPCION  = src.descripcion,
               tgt.COD_PROGRAMA = src.cod_programa,
               tgt.OBLIGATORIO  = 'S',
               tgt.FRECUENCIA   = 'D',
               tgt.ACTIVO       = 'S';

  COMMIT;
END;
/
