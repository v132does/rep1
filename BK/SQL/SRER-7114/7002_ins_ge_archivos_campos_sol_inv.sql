-- =============================================================================
-- Configuracion GE_ARCHIVOS, GE_ARC_TABLAS, GE_ARC_CAMPOS
--                  y GE_PROCESOS para importacion SOL_INV
-- =============================================================================
SET SERVEROUTPUT ON;

DECLARE
  v_cod_proceso  NUMBER(10)   := 316;
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
      FROM IT.BA_PROGRAMAS WHERE COD_PROGRAMA = 'PRS_ACT_SOL_INV';

    MERGE INTO IT.BA_PROGRAMAS tgt
    USING (SELECT 'PRS_ACT_SOL_INV' cod FROM DUAL) src
    ON (tgt.COD_PROGRAMA = src.cod)
    WHEN NOT MATCHED THEN
      INSERT (COD_PROGRAMA, DESCRIPCION, DES_DETALLADA, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, UBI_MENU)
      VALUES ('PRS_ACT_SOL_INV', 'CARGA INVENTARIO COLOCACIONES SOLVENCIA',
              'CARGA INVENTARIO COLOCACIONES SOLVENCIA', 4, 1, 'BASE DE DATOS', 'BASE DE DATOS', 'IMPORTACION SOLVENCIA')
    WHEN MATCHED THEN
      UPDATE SET tgt.DESCRIPCION   = 'CARGA INVENTARIO COLOCACIONES SOLVENCIA',
                 tgt.DES_DETALLADA = 'CARGA INVENTARIO COLOCACIONES SOLVENCIA',
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
    SELECT 'SOL_INV', 'INVENTARIO_COLOCACIONES.XLSX', '1', ';', 2, NULL, 'PRS_ACT_SOL_INV', NULL, 'N'
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARCHIVOS WHERE REFERENCIA = 'SOL_INV');
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
    SELECT 'SOL_INV', 'SB_SOL_INV_TMP', 'INVENTARIO_COLOCACIONES.XLSX', 1, 'N'
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_TABLAS WHERE REFERENCIA = 'SOL_INV' AND NOM_TABLA = 'SB_SOL_INV_TMP');
    v_est_ge_tab := CASE SQL%ROWCOUNT WHEN 1 THEN 'Creado' ELSE 'No insertado - ya existe' END;
  EXCEPTION WHEN OTHERS THEN
    v_tiene_error := TRUE;
    v_est_ge_tab := 'No insertado - error: ' || SUBSTR(SQLERRM, 1, 170);
  END;

  -- -------------------------------------------------------------------------
  -- GE_ARC_CAMPOS (21 campos)
  -- Col  1: Fecha del inventario        -> FECHA             VARCHAR2 20
  -- Col  2: Tipo de deudor              -> TIP_DEUDOR        VARCHAR2 128
  -- Col  3: Numero de cuenta            -> NRO_CUENTA        NUMBER   10
  -- Col  4: Codigo de persona           -> COD_PERSONA       NUMBER   10
  -- Col  5: Numero de documento         -> NRO_DOCUMENTO     VARCHAR2 20
  -- Col  6: Nombre del cliente          -> NOMBRE            VARCHAR2 100
  -- Col  7: Codigo de modulo            -> COD_MODULO        NUMBER    5
  -- Col  8: Codigo de modalidad         -> COD_MODALIDAD     NUMBER    5
  -- Col  9: Descripcion de modalidad    -> MODAL             VARCHAR2 50
  -- Col 10: Codigo de oficina           -> COD_OFICINA       NUMBER    5
  -- Col 11: Descripcion de oficina      -> DESC_OFI          VARCHAR2 50
  -- Col 12: Codigo de moneda            -> COD_MONEDA        VARCHAR2  5
  -- Col 13: Tipo de saldo               -> TIP_SALDO         VARCHAR2  5
  -- Col 14: Situacion del credito       -> SITUACION         VARCHAR2 20
  -- Col 15: Estado del credito          -> ESTADO            VARCHAR2 20
  -- Col 16: Fecha de apertura           -> FEC_APERTURA      VARCHAR2 20
  -- Col 17: Fecha de vencimiento        -> FEC_VENCIMIENTO   VARCHAR2 20
  -- Col 18: Valor de tasa               -> VAL_TASA          VARCHAR2 20
  -- Col 19: Codigo de rubro BCP         -> COD_RUBRO         VARCHAR2 15
  -- Col 20: Descripcion de rubro        -> DES_RUBRO         VARCHAR2 100
  -- Col 21: Saldo actual                -> SAL_ACTUAL        NUMBER   20
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',1,'FECHA','Fecha del inventario',20,'DATE',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=1);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',2,'TIP_DEUDOR','Tipo de deudor',128,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=2);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',3,'NRO_CUENTA','Numero de cuenta',10,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=3);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',4,'COD_PERSONA','Codigo de persona en el sistema',10,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=4);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',5,'NRO_DOCUMENTO','Numero de documento de identidad',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=5);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',6,'NOMBRE','Nombre del cliente',100,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=6);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',7,'COD_MODULO','Codigo del modulo contable',5,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=7);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',8,'COD_MODALIDAD','Codigo de modalidad del credito',5,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=8);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',9,'MODAL','Descripcion de la modalidad',50,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=9);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',10,'COD_OFICINA','Codigo de oficina',5,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=10);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',11,'DESC_OFI','Descripcion de la oficina',50,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=11);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',12,'COD_MONEDA','Codigo de moneda (GS/USD)',5,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=12);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',13,'TIP_SALDO','Tipo de saldo',5,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=13);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',14,'SITUACION','Situacion del credito',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=14);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',15,'ESTADO','Estado del credito',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=15);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',16,'FEC_APERTURA','Fecha de apertura del credito',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=16);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',17,'FEC_VENCIMIENTO','Fecha de vencimiento del credito',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=17);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',18,'VAL_TASA','Valor de la tasa de interes',20,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=18);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',19,'COD_RUBRO','Codigo del rubro contable BCP',15,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=19);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',20,'DES_RUBRO','Descripcion del rubro contable',100,'VARCHAR2',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=20);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  BEGIN
    INSERT INTO IT.GE_ARC_CAMPOS (REFERENCIA,NOM_TABLA,ARCHIVO,NRO_SECUENCIA,CAMPO,DESCRIPCION,LONGITUD,TIP_DATO,POS_INICIAL,FORMATO,SALTAR)
    SELECT 'SOL_INV','SB_SOL_INV_TMP','INVENTARIO_COLOCACIONES.XLSX',21,'SAL_ACTUAL','Saldo actual de la operacion',20,'NUMBER',NULL,NULL,NULL FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA='SOL_INV' AND NRO_SECUENCIA=21);
    IF SQL%ROWCOUNT=1 THEN v_cnt_cam_cre:=v_cnt_cam_cre+1; ELSE v_cnt_cam_exi:=v_cnt_cam_exi+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_cnt_cam_err:=v_cnt_cam_err+1; END;

  -- -------------------------------------------------------------------------
  -- GE_PROCESOS
  -- Busca el primer valor libre a partir de 316 dentro del rango NUMBER(3)
  -- -------------------------------------------------------------------------
  BEGIN
    SELECT COUNT(*) INTO v_existe
      FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'SOL_INV';

    IF v_existe = 0 THEN
      SELECT NVL(MIN(t.candidate), NULL) INTO v_cod_proceso
        FROM (SELECT 316 + ROWNUM - 1 AS candidate
                FROM DUAL CONNECT BY ROWNUM <= 684) t
       WHERE t.candidate <= 999
         AND NOT EXISTS (
               SELECT 1 FROM IT.GE_PROCESOS WHERE COD_PROCESO = t.candidate);
    END IF;

    MERGE INTO IT.GE_PROCESOS tgt
    USING (SELECT 'SOL_INV' descripcion FROM DUAL) src
    ON (tgt.DESCRIPCION = src.descripcion)
    WHEN NOT MATCHED THEN
      INSERT (COD_PROCESO, DESCRIPCION, TIPO, NRO_ORDEN, COD_USUARIO, PERMISO)
      VALUES (v_cod_proceso, 'SOL_INV', 'P', 0,
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
  DBMS_OUTPUT.PUT_LINE('Resumen de ejecucion - SOL_INV');
  DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('BA_PROGRAMAS  | PRS_ACT_SOL_INV         | ' || v_est_ba_prog);
  DBMS_OUTPUT.PUT_LINE('GE_ARCHIVOS   | SOL_INV                 | ' || v_est_ge_arch);
  DBMS_OUTPUT.PUT_LINE('GE_ARC_TABLAS | SOL_INV                 | ' || v_est_ge_tab);
  DBMS_OUTPUT.PUT_LINE('GE_ARC_CAMPOS | SOL_INV (21 campos)     | Creados: ' || v_cnt_cam_cre || ' / Ya existian: ' || v_cnt_cam_exi || ' / Errores: ' || v_cnt_cam_err);
  DBMS_OUTPUT.PUT_LINE('GE_PROCESOS   | SOL_INV                 | ' || v_est_ge_proc);
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
