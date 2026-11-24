CREATE OR REPLACE PACKAGE BODY IT.PAS_LCR IS

/*======================================================================
  DESCRIPCIÓN GENERAL:
  Generación del informe LCR a partir de definiciones parametrizadas,
  ejecución de SQL dinámico, procesamiento de datos y exportación a CSV.

  ----------------------------------------------------------------------
  ÍNDICE DE COMPONENTES
  ----------------------------------------------------------------------
  [1] CONFIGURACIÓN
      - Constantes globales (directorio, separadores, formatos)
  [2] LIMPIEZA DE DATOS
      - PR_LIMPIAR_TMP : Limpia tabla temporal
      - PR_LIMPIAR_FINAL : Elimina datos previos del informe por fecha
  [3] PROCESAMIENTO DE DATOS
      - PR_EJECUTAR_SQL_ITEM : Ejecuta SQL dinámico y carga datos en TMP
      - PR_TMP_A_FINAL : Transfiere datos de TMP a tabla final
      - PR_INSERTA_ITEM_FINAL : Inserta los datos con SQL nulo como titulos
      - PR_GEN_DATOS : Generación de datos por jerarquía
      - PR_ASI_FUTUROS : Obtiene los asientos futuros
      - PR_ASI_AUTOMATICOS : Obtiene los asientos automáticos
      - PR_ACT_SALDOS : Actualiza los saldos del Balance
      - PR_SUM_SAL_OFICINAS : Actualiza el Balance por Oficinas
      - PR_SUM_SAL_CONSOLIDADOS : Actualiza el Balance Consolidado
      - PR_AJU_DIF_CAMBIOS : Realiza la valuación del Balance
      - PR_CAL_UTILIDAD : Calcula la Utilidad del Balance
      - PR_CON_BALANCE : Genera el Balance por Sucursal
      - PR_GEN_BALANCE : Proceso Principal que Genera el Balance Proyectado
  [4] GENERACIÓN DE INFORME
      - PR_GEN_INFORME : Genera archivo CSV con estructura jerárquica
  [5] PROCEDIMIENTO PRINCIPAL
      - PR_PRO_GEN_LCR : Ejecuta el flujo completo del proceso LCR
  ----------------------------------------------------------------------
  NOTAS:
  - El procesamiento se basa en estructura jerárquica (CONNECT BY)
  - La lógica de negocio está desacoplada mediante SQL parametrizado
  - El archivo generado se almacena en el servidor vía UTL_FILE
  ----------------------------------------------------------------------
======================================================================*/

  G_DIRECTORIO  CONSTANT VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_FTP');-- A COFIRMAR DIRECCION FTP
  G_SEPARADOR   CONSTANT VARCHAR2(1) := ',';
  --G_SALTO_LINEA CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);/*inicio de linea y salto de linea (solo en el caso que usemos)*/

---------------------------------------------------------------------------------
PROCEDURE PR_LIMPIAR_TMP IS
  BEGIN

    EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.SB_LCR_DATOS_TMP';

  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001,'Error al truncar SB_LCR_DATOS_TMP: ' || SQLERRM);

END PR_LIMPIAR_TMP;

---------------------------------------------------------------------------------
PROCEDURE PR_LIMPIAR_FINAL (P_FECHA_PROCESO IN DATE) IS
BEGIN

    IF P_FECHA_PROCESO IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Fecha de proceso requerida');
    END IF;

    DELETE FROM SB_LCR_INF_FINAL DEL
    WHERE DEL.FEC_PROCESO >= TRUNC(P_FECHA_PROCESO)
      AND DEL.FEC_PROCESO < TRUNC(P_FECHA_PROCESO) + 1;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR( -20011,'Error al limpiar SB_LCR_INF_FINAL: ' || SQLERRM);
END PR_LIMPIAR_FINAL;

---------------------------------------------------------------------------------
PROCEDURE PR_EJECUTAR_SQL_ITEM (
    p_sql CLOB,
    p_nro_item NUMBER,
    p_id_padre NUMBER,
    p_agrupador NUMBER,
    --p_orden NUMBER,
    p_porcentaje NUMBER,
    p_fecha_proceso DATE,
    p_id_bcp number,
    p_reporta varchar2,
    p_cotizacion number
) IS

    v_sql CLOB;
    v_concepto VARCHAR2(200);
    v_ml NUMBER;
    v_me NUMBER;
    v_total NUMBER;
    v_ml_p NUMBER;
    v_me_p NUMBER;
    v_total_p NUMBER;
    rc SYS_REFCURSOR;
    v_hay_datos BOOLEAN := FALSE;
    v_error varchar2(200);

BEGIN

    -- 1. VALIDAR SQL
    IF p_sql IS NULL THEN
        RETURN;
    END IF;

    -- 2. REEMPLAZAR PARÁMETROS
    v_sql := p_sql;

    v_sql := REPLACE(v_sql, '&'||'ANIO', TO_CHAR(EXTRACT(YEAR FROM p_fecha_proceso)));
    v_sql := REPLACE(v_sql, '&'||'MES', TO_CHAR(EXTRACT(MONTH FROM p_fecha_proceso)));
    v_sql := REPLACE(v_sql, '&'||'FECHA', '''' || TO_CHAR(p_fecha_proceso, 'DD/MM/YYYY') || '''');
    v_sql := REPLACE(v_sql, '&'||'VAL_COTIZACION', to_char(p_cotizacion,'99999.99999999'));

    -- 3. ABRIR CURSOR DINÁMICO
    OPEN rc FOR v_sql;

    LOOP
        FETCH rc INTO v_concepto, v_ml, v_me;
        EXIT WHEN rc%NOTFOUND;

        v_hay_datos := TRUE;
        v_ml := NVL (v_ml,0);
        v_me := NVL (v_me,0);

        v_error := null;

        -- 4. CALCULOS DE CONSOLIDADO Y PONDERACION DE SALDO DE ML Y ME

        v_total := NVL(v_ml,0) + NVL(v_me,0);

        v_ml_p := NVL(v_ml,0) * (NVL(p_porcentaje,0) / 100);
        v_me_p := NVL(v_me,0) * (NVL(p_porcentaje,0) / 100);

        v_total_p := v_total * (NVL(p_porcentaje,0) / 100);

        -- 5. INSERT EN TMP
        begin
            INSERT INTO SB_LCR_DATOS_TMP (
                nro_item,
                id_padre,
                grupo,
                sub_grupo,
                sal_mon_local,
                sal_extranjera,
                sal_total ,
                sal_ml_ponderado,
                sal_ext_ponderado,
                sal_tot_ponderado,
                id_bcp,
                reporta
            )
            VALUES (
                p_nro_item,
                p_id_padre,
                p_agrupador,
                v_concepto,
                v_ml,
                round((v_me / p_cotizacion),0),
                v_total,
                v_ml_p,
                v_me_p,
                v_total_p,
                p_id_bcp,
                p_reporta
            );
        EXCEPTION
          WHEN OTHERS THEN
            v_error := SUBSTR(SQLERRM, 1, 200);
            -- inserta el log --
            INSERT INTO sb_log_crc(fecha, nom_referencia, usu_insercion, fec_insercion, mensaje, nro_registro)
                           VALUES (p_fecha_proceso, 'INF_LCR', user, sysdate, 'Error al insertar en SB_LCR_DATOS_TMP, con ID_BCP: '||p_id_bcp||' Error: '||v_error,
                                   p_id_bcp);

            -- inserta el item con saldos en cero --
            INSERT INTO SB_LCR_DATOS_TMP(nro_item,id_padre,grupo,sub_grupo,sal_mon_local,sal_extranjera,sal_total,sal_ml_ponderado,sal_ext_ponderado,sal_tot_ponderado,id_bcp)
                                  VALUES(p_nro_item, p_id_padre, p_agrupador, 'SIN DATOS', 0, 0, 0, 0, 0, 0, p_id_bcp );
        END;

    END LOOP;

    CLOSE rc;
    /* SI NO HAY DATOS INSERTAR LA DESCRIPCION CON SALDOS EN 0*/
    IF NOT v_hay_datos THEN
      BEGIN
        INSERT INTO SB_LCR_DATOS_TMP (
            nro_item,
            id_padre,
            grupo,
            sub_grupo,
            sal_mon_local,
            sal_extranjera,
            sal_total,
            sal_ml_ponderado,
            sal_ext_ponderado,
            sal_tot_ponderado,
            id_bcp,
            reporta
        )
        VALUES (
            p_nro_item,
            p_id_padre,
            p_agrupador,
            'SIN DATOS',
            0,
            0,
            0,
            0,
            0,
            0,
            p_id_bcp,
            p_reporta
        );
      EXCEPTION
        WHEN OTHERS THEN
          v_error := SUBSTR(SQLERRM, 1, 200);
          INSERT INTO sb_log_crc(fecha, nom_referencia, usu_insercion, fec_insercion, mensaje, nro_registro)
                         VALUES (p_fecha_proceso, 'INF_LCR', user, sysdate, 'Error al insertar en SB_LCR_DATOS_TMP, con ID_BCP: '||p_id_bcp||' Error: '||v_error,
                                 p_id_bcp);
      END;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        IF rc%ISOPEN THEN
            CLOSE rc;
        END IF;

        --RAISE_APPLICATION_ERROR(-20020,'Error ejecutando SQL item ' || p_nro_item || ': ' || SQLERRM);

END PR_EJECUTAR_SQL_ITEM;

---------------------------------------------------------------------------------

PROCEDURE PR_TMP_A_FINAL (p_fecha_proceso IN DATE) IS

    v_reg SB_LCR_INF_FINAL%ROWTYPE;
    v_def SB_LCR_DEFINICIONES%ROWTYPE;
    v_error varchar2(200);

BEGIN

    FOR r IN (
              SELECT T.*
              FROM SB_LCR_DATOS_TMP T
              ) LOOP

      BEGIN
        v_error := null;

        -- Obtener definición (estructura del árbol)
        SELECT D.*
        INTO v_def
        FROM SB_LCR_DEFINICIONES D
        WHERE D.NRO_ITEM = r.NRO_ITEM;

        -- Cargar estructura
        v_reg.fec_proceso := p_fecha_proceso;
        v_reg.nro_item := v_def.nro_item;
        v_reg.id_padre := v_def.id_padre;
        v_reg.nro_agrupador := v_def.nro_agrupador;
        v_reg.nro_orden := v_def.nro_orden;
        v_reg.id_bcp := v_def.id_bcp;
        v_reg.reporta := v_def.reporta;

        -- Descripción jerárquica
        v_reg.grupo := v_def.desc_informe ;

        -- Detalle del SQL
        v_reg.sub_grupo := r.sub_grupo;

        -- Saldos
        v_reg.sal_guaranies := r.sal_mon_local;
        v_reg.sal_extranjera := r.sal_extranjera;
        v_reg.sal_total := r.sal_total;

        v_reg.sal_gua_ponderado := r.sal_ml_ponderado;
        v_reg.sal_ext_ponderado := r.sal_ext_ponderado;
        v_reg.sal_tot_ponderado := r.sal_tot_ponderado;

        -- Insert final
        INSERT INTO SB_LCR_INF_FINAL
        VALUES v_reg;

      EXCEPTION
          WHEN OTHERS THEN
            v_error := SUBSTR(SQLERRM, 1, 200);
            -- inserta el log de error --
            INSERT INTO sb_log_crc(fecha, nom_referencia, usu_insercion, fec_insercion, mensaje, nro_registro)
                           VALUES (p_fecha_proceso, 'INF_LCR', user, sysdate, 'Error al insertar en SB_LCR_INF_FINAL, ID BCP: '||v_def.id_bcp||' Error: '||v_error,
                                   v_def.id_bcp);

            -- inserta el item con saldos en cero --
            INSERT INTO SB_LCR_INF_FINAL(fec_proceso,nro_item,id_padre,nro_agrupador,nro_orden,grupo,sub_grupo, sal_guaranies,sal_extranjera,
                                         sal_gua_ponderado,sal_ext_ponderado,sal_total,sal_tot_ponderado,usu_insercion,fec_insercion,
                                         usu_modificacion,fec_modificacion,id_bcp)
                                  VALUES(p_fecha_proceso,v_def.nro_item, v_def.id_padre, v_def.nro_agrupador, v_def.nro_orden, v_def.desc_informe,
                                         'SIN DATOS', 0, 0, 0, 0, 0, 0, user, sysdate, user, sysdate, v_def.id_bcp );
      END;
    END LOOP;
END PR_TMP_A_FINAL;
---------------------------------------------------------------------------------

PROCEDURE PR_INSERTA_ITEM_FINAL (
    p_fecha_proceso IN DATE,
    p_nro_item IN NUMBER
) IS
    v_reg SB_LCR_INF_FINAL%ROWTYPE;
    v_def SB_LCR_DEFINICIONES%ROWTYPE;
    v_error varchar2(200);

BEGIN

    SELECT *
    INTO v_def
    FROM SB_LCR_DEFINICIONES
    WHERE nro_item = p_nro_item;

    v_reg.fec_proceso := p_fecha_proceso;
    v_reg.nro_item := v_def.nro_item;
    v_reg.id_padre := v_def.id_padre;
    v_reg.nro_agrupador := v_def.nro_agrupador;
    v_reg.nro_orden := v_def.nro_orden;
    v_reg.id_bcp := v_def.id_bcp;
    v_reg.reporta := v_def.reporta;

    v_reg.grupo := v_def.desc_informe ;
    v_reg.sub_grupo := v_def.desc_informe;

    v_reg.sal_guaranies := 0;
    v_reg.sal_extranjera := 0;
    v_reg.sal_total := 0;

    v_reg.sal_gua_ponderado := 0;
    v_reg.sal_ext_ponderado := 0;
    v_reg.sal_tot_ponderado := 0;

    v_reg.usu_insercion := USER;
    v_reg.fec_insercion := SYSDATE;
    v_reg.usu_modificacion := NULL;
    v_reg.fec_modificacion := NULL;

    INSERT INTO SB_LCR_INF_FINAL
    VALUES v_reg;

EXCEPTION
    WHEN OTHERS THEN
      v_error := SUBSTR(SQLERRM, 1, 200);
      -- inserta en log de errores --
      INSERT INTO sb_log_crc(fecha, nom_referencia, usu_insercion, fec_insercion, mensaje, nro_registro)
                     VALUES (p_fecha_proceso, 'INF_LCR', user, sysdate, 'Error al insertar en SB_LCR_INF_FINAL, ID BCP: '||v_def.id_bcp||' Error: '||v_error, v_def.id_bcp);

      -- inserta el item con saldos en cero --
      INSERT INTO SB_LCR_INF_FINAL(fec_proceso,nro_item,id_padre,nro_agrupador,nro_orden,grupo,sub_grupo, sal_guaranies,sal_extranjera,
                                   sal_gua_ponderado,sal_ext_ponderado,sal_total,sal_tot_ponderado,usu_insercion,fec_insercion,
                                   usu_modificacion,fec_modificacion,id_bcp)
                            VALUES(p_fecha_proceso,v_def.nro_item, v_def.id_padre, v_def.nro_agrupador, v_def.nro_orden, v_def.desc_informe,
                                   'SIN DATOS', 0, 0, 0, 0, 0, 0, user, sysdate, user, sysdate, v_def.id_bcp );

END PR_INSERTA_ITEM_FINAL;

---------------------------------------------------------------------------------

  /*PROCEDURE PR_SUBIR_FTP  () IS \*AGREGAR PARAMETROS*\
  BEGIN
    \* ULTILIZAR EL PROCESO DE FTP DE TASAS *\
    \*agregar al spec para la llamada por fuera*\

  EXCEPTION
    WHEN OTHERS THEN
      P_MENSAJE := 'Error al subir archivo al FTP: ' || SQLERRM;

  END PR_SUBIR_FTP;*/

---------------------------------------------------------------------------------
/*PROCESO QUE CARGA Y GENERACION DE DATOS LOS INFORMES*/
---------------------------------------------------------------------------------

PROCEDURE PR_GEN_DATOS (p_fecha_proceso IN DATE, p_bal_cerrado in varchar2 ) IS

    CURSOR c_def IS
        SELECT
            D.nro_item,
            D.id_padre,
            D.nro_agrupador,
            D.nro_orden,
            decode(p_bal_cerrado, 'S', D.Sql_Bal_Cerrado, D.SQL) AS QUERY,
            D.PORC_PONDERACION,
            D.ID_BCP,
            D.REPORTA,
            CONNECT_BY_ISLEAF nivel
        FROM sb_lcr_definiciones D
        START WITH D.id_padre IS NULL
        CONNECT BY PRIOR D.nro_item = D.id_padre
        ORDER SIBLINGS BY D.nro_orden;

    v_items_sin_sql varchar2(500);
    v_val_cotizacion GE_COTIZACIONES.VAL_CONVERSION%TYPE := FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,p_fecha_proceso);

