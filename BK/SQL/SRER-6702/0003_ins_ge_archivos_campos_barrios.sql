-- =============================================================================
-- FIELDESK-164963: Configuracion GE_ARCHIVOS, GE_ARC_TABLAS, GE_ARC_CAMPOS
--                  y GE_PROCESOS para importacion BCP_BARRIOS
-- =============================================================================
SET SERVEROUTPUT ON;

DECLARE
  v_cod_proceso  NUMBER(10)   := 314;
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
      FROM IT.BA_PROGRAMAS WHERE COD_PROGRAMA = 'PRS_ACT_REF_BARRIOS';

    MERGE INTO IT.BA_PROGRAMAS tgt
    USING (SELECT 'PRS_ACT_REF_BARRIOS' cod FROM DUAL) src
    ON (tgt.COD_PROGRAMA = src.cod)
    WHEN NOT MATCHED THEN
      INSERT (COD_PROGRAMA, DESCRIPCION, DES_DETALLADA, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, UBI_MENU)
      VALUES ('PRS_ACT_REF_BARRIOS', 'ACTUALIZA REF_EXTERNA BA_BARRIOS DESDE BCP',
              'ACTUALIZA REF_EXTERNA BA_BARRIOS DESDE BCP', 4, 1, 'BASE DE DATOS', 'BASE DE DATOS', 'IMPORTACION BCP')
    WHEN MATCHED THEN
      UPDATE SET tgt.DESCRIPCION   = 'ACTUALIZA REF_EXTERNA BA_BARRIOS DESDE BCP',
                 tgt.DES_DETALLADA = 'ACTUALIZA REF_EXTERNA BA_BARRIOS DESDE BCP',
                 tgt.UBI_MENU      = 'IMPORTACION BCP';

    v_est_ba_prog := CASE v_existe WHEN 0 THEN 'Creado' ELSE 'No insertado - ya existe' END;
  EXCEPTION WHEN OTHERS THEN
    v_tiene_error := TRUE;
    v_est_ba_prog := 'No insertado - error: ' || SUBSTR(SQLERRM, 1, 170);
  END;

  -- -------------------------------------------------------------------------
  -- GE_ARCHIVOS
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO IT.GE_ARCHIVOS
      (REFERENCIA, ARCHIVO, NRO_SECUENCIA, SEPARADOR, LIN_INICIAL, UTI_LOADER, POS_PROCESO, PRE_PROCESO, DIRECT_PATH)
    SELECT 'BCP_BARRIOS', 'BARRIOS_BCP.CSV', '1', ';', 2, 'S', 'PRS_ACT_REF_BARRIOS', NULL, 'N'
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARCHIVOS WHERE REFERENCIA = 'BCP_BARRIOS');
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
    SELECT 'BCP_BARRIOS', 'SB_BCP_BAR_TMP', 'BARRIOS_BCP.CSV', 1, 'N'
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_TABLAS WHERE REFERENCIA = 'BCP_BARRIOS' AND NOM_TABLA = 'SB_BCP_BAR_TMP');
    v_est_ge_tab := CASE SQL%ROWCOUNT WHEN 1 THEN 'Creado' ELSE 'No insertado - ya existe' END;
  EXCEPTION WHEN OTHERS THEN
    v_tiene_error := TRUE;
    v_est_ge_tab := 'No insertado - error: ' || SUBSTR(SQLERRM, 1, 170);
  END;

  -- -------------------------------------------------------------------------
  -- GE_ARC_CAMPOS (7 campos)
  -- Col 1: Codigo Barrio       -> COD_BCP        NUMBER   7
  -- Col 2: Descripcion Barrio  -> DESCRIPCION    VARCHAR2 60
  -- Col 3: Codigo Ciudad       -> COD_CIUDAD_BCP VARCHAR2  4
  -- Col 4: Ciudad              -> DES_CIUDAD     VARCHAR2 60
  -- Col 5: Codigo Departamento -> COD_DEPTO_BCP  VARCHAR2  2
  -- Col 6: Departamento        -> DES_DEPARTAMENTO VARCHAR2 60
  -- Col 7: Tipo Zona           -> TIPO_ZONA      VARCHAR2 20
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'BCP_BARRIOS','SB_BCP_BAR_TMP','BARRIOS_BCP.CSV',1,'COD_BCP','Codigo BCP barrio',7,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='BCP_BARRIOS' AND NRO_SECUENCIA=1);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'BCP_BARRIOS','SB_BCP_BAR_TMP','BARRIOS_BCP.CSV',2,'DESCRIPCION','Descripcion barrio BCP',60,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='BCP_BARRIOS' AND NRO_SECUENCIA=2);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'BCP_BARRIOS','SB_BCP_BAR_TMP','BARRIOS_BCP.CSV',3,'COD_CIUDAD_BCP','Codigo ciudad BCP (zero-padded)',4,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='BCP_BARRIOS' AND NRO_SECUENCIA=3);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'BCP_BARRIOS','SB_BCP_BAR_TMP','BARRIOS_BCP.CSV',4,'DES_CIUDAD','Descripcion ciudad (informativo)',60,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='BCP_BARRIOS' AND NRO_SECUENCIA=4);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'BCP_BARRIOS','SB_BCP_BAR_TMP','BARRIOS_BCP.CSV',5,'COD_DEPTO_BCP','Codigo departamento BCP (zero-padded)',2,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='BCP_BARRIOS' AND NRO_SECUENCIA=5);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'BCP_BARRIOS','SB_BCP_BAR_TMP','BARRIOS_BCP.CSV',6,'DES_DEPARTAMENTO','Descripcion departamento (informativo)',60,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='BCP_BARRIOS' AND NRO_SECUENCIA=6);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'BCP_BARRIOS','SB_BCP_BAR_TMP','BARRIOS_BCP.CSV',7,'TIPO_ZONA','Tipo de zona (Urbana/Rural/Sub Urbana)',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='BCP_BARRIOS' AND NRO_SECUENCIA=7);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  -- -------------------------------------------------------------------------
  -- GE_PROCESOS
  -- BCP_CIUDADES tiene COD_PROCESO=313. Se busca el primer valor libre
  -- a partir de 314 (siguiente natural) dentro del rango de NUMBER(3).
  -- No se usa MAX+1 porque el maximo posible es 999 y ya esta ocupado.
  -- -------------------------------------------------------------------------
  BEGIN
    SELECT COUNT(*) INTO v_existe
      FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'BCP_BARRIOS';

    -- Calcular COD_PROCESO solo si vamos a hacer INSERT (WHEN MATCHED lo ignora)
    -- Busca el primer valor libre entre 314 y 999 (columna NUMBER(3))
    IF v_existe = 0 THEN
      SELECT NVL(MIN(t.candidate), NULL) INTO v_cod_proceso
        FROM (SELECT 314 + ROWNUM - 1 AS candidate
                FROM DUAL CONNECT BY ROWNUM <= 686) t
       WHERE t.candidate <= 999
         AND NOT EXISTS (
               SELECT 1 FROM IT.GE_PROCESOS WHERE COD_PROCESO = t.candidate);
    END IF;

    -- COD_USUARIO: tomado de BCP_CIUDADES (mismo ambiente) para evitar FK_GPROC_COD_USUARIO
    MERGE INTO IT.GE_PROCESOS tgt
    USING (SELECT 'BCP_BARRIOS' descripcion FROM DUAL) src
    ON (tgt.DESCRIPCION = src.descripcion)
    WHEN NOT MATCHED THEN
      INSERT (COD_PROCESO, DESCRIPCION, TIPO, NRO_ORDEN, COD_USUARIO, PERMISO)
      VALUES (v_cod_proceso, 'BCP_BARRIOS', 'P', 0,
              (SELECT COD_USUARIO FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'BCP_CIUDADES' AND ROWNUM = 1),
              'ADM. DE SISTEMAS-ADMINISTRADOR DE SISTEMAS o USUARIOHML-USUARIO HOMOLOGACION')
    WHEN MATCHED THEN
      UPDATE SET tgt.NRO_ORDEN   = 0,
                 tgt.TIPO        = 'P',
                 tgt.COD_USUARIO = (SELECT COD_USUARIO FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'BCP_CIUDADES' AND ROWNUM = 1),
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
  DBMS_OUTPUT.PUT_LINE('Resumen de ejecucion - BCP_BARRIOS');
  DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('BA_PROGRAMAS  | PRS_ACT_REF_BARRIOS    | ' || v_est_ba_prog);
  DBMS_OUTPUT.PUT_LINE('GE_ARCHIVOS   | BCP_BARRIOS            | ' || v_est_ge_arch);
  DBMS_OUTPUT.PUT_LINE('GE_ARC_TABLAS | BCP_BARRIOS            | ' || v_est_ge_tab);
  DBMS_OUTPUT.PUT_LINE('GE_ARC_CAMPOS | BCP_BARRIOS (7 campos) | Creados: ' || v_cnt_cam_cre || ' / Ya existian: ' || v_cnt_cam_exi || ' / Errores: ' || v_cnt_cam_err);
  DBMS_OUTPUT.PUT_LINE('GE_PROCESOS   | BCP_BARRIOS            | ' || v_est_ge_proc);
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
