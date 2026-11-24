-- =============================================================================
-- SRER-5499: GE_FILTROS (FEC_CF) + BA_PAR_CONSULTAS para CD_CF_ARC y CD_CF_EXCL
-- =============================================================================
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  -- GE_FILTROS: FEC_CF - campo de parametro para el dialogo WIN_PAR del proceso 315
  MERGE INTO IT.GE_FILTROS tgt
  USING (SELECT 'FEC_CF' COD_CAMPO FROM DUAL) src
  ON (tgt.COD_CAMPO = src.COD_CAMPO)
  WHEN NOT MATCHED THEN
    INSERT (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO,
            VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA,
            NRO_ORDEN, DET_SQL, TIPO, AFE_CONSULTAS, AFE_REPORTES,
            USU_INSERCION, FEC_INSERCION)
    VALUES ('FEC_CF', 'Fecha Cierre CF Alta', 'F', 10, 'R',
            NULL, NULL, NULL, 'FECHA',
            2, 'select to_char(fug_obt_fec_anterior(1),''DD/MM/YYYY'') from dual',
            'G', 'S', 'S',
            USER, SYSDATE)
  WHEN MATCHED THEN
    UPDATE SET tgt.DESCRIPCION   = 'Fecha Cierre CF Alta',
               tgt.TIP_CAMPO     = 'F',
               tgt.TIP_DATO      = 'R',
               tgt.NOM_REFERENCIA= 'FECHA',
               tgt.NRO_ORDEN     = 2,
               tgt.DET_SQL       = 'select to_char(fug_obt_fec_anterior(1),''DD/MM/YYYY'') from dual',
               tgt.TIPO          = 'G',
               tgt.AFE_CONSULTAS = 'S',
               tgt.AFE_REPORTES  = 'S';

  -- BA_PAR_CONSULTAS: enlace CD_CF_ARC -> FEC_CF
  MERGE INTO IT.BA_PAR_CONSULTAS tgt
  USING (SELECT 'CD_CF_ARC' COD_CONSULTA, 'FEC_CF' COD_CAMPO FROM DUAL) src
  ON (tgt.COD_CONSULTA = src.COD_CONSULTA AND tgt.COD_CAMPO = src.COD_CAMPO)
  WHEN NOT MATCHED THEN
    INSERT (COD_CONSULTA, COD_CAMPO, TIPO, NRO_ORDEN, OBLIGATORIO, TIP_VAL_DEFECTO, MODIFICABLE, VAL_DEFECTO)
    VALUES ('CD_CF_ARC', 'FEC_CF', 'F', 1, 'S', 'S', 'S',
            'select ''Igual_a ''||chr(39)||to_char(fug_obt_fec_anterior(1),''dd/mm/yyyy'')||chr(39) from dual')
  WHEN MATCHED THEN
    UPDATE SET TIPO='F', NRO_ORDEN=1, OBLIGATORIO='S', TIP_VAL_DEFECTO='S', MODIFICABLE='S',
               VAL_DEFECTO='select ''Igual_a ''||chr(39)||to_char(fug_obt_fec_anterior(1),''dd/mm/yyyy'')||chr(39) from dual';

  -- BA_PAR_CONSULTAS: enlace CD_CF_EXCL -> FEC_CF
  MERGE INTO IT.BA_PAR_CONSULTAS tgt
  USING (SELECT 'CD_CF_EXCL' COD_CONSULTA, 'FEC_CF' COD_CAMPO FROM DUAL) src
  ON (tgt.COD_CONSULTA = src.COD_CONSULTA AND tgt.COD_CAMPO = src.COD_CAMPO)
  WHEN NOT MATCHED THEN
    INSERT (COD_CONSULTA, COD_CAMPO, TIPO, NRO_ORDEN, OBLIGATORIO, TIP_VAL_DEFECTO, MODIFICABLE, VAL_DEFECTO)
    VALUES ('CD_CF_EXCL', 'FEC_CF', 'F', 1, 'S', 'S', 'S',
            'select ''Igual_a ''||chr(39)||to_char(fug_obt_fec_anterior(1),''dd/mm/yyyy'')||chr(39) from dual')
  WHEN MATCHED THEN
    UPDATE SET TIPO='F', NRO_ORDEN=1, OBLIGATORIO='S', TIP_VAL_DEFECTO='S', MODIFICABLE='S',
               VAL_DEFECTO='select ''Igual_a ''||chr(39)||to_char(fug_obt_fec_anterior(1),''dd/mm/yyyy'')||chr(39) from dual';

  COMMIT;
END;
/