BEGIN

    IF p_fecha_proceso IS NULL THEN
        RAISE_APPLICATION_ERROR(-20070, 'Fecha de proceso requerida');
    END IF;

    FOR r IN c_def LOOP
        -- 1. Limpiar TMP en cada iteración
        PR_LIMPIAR_TMP;

        -- 2. Ejecutar solo si tiene SQL
        IF r.QUERY IS NOT NULL THEN

            -- Ejecutar SQL dinámico (inserta en TMP)
            PR_EJECUTAR_SQL_ITEM(
                p_sql => r.QUERY,
                p_nro_item => r.nro_item,
                p_id_padre => r.id_padre,
                p_agrupador => r.nro_agrupador,
               -- p_orden => r.nro_orden,
                p_porcentaje => r.porc_ponderacion,
                p_fecha_proceso => p_fecha_proceso,
                p_id_bcp => r.id_bcp,
                p_reporta => r.reporta,
                p_cotizacion => v_val_cotizacion
            );

            -- 3. Pasar TMP A TABLA FINAL DE INFORME
            PR_TMP_A_FINAL(p_fecha_proceso);

        ELSE
            if r.nivel = 1 then
              if v_items_sin_sql is null then
                v_items_sin_sql := r.id_bcp;
              else
                v_items_sin_sql := v_items_sin_sql||' - '||r.id_bcp;
              end if;
            end if;

            PR_INSERTA_ITEM_FINAL( p_fecha_proceso => p_fecha_proceso, p_nro_item => r.nro_item  );
        END IF;
    END LOOP;

    -- Se informan los items que aun no tienen definidos un SQL de consulta de saldos --
    if v_items_sin_sql is not null then
        INSERT INTO sb_log_crc(fecha, nom_referencia, usu_insercion, fec_insercion, mensaje, nro_registro)
                       VALUES (p_fecha_proceso, 'INF_LCR', user, sysdate, 'Se informan los items que aun no tienen definidos un sql de consulta de saldos. ID BCP: '||v_items_sin_sql, 1);
    end if;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20071,'Error en el proceso PR_GEN_DATOS: ' || SQLERRM);

END PR_GEN_DATOS;

---------------------------------------------------------------------------------
/*PROCESO DE GENERACION DE INFORME*/
---------------------------------------------------------------------------------

PROCEDURE PR_GEN_INFORME (p_fecha_proceso IN DATE,p_nombre_archivo OUT VARCHAR2) IS

    v_file UTL_FILE.FILE_TYPE;
    v_nombre VARCHAR2(200);
    v_linea VARCHAR2(4000);

BEGIN

    -- Validacion
    IF p_fecha_proceso IS NULL THEN
        RAISE_APPLICATION_ERROR(-20100, 'Fecha de proceso requerida');
    END IF;

    -- Nombre de archivo
    v_nombre := 'LCR_' || TO_CHAR(p_fecha_proceso, 'YYYYMMDD') || '.csv';

    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(G_DIRECTORIO,v_nombre,'W',32767);
    -- Cabecera
    v_linea :=
          'ORDEN' || G_SEPARADOR ||
          'DESCRIPCION' || G_SEPARADOR ||
          'SALDO_GS' || G_SEPARADOR ||
          'SALDO_ME' || G_SEPARADOR ||
          'SALDO_TOTAL' || G_SEPARADOR ||
          'SALDO_GS_POND' || G_SEPARADOR ||
          'SALDO_ME_POND' || G_SEPARADOR ||
          'SALDO_TOTAL_POND';

    UTL_FILE.PUT_LINE(v_file, v_linea);
    -- Datos
    FOR r IN (
        SELECT
            LEVEL AS nivel,
            LTRIM(SYS_CONNECT_BY_PATH(Y.NRO_ORDEN, '.'), '.') AS orden_visual,
            -- arma el arbol visual
            LPAD(' ', (LEVEL - 1) * 3) ||
                NVL(Y.GRUPO, Y.SUB_GRUPO) AS descripcion,
            Y.sal_guaranies,
            Y.sal_extranjera,
            Y.sal_total,
            Y.sal_gua_ponderado,
            Y.sal_ext_ponderado,
            Y.sal_tot_ponderado
        FROM sb_lcr_inf_final Y
        WHERE Y.fec_proceso = p_fecha_proceso
        START WITH id_padre IS NULL
        CONNECT BY PRIOR Y.nro_item = Y.id_padre
               AND PRIOR Y.fec_proceso = Y.fec_proceso
        ORDER SIBLINGS BY Y.nro_orden
    ) LOOP

        v_linea :=
              r.orden_visual || G_SEPARADOR ||
              r.descripcion || G_SEPARADOR ||
              NVL(r.sal_guaranies, 0) || G_SEPARADOR ||
              NVL(r.sal_extranjera, 0) || G_SEPARADOR ||
              NVL(r.sal_total, 0) || G_SEPARADOR ||
              NVL(r.sal_gua_ponderado, 0) || G_SEPARADOR ||
              NVL(r.sal_ext_ponderado, 0) || G_SEPARADOR ||
              NVL(r.sal_tot_ponderado, 0);

        UTL_FILE.PUT_LINE(v_file, v_linea);

    END LOOP;

    -- Cerrar archivo
    UTL_FILE.FCLOSE(v_file);

    -- devolver nombre
    p_nombre_archivo := v_nombre;

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(v_file) THEN
            UTL_FILE.FCLOSE(v_file);
        END IF;

        RAISE_APPLICATION_ERROR(-20101,'Error en PR_GEN_INFORME: ' || SQLERRM);

END PR_GEN_INFORME;

---------------------------------------------------------------------------------
/*PROCESO PRINCIPAL*/
---------------------------------------------------------------------------------
PROCEDURE PR_PRO_GEN_LCR  IS

    v_fecha_proceso DATE;
    --v_archivo VARCHAR2(200);
    v_bal_cerrado varchar2(1) := 'N';
    v_registro    number(1);

BEGIN
    begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;

    -- Obtener fecha
    v_fecha_proceso := NVL(fug_obt_pardinamico('FEC_LCR'), pag_cal.fu_obt_fec_actual(2));

    -- Verificamos si contamos con balance cerrado el día del proceso --
    begin
      begin
        select 1 into v_registro from cb_sal_consolidados_dia d where d.fecha = v_fecha_proceso and rownum = 1;
      exception
        when others then
          v_registro := 0;
      end;

      if nvl(v_registro,0) = 1 then
        v_bal_cerrado := 'S';
      else
        v_bal_cerrado := 'N';
      end if;
    end;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.SB_LCR_LIQ_INV_TMP';
    
    -- Datos para Salida de Efectivo
    PR_CARGAR_SAL_EFE(v_fecha_proceso);

    -- Si no tenemos el balance cerrado, generamos bal. proyectado
    if nvl(v_bal_cerrado,'N') = 'N' then
      -- Datos liquides
      PR_CARGAR_LIQ_INV_TMP(v_fecha_proceso);

      -- Balance Proyectado
      PR_GEN_BALANCE(v_fecha_proceso);
    end if;

    -- Limpiar información previa
    PR_LIMPIAR_FINAL(v_fecha_proceso);

    -- Generar datos
    PR_GEN_DATOS(v_fecha_proceso, v_bal_cerrado);

    PR_TOTALIZA_SALDOS_LCR(v_fecha_proceso);

    PR_CALCULA_ITEMS_LCR(v_fecha_proceso);

    -- Generar archivo
  --  PR_GEN_INFORME(v_fecha_proceso,v_archivo);

    -- FTP
    /*
    PR_SUBIR_FTP( );
    */

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20201,'Error en PR_PRO_GEN_LCR: ' || SQLERRM);

END PR_PRO_GEN_LCR;

---------------------------------------------------------------------------------
/*PROCEDIMIENTO QUE EJECUTA ARCHIVO DE LIQUIDEZ*/
---------------------------------------------------------------------------------
PROCEDURE PR_CARGAR_LIQ_INV_TMP (p_fecha_proceso IN DATE) IS

v_fec_proceso ge_calendarios.fec_actual%TYPE := p_fecha_proceso;
v_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
v_mon_fuerte  ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;

