-- =============================================================================
-- Configuracion GE_ARCHIVOS, GE_ARC_TABLAS, GE_ARC_CAMPOS
--                  y GE_PROCESOS para importacion SOL_RUBROS
-- =============================================================================
SET SERVEROUTPUT ON;

DECLARE
  v_cod_proceso  NUMBER(10)   := 315;
  v_existe       NUMBER;
  v_tiene_error  BOOLEAN      := FALSE;
  -- Variables de resumen: inicializadas a 'error'; cada paso exitoso las sobreescribe
  v_est_ba_prog  VARCHAR2(200) := 'No insertado - error';
  v_est_ge_arch  VARCHAR2(200) := 'No insertado - error';
  v_est_ge_tab   VARCHAR2(200) := 'No insertado - error';
  v_cnt_cam_cre  NUMBER        := 0;
  v_cnt_cam_exi  NUMBER        := 0;
  v_cnt_cam_err  NUMBER        := 0;
  v_est_ge_proc  VARCHAR2(200) := 'No insertado - error';
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  -- -------------------------------------------------------------------------
  -- BA_PROGRAMAS (requerido antes de GE_ARCHIVOS por FK FK_EARCH_COD_PROGRAMA_POS)
  -- -------------------------------------------------------------------------
  BEGIN
    SELECT COUNT(*) INTO v_existe
      FROM IT.BA_PROGRAMAS WHERE COD_PROGRAMA = 'PRS_ACT_SOL_RUBROS';

    MERGE INTO IT.BA_PROGRAMAS tgt
    USING (SELECT 'PRS_ACT_SOL_RUBROS' cod FROM DUAL) src
    ON (tgt.COD_PROGRAMA = src.cod)
    WHEN NOT MATCHED THEN
      INSERT (COD_PROGRAMA, DESCRIPCION, DES_DETALLADA, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, UBI_MENU)
      VALUES ('PRS_ACT_SOL_RUBROS', 'ACTUALIZA RUBROS DE SOLVENCIA DESDE EXCEL',
              'ACTUALIZA RUBROS DE SOLVENCIA DESDE EXCEL', 4, 1, 'BASE DE DATOS', 'BASE DE DATOS', 'IMPORTACION SOLVENCIA')
    WHEN MATCHED THEN
      UPDATE SET tgt.DESCRIPCION   = 'ACTUALIZA RUBROS DE SOLVENCIA DESDE EXCEL',
                 tgt.DES_DETALLADA = 'ACTUALIZA RUBROS DE SOLVENCIA DESDE EXCEL',
                 tgt.UBI_MENU      = 'IMPORTACION SOLVENCIA';

    v_est_ba_prog := CASE v_existe WHEN 0 THEN 'Creado' ELSE 'No insertado - ya existe' END;
  EXCEPTION WHEN OTHERS THEN
    v_tiene_error := TRUE;
    v_est_ba_prog := 'No insertado - error: ' || SUBSTR(SQLERRM, 1, 170);
  END;

  -- -------------------------------------------------------------------------
  -- GE_ARCHIVOS
  -- UTI_LOADER=NULL: el archivo es XLSX (no pasa por SQL*Loader clasico)
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO IT.GE_ARCHIVOS
      (REFERENCIA, ARCHIVO, NRO_SECUENCIA, SEPARADOR, LIN_INICIAL, UTI_LOADER, POS_PROCESO, PRE_PROCESO, DIRECT_PATH)
    SELECT 'SOL_RUBROS', 'RUBROS_SOLVENCIA.XLSX', '1', ';', 6, NULL, 'PRS_ACT_SOL_RUBROS', NULL, 'N'
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARCHIVOS WHERE REFERENCIA = 'SOL_RUBROS');
    v_est_ge_arch := CASE SQL%ROWCOUNT WHEN 1 THEN 'Creado' ELSE 'No insertado - ya existe' END;
  EXCEPTION WHEN OTHERS THEN
    v_tiene_error := TRUE;
    v_est_ge_arch := 'No insertado - error: ' || SUBSTR(SQLERRM, 1, 170);
  END;

  -- -------------------------------------------------------------------------
  -- GE_ARC_TABLAS
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO IT.GE_ARC_TABLAS (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
    SELECT 'SOL_RUBROS', 'SB_SOL_RUBROS_TMP', 'RUBROS_SOLVENCIA.XLSX', 1, 'N'
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_TABLAS WHERE REFERENCIA = 'SOL_RUBROS' AND NOM_TABLA = 'SB_SOL_RUBROS_TMP');
    v_est_ge_tab := CASE SQL%ROWCOUNT WHEN 1 THEN 'Creado' ELSE 'No insertado - ya existe' END;
  EXCEPTION WHEN OTHERS THEN
    v_tiene_error := TRUE;
    v_est_ge_tab := 'No insertado - error: ' || SUBSTR(SQLERRM, 1, 170);
  END;

  -- -------------------------------------------------------------------------
  -- GE_ARC_CAMPOS (14 campos)
  -- Col  1: Tipo de reporte         -> REPORTE        VARCHAR2 50
  -- Col  2: Clasificacion           -> CLASIFICACION   VARCHAR2  1
  -- Col  3: Codigo rubro            -> RUBRO           VARCHAR2 15
  -- Col  4: Descripcion rubro       -> DESCRIPCION     VARCHAR2 100
  -- Col  5: Seccion del informe     -> SECCION         VARCHAR2 50
  -- Col  6: Pais                    -> PAIS            VARCHAR2 20
  -- Col  7: Ciudad                  -> CIUDAD          VARCHAR2 20
  -- Col  8: Codigo moneda ISO       -> COD_MONEDA      VARCHAR2  3
  -- Col  9: Ponderacion (%)         -> PONDERACION     NUMBER    3
  -- Col 10: Orden de presentacion   -> ORDEN           NUMBER    3
  -- Col 11: Categoria               -> CATEGORIA       NUMBER    1
  -- Col 12: Codigo rubro reporte    -> COD_RUBRO_RPT   VARCHAR2 15
  -- Col 13: Activo (S/null)         -> ACTIVO          VARCHAR2  1
  -- Col 14: Accion (reservado)      -> ACCION          VARCHAR2 20
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',1,'REPORTE','Tipo de reporte de solvencia',50,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=1);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',2,'CLASIFICACION','Clasificacion del rubro',1,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=2);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',3,'RUBRO','Codigo de rubro contable BCP',15,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=3);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',4,'DESCRIPCION','Descripcion del rubro',100,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=4);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',5,'SECCION','Seccion del informe de solvencia',50,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=5);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',6,'PAIS','Pais (rubros de Banco Exterior)',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=6);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',7,'CIUDAD','Ciudad (rubros de Banco Exterior)',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=7);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',8,'COD_MONEDA','Codigo de moneda ISO 4217',3,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=8);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',9,'PONDERACION','Ponderacion en porcentaje (0/20/50/100)',3,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=9);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',10,'ORDEN','Orden de presentacion en el informe',3,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=10);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',11,'CATEGORIA','Categoria del rubro (1-4)',1,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=11);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',12,'COD_RUBRO_RPT','Codigo de rubro del reporte de referencia',15,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=12);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',13,'ACTIVO','Indicador de activo (S=activo)',1,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=13);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_RUBROS','SB_SOL_RUBROS_TMP','RUBROS_SOLVENCIA.XLSX',14,'ACCION','Accion de carga (reservado)',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_RUBROS' AND NRO_SECUENCIA=14);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  -- -------------------------------------------------------------------------
  -- GE_PROCESOS
  -- Busca el primer valor libre a partir de 315 dentro del rango NUMBER(3)
  -- -------------------------------------------------------------------------
  BEGIN
    SELECT COUNT(*) INTO v_existe
      FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'SOL_RUBROS';

    IF v_existe = 0 THEN
      SELECT NVL(MIN(t.candidate), NULL) INTO v_cod_proceso
        FROM (SELECT 315 + ROWNUM - 1 AS candidate
                FROM DUAL CONNECT BY ROWNUM <= 685) t
       WHERE t.candidate <= 999
         AND NOT EXISTS (
               SELECT 1 FROM IT.GE_PROCESOS WHERE COD_PROCESO = t.candidate);
    END IF;

    MERGE INTO IT.GE_PROCESOS tgt
    USING (SELECT 'SOL_RUBROS' descripcion FROM DUAL) src
    ON (tgt.DESCRIPCION = src.descripcion)
    WHEN NOT MATCHED THEN
      INSERT (COD_PROCESO, DESCRIPCION, TIPO, NRO_ORDEN, COD_USUARIO, PERMISO)
      VALUES (v_cod_proceso, 'SOL_RUBROS', 'P', 0,
              (SELECT COD_USUARIO FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'BCP_BARRIOS' AND ROWNUM = 1),
              'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS o USUARIOHML-USUARIO HOMOLOGACION')
    WHEN MATCHED THEN
      UPDATE SET tgt.NRO_ORDEN   = 0,
                 tgt.TIPO        = 'P',
                 tgt.COD_USUARIO = (SELECT COD_USUARIO FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'BCP_BARRIOS' AND ROWNUM = 1),
                 tgt.PERMISO     = 'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS o USUARIOHML-USUARIO HOMOLOGACION';

    v_est_ge_proc := CASE v_existe
                       WHEN 0 THEN 'Creado (COD_PROCESO=' || v_cod_proceso || ')'
                       ELSE 'No insertado - ya existe'
                     END;
  EXCEPTION WHEN OTHERS THEN
    v_tiene_error := TRUE;
    v_est_ge_proc := 'No insertado - error: ' || SUBSTR(SQLERRM, 1, 170);
  END;

  -- -------------------------------------------------------------------------
  -- Commit o rollback segun si hubo errores
  -- -------------------------------------------------------------------------
  IF v_tiene_error OR v_cnt_cam_err > 0 THEN
    ROLLBACK;
  ELSE
    COMMIT;
  END IF;

  -- -------------------------------------------------------------------------
  -- Resumen
  -- -------------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('==============================================');
  DBMS_OUTPUT.PUT_LINE('Resumen de ejecucion - SOL_RUBROS');
  DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('BA_PROGRAMAS  | PRS_ACT_SOL_RUBROS      | ' || v_est_ba_prog);
  DBMS_OUTPUT.PUT_LINE('GE_ARCHIVOS   | SOL_RUBROS              | ' || v_est_ge_arch);
  DBMS_OUTPUT.PUT_LINE('GE_ARC_TABLAS | SOL_RUBROS              | ' || v_est_ge_tab);
  DBMS_OUTPUT.PUT_LINE('GE_ARC_CAMPOS | SOL_RUBROS (14 campos)  | Creados: ' || v_cnt_cam_cre || ' / Ya existian: ' || v_cnt_cam_exi || ' / Errores: ' || v_cnt_cam_err);
  DBMS_OUTPUT.PUT_LINE('GE_PROCESOS   | SOL_RUBROS              | ' || v_est_ge_proc);
  DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
  IF v_tiene_error OR v_cnt_cam_err > 0 THEN
    DBMS_OUTPUT.PUT_LINE('** RESULTADO: ROLLBACK - se revirtieron todos los cambios **');
  ELSE
    DBMS_OUTPUT.PUT_LINE('** RESULTADO: COMMIT - todos los cambios confirmados **');
  END IF;
  DBMS_OUTPUT.PUT_LINE('==============================================');
EXCEPTION WHEN OTHERS THEN
  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('** ERROR INESPERADO - ROLLBACK aplicado **');
  DBMS_OUTPUT.PUT_LINE(SUBSTR(SQLERRM, 1, 200));
END;
/