BEGIN

    IF v_fec_proceso IS NULL THEN
        RAISE_APPLICATION_ERROR(-20300, 'Fecha de proceso requerida');
    END IF;

    IF v_mon_local IS NULL THEN
        RAISE_APPLICATION_ERROR(-20301, 'Moneda local requerida');
    END IF;

    IF v_mon_fuerte IS NULL THEN
        RAISE_APPLICATION_ERROR(-20302, 'Moneda extranjera requerida');
    END IF;

    INSERT /*+ APPEND */ INTO IT.SB_LCR_LIQ_INV_TMP
    (MONEDA,COD_RUBRO,NRO_CUENTA,PLAZO,MONTO)
    --PRESTAMOS (solo capital por cuotas) --
    select x.moneda, x.cuentas, x.cuenta, x.plazo, x.monto
    from (      
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             (CASE
               WHEN cuentas like '16%' THEN
                '10'
               WHEN dias <= 0 OR dias = 1 THEN
                '11'
               WHEN dias = 2 THEN
                '12'
               WHEN dias = 3 THEN
                '13'
               WHEN dias = 4 THEN
                '14'
               WHEN dias = 5 THEN
                '15'
               WHEN dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) and
                            c.cod_modalidad not in (670, 671) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             pc.sal_capital)
                       WHEN c.cod_moneda IN (v_mon_local, v_mon_fuerte) and
                            c.cod_modalidad not in (670, 671) THEN
                        pc.sal_capital
                       WHEN c.cod_moneda IN (v_mon_local, v_mon_fuerte) and
                            c.cod_modalidad in (670, 671) THEN
                        nvl(pc.sal_capital, 0) + nvl(pc.sal_interes, 0) +
                        nvl(pc.sal_int_documentado, 0)
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            pc.sal_capital,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            pc.sal_capital) monto_gs,
                     d.nro_cuenta cuenta,
                     (CASE
                       WHEN pr.cod_modalidad IN (675, 677) THEN
                        1
                       ELSE
                        (nvl(pc.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     END) dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_cta_prestamos           pr,
                     pr_cuotas                  pc
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 6
                 AND c.tip_saldo IN ('C', 'F') -- Capital
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P'
                 AND nvl(d.sal_actual, 0) != 0
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = pr.nro_cuenta
                 AND pr.nro_cuenta = pc.nro_cuenta
                 AND pc.nro_cuota > 0
                 AND pc.estado != 'N') v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN cuentas like '16%' THEN
                   '10'
                  WHEN dias <= 0 OR dias = 1 THEN
                   '11'
                  WHEN dias = 2 THEN
                   '12'
                  WHEN dias = 3 THEN
                   '13'
                  WHEN dias = 4 THEN
                   '14'
                  WHEN dias = 5 THEN
                   '15'
                  WHEN dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --PRESTAMOS ( solo Interes Devengado no cobrado por cuota ) --
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             (CASE
               WHEN cuentas like '16%' THEN
                '10'
               WHEN v.dias in (0, 1) THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       ELSE
                        d.sal_actual
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta,
                     (CASE
                       WHEN pr.cod_modalidad IN (675, 677) THEN
                        1
                       WHEN pr.fec_vencimiento < v_fec_proceso THEN
                        v_fec_proceso - pr.fec_vencimiento
                       ELSE
                        (nvl(pr.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     END) dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_cta_prestamos           pr
               WHERE d.fecha = v_fec_proceso
                 AND d.nro_referencia = c.nro_referencia
                 AND d.fecha = c.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 6
                 AND c.tip_saldo IN ('A', 'I') -- Interes a Cobrar.
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = pr.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN cuentas like '16%' THEN
                   '10'
                  WHEN v.dias in (0, 1) THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION
      --- PREVISIONES DE PRESTAMOS
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             (CASE
               WHEN cuentas like '16%' THEN
                '10'
               WHEN dias <= 0 OR dias = 1 THEN
                '11'
               WHEN dias = 2 THEN
                '12'
               WHEN dias = 3 THEN
                '13'
               WHEN dias = 4 THEN
                '14'
               WHEN dias = 5 THEN
                '15'
               WHEN dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            'GS',
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     ((CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             'USD',
                                             d.sal_actual)
                       ELSE
                        d.sal_actual
                     END)) monto,
                     (decode(c.cod_moneda,
                             v_mon_local,
                             d.sal_actual,
                             pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                       v_fec_proceso) *
                             d.sal_actual)) monto_gs,
                     d.nro_cuenta cuenta,
                     (CASE
                       WHEN pr.cod_modalidad IN (675, 677) THEN
                        1
                       ELSE
                        (nvl(pr.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     END) dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_cta_prestamos           pr
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 6
                 AND c.tip_saldo = 'V' -- Previsiones
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P'
                 AND nvl(d.sal_actual, 0) != 0
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = pr.nro_cuenta
                 AND pr.estado != 'N') v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN cuentas like '16%' THEN
                   '10'
                  WHEN dias <= 0 OR dias = 1 THEN
                   '11'
                  WHEN dias = 2 THEN
                   '12'
                  WHEN dias = 3 THEN
                   '13'
                  WHEN dias = 4 THEN
                   '14'
                  WHEN dias = 5 THEN
                   '15'
                  WHEN dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --- Previsiones diferidas
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             NVL((CASE
                   WHEN dias <= 0 then
                    '10'
                   WHEN dias = 1 THEN
                    '11'
                   WHEN dias = 2 THEN
                    '12'
                   WHEN dias = 3 THEN
                    '13'
                   WHEN dias = 4 THEN
                    '14'
                   WHEN dias = 5 THEN
                    '15'
                   WHEN dias BETWEEN 6 AND 15 THEN
                    '20'
                   WHEN dias BETWEEN 16 AND 30 THEN
                    '30'
                   WHEN dias BETWEEN 31 AND 60 THEN
                    '40'
                   WHEN dias BETWEEN 61 AND 90 THEN
                    '50'
                   WHEN dias BETWEEN 91 AND 180 THEN
                    '60'
                   WHEN dias BETWEEN 181 AND 365 THEN
                    '70'
                   WHEN dias > 365 THEN
                    '80'
                 END),
                 '10') plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            'GS',
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in ('GS', 'USD') then
                        decode(substr(r.cod_rub_padre, 9, 2),
                               '99',
                               FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                                    'USD',
                                                    d.sal_actual * -1),
                               FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                                    'USD',
                                                    d.sal_actual))
                       else
                        decode(substr(r.cod_rub_padre, 9, 2),
                               '99',
                               d.sal_actual * -1,
                               d.sal_actual)
                     end) monto,
                     d.nro_cuenta cuenta,
                     (case
                       when pr.cod_modalidad in (675, 677) then
                        1
                       else
                        (nvl(pr.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     end) dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     pr_cta_prestamos           pr,
                     cb_rubros                  r,
                     ba_monedas                 m
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 and c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 and d.nro_cuenta = pr.nro_cuenta
                 AND c.cod_modulo = 6
                 AND c.tip_saldo = 'O') v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN dias <= 0 then
                   '10'
                  WHEN dias = 1 THEN
                   '11'
                  WHEN dias = 2 THEN
                   '12'
                  WHEN dias = 3 THEN
                   '13'
                  WHEN dias = 4 THEN
                   '14'
                  WHEN dias = 5 THEN
                   '15'
                  WHEN dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --CTA.CTE--
      SELECT v.moneda,
             v.cuentas cuentas,
             v.cuenta,
             '10' plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       else
                        d.sal_actual
                     end) monto,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 4
                 AND c.cod_modalidad = 41
                 AND c.tip_saldo in ('C', 'T', 'V')
                 AND nvl(d.sal_actual, 0) != 0
                    --AND substr(r.cod_rub_padre,1,2) <> '16'
                 AND c.cod_rubro IS NOT NULL
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P') v
       GROUP BY v.moneda, v.cuentas, v.cuenta
      UNION ALL
      --AHORRO
      SELECT v.moneda, v.cuentas, v.cuenta, v.plazo,nvl(SUM(v.monto),0) monto
        FROM (SELECT decode(c.cod_moneda, v_mon_local, m.cod_mon_bco_central,'6100') moneda,
                decode(substr(r.cod_rub_padre, 1, 5), '22010', rpad(to_char(r.cod_rub_padre), 10, '0') ,
                        decode(substr(r.cod_rub_padre, 1, 5), '14010', rpad(to_char(r.cod_rub_padre), 10, '0') ,
                        decode(substr(r.cod_rub_padre, 1, 10), '12010123060', '12010123006',
                        decode(substr(r.cod_rub_padre, 1, 10), '12010123080', '12010123008',
                        rpad(to_char(r.cod_rub_padre), 10, '0') ))))  cuentas,
                         '10' plazo,
                         (case when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                               FUB_CON_MON_A_MONEDA(c.cod_moneda,v_mon_fuerte,
                                                    (case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end))
                          else (case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end) end) monto,
                         d.nro_cuenta cuenta
           FROM cb_sal_inventarios_det_his     d,
                cb_sal_inventarios_his         c,
                cb_rubros                  r,
                ba_monedas                 m,
                ge_clientes                g,
                ge_cta_clientes            ge
          WHERE d.fecha = v_fec_proceso
                    AND c.nro_referencia = d.nro_referencia
                    AND c.fecha=d.fecha
            AND c.cod_rubro = r.cod_rubro
            AND c.cod_moneda = m.cod_moneda
            AND c.cod_modulo = 3
            AND c.cod_modalidad in (31,334)
            AND c.tip_saldo not in ('R','P')
            AND nvl(d.sal_actual, 0) != 0
            AND c.cod_rubro IS NOT NULL
            AND ge.nro_cuenta = d.nro_cuenta
            AND g.cod_persona = ge.cod_persona
            AND ge.relacion = 'P') v
  GROUP BY v.moneda, v.cuentas, v.cuenta, v.plazo
      UNION
      --OPERACIONES VENCIDAS.
      SELECT v.moneda, v.cuentas, v.cuenta, v.plazo, nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     '10' plazo,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       ELSE
                        d.sal_actual
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m
               WHERE d.fecha = v_fec_proceso
                 AND d.nro_referencia = c.nro_referencia
                 AND d.fecha = c.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 15
                 AND c.tip_saldo = 'C'
                 AND nvl(d.sal_actual, 0) != 0
                 AND c.cod_rubro IS NOT NULL) v
       GROUP BY v.moneda, v.cuentas, v.cuenta, v.plazo
      UNION
      --C.D.A
      SELECT v.moneda,
             v.cuentas cuentas,
             v.cuenta,
             (CASE
               WHEN decode(a.est_batch,
                           'B',
                           decode(a.est_cer_batch, 'V', 'V', 'N'),
                           decode(a.est_batch, 'P', 'V', a.est_batch)) = 'V' THEN
                '10'
               WHEN a.fec_vencimiento - v_fec_proceso = 1 THEN
                '11'
               WHEN a.fec_vencimiento - v_fec_proceso = 2 THEN
                '12'
               WHEN a.fec_vencimiento - v_fec_proceso = 3 THEN
                '13'
               WHEN a.fec_vencimiento - v_fec_proceso = 4 THEN
                '14'
               WHEN a.fec_vencimiento - v_fec_proceso = 5 THEN
                '15'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 6 AND 15 THEN
                '20'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 16 AND 30 THEN
                '30'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 31 AND 60 THEN
                '40'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 61 AND 90 THEN
                '50'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 91 AND 180 THEN
                '60'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 181 AND 365 THEN
                '70'
               WHEN a.fec_vencimiento - v_fec_proceso > 365 THEN
                '80'
             END) plazo,
             SUM(v.monto) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       ELSE
                        d.sal_actual
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE d.fecha = v_fec_proceso
                 AND d.nro_referencia = c.nro_referencia
                 AND d.fecha = c.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 3
                 AND c.cod_modalidad NOT IN (31, 36, 38, 39, 334)
                 AND c.tip_saldo IN ('C', 'T', 'I', 'A')
                 AND c.situacion NOT IN ('V', 'P') --Vencido - Pend.Cancelacion
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN decode(a.est_batch,
                              'B',
                              decode(a.est_cer_batch, 'V', 'V', 'N'),
                              decode(a.est_batch, 'P', 'V', a.est_batch)) = 'V' THEN
                   '10'
                  WHEN a.fec_vencimiento - v_fec_proceso = 1 THEN
                   '11'
                  WHEN a.fec_vencimiento - v_fec_proceso = 2 THEN
                   '12'
                  WHEN a.fec_vencimiento - v_fec_proceso = 3 THEN
                   '13'
                  WHEN a.fec_vencimiento - v_fec_proceso = 4 THEN
                   '14'
                  WHEN a.fec_vencimiento - v_fec_proceso = 5 THEN
                   '15'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN a.fec_vencimiento - v_fec_proceso > 365 THEN
                   '80'
                END)
      UNION
      --CDA VENCIDOS
      SELECT v.moneda, v.cuentas cuentas, v.cuenta, '10' plazo, SUM(v.monto) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       ELSE
                        d.sal_actual
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE d.fecha = v_fec_proceso
                 AND d.nro_referencia = c.nro_referencia
                 AND d.fecha = c.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 3
                 AND c.cod_modalidad NOT IN (31, 36, 38, 39, 334)
                 AND c.tip_saldo IN ('C', 'T')
                 AND c.situacion IN ('V', 'P') --Vencido - Pend.Cancelacion
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
       GROUP BY v.moneda, v.cuentas, v.cuenta, '10'
      UNION ALL
      --PIGNORACION.
      SELECT v.moneda,
             v.cuentas cuentas,
             v.cuenta,
             NVL((CASE
                   WHEN v.dias <= 0 THEN
                    '10'
                   WHEN v.dias = 1 THEN
                    '11'
                   WHEN v.dias = 2 THEN
                    '12'
                   WHEN v.dias = 3 THEN
                    '13'
                   WHEN v.dias = 4 THEN
                    '14'
                   WHEN v.dias = 5 THEN
                    '15'
                   WHEN v.dias BETWEEN 6 AND 15 THEN
                    '20'
                   WHEN v.dias BETWEEN 16 AND 30 THEN
                    '30'
                   WHEN v.dias BETWEEN 31 AND 60 THEN
                    '40'
                   WHEN v.dias BETWEEN 61 AND 90 THEN
                    '50'
                   WHEN v.dias BETWEEN 91 AND 180 THEN
                    '60'
                   WHEN v.dias BETWEEN 181 AND 365 THEN
                    '70'
                   WHEN v.dias > 365 THEN
                    '80'
                 END),
                 '10') plazo,
             SUM(v.monto) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       else
                        d.sal_actual
                     end) monto,
                     d.nro_cuenta cuenta,
                     p.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_gar_cash                P
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo in (3, 4) --Ahorros y Cta.Cte
                 AND c.cod_modalidad in (31, 41, 334)
                 AND c.tip_saldo = 'P'
                 AND nvl(d.sal_actual, 0) != 0
                    --and substr(r.cod_rub_padre,1,2) <> '16' -- Vencidas No se informa
                 AND c.cod_rubro IS NOT NULL
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P'
                 AND d.nro_cuenta = p.nro_cta_referencia) v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --- MESA DE DINERO
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             (CASE
               WHEN v.dias <= 0 THEN
                '10'
               WHEN v.dias = 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'A' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'A' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     d.nro_cuenta cuenta,
                     a.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     md_cta_documentos          a
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modalidad in (112, 117, 118, 144, 126, 101, 145)
                 AND c.tip_saldo in ('C', 'A', 'I') -- Capital, A devengar e Interés
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --- AHORRO PROGRAMADO
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             (CASE
               WHEN v.dias <= 0 THEN
                '10'
               WHEN v.dias = 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END)     plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             sal_actual)
                       else
                        sal_actual
                     end) monto,
                     d.nro_cuenta cuenta,
                     a.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     ah_cta_plazos          a
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.tip_saldo in ('C') -- Capital
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION ALL
       --BONOS SUBORDINADOS
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             (CASE
               WHEN v.dias <= 0 THEN
                '10'
               WHEN v.dias = 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END)     plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             sal_actual)
                       else
                        sal_actual
                     end) monto,
                     d.nro_cuenta cuenta,
                     a.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     ah_cta_certificados         a
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND instr(fug_obt_pardinamico('MAD_BON_SUBORDINADOS'), a.cod_modalidad || ',') >0
                 AND c.tip_saldo in ('C') -- Capital
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)

      UNION ALL
      --- Tarjetas
      SELECT v.moneda,
             v.cuentas,
             v.cuenta,
             (CASE
               WHEN v.dias <= 0 THEN
                '10'
               WHEN v.dias = 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            'GS',
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'V' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'V' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     d.nro_cuenta cuenta,
                     decode(nvl(a.dia_mora, 0),
                            0,
                            a.fec_vct_ult_cierre,
                            pag_cal.fu_obt_fec_actual(2) - a.dia_mora - 1) -
                     v_fec_proceso dias
                FROM cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     ta_cta_tarjetas            a
               WHERE d.fecha = v_fec_proceso
                 AND c.nro_referencia = d.nro_referencia
                 AND c.fecha = d.fecha
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.tip_saldo in ('C', 'V') -- Capital y previsiones
                 and substr(r.cod_rub_padre, 1, 2) <> '25' -- Previsiones no se informa
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                v.cuenta,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)) x ;
      /*where x.cuentas like '14010%' or x.cuentas like '14080%' or x.cuentas like '13010%' or x.cuentas like '13080%' or
            x.cuentas like '21010306%' or x.cuentas like '21040%' or x.cuentas like '21080%' or x.cuentas like '21010102%';*/

COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20303, 'Error en PR_CARGAR_LIQ_INV_TMP: ' || SQLERRM);

END PR_CARGAR_LIQ_INV_TMP;

---------------------------------------------------------------------------------
/*CONJUNTO DE PROCEDIMIENTOS QUE GENERAN EL BALANCE PROYECTADO*/
---------------------------------------------------------------------------------

/* Obtiene los asientos futuros */
PROCEDURE PR_ASI_FUTUROS(p_fecha in ge_calendarios.fec_actual%type) is
   -- Variables.
   v_fec_actual     date        := p_fecha;
   v_fec_mes        date        := p_fecha;
   v_nro_asiento    number;
   v_procesar       varchar2(1) := 'N';
   -- Cursores.
   CURSOR asi IS
      SELECT COD_OFICINA, NRO_ASIENTO, COD_CARGO, FECHA, ROWID FILA
        FROM CB_ASI_FUTUROS
       WHERE FECHA <= v_fec_mes
         AND nro_asi_real IS NULL;
begin
   pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
   -- Obtengo la fecha del último día del mes.
   /*BEGIN
      SELECT last_day(v_fec_actual)
        INTO v_fec_mes
        FROM dual;
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_mes := p_fecha;
   END;*/
   -- Obtengo el número de asiento.
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_REF_BALANCE');
   FOR a in asi LOOP
     -- inserto la cabecera
     insert into cb_sim_asientos
           (cod_oficina, nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fec_valor, nro_asi_futuro, cod_cargo)
     select cod_oficina, v_nro_asiento, cod_usuario, v_fec_actual,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fecha, nro_asiento, cod_cargo
       from cb_asi_futuros
      where cod_oficina  = a.cod_oficina
        and nro_asiento  = a.nro_asiento
        and nro_asi_real is null
        and fecha        = a.fecha;

     -- inserto los detalles de los asientos
     insert into cb_sim_asientos_det
           (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fec_valor)
     select v_fec_actual, cod_oficina, v_nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fecha
       from cb_asi_futuros_det
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and fecha       = a.fecha;

     -- incrementa numero de asiento
     v_nro_asiento := v_nro_asiento + 1;
     v_procesar := 'S';
   END LOOP;
   ------- ACTUALIZA PARAMETROS -----
   if v_procesar = 'S' then
      prg_act_par_dinamico('SIG_NRO_REF_BALANCE',null, null, null, null, v_nro_asiento);
   end if;
end PR_ASI_FUTUROS;

/* Obtiene los asientos automaticos */
PROCEDURE PR_ASI_AUTOMATICOS(p_fecha in ge_calendarios.fec_actual%type) is
   -- Variables.
   v_fec_actual     date        := p_fecha;
   v_fec_mes        date        := p_fecha;
   v_nro_asiento    number;
   v_procesar       varchar2(1) := 'N';
   -- Cursores.
   CURSOR asi IS
      select ac.cod_oficina, ac.nro_asiento, ac.fecha, rowid fila
      from cb_asi_automaticos ac
      where ac.fecha <= v_fec_mes
        and ac.nro_asi_real is null;
begin
   pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
   -- Obtengo la fecha del último día del mes.
  /* BEGIN
      SELECT last_day(v_fec_actual)
        INTO v_fec_mes
        FROM dual;
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_mes := p_fecha;
   END;*/
   -- Obtengo el número de asiento.
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_REF_BALANCE');

   FOR a in asi LOOP
     -- inserto la cabecera
     insert into cb_sim_asientos
           (cod_oficina, nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fec_valor, nro_asi_futuro, cod_cargo)
      select ac.cod_oficina, v_nro_asiento, ac.cod_usuario, v_fec_actual,
             ac.cod_modulo, ac.cod_modalidad, ac.tot_control, ac.actualizado,
             ac.reversado, ac.cod_ofi_origen, ac.ofi_integrada, ac.confirmado,
             ac.fecha, ac.nro_asiento, null
      from cb_asi_automaticos ac
      where ac.fecha       = a.fecha
        and ac.cod_oficina = a.cod_oficina
        and ac.nro_asiento = a.nro_asiento
        and ac.nro_asi_real is null;

     -- inserto los detalles de los asientos
     insert into cb_sim_asientos_det
           (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fec_valor)
      select v_fec_actual, ad.cod_oficina, v_nro_asiento, ad.nro_linea, ad.cod_rubro, ad.tip_movimiento,
             ad.mto_mon_rubro, ad.mto_mon_local, ad.descripcion, ad.referencia,
             ad.protegido, ad.actualizado, ad.val_cotizacion, ad.distribuido,
             ad.ref_movimiento, ad.fecha
      from cb_asi_automaticos_det ad
      where ad.cod_oficina = a.cod_oficina
        and ad.nro_asiento = a.nro_asiento
        and ad.fecha       = a.fecha;

     -- incrementa numero de asiento
     v_nro_asiento := v_nro_asiento + 1;
     v_procesar := 'S';
   END LOOP;
   ------- ACTUALIZA PARAMETROS -----
   if v_procesar = 'S' then
      prg_act_par_dinamico('SIG_NRO_REF_BALANCE',null, null, null, null, v_nro_asiento);
   end if;
end PR_ASI_AUTOMATICOS;

/* Actualiza los saldos del Balance */
PROCEDURE PR_ACT_SALDOS(p_fecha in ge_calendarios.fec_actual%type)
IS
  -- Cursores.
  CURSOR SALD_M IS
         SELECT CB_SIM_ASIENTOS.COD_OFICINA, CB_SIM_ASIENTOS_DET.COD_RUBRO,
                CB_SIM_ASIENTOS_DET.TIP_MOVIMIENTO, BA_OFICINAS.DESCRIPCION,
                SUM(NVL(CB_SIM_ASIENTOS_DET.MTO_MON_LOCAL,0)),
                SUM(NVL(CB_SIM_ASIENTOS_DET.MTO_MON_RUBRO,0)),
                decode(substr(cb_rubros.cod_rubro,14,2),'98','USD',CB_RUBROS.COD_MONEDA)
           FROM CB_RUBROS, CB_SIM_ASIENTOS, CB_SIM_ASIENTOS_DET, BA_OFICINAS
          WHERE CB_SIM_ASIENTOS.COD_OFICINA = CB_SIM_ASIENTOS_DET.COD_OFICINA
            AND CB_SIM_ASIENTOS.COD_OFICINA = BA_OFICINAS.COD_OFICINA
            AND CB_SIM_ASIENTOS.NRO_ASIENTO = CB_SIM_ASIENTOS_DET.NRO_ASIENTO
            AND CB_SIM_ASIENTOS.CONFIRMADO = 'S'
            AND CB_SIM_ASIENTOS.ACTUALIZADO = 'N'
            AND CB_RUBROS.COD_RUBRO = CB_SIM_ASIENTOS_DET.COD_RUBRO
          GROUP BY CB_SIM_ASIENTOS.COD_OFICINA, CB_SIM_ASIENTOS_DET.COD_RUBRO,
                   CB_SIM_ASIENTOS_DET.TIP_MOVIMIENTO, BA_OFICINAS.DESCRIPCION,
                  decode(substr(cb_rubros.cod_rubro,14,2),'98','USD',CB_RUBROS.COD_MONEDA);
  -- Variables.
  CDOFICI      NUMBER(03);
  IMMOVGS      NUMBER(18,2);
  IMMONEX      NUMBER(18,2);
  WW_IMMOUSD   NUMBER(18,2);
  CDCUENT      VARCHAR2(15);
  TPMOVIM      VARCHAR2(01);
  NMOFICI      VARCHAR2(35);
  WCDMONED     VARCHAR2(4) ;
  W_MON_FUERTE VARCHAR2(4) := PAG_GEN.FU_OBT_MON_FUERTE;
  W_MON_LOCAL  VARCHAR2(4) := PAG_GEN.FU_OBT_MON_LOCAL;
  --
  v_fec_actual date := p_fecha;
  v_ano number(4)   := to_char(v_fec_actual,'yyyy');
  v_mes number(2)   := to_char(v_fec_actual,'mm');
  --
  PROCEDURE lp_sum_sal_consolidados(WCDCUENT IN CHAR,
                                    WTPMOVIM IN CHAR,
                                    WIMMOVGS IN NUMBER,
                                    WIMMONEX IN NUMBER,
                                    WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                ---------------------------------------------------------
                -- VERIFICA SI EXISTE EN CB_SAL_CONSOLIDADOS EL PADRE
                ---------------------------------------------------------
                BEGIN
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SIM_SAL_CONSOLIDADOS
                   WHERE COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                       INSERT INTO CB_SIM_SAL_CONSOLIDADOS
                                       (COD_RUBRO, ANO, MES, PROTEGIDO)
                                VALUES (CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - '||sqlerrm);
                END;
                IF WTPMOVIM = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE CB_SIM_SAL_CONSOLIDADOS
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE CB_SIM_SAL_CONSOLIDADOS
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                END IF;
             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuenta');
  END;
  --
  PROCEDURE lp_ins_rub_oficinas(WCDOFICI IN NUMBER, WCDCUENT IN CHAR) IS
  CDCUENT VARCHAR2(15);
  CDDIGVE NUMBER(01);
  CDCTDFC VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  CDTIPCT NUMBER(01);
  CDNIVCT NUMBER(02);
  NRMAYOR NUMBER(05);
  BEGIN
  SELECT COD_RUBRO, null, null, COD_RUB_PADRE,
         TIPO, NIVEL, ULT_NRO_MAYOR
    INTO CDCUENT, CDDIGVE, CDCTDFC, CDCTPAD,
         CDTIPCT, CDNIVCT, NRMAYOR
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     INSERT INTO CB_RUB_OFICINAS (COD_OFICINA, COD_RUBRO, ULT_NRO_EXTRACTO)
                  VALUES (WCDOFICI, CDCUENT, NRMAYOR);
     LOOP
     BEGIN
     SELECT COD_RUBRO, COD_RUB_PADRE, TIPO, NIVEL, ULT_NRO_MAYOR
       INTO CDCUENT, CDCTPAD, CDTIPCT, CDNIVCT, NRMAYOR
       FROM CB_RUBROS
      WHERE COD_RUBRO = CDCTPAD;
         IF SQL%FOUND THEN
            INSERT INTO CB_RUB_OFICINAS
            SELECT WCDOFICI, CDCUENT, NRMAYOR, USER, SYSDATE, USER, SYSDATE
              FROM DUAL
             WHERE NOT EXISTS (SELECT 'X' FROM CB_RUB_OFICINAS
                                WHERE COD_OFICINA = WCDOFICI
                                  AND COD_RUBRO = CDCUENT);
         END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     EXIT;
     END;
     END LOOP;
  END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||' inexistente en el Plan de Cuentas Consolidado');
  END;
  --
  PROCEDURE lp_ins_sal_consolidados(WCDCUENT IN CHAR,
                               WTPMOVIM IN VARCHAR2,
                               WIMMOVGS IN NUMBER,
                               WIMMONEX IN NUMBER,
                               WIMMOUSD IN NUMBER,
                               WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  LGPROTE VARCHAR2(01) := 'N'; ---
  V_MON_EQU_LOCAL NUMBER(18,2) := 0;
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     IF WCDMONED <> W_MON_LOCAL THEN
        V_MON_EQU_LOCAL := WIMMOVGS;
     END IF;

     IF WTPMOVIM = 'D' THEN
        -----------------------------------------------------------------
        -- INSERTA SALDO DE DEBITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_CONSOLIDADOS (COD_RUBRO, ANO, MES, DEB_MON_LOCAL, DEB_MON_RUBRO, PROTEGIDO, DEB_EQU_LOCAL)
                     VALUES (CDCUENT, v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE,V_MON_EQU_LOCAL);
     ELSE
        -----------------------------------------------------------------
        -- INSERTA SALDO DE CREDITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_CONSOLIDADOS (COD_RUBRO, ANO, MES, CRE_MON_LOCAL, CRE_MON_RUBRO, PROTEGIDO, CRE_EQU_LOCAL)
                     VALUES (CDCUENT,  v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE, V_MON_EQU_LOCAL);
      END IF;
      lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
     END IF;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||' inexistente en Plan de Cuentas Consolidado');
  END;
  ---
  PROCEDURE lp_sum_sal_oficinas(WCDOFICI IN NUMBER,
                             WCDCUENT IN CHAR,
                             WTPMOVIM IN CHAR,
                             WIMMOVGS IN NUMBER,
                             WIMMONEX IN NUMBER,
                             WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN CB_SAL_OFICINAS
                  ---------------------------------------------------------
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SIM_SAL_OFICINAS
                   WHERE COD_OFICINA = WCDOFICI
                     AND COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, PROTEGIDO)
                                            VALUES (WCDOFICI, CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - Ofic '||wcdofici||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                   IF WTPMOVIM = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE CB_SIM_SAL_OFICINAS
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                   ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE CB_SIM_SAL_OFICINAS
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                   END IF;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||' inexistente en Plan de Cuenta');
  END;
  --
  PROCEDURE lp_ins_sal_oficinas(WCDOFICI IN NUMBER,
                                WCDCUENT IN CHAR,
                                WTPMOVIM IN CHAR,
                                WIMMOVGS IN NUMBER,
                                WIMMONEX IN NUMBER,
                                WIMMOUSD IN NUMBER,
                                WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  LGPROTE VARCHAR2(01) := 'N'; ---
  V_MON_EQU_LOCAL NUMBER(18,2) := 0;
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     IF WCDMONED <> W_MON_LOCAL THEN
        V_MON_EQU_LOCAL := WIMMOVGS;
     END IF;
     IF WTPMOVIM = 'D' THEN
        -----------------------------------------------------------------
        -- INSERTA SALDO DE DEBITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, DEB_MON_LOCAL, DEB_MON_RUBRO, PROTEGIDO, DEB_EQU_LOCAL)
                     VALUES (WCDOFICI, CDCUENT,  v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE,V_MON_EQU_LOCAL);
     ELSE
        -----------------------------------------------------------------
        -- INSERTA SALDO DE CREDITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, CRE_MON_LOCAL, CRE_MON_RUBRO, PROTEGIDO, CRE_EQU_LOCAL)
                     VALUES (WCDOFICI, CDCUENT,  v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE, V_MON_EQU_LOCAL);
      END IF;
  END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuentas Consolidado');
  END;
  --
  PROCEDURE lp_act_asientos(WCDOFICI IN NUMBER,
                            WCDCUENT IN CHAR,
                            WTPMOVIM IN CHAR) IS
     cursor c_asientos is
     select fecha, cod_oficina, nro_asiento
       from CB_SIM_ASIENTOS
      WHERE CB_SIM_ASIENTOS.COD_OFICINA = WCDOFICI
        AND CB_SIM_ASIENTOS.NRO_ASIENTO IN (SELECT NRO_ASIENTO FROM CB_SIM_ASIENTOS_DET
                               WHERE CB_SIM_ASIENTOS_DET.COD_OFICINA = CB_SIM_ASIENTOS.COD_OFICINA
                                 AND CB_SIM_ASIENTOS_DET.NRO_ASIENTO = CB_SIM_ASIENTOS_DET.NRO_ASIENTO
                                 AND CB_SIM_ASIENTOS_DET.COD_RUBRO = WCDCUENT
                                 AND CB_SIM_ASIENTOS_DET.TIP_MOVIMIENTO = WTPMOVIM)
        AND CB_SIM_ASIENTOS.ACTUALIZADO = 'N'
        AND CB_SIM_ASIENTOS.CONFIRMADO = 'S';

  BEGIN
     for i in c_asientos loop
        UPDATE CB_SIM_ASIENTOS
           SET CB_SIM_ASIENTOS.ACTUALIZADO = 'S'
         WHERE CB_SIM_ASIENTOS.FECHA = i.fecha
           and CB_SIM_ASIENTOS.COD_OFICINA = i.cod_oficina
           and CB_SIM_ASIENTOS.Nro_Asiento = i.nro_asiento;

        UPDATE CB_SIM_ASIENTOS_DET
           SET CB_SIM_ASIENTOS_DET.ACTUALIZADO = 'S'
         WHERE CB_SIM_ASIENTOS_DET.FECHA = i.fecha
           and CB_SIM_ASIENTOS_DET.COD_OFICINA = i.cod_oficina
           and CB_SIM_ASIENTOS_DET.Nro_Asiento = i.nro_asiento
           AND CB_SIM_ASIENTOS_DET.ACTUALIZADO = 'N';
     end loop;
  END;
  --
  PROCEDURE lp_act_sal_oficinas(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              WTPMOVIM IN CHAR,
                              WIMMOVGS IN NUMBER,
                              WIMMONEX IN NUMBER,
                              WIMMOUSD IN NUMBER,
                              WCDMONED IN VARCHAR2) IS
  WDUMMY   CHAR(1);
  BEGIN
  SELECT 'X' INTO WDUMMY
    FROM CB_SIM_SAL_OFICINAS
   WHERE COD_OFICINA = WCDOFICI
     AND COD_RUBRO = WCDCUENT
     AND ANO = v_ano
     AND MES = v_mes
     FOR UPDATE OF COD_RUBRO;
     IF SQL%FOUND THEN
        IF WTPMOVIM = 'D' THEN
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE DEBITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_OFICINAS
              SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_OFICINA = WCDOFICI
              AND COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           --lp_sum_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
        ELSE
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE CREDITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_OFICINAS
              SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_OFICINA = WCDOFICI
              AND COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           --lp_sum_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
        END IF;
     END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     ----------------------------------------------------------------
     -- NO ENCONTRO REGISTRO EN CB_SAL_OFICINAS POR LO TANTO SE DEBE INSERTAR
     -- LA CUENTA PREVIA VERIFICACION EN CB_RUB_OFICINAS
     ----------------------------------------------------------------
     BEGIN
       SELECT 'X'
         INTO WDUMMY
         FROM CB_RUB_OFICINAS
        WHERE COD_OFICINA = WCDOFICI
          AND COD_RUBRO = WCDCUENT;
       IF SQL%FOUND THEN
          lp_ins_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END IF;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
         ------------------------------------------------------------
         -- INSERTA CUENTAS EN EL PLAN DE CUENTAS CONSOLIDADO
         -- CUENTAS ASENTABLES Y CUENTAS PADRES
         ------------------------------------------------------------
         lp_ins_rub_oficinas(WCDOFICI, WCDCUENT);
         lp_ins_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END;
  END;
  --
  PROCEDURE lp_act_sal_consolidados(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              WTPMOVIM IN CHAR,
                              WIMMOVGS IN NUMBER,
                              WIMMONEX IN NUMBER,
                              WIMMOUSD IN NUMBER,
                              WCDMONED IN VARCHAR2) IS
  WDUMMY   CHAR(1);
  BEGIN
  SELECT 'X' INTO WDUMMY
    FROM CB_SIM_SAL_CONSOLIDADOS
   WHERE COD_RUBRO = WCDCUENT
     AND ANO = v_ano
     AND MES = v_mes
     FOR UPDATE OF COD_RUBRO;
     IF SQL%FOUND THEN
        IF WTPMOVIM = 'D' THEN
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE DEBITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_CONSOLIDADOS
              SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
        ELSE
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE CREDITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_CONSOLIDADOS
              SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
        END IF;
     END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     ----------------------------------------------------------------
     -- NO ENCONTRO REGISTRO EN CB_SAL_CONSOLIDADOS POR LO TANTO SE DEBE INSERTAR
     -- LA CUENTA PREVIA VERIFICACION EN CB_RUB_OFICINAS
     ----------------------------------------------------------------
     BEGIN
       SELECT 'X'
         INTO WDUMMY
         FROM CB_RUB_OFICINAS
        WHERE COD_OFICINA = WCDOFICI
          AND COD_RUBRO = WCDCUENT;
       IF SQL%FOUND THEN
          lp_ins_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END IF;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
         ------------------------------------------------------------
         -- INSERTA CUENTAS EN EL PLAN DE CUENTAS CONSOLIDADO
         -- CUENTAS ASENTABLES Y CUENTAS PADRES
         ------------------------------------------------------------
         lp_ins_rub_oficinas(WCDOFICI,WCDCUENT);
         lp_ins_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END;
  END;

-- Inicio del proceso principal de actualizacion de saldos contables
BEGIN
  PAE_CNF.G_COD_MODULO := 2;
  IF SALD_M%ISOPEN THEN
     CLOSE SALD_M;
  END IF;
  OPEN SALD_M;
  LOOP
  FETCH SALD_M INTO CDOFICI, CDCUENT, TPMOVIM, NMOFICI, IMMOVGS, IMMONEX, WCDMONED;
  WW_IMMOUSD := fub_con_mon_a_moneda(WCDMONED,W_MON_FUERTE,IMMONEX); --Obtener la cotización del modulo 2 (Contabilidad).
  EXIT WHEN SALD_M%notfound;
  IF SALD_M%FOUND THEN
     lp_act_sal_oficinas(CDOFICI, CDCUENT, TPMOVIM, IMMOVGS, IMMONEX,WW_IMMOUSD,WCDMONED);
  END IF;
  lp_act_asientos(CDOFICI, CDCUENT, TPMOVIM);
  END LOOP;
END PR_ACT_SALDOS;

/* Actualiza el Balance por Oficinas. */
PROCEDURE PR_SUM_SAL_OFICINAS(p_fecha in ge_calendarios.fec_actual%type) IS

-- Variables.
v_cod_mon_fuerte        varchar2(4) := pag_gen.FU_OBT_MON_FUERTE;
v_fec_actual            date        := p_fecha;
v_ano                   number(4)   := to_char(v_fec_actual,'yyyy');
v_mes                   number(2)   := to_char(v_fec_actual,'mm');
v_sal_mon_rub_ant       number;
v_deb_mon_rubro         number;
v_cre_mon_rubro         number;
v_sal_ini_mes_mon_rubro number;

-- Cursores.
cursor cta is
 select a.cod_oficina, b.cod_rub_padre, b.cod_moneda,
        sum(nvl(sal_mon_loc_ant,0)) sal_mon_loc_ant,
        sum(nvl(deb_mon_local,0)) deb_mon_local,
        sum(nvl(cre_mon_local,0)) cre_mon_local,
        sum(nvl(sal_mon_rub_ant,0)) sal_mon_rub_ant,
        sum(nvl(deb_mon_rubro,0)) deb_mon_rubro,
        sum(nvl(cre_mon_rubro,0)) cre_mon_rubro,
        sum(nvl(sal_equ_loc_ant,0)) sal_equ_loc_ant,
        sum(nvl(deb_equ_local,0)) deb_equ_local,
        sum(nvl(cre_equ_local,0)) cre_equ_local,
        sum(nvl(sal_ini_mes_mon_local,0)) sal_ini_mes_mon_local,
        sum(nvl(sal_ini_mes_mon_rubro,0)) sal_ini_mes_mon_rubro,
        sum(nvl(sal_ini_mes_mon_fuerte,0)) sal_ini_mes_mon_fuerte,
        sum(nvl(sal_ini_mes_equ_local,0)) sal_ini_mes_equ_local
   from  cb_sim_sal_oficinas a,cb_rubros b
  where a.cod_rubro = b.cod_rubro
    and b.imputable = 'S'
   group by a.cod_oficina, b.cod_rub_padre, b.cod_moneda;

-- Procedimientos Internos.
PROCEDURE lp_sum_sal_oficinas(wcdofici in number,
                              wcdcuent in char,
                              p_sal_mon_loc_ant in number,
                              p_deb_mon_local in number,
                              p_cre_mon_local  in number,
                              p_sal_mon_rub_ant in number,
                              p_deb_mon_rubro in number,
                              p_cre_mon_rubro in number,
                              p_sal_equ_loc_ant in number,
                              p_deb_equ_local in number,
                              p_cre_equ_local in number,
                              p_sal_ini_mes_mon_local in number,
                              p_sal_ini_mes_mon_rubro in number,
                              p_sal_ini_mes_mon_fuerte in number,
                              p_sal_ini_mes_equ_local in number) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN CB_SAL_OFICINAS
                  ---------------------------------------------------------
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SIM_SAL_OFICINAS
                   WHERE COD_OFICINA = WCDOFICI
                     AND COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, PROTEGIDO)
                                        VALUES (WCDOFICI, CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - Ofic '||wcdofici||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                    ----------------------------------------
                      UPDATE CB_SIM_SAL_OFICINAS
                        SET sal_mon_loc_ant = nvl(sal_mon_loc_ant,0) + nvl(p_sal_mon_loc_ant,0),
                            deb_mon_local = nvl(deb_mon_local,0) + nvl(p_deb_mon_local,0),
                            cre_mon_local =  nvl(cre_mon_local,0) + nvl(p_cre_mon_local,0),
                            sal_mon_rub_ant = nvl(sal_mon_rub_ant,0) + nvl(p_sal_mon_rub_ant,0),
                            deb_mon_rubro = nvl(deb_mon_rubro,0) + nvl(p_deb_mon_rubro,0),
                            cre_mon_rubro = nvl(cre_mon_rubro,0) + nvl(p_cre_mon_rubro,0),
                            sal_equ_loc_ant = nvl(sal_equ_loc_ant,0) + nvl(p_sal_equ_loc_ant,0),
                            deb_equ_local = nvl(deb_equ_local,0) + nvl(p_deb_equ_local,0),
                            cre_equ_local = nvl(cre_equ_local,0) + nvl(p_cre_equ_local,0),
                            sal_ini_mes_mon_local = nvl(sal_ini_mes_mon_local,0) + nvl(p_sal_ini_mes_mon_local,0),
                            sal_ini_mes_mon_rubro = nvl(sal_ini_mes_mon_rubro,0) + nvl(p_sal_ini_mes_mon_rubro,0),
                            sal_ini_mes_mon_fuerte = nvl(sal_ini_mes_mon_fuerte,0) + nvl(p_sal_ini_mes_mon_fuerte,0),
                            sal_ini_mes_equ_local = nvl(sal_ini_mes_equ_local,0) + nvl(p_sal_ini_mes_equ_local,0)
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuenta');
  END;
-- Proceso Principal.
begin
    -- cero todas las cuentas no imputables
    update CB_SIM_SAL_OFICINAS a
       set sal_mon_loc_ant = 0,
             deb_mon_local = 0,
             cre_mon_local = 0,
             sal_mon_rub_ant = 0,
             deb_mon_rubro = 0,
             cre_mon_rubro = 0,
             sal_equ_loc_ant = 0,
             deb_equ_local = 0,
             cre_equ_local = 0,
             sal_ini_mes_mon_local = 0,
             sal_ini_mes_mon_rubro = 0,
             sal_ini_mes_mon_fuerte = 0,
             sal_ini_mes_equ_local = 0
      where exists (select 0 from cb_rubros b
                     where b.cod_rubro = a.cod_rubro
                       and b.imputable = 'N');
   -- sumarizo las cuentas
   for r in cta loop
      v_sal_mon_rub_ant       := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.sal_mon_rub_ant,null,v_fec_actual);
      v_deb_mon_rubro         := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.deb_mon_rubro,null,v_fec_actual);
      v_cre_mon_rubro         := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.cre_mon_rubro,null,v_fec_actual);
      v_sal_ini_mes_mon_rubro := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.sal_ini_mes_mon_rubro,null,v_fec_actual);

      update CB_SIM_SAL_OFICINAS
         set sal_mon_loc_ant = sal_mon_loc_ant + r.sal_mon_loc_ant,
             deb_mon_local = deb_mon_local + r.deb_mon_local,
             cre_mon_local = cre_mon_local + r.cre_mon_local,
             sal_mon_rub_ant = sal_mon_rub_ant + v_sal_mon_rub_ant,
             deb_mon_rubro = deb_mon_rubro + v_deb_mon_rubro,
             cre_mon_rubro = cre_mon_rubro + v_cre_mon_rubro,
             sal_equ_loc_ant = sal_equ_loc_ant + r.sal_equ_loc_ant,
             deb_equ_local = deb_equ_local + r.deb_equ_local,
             cre_equ_local = cre_equ_local + r.cre_equ_local,
             sal_ini_mes_mon_local = sal_ini_mes_mon_local + r.sal_ini_mes_mon_local,
             sal_ini_mes_mon_rubro = sal_ini_mes_mon_rubro + v_sal_ini_mes_mon_rubro,
             sal_ini_mes_mon_fuerte = sal_ini_mes_mon_fuerte + r.sal_ini_mes_mon_fuerte,
             sal_ini_mes_equ_local =  sal_ini_mes_equ_local + r.sal_ini_mes_equ_local
       where cod_rubro = r.cod_rub_padre
         and cod_oficina = r.cod_oficina;

      --Si no existe, crear la cuenta padre en cb_sal_oficinas.
      if sql%notfound then
         insert into CB_SIM_SAL_OFICINAS
         (cod_oficina, cod_rubro, ano, mes, protegido,
          sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_mon_rub_ant,
          deb_mon_rubro, cre_mon_rubro, sal_equ_loc_ant, deb_equ_local,
          cre_equ_local, sal_ini_mes_mon_local, sal_ini_mes_mon_rubro,
          sal_ini_mes_mon_fuerte, sal_ini_mes_equ_local)
         values
         (r.cod_oficina, r.cod_rub_padre, v_ano, v_mes, 'S',
          r.sal_mon_loc_ant, r.deb_mon_local, r.cre_mon_local, v_sal_mon_rub_ant,
          v_deb_mon_rubro, v_cre_mon_rubro, r.sal_equ_loc_ant, r.deb_equ_local,
          r.cre_equ_local, r.sal_ini_mes_mon_local, v_sal_ini_mes_mon_rubro,
          r.sal_ini_mes_mon_fuerte, r.sal_ini_mes_equ_local);
      end if;

      -- Actualizo los demas rubros padres.
      lp_sum_sal_oficinas(r.cod_oficina,
                          r.cod_rub_padre,
                          r.sal_mon_loc_ant ,
                          r.deb_mon_local,
                          r.cre_mon_local,
                          v_sal_mon_rub_ant,
                          v_deb_mon_rubro,
                          v_cre_mon_rubro,
                          r.sal_equ_loc_ant,
                          r.deb_equ_local,
                          r.cre_equ_local,
                          r.sal_ini_mes_mon_local,
                          v_sal_ini_mes_mon_rubro,
                          r.sal_ini_mes_mon_fuerte,
                          r.sal_ini_mes_equ_local);
  END LOOP;
END PR_SUM_SAL_OFICINAS;

/* Actualiza el Balance Consolidado. */
PROCEDURE PR_SUM_SAL_CONSOLIDADOS(p_fecha in ge_calendarios.fec_actual%type)
IS
-- Variables.
v_fec_actual    date := p_fecha;
v_ano           number(4);
v_mes           number(2);
v_cod_rubro     varchar2(15);

-- Cursores.
CURSOR UTI is
  SELECT SUBSTR(COD_RUBRO,1,5)||'XXX'||SUBSTR(COD_RUBRO,9) COD_RUBRO, ANO, MES,
         SUM(NVL(SAL_MON_LOC_ANT,0)) SAL_MON_LOC_ANT,
         SUM(NVL(DEB_MON_LOCAL,0)) DEB_MON_LOCAL,
         SUM(NVL(CRE_MON_LOCAL,0)) CRE_MON_LOCAL,
         SUM(NVL(SAL_INI_MES_MON_LOCAL,0)) SAL_INI_MES_MON_LOCAL,
         SUM(NVL(SAL_MON_RUB_ANT,0)) SAL_MON_RUB_ANT,
         SUM(NVL(DEB_MON_RUBRO,0)) DEB_MON_RUBRO,
         SUM(NVL(CRE_MON_RUBRO,0)) CRE_MON_RUBRO,
         SUM(NVL(SAL_INI_MES_MON_RUBRO,0)) SAL_INI_MES_MON_RUBRO,
         SUM(NVL(SAL_EQU_LOC_ANT,0)) SAL_EQU_LOC_ANT,
         SUM(NVL(DEB_EQU_LOCAL,0)) DEB_EQU_LOCAL,
         SUM(NVL(CRE_EQU_LOCAL,0)) CRE_EQU_LOCAL,
         SUM(NVL(SAL_INI_MES_EQU_LOCAL,0)) SAL_INI_MES_EQU_LOCAL
    FROM CB_SIM_SAL_OFICINAS
   WHERE CB_SIM_SAL_OFICINAS.ANO = v_ano
     AND CB_SIM_SAL_OFICINAS.MES = v_mes
     AND SUBSTR(COD_RUBRO,1,8) IN ('31060418','31060422')
   GROUP BY SUBSTR(COD_RUBRO,1,5)||'XXX'||SUBSTR(COD_RUBRO,9), ANO, MES;

BEGIN
  -- Variables de fecha.
  v_ano := to_char(v_fec_actual,'yyyy');
  v_mes := to_char(v_fec_actual,'mm');
  /* borro los registros anteriores */
  DELETE CB_SIM_SAL_CONSOLIDADOS
   WHERE CB_SIM_SAL_CONSOLIDADOS.ANO = v_ano
     AND CB_SIM_SAL_CONSOLIDADOS.MES = v_mes;
  /* copios los saldos por oficina */
  INSERT INTO CB_SIM_SAL_CONSOLIDADOS
    (COD_RUBRO, ANO, MES, SAL_MON_LOC_ANT,
     DEB_MON_LOCAL, CRE_MON_LOCAL,
     SAL_INI_MES_MON_LOCAL, SAL_MON_RUB_ANT,
     DEB_MON_RUBRO, CRE_MON_RUBRO, SAL_INI_MES_MON_RUBRO,
     SAL_EQU_LOC_ANT, DEB_EQU_LOCAL, CRE_EQU_LOCAL, SAL_INI_MES_EQU_LOCAL)
  SELECT COD_RUBRO, ANO, MES,
         SUM(NVL(SAL_MON_LOC_ANT,0)),
         SUM(NVL(DEB_MON_LOCAL,0)),
         SUM(NVL(CRE_MON_LOCAL,0)),
         SUM(NVL(SAL_INI_MES_MON_LOCAL,0)),
         SUM(NVL(SAL_MON_RUB_ANT,0)),
         SUM(NVL(DEB_MON_RUBRO,0)),
         SUM(NVL(CRE_MON_RUBRO,0)),
         SUM(NVL(SAL_INI_MES_MON_RUBRO,0)),
         SUM(NVL(SAL_EQU_LOC_ANT,0)),
         SUM(NVL(DEB_EQU_LOCAL,0)),
         SUM(NVL(CRE_EQU_LOCAL,0)),
         SUM(NVL(SAL_INI_MES_EQU_LOCAL,0))
    FROM CB_SIM_SAL_OFICINAS
   WHERE CB_SIM_SAL_OFICINAS.ANO = v_ano
     AND CB_SIM_SAL_OFICINAS.MES = v_mes
     AND SUBSTR(COD_RUBRO,1,8) NOT IN ('31060418','31060422')
   GROUP BY COD_RUBRO, ANO, MES;
  /* utilidad */
  FOR I IN UTI LOOP
     IF i.sal_mon_loc_ant + i.deb_mon_local - i.cre_mon_local > 0 then
         -- PERDIDA
         V_COD_RUBRO := REPLACE(i.cod_rubro,'XXX','422');
     ELSE
         -- GANANCIA
         V_COD_RUBRO := REPLACE(i.cod_rubro,'XXX','418');
     END IF;
     INSERT INTO CB_SIM_SAL_CONSOLIDADOS
      (COD_RUBRO, ANO, MES, SAL_MON_LOC_ANT,
       DEB_MON_LOCAL, CRE_MON_LOCAL,
       SAL_INI_MES_MON_LOCAL, SAL_MON_RUB_ANT,
       DEB_MON_RUBRO, CRE_MON_RUBRO, SAL_INI_MES_MON_RUBRO,
       SAL_EQU_LOC_ANT, DEB_EQU_LOCAL, CRE_EQU_LOCAL, SAL_INI_MES_EQU_LOCAL)
    VALUES
     ( V_COD_RUBRO, V_ANO, V_MES,
       I.SAL_MON_LOC_ANT,
       I.DEB_MON_LOCAL,
       I.CRE_MON_LOCAL,
       I.SAL_INI_MES_MON_LOCAL,
       I.SAL_MON_RUB_ANT,
       I.DEB_MON_RUBRO,
       I.CRE_MON_RUBRO,
       I.SAL_INI_MES_MON_RUBRO,
       I.SAL_EQU_LOC_ANT,
       I.DEB_EQU_LOCAL,
       I.CRE_EQU_LOCAL,
       I.SAL_INI_MES_EQU_LOCAL);
  END LOOP;
END PR_SUM_SAL_CONSOLIDADOS;

/* Realiza la valuación del Balance. */
PROCEDURE PR_AJU_DIF_CAMBIOS(p_fecha in ge_calendarios.fec_actual%type) is
  /* proceso diario de ajuste por diferencia de cambios */
  v_fec_actual       date          := p_fecha;
  v_ano              number(4)     := to_char(v_fec_actual,'yyyy');
  v_mes              number(2)     := to_char(v_fec_actual,'mm');
  v_cod_mon_local    varchar2(4)   := pag_gen.FU_OBT_MON_LOCAL;
  --
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_cod_rubro        cb_rubros.cod_rubro%type;
  v_aju_oficina      VARCHAR2(01);
  v_sal_mon_local    NUMBER(16,2);
  v_sal_mon_rubro    NUMBER(16,2);
  v_cod_rub_dif_cam  VARCHAR2(15);
  v_cod_tip_cuenta   NUMBER(2);
  v_cod_moneda       ba_monedas.cod_moneda%type;
  v_cod_rub_utilidad cb_rubros.cod_rubro%type;
  v_cod_rub_perdida  cb_rubros.cod_rubro%type;
  ----
  v_tot_control      NUMBER;
  v_tot_acumulado    NUMBER;
  v_nro_linea        NUMBER;
  v_imp_dif_cambios  NUMBER;
  v_nro_asiento      NUMBER;
  asiento            NUMBER;
  v_diferencia       NUMBER;
  v_tip_movimiento   VARCHAR2(1);
  v_tip_mov_contra   VARCHAR2(1);
  v_cas_matriz       number(3);
  v_redondeo_ml      number(5);

  -- Cursores.
  CURSOR OFICINA IS
     SELECT COD_OFICINA,DESCRIPCION
       FROM BA_OFICINAS
      ORDER BY COD_OFICINA;
  ----
  CURSOR CURX is
      SELECT cb_rubros.COD_RUBRO, COD_OFICINA, /*AJUSTABLE*/ 'S',
             NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0),
             NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0),
             TIPO, COD_MONEDA
        FROM CB_SIM_SAL_OFICINAS, CB_RUBROS
       WHERE ANO = v_ano
         AND MES = v_mes
         AND CB_SIM_SAL_OFICINAS.COD_RUBRO = CB_RUBROS.COD_RUBRO
         AND IMPUTABLE = 'S'
         AND (TIPO IN (1,2,3,4,5,9))
         and substr(CB_RUBROS.cod_rubro,1,2) not in ('42','52')
         AND COD_MONEDA != v_cod_mon_local
      ORDER BY COD_MONEDA,cb_rubros.COD_RUBRO,COD_OFICINA;
  --
  WT_TASCTZ NUMBER;
  WT_MONEDA VARCHAR2(03);
  WC_AJCONS NUMBER(22);
  WC_CDCTAJU VARCHAR2(15);
  WT_CTACONT VARCHAR2(15) := '12';
  WT_TOTALME NUMBER(22,2);
  WT_TOTALGS NUMBER(22,2);
  WW_AJUSTO  VARCHAR2(01) := 'N';
  WT_CDOFICI NUMBER(03);
  v_hay_asiento  varchar2(1) := 'N';
  v_gen_cabecera varchar2(1) := 'N';
  v_lugar    varchar2(300);
  ---
  PROCEDURE LP_OBT_RUB_AJUSTE
    (p_cod_rubro IN     CHAR,
     p_cod_rub_utilidad IN OUT CHAR,
     p_cod_rub_perdida IN OUT CHAR) IS
  v_cod_sector varchar2(01) := SUBSTR(p_cod_rubro,1,1);
  v_cod_capitulo varchar2(01) := SUBSTR(p_cod_rubro,2,1);
  v_cod_grupo varchar2(01) := SUBSTR(p_cod_rubro,4,1);
  v_sub_cuenta varchar2(02) := SUBSTR(p_cod_rubro,9,2);
  v_tip_sub_cta varchar2(1) := 'P';
  v_nro_cuenta varchar2(3) := SUBSTR(p_cod_rubro,6,3);
  v_mod_interno varchar2(3) := substr(p_cod_rubro,11,3);
  v_cod_subcuenta  varchar2(1);
  v_cod_mon_numerico varchar2(2) := substr(p_cod_rubro,14,2);
  CURSOR C1 IS
     SELECT COD_RUB_UTILIDAD,COD_RUB_PERDIDA
      FROM CB_AJUSTES
     WHERE COD_SECTOR = v_cod_sector
       AND COD_CAPITULO = v_cod_capitulo
       AND (COD_GRUPO = v_cod_grupo OR COD_GRUPO = 'T')
       AND (NRO_CUENTA = v_nro_cuenta OR NRO_CUENTA IS NULL)
       AND (COD_SUBCUENTA = v_sub_cuenta  or cod_subcuenta = v_tip_sub_cta or COD_SUBCUENTA = 'T' ) -- Modificado por ICL 18/08/2011. Tomar el registro más detallado y posteriormente el global.
       AND (MOD_INTERNO = v_mod_interno OR MOD_INTERNO IS NULL)
       AND (COD_MON_NUMERICO = v_cod_mon_numerico OR COD_MON_NUMERICO IS NULL)
     ORDER BY COD_GRUPO desc, nvl(NRO_CUENTA,999), COD_SUBCUENTA desc, nvl(MOD_INTERNO,999);
  R1 C1%ROWTYPE;
  BEGIN
     select cod_ofi_matriz into v_cas_matriz
       from ge_par_generales;
     -- Busco las cuentas dif.cambios a ser asignadas --------------------
     IF (MOD(TO_NUMBER(v_sub_cuenta),2) = 0) OR
        (v_sub_cuenta = '01' AND v_cod_sector||v_cod_capitulo <> '12') THEN
        v_tip_sub_cta := 'P';
     ELSE
        v_tip_sub_cta := 'I';
     END IF;
     IF C1%ISOPEN THEN
        CLOSE C1;
     END IF;
     OPEN C1;
     FETCH C1 INTO R1;
     IF C1%NOTFOUND THEN
       CLOSE C1;
       raise_application_error(-20000,'ERROR. No existe Cuenta de Ajuste p/ Sec.: '||v_cod_sector||
       ' Cap: '||v_cod_capitulo||' Gru: '||v_cod_grupo||' Cta: '||v_nro_cuenta||' TipSubCta: '||v_tip_sub_cta||
       ' CodSubCta.:'||v_sub_cuenta||' y CodSubCta.:'||v_mod_interno||' y CodSubCta.:'||v_cod_subcuenta||' Rubro:'||v_cod_rubro);
     END IF;
     p_cod_rub_utilidad := R1.COD_RUB_UTILIDAD;
     p_cod_rub_perdida := R1.COD_RUB_PERDIDA;
     CLOSE C1;
  END;

-- Proceso Principal.
BEGIN
  --- Inicializo las variables a ser utilizadas en el proceso -------
  v_tot_acumulado     := 0;
  v_nro_linea   := 0;
  v_tot_control  := 0;
  WT_MONEDA := 'WQX';
  v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 2, 21 ,v_cod_mon_local);
  --- Busco el Primer Numero de asiento disponible ------------------
  asiento := fug_obt_pardinamico('SIG_NRO_REF_BALANCE');
  v_nro_asiento := -1;
  ---
  WC_CDCTAJU := fug_obt_pardinamico('COD_RUB_TEMPORAL');
  --- Ciclo de lectura de las cuentas ordenado por Moneda,Cuenta,Of.--
  OPEN CURX;
  WC_AJCONS  := 0;
  WT_TOTALME := 0;
  WT_TOTALGS := 0;
  WW_AJUSTO  := 'N';

LOOP
  v_lugar := 'Antes del Fetch ';
  FETCH CURX INTO v_cod_rubro, v_cod_oficina, v_aju_oficina,
                  v_sal_mon_local, v_sal_mon_rubro, v_cod_tip_cuenta,
                  v_cod_moneda;
  v_lugar := 'Despues del fectch CURX';
  EXIT WHEN CURX%notfound;
  IF v_cod_rubro <> WT_CTACONT THEN
    IF WW_AJUSTO = 'S' THEN /* hubo ajuste */
       IF NVL(WT_TOTALME,0) = 0 AND NVL(WT_TOTALGS,0) IN (1,-1) THEN
          IF WC_AJCONS <> 0 THEN /* solo si se hara ajuste of.central*/
             /* hay que ajustar la ultima linea generada */
             WC_AJCONS := NVL(WC_AJCONS,0)+NVL(WT_TOTALGS,0);
          END IF;
          IF v_tip_movimiento = 'D' THEN /* si la ultima linea es debito */
             WT_TOTALGS := WT_TOTALGS * -1; /* cambio el signo*/
          END IF;
          UPDATE CB_SIM_ASIENTOS_DET
             SET MTO_MON_LOCAL = NVL(MTO_MON_LOCAL,0)+NVL(WT_TOTALGS,0)
           WHERE FECHA = v_fec_actual
             AND COD_OFICINA = WT_CDOFICI
             AND NRO_ASIENTO = v_nro_asiento
             AND NRO_LINEA IN (v_nro_linea,v_nro_linea-1);
       END IF;
    END IF;
    IF WC_AJCONS <> 0 THEN /* se debe ajustar en la ofC.Central */
       --- busca las cuentas de ajuste correspondientes ---------
       LP_OBT_RUB_AJUSTE(WT_CTACONT,v_cod_rub_utilidad,v_cod_rub_perdida);
       ----------------------------------------------------------
       IF WC_AJCONS > 0 THEN
          -- SE HACE credito a la cuenta puente
          v_diferencia   := WC_AJCONS;
          v_tip_movimiento       := 'C';
          v_tip_mov_contra := 'D';
          v_cod_rub_dif_cam    := v_cod_rub_perdida;
       ELSE
          -- SE HACE CREDITO A LA CUENTA
          v_diferencia   := WC_AJCONS * -1;
          v_tip_movimiento       := 'D';
          v_tip_mov_contra := 'C';
          v_cod_rub_dif_cam    := v_cod_rub_utilidad;
       END IF;
       --
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_SIM_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO,FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, WC_CDCTAJU,
             v_diferencia, 0,v_tip_movimiento, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N',v_fec_actual);
       ---
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_SIM_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, v_cod_rub_dif_cam,
             v_diferencia, 0,v_tip_mov_contra, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
     END IF;
     --- actualizo las variables para el siguiente corte ----
     WT_CTACONT := v_cod_rubro;
     WC_AJCONS  := 0;
     WT_TOTALME := 0;
     WT_TOTALGS := 0;
     WW_AJUSTO  := 'N';
  END IF;
  --- busco la cotizacion de la moneda solo si hubo cambio de moneda
  IF WT_MONEDA <> v_cod_moneda THEN
     WT_TASCTZ := FUG_OBT_COTIZACION(v_cod_moneda,v_fec_actual);
     WT_MONEDA := v_cod_moneda;
  END IF;
  --- Calculo el valor en M/L del saldol en M/e para si es necesario-
  v_imp_dif_cambios  := NVL(v_sal_mon_rubro,0)*NVL(WT_TASCTZ,0)-NVL(v_sal_mon_local,0);
  v_imp_dif_cambios  := ROUND(v_imp_dif_cambios,v_redondeo_ml);
  -- voy calculando el consolidado de la cuenta -----------------------
  WT_TOTALME := NVL(WT_TOTALME,0) + NVL(v_sal_mon_rubro,0);
  WT_TOTALGS := NVL(WT_TOTALGS,0) + (NVL(v_sal_mon_local,0)+NVL(v_imp_dif_cambios,0));
  ---------------------------------------------------------------------
  v_tot_acumulado    := v_tot_acumulado + v_imp_dif_cambios;
  v_tot_control := v_tot_control + ABS(v_imp_dif_cambios);
  v_diferencia := 0;
  IF v_imp_dif_cambios != 0 THEN
     IF v_imp_dif_cambios >0 THEN
        -- SE HACE DEBITO A LA CUENTA
        v_diferencia   := v_imp_dif_cambios;
        v_tip_movimiento       := 'D';
     ELSE
        -- SE HACE CREDITO A LA CUENTA
        v_diferencia   := v_imp_dif_cambios * -1;
        v_tip_movimiento       := 'C';
     END IF;
     v_hay_asiento := 'S';
     v_gen_cabecera := 'S';
     -- carga detalles (1a. Linea)           --
     -- La cuenta que tuvo diferencia        --
     ------------------------------------------
     v_nro_linea := v_nro_linea + 1;
     v_lugar := 'Genera CB_ASIENTOS_DET';
     INSERT INTO CB_SIM_ASIENTOS_DET
          (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
           MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
           DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
           DISTRIBUIDO, FECHA)
     VALUES
          (v_cod_oficina , v_nro_asiento, v_nro_linea    , v_cod_rubro,
           v_diferencia, 0, v_tip_movimiento, 'AJUSTE',
           'ASIENTO AJUSTE', 'N','N', 0 ,'N', v_fec_actual);
     -- guardo los valores para el ajuste de 1guarani si es necesario
     WW_AJUSTO := 'S';
     WT_CDOFICI := v_cod_oficina;
     ----------------------------------------------------------------
     IF v_aju_oficina = 'S' THEN
        --- busca las cuentas de ajuste correspondientes ---------
        LP_OBT_RUB_AJUSTE(v_cod_rubro,v_cod_rub_utilidad,v_cod_rub_perdida);
        ----------------------------------------------------------
        IF v_tip_movimiento = 'D' THEN
           v_cod_rub_dif_cam    := v_cod_rub_utilidad;
           v_tip_mov_contra := 'C';
        ELSE
           v_cod_rub_dif_cam    := v_cod_rub_perdida;
           v_tip_mov_contra := 'D';
        END IF;
     ELSE
        v_cod_rub_dif_cam := WC_CDCTAJU;  /* cuenta puente de ajuste */
        IF v_tip_movimiento = 'D' THEN
           WC_AJCONS := NVL(WC_AJCONS,0) - NVL(v_diferencia,0);
           v_tip_mov_contra := 'C';
        ELSE
           WC_AJCONS := NVL(WC_AJCONS,0) + NVL(v_diferencia,0);
           v_tip_mov_contra := 'D';
        END IF;
     END IF;
     -----------------------------------------------
     -- carga detalle CUENTA DIFERENCIA DE CAMBIO --
     -----------------------------------------------
     v_nro_linea := v_nro_linea + 1;
     INSERT INTO CB_SIM_ASIENTOS_DET
           (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
            MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
            DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
            DISTRIBUIDO, FECHA)
     VALUES
           (v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_dif_cam,
            v_diferencia, 0,v_tip_mov_contra, 'AJUSTE',
            'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
   END IF;
------------------------------------------------------------------
   END LOOP;
   CLOSE CURX;
   /* El ultimo corte leido */
   IF WW_AJUSTO = 'S' THEN /* hubo ajuste */
       IF NVL(WT_TOTALME,0) = 0 AND NVL(WT_TOTALGS,0) IN (1,-1) THEN
          /* hay que ajustar la ultima linea generada */
          WC_AJCONS := NVL(WC_AJCONS,0)+NVL(WT_TOTALGS,0);
          IF v_tip_movimiento = 'D' THEN /* si la ultima linea es debito */
             WT_TOTALGS := WT_TOTALGS * -1; /* cambio el signo*/
          END IF;
          UPDATE CB_SIM_ASIENTOS_DET
             SET MTO_MON_LOCAL = NVL(MTO_MON_LOCAL,0)+NVL(WT_TOTALGS,0)
           WHERE FECHA = v_fec_actual
             AND COD_OFICINA = WT_CDOFICI
             AND NRO_ASIENTO = v_nro_asiento
             AND NRO_LINEA IN (v_nro_linea,v_nro_linea-1);
       END IF;
   END IF;
   IF WC_AJCONS <> 0 THEN /* se debe ajustar en la ofC.Central */
      IF WC_AJCONS > 0 THEN
          -- SE HACE credito a la cuenta puente
          v_diferencia   := WC_AJCONS;
          v_tip_movimiento       := 'C';
          v_tip_mov_contra := 'D';
          v_cod_rub_dif_cam    := v_cod_rub_perdida;
       ELSE
          -- SE HACE CREDITO A LA CUENTA
          v_diferencia   := WC_AJCONS * -1;
          v_tip_movimiento       := 'D';
          v_tip_mov_contra := 'C';
          v_cod_rub_dif_cam    := v_cod_rub_utilidad;
       END IF;
       --
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_SIM_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, WC_CDCTAJU,
             v_diferencia, 0,v_tip_movimiento, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
       ---
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_SIM_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, v_cod_rub_dif_cam,
             v_diferencia, 0,v_tip_mov_contra, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
   END IF;
   v_nro_asiento := asiento;
   asiento := -1;
   --v_nro_asiento := v_nro_asiento + 1;
   FOR OFI IN OFICINA LOOP
     --- Actualizo el nro de Asiento y Lineas po cada oficina ---
     UPDATE CB_SIM_ASIENTOS_DET
        SET NRO_ASIENTO = v_nro_asiento,
            NRO_LINEA = ROWNUM
      WHERE FECHA = v_fec_actual
        AND COD_OFICINA = OFI.COD_OFICINA
        AND NRO_ASIENTO = ASIENTO;
     IF SQL%FOUND THEN
        --- Sumo para el Totald e control de la cabecera --------
        SELECT SUM(MTO_MON_LOCAL) INTO v_tot_control
          FROM CB_SIM_ASIENTOS_DET
         WHERE FECHA = v_fec_actual
           AND COD_OFICINA = OFI.COD_OFICINA
           AND NRO_ASIENTO = v_nro_asiento;
        ---------------------- CABECERA -------------------------
        INSERT INTO CB_SIM_ASIENTOS
            (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
             COD_MODULO, COD_MODALIDAD,
             TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
             OFI_INTEGRADA, CONFIRMADO)
        VALUES
            (OFI.COD_OFICINA, v_nro_asiento,user,
             v_fec_actual, 2, 21,
             v_tot_control, 'N','N', NULL,'N', 'S');
        v_nro_asiento := v_nro_asiento + 1;
      END IF;
   END LOOP;
   ------- ACTUALIZA PARAMETROS -----
   prg_act_par_dinamico('SIG_NRO_REF_BALANCE',null, null, null, null, v_nro_asiento);
EXCEPTION
   WHEN VALUE_ERROR THEN
     CLOSE CURX;
     raise_application_error(-20000,' ERROR. En valores del Procedure PROCESO_DE_AJUSTE '||'-'||v_lugar);
   WHEN OTHERS THEN
     CLOSE CURX;
     raise_application_error(-20000,'ERROR. en. Rubro:'||v_cod_rubro||'-'||v_lugar||'-'||SQLERRM);
END PR_AJU_DIF_CAMBIOS;

/* Calcula la Utilidad del Balance. */
PROCEDURE PR_CAL_UTILIDAD(p_fecha in ge_calendarios.fec_actual%type) IS
-- Variables.
  v_fec_actual  date := p_fecha;
  ww_sal7       number;
  ww_sal6       number;
  ww_debi       number;
  ww_cred       number;
  ww_dife       number;
  ww_deb_hoy    number;
  ww_cre_hoy    number;
  ww_sal_act    number;
  v_mes         number := to_char(v_fec_actual,'MM');
  v_ano         number := to_char(v_fec_actual,'YYYY');

  -- Cursores.
  cursor  ofi is
     select distinct cod_oficina
       from cb_sim_sal_oficinas;

-- Proceso Principal.
begin
  -- Proceso.
  for o in ofi loop
    ww_sal7 := 0;
    ww_sal6 := 0;
    ww_debi := 0;
    ww_cred := 0;
    -- cargo los rubros de utilidad por si no existan
    insert into cb_sim_sal_oficinas
               (cod_oficina, cod_rubro, ano, mes)
        select o.cod_oficina, b.cod_rubro, v_ano, v_mes
          from cb_rubros b
         where cod_rubro in ('310604180000000','310604180100000','310604180100199',
                             '310604220000000','310604220100000','310604220100199',
                             '310600000000000','310000000000000','300000000000000')
           and not exists (select 0 from cb_sim_sal_oficinas a
                            where a.cod_rubro = b.cod_rubro
                              and a.mes = v_mes
                              and a.ano = v_ano
                              and a.cod_oficina = o.cod_oficina);
    -- saldo de la cuenta GANANCIAS
    begin
    select sum(nvl(sal_mon_loc_ant,0))
      into ww_sal6
      from cb_sim_sal_oficinas
     where cod_rubro = '600000000000000'
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
    -- saldo de la cuenta PERDIDAS
    select sum(nvl(sal_mon_loc_ant,0))
      into ww_sal7
      from cb_sim_sal_oficinas
     where cod_rubro = '700000000000000'
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
    exception
       when others then
        raise_application_error(-20000,'Error al buscar la Ganancia o Perdida de la Oficina '||o.cod_oficina|| ' Mes '||v_mes||'/'||v_ano);
    end;
    -- movimiento debito de hoy de la cuenta 6000000000 y 7000000000
    select sum(nvl(DEB_MON_LOCAL,0))
      into ww_debi
      from cb_sim_sal_oficinas, cb_rubros
     where cb_rubros.cod_rubro = cb_sim_sal_oficinas.cod_rubro
       and imputable = 'S'
       and cod_oficina = o.cod_oficina
       and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
    -- movimiento credito de hoy de la cuenta 6000000000 y 7000000000
    select sum(nvl(CRE_MON_LOCAL,0))
      into ww_cred
      from cb_sim_sal_oficinas, cb_rubros
     where cb_rubros.cod_rubro = cb_sim_sal_oficinas.cod_rubro
       and imputable = 'S'
       and cod_oficina = o.cod_oficina
       and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
    -- halla la diferencia entre ambos movimientos debitos y creditos
    ww_dife :=  abs(nvl(ww_debi,0)-nvl(ww_cred,0));
    -- calculo el saldo actual
    ww_sal_act := nvl(ww_sal6,0) + nvl(ww_sal7,0)+nvl(ww_debi,0)-nvl(ww_cred,0);
    -- calculo el debito y credito de hoy
    if nvl(ww_debi,0) > nvl(ww_cred,0) then
       ww_deb_hoy := nvl(ww_dife,0);
       ww_cre_hoy := 0;
    else
       ww_cre_hoy := nvl(ww_dife,0);
       ww_deb_hoy :=0;
    end if;
    -- si es ganancia
    if ww_sal_act < 0 then
        -- GANANCIA.
        -- actualiza con la diferencia entre ambos saldos
        update cb_sim_sal_oficinas
           set deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in ('310604180000000','310604180100000','310604180100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
        -- cero los datos de las perdidas
        update cb_sim_sal_oficinas
           set deb_mon_local   = 0,
               cre_mon_local   = 0
         where cod_rubro in ('310604220000000','310604220100000','310604220100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    else
        -- perdida
        -- actualiza con la diferencia entre ambos saldos
        update cb_sim_sal_oficinas
           set deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in ('310604180000000','310604180100000','310604180100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
        -- actualiza en cero las ganancias
        update cb_sim_sal_oficinas
           set deb_mon_local   = 0,
               cre_mon_local   = 0
         where cod_rubro in ('310604220000000','310604220100000','310604220100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    end if;
    -- actualizo el padre comun
    update cb_sim_sal_oficinas
           set deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro = '310600000000000'
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    ----------------------------------------
    -- sumarizacion de patrimonio
    ----------------------------------------
    update cb_sim_sal_oficinas
       set deb_mon_local = nvl(deb_mon_local,0) + nvl(ww_deb_hoy,0),
           cre_mon_local = nvl(cre_mon_local,0) + nvl(ww_cre_hoy,0)
     where cod_rubro in ('300000000000000','310000000000000')
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
  end loop;
END PR_CAL_UTILIDAD;

/* Genera el Balance por Sucursal. */
PROCEDURE PR_CON_BALANCE(p_fecha in ge_calendarios.fec_actual%type) IS
  -- Variables.
  v_fec_actual  ge_calendarios.fec_actual%type;
  v_fec_proceso ge_calendarios.fec_actual%type := p_fecha;
BEGIN
   -- Obtiene los datos del último cierre del Balance.
   BEGIN
      SELECT max(a.fecha)
        INTO v_fec_actual
        FROM cb_sal_consolidados_dia a
        WHERE a.fecha <= v_fec_proceso;
   EXCEPTION
      WHEN OTHERS THEN
         v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(2);
   END;

   -- Obtengo los datos de la tabla cb_sal_oficinas_dia.
   BEGIN
      -- El balance por oficinas.
      INSERT INTO cb_sim_sal_oficinas
           SELECT cod_oficina,
                  cod_rubro,
                  to_char(v_fec_proceso,'yyyy'),
                  to_char(v_fec_proceso,'mm'),
                  sal_mon_loc_ant,
                  deb_mon_local,
                  cre_mon_local,
                  sal_ini_mes_mon_local,
                  sal_mon_rub_ant,
                  deb_mon_rubro,
                  cre_mon_rubro,
                  sal_ini_mes_mon_rubro,
                  sal_ini_mes_mon_fuerte,
                  protegido,
                  sal_equ_loc_ant,
                  deb_equ_local,
                  cre_equ_local,
                  sal_ini_mes_equ_local,
                  usu_insercion,
                  fec_insercion,
                  usu_modificacion,
                  fec_modificacion
             FROM cb_sal_oficinas_dia m
            WHERE m.fecha = v_fec_actual;

      -- El balance consolidado.
      INSERT INTO cb_sim_sal_consolidados
           SELECT cod_rubro,
                  to_char(v_fec_proceso,'yyyy'),
                  to_char(v_fec_proceso,'mm'),
                  sal_mon_loc_ant,
                  deb_mon_local,
                  cre_mon_local,
                  sal_ini_mes_mon_local,
                  sal_mon_rub_ant,
                  deb_mon_rubro,
                  cre_mon_rubro,
                  sal_ini_mes_mon_rubro,
                  protegido,
                  sal_equ_loc_ant,
                  deb_equ_local,
                  cre_equ_local,
                  sal_ini_mes_equ_local,
                  usu_insercion,
                  fec_insercion,
                  usu_modificacion,
                  fec_modificacion
             FROM cb_sal_consolidados_dia m
            WHERE m.fecha = v_fec_actual;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error en PR_CON_BALANCE - Inserta Datos: ' ||' - '|| sqlerrm);
   END;

   -- Ejecuto la generación del Balance.
   BEGIN
      PR_ASI_FUTUROS(v_fec_proceso);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error en PR_ASI_FUTUROS - Gen. Bal.: ' ||' - '|| sqlerrm);
   END;

   BEGIN
      PR_ASI_AUTOMATICOS(v_fec_proceso);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error en PR_ASI_AUTOMATICOS - Gen. Bal.: ' ||' - '|| sqlerrm);
   END;

   BEGIN
      PR_ACT_SALDOS(v_fec_proceso);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error en PR_ACT_SALDOS - Gen. Bal.: ' ||' - '|| sqlerrm);
   END;

   BEGIN
      PR_SUM_SAL_OFICINAS(v_fec_proceso);
      PR_SUM_SAL_CONSOLIDADOS(v_fec_proceso);
      PR_AJU_DIF_CAMBIOS(v_fec_proceso);
      PR_SUM_SAL_OFICINAS(v_fec_proceso);
      PR_SUM_SAL_CONSOLIDADOS(v_fec_proceso);
      PR_CAL_UTILIDAD(v_fec_proceso);
      PR_SUM_SAL_OFICINAS(v_fec_proceso);
      PR_SUM_SAL_CONSOLIDADOS(v_fec_proceso);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error en PR_CON_BALANCE - Genera Balance: ' ||' - '|| sqlerrm);
   END;
END PR_CON_BALANCE;

/* Proceso Principal que Genera el Balance Proyectado. */
PROCEDURE PR_GEN_BALANCE(p_fecha_proceso IN DATE) IS
  -- Variables.
  v_fec_actual  ge_calendarios.fec_actual%type := p_fecha_proceso;
  v_msj         varchar2(250);
BEGIN
    -- Actualizo el nro. de referencia de los asientos.
    prg_act_par_dinamico('SIG_NRO_REF_BALANCE', NULL, NULL, NULL, NULL, 1);

    -- Elimino los registro de las tablas.
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_sal_oficinas DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20002, v_msj);
    end if;

    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_sal_consolidados DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20001, v_msj);
    end if;

    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_asientos_det DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20002, v_msj);
    end if;

    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_asientos DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20001, v_msj);
    end if;

    -- Ejecuto la generación del Balance.
    BEGIN
       PR_CON_BALANCE(v_fec_actual);
    EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20001, 'Error en PR_GEN_BALANCE' ||' - '|| sqlerrm);
    END;

END PR_GEN_BALANCE;

PROCEDURE PR_TOTALIZA_ITEM (
   p_fec_proceso IN DATE,
   p_nro_item_padre IN NUMBER,
   p_items_hijos IN VARCHAR2
) IS
BEGIN
   UPDATE it.sb_lcr_inf_final f
      SET (f.sal_guaranies,
           f.sal_extranjera,
           f.sal_total,
           f.sal_gua_ponderado,
           f.sal_ext_ponderado,
           f.sal_tot_ponderado) =
          (
           SELECT NVL(SUM(h.sal_guaranies), 0),
                  NVL(SUM(h.sal_extranjera), 0),
                  NVL(SUM(h.sal_total), 0),
                  NVL(SUM(h.sal_gua_ponderado), 0),
                  NVL(SUM(h.sal_ext_ponderado), 0),
                  NVL(SUM(h.sal_tot_ponderado), 0)
             FROM it.sb_lcr_inf_final h
            WHERE h.fec_proceso = p_fec_proceso
              AND h.nro_item IN (
                  SELECT TO_NUMBER(REGEXP_SUBSTR(p_items_hijos, '[^,]+', 1, LEVEL))
                    FROM dual
                 CONNECT BY REGEXP_SUBSTR(p_items_hijos, '[^,]+', 1, LEVEL) IS NOT NULL
              )
          )
    WHERE f.fec_proceso = p_fec_proceso
      AND f.nro_item = p_nro_item_padre;
END pr_totaliza_item;

PROCEDURE PR_TOTALIZA_SALDOS_LCR (
   p_fec_proceso IN DATE
) IS
BEGIN
   pr_totaliza_item(p_fec_proceso, 96, '21,22,23,24,25,26,27,5,28,29,6,30,31,32,33');

   pr_totaliza_item(p_fec_proceso, 34, '62,63');
   pr_totaliza_item(p_fec_proceso, 35, '64,65');
   pr_totaliza_item(p_fec_proceso, 7, '34,35,36');

   pr_totaliza_item(p_fec_proceso, 66, '79,80');
   pr_totaliza_item(p_fec_proceso, 67, '81,82');
   pr_totaliza_item(p_fec_proceso, 38, '69,70');
   pr_totaliza_item(p_fec_proceso, 8, '66,67,68,38');


   pr_totaliza_item(p_fec_proceso, 83, '89');
   pr_totaliza_item(p_fec_proceso, 84, '90,85');
   pr_totaliza_item(p_fec_proceso, 69, '83,84');

   pr_totaliza_item(p_fec_proceso, 86, '91,92');
   pr_totaliza_item(p_fec_proceso, 87, '93,94');
   pr_totaliza_item(p_fec_proceso, 70, '86,87,88');

   pr_totaliza_item(p_fec_proceso, 39, '71,72,73,74,75,76,77,78');

   pr_totaliza_item(p_fec_proceso, 9, '40,41,42,43');
   pr_totaliza_item(p_fec_proceso, 10, '44,45,46,47');
   pr_totaliza_item(p_fec_proceso, 11, '48,49,50');

   pr_totaliza_item(p_fec_proceso, 14, '51,52,53,54');
   pr_totaliza_item(p_fec_proceso, 15, '55,56');
   pr_totaliza_item(p_fec_proceso, 17, '57,58,59');
   pr_totaliza_item(p_fec_proceso, 20, '60,61');

   pr_totaliza_item(p_fec_proceso, 99, '7,8,39,9,10,11,12,13');
   pr_totaliza_item(p_fec_proceso, 100, '14,15,16,17,18,19,20');
END pr_totaliza_saldos_lcr;

PROCEDURE PR_CALCULA_ITEMS_LCR (
   p_fec_proceso IN DATE
) IS
BEGIN
   -- ITEM 101 - FONDO ALAC (I)
   UPDATE it.sb_lcr_inf_final f
      SET (f.sal_guaranies,
           f.sal_extranjera,
           f.sal_total,
           f.sal_gua_ponderado,
           f.sal_ext_ponderado,
           f.sal_tot_ponderado) =
          (
           SELECT NVL(i.sal_gua_ponderado, 0),
                  NVL(i.sal_ext_ponderado, 0),
                  NVL(i.sal_tot_ponderado, 0),
                  NVL(i.sal_gua_ponderado, 0),
                  NVL(i.sal_ext_ponderado, 0),
                  NVL(i.sal_tot_ponderado, 0)
             FROM it.sb_lcr_inf_final i
            WHERE i.fec_proceso = p_fec_proceso
              AND i.nro_item = 96
          )
    WHERE f.fec_proceso = p_fec_proceso
      AND f.nro_item = 101;

   -- ITEM 102 - SALIDAS DE EFECTIVO NETAS
   UPDATE it.sb_lcr_inf_final f
      SET (f.sal_guaranies,
           f.sal_extranjera,
           f.sal_total,
           f.sal_gua_ponderado,
           f.sal_ext_ponderado,
           f.sal_tot_ponderado) =
          (
           SELECT NVL(s.sal_gua_ponderado, 0) - LEAST(NVL(e.sal_gua_ponderado, 0), NVL(s.sal_gua_ponderado, 0) * 0.75),
                  NVL(s.sal_ext_ponderado, 0) - LEAST(NVL(e.sal_ext_ponderado, 0), NVL(s.sal_ext_ponderado, 0) * 0.75),
                  NVL(s.sal_tot_ponderado, 0) - LEAST(NVL(e.sal_tot_ponderado, 0), NVL(s.sal_tot_ponderado, 0) * 0.75),
                  NVL(s.sal_gua_ponderado, 0) - LEAST(NVL(e.sal_gua_ponderado, 0), NVL(s.sal_gua_ponderado, 0) * 0.75),
                  NVL(s.sal_ext_ponderado, 0) - LEAST(NVL(e.sal_ext_ponderado, 0), NVL(s.sal_ext_ponderado, 0) * 0.75),
                  NVL(s.sal_tot_ponderado, 0) - LEAST(NVL(e.sal_tot_ponderado, 0), NVL(s.sal_tot_ponderado, 0) * 0.75)
             FROM it.sb_lcr_inf_final s,
                  it.sb_lcr_inf_final e
            WHERE s.fec_proceso = p_fec_proceso
              AND e.fec_proceso = p_fec_proceso
              AND s.nro_item = 99
              AND e.nro_item = 100
          )
    WHERE f.fec_proceso = p_fec_proceso
      AND f.nro_item = 102;

   -- ITEM 103 - LCR
   UPDATE it.sb_lcr_inf_final f
      SET (f.sal_guaranies,
           f.sal_extranjera,
           f.sal_total,
           f.sal_gua_ponderado,
           f.sal_ext_ponderado,
           f.sal_tot_ponderado) =
          (
           SELECT CASE WHEN NVL(n.sal_guaranies, 0) = 0 THEN 0 ELSE NVL(a.sal_guaranies, 0) / n.sal_guaranies END,
                  CASE WHEN NVL(n.sal_extranjera, 0) = 0 THEN 0 ELSE NVL(a.sal_extranjera, 0) / n.sal_extranjera END,
                  CASE WHEN NVL(n.sal_total, 0) = 0 THEN 0 ELSE NVL(a.sal_total, 0) / n.sal_total END,
                  CASE WHEN NVL(n.sal_guaranies, 0) = 0 THEN 0 ELSE NVL(a.sal_guaranies, 0) / n.sal_guaranies END,
                  CASE WHEN NVL(n.sal_extranjera, 0) = 0 THEN 0 ELSE NVL(a.sal_extranjera, 0) / n.sal_extranjera END,
                  CASE WHEN NVL(n.sal_total, 0) = 0 THEN 0 ELSE NVL(a.sal_total, 0) / n.sal_total END
             FROM it.sb_lcr_inf_final a,
                  it.sb_lcr_inf_final n
            WHERE a.fec_proceso = p_fec_proceso
              AND n.fec_proceso = p_fec_proceso
              AND a.nro_item = 101
              AND n.nro_item = 102
          )
    WHERE f.fec_proceso = p_fec_proceso
      AND f.nro_item = 103;
END pr_calcula_items_lcr;

PROCEDURE PR_CARGAR_SAL_EFE (p_fecha_proceso IN DATE) IS

  v_fec_proceso ge_calendarios.fec_actual%TYPE := p_fecha_proceso;

BEGIN

    IF v_fec_proceso IS NULL THEN
        RAISE_APPLICATION_ERROR(-20300, 'Fecha de proceso requerida');
    END IF;

    INSERT /*+ APPEND */ INTO IT.SB_LCR_LIQ_INV_TMP
    (fecha, cod_persona, tipo, deposito, saldo_total, sal_vista_gs, sal_vista_ext, sal_plazo_gs, sal_plazo_ext, sal_res_gs, sal_res_ext)

      select c.fecha, r.cod_persona, p.tipo, CASE WHEN p.tipo = 'F' THEN 1 ELSE 2 END deposito,
             sum(case when c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) > 30 then 0 else
                 round((d.sal_actual * nvl((select cot.val_conversion
                                                  from ge_cotizaciones cot
                                                  where cot.cod_moneda = c.cod_moneda
                                                    and cot.fecha = c.fecha),1)),0) end) saldo_total,
             sum(case when c.cod_moneda = 'GS' and c.cod_modalidad IN ('31', '39', '334', '41') THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                                                                        from ge_cotizaciones cot
                                                                                                        where cot.cod_moneda = c.cod_moneda
                                                                                                          and cot.fecha = c.fecha),1)),0) else 0 end) sal_vista_gs,
             sum(case when c.cod_moneda <> 'GS' and c.cod_modalidad IN ('31', '39', '334', '41') THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                                                                        from ge_cotizaciones cot
                                                                                                        where cot.cod_moneda = c.cod_moneda
                                                                                                          and cot.fecha = c.fecha),1)),0) else 0 end) sal_vista_ext,
             sum(case when c.cod_moneda = 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) <= 30
                         THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                          from ge_cotizaciones cot
                                                          where cot.cod_moneda = c.cod_moneda
                                                            and cot.fecha = c.fecha),1)),0) else 0 end) sal_plazo_gs,
             sum(case when c.cod_moneda <> 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) <= 30
                         THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                          from ge_cotizaciones cot
                                                          where cot.cod_moneda = c.cod_moneda
                                                            and cot.fecha = c.fecha),1)),0) else 0 end) sal_plazo_ext,
             sum(case when c.cod_moneda = 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) > 30
                         THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                          from ge_cotizaciones cot
                                                          where cot.cod_moneda = c.cod_moneda
                                                            and cot.fecha = c.fecha),1)),0) else 0 end) sal_res_gs,
             sum(case when c.cod_moneda <> 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) > 30
                         THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                          from ge_cotizaciones cot
                                                          where cot.cod_moneda = c.cod_moneda
                                                            and cot.fecha = c.fecha),1)),0) else 0 end) sal_res_ext
      from cb_sal_inventarios_his c, cb_sal_inventarios_det_his d, ge_cta_clientes r, ba_personas p, ge_clientes cl, ge_cuentas cu
      where c.fecha          = v_fec_proceso
        and c.cod_modalidad  in (31,334,41,39,33,36,37,38)
        and ((c.cod_modalidad = 41 and c.tip_saldo in ('C','Q')) or (c.tip_saldo = 'C' ))
        and c.situacion      not in ('A','T')
        and d.fecha          = c.fecha
        and d.nro_referencia = c.nro_referencia
        and d.nro_cuenta     = r.nro_cuenta
        and r.relacion       = 'P'
        and p.cod_persona    = r.cod_persona
        and p.cod_persona    <> '1'
        and cl.cod_persona   = p.cod_persona
        and (cl.cod_seg_cliente is null or cl.cod_seg_cliente <> 12)
        and d.sal_actual     > 0
        and cu.nro_cuenta    = r.nro_cuenta
        and cu.estado        <> 'T'
      group by c.fecha, r.cod_persona, p.tipo;   
    
COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20303, 'Error en PR_CARGAR_SAL_EFE: ' || SQLERRM);
END PR_CARGAR_SAL_EFE;

END PAS_LCR;
/
