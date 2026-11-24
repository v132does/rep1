create or replace PROCEDURE IT.PRS_ACT_SOL_RUBROS
AS
    /*
       Cada registro se procesa de forma independiente con SAVEPOINT.
       Un error en un registro no revierte los anteriores.
       Se usa ROWID para identificar cada fila (sin necesidad de PK).
       Al finalizar todos los registros se hace un COMMIT global.
       Los errores se registran en IT.SB_SOL_LOGS via IT.PAS_SOL.PR_REGISTRAR_LOG.
    */

    v_id_ejecucion VARCHAR2(36);
    v_count        NUMBER;
    v_error        VARCHAR2(500);
    v_ok           NUMBER := 0;
    v_err          NUMBER := 0;

    CURSOR c_pendientes IS
        SELECT ROWID AS RID, t.*
        FROM IT.SB_SOL_RUBROS_TMP t
        WHERE ACCION IN ('I','U','D')
        ORDER BY REPORTE, RUBRO;

BEGIN

    v_id_ejecucion := LOWER(
        SUBSTR(SYS_GUID(), 1, 8)  || '-' ||
        SUBSTR(SYS_GUID(), 9, 4)  || '-' ||
        SUBSTR(SYS_GUID(), 13, 4) || '-' ||
        SUBSTR(SYS_GUID(), 17, 4) || '-' ||
        SUBSTR(SYS_GUID(), 21, 12)
    );

    IT.PAS_SOL.PR_REGISTRAR_LOG(
        p_id_ejecucion => v_id_ejecucion,
        p_tipo_log     => 'INFO',
        p_mensaje      => 'PRS_ACT_SOL_RUBROS: Inicio del proceso de actualizacion de rubros'
    );

    FOR r IN c_pendientes LOOP

        SAVEPOINT sp_registro;

        BEGIN

            IF TRIM(r.RUBRO) IS NULL and upper(r.reporte) != 'PLANTILLA DE SOLVENCIA' THEN
                IT.PAS_SOL.PR_REGISTRAR_LOG(
                    p_id_ejecucion => v_id_ejecucion,
                    p_tipo_log     => 'ERROR',
                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: COD_RUBRO no puede ser nulo para la accion ' || UPPER(r.ACCION)
                );
                RAISE_APPLICATION_ERROR(-20010,
                    'COD_RUBRO no puede ser nulo para la accion ' || upper(r.ACCION) || '.');
            END IF;

            IF TRIM(r.REPORTE) IS NULL THEN
                IT.PAS_SOL.PR_REGISTRAR_LOG(
                    p_id_ejecucion => v_id_ejecucion,
                    p_tipo_log     => 'ERROR',
                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: La columna REPORTE no puede ser nula'
                );
                RAISE_APPLICATION_ERROR(-20011,
                    'La columna REPORTE no puede ser nula.');
            END IF;

            CASE UPPER(TRIM(r.REPORTE))

                WHEN 'BANCO PAIS' THEN

                    SELECT COUNT(1) INTO v_count
                    FROM IT.CB_RUBROS_BCO_PAIS
                    WHERE RUBRO = r.RUBRO;

                    CASE upper(r.ACCION)
                        WHEN 'I' THEN
                            IF v_count > 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_PAIS: ya existe RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20020,
                                    'CB_RUBROS_BCO_PAIS: ya existe RUBRO=' || r.RUBRO);
                            END IF;
                            IF r.SECCION NOT IN ('Bancos Oficiales del Pais', 'Bancos del Pais') THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_PAIS: SECCION invalida para RUBRO=' || r.RUBRO
                                                      || '. Valor recibido: [' || r.SECCION || ']'
                                                      || '. Valores permitidos: Bancos Oficiales del Pais, Bancos del Pais'
                                );
                                RAISE_APPLICATION_ERROR(-20023,
                                    'CB_RUBROS_BCO_PAIS: SECCION invalida [' || r.SECCION || '] para RUBRO=' || r.RUBRO
                                    || '. Valores permitidos: ''Bancos Oficiales del Pais'', ''Bancos del Pais''.');
                            END IF;
                            INSERT INTO IT.CB_RUBROS_BCO_PAIS
                                (RUBRO, DESCRIPCION, SECCION)
                            VALUES
                                (r.RUBRO, r.DESCRIPCION, r.SECCION);

                        WHEN 'U' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_PAIS: no existe RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20021,
                                    'CB_RUBROS_BCO_PAIS: no existe RUBRO=' || r.RUBRO);
                            END IF;
                            IF r.SECCION NOT IN ('Bancos Oficiales del Pais', 'Bancos del Pais') THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_PAIS: SECCION invalida para RUBRO=' || r.RUBRO
                                                      || '. Valor recibido: [' || r.SECCION || ']'
                                                      || '. Valores permitidos: Bancos Oficiales del Pais, Bancos del Pais'
                                );
                                RAISE_APPLICATION_ERROR(-20023,
                                    'CB_RUBROS_BCO_PAIS: SECCION invalida [' || r.SECCION || '] para RUBRO=' || r.RUBRO
                                    || '. Valores permitidos: ''Bancos Oficiales del Pais'', ''Bancos del Pais''.');
                            END IF;
                            UPDATE IT.CB_RUBROS_BCO_PAIS
                            SET DESCRIPCION = r.DESCRIPCION,
                                SECCION     = r.SECCION
                            WHERE RUBRO = r.RUBRO;

                        WHEN 'D' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_PAIS: no existe RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20022,
                                    'CB_RUBROS_BCO_PAIS: no existe RUBRO=' || r.RUBRO);
                            END IF;
                            DELETE FROM IT.CB_RUBROS_BCO_PAIS
                            WHERE RUBRO = r.RUBRO;
                    END CASE;

                WHEN 'BANCO EXTERIOR' THEN

                    SELECT COUNT(1) INTO v_count
                    FROM IT.CB_RUBROS_BCO_EXTERIOR
                    WHERE COD_RUBRO = r.RUBRO;

                    CASE upper(r.ACCION)
                        WHEN 'I' THEN
                            IF v_count > 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_EXTERIOR: ya existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20030,
                                    'CB_RUBROS_BCO_EXTERIOR: ya existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            SELECT COUNT(1) INTO v_count
                              FROM ge_cotizaciones
                             WHERE cod_moneda = r.COD_MONEDA
                               AND fecha = (SELECT fec_actual FROM ge_calendarios WHERE cod_modulo = 1);
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_EXTERIOR: COD_MONEDA=' || r.COD_MONEDA
                                                      || ' no tiene cotizacion en ge_cotizaciones para la fecha actual'
                                );
                                RAISE_APPLICATION_ERROR(-20033,
                                    'CB_RUBROS_BCO_EXTERIOR: COD_MONEDA=' || r.COD_MONEDA
                                    || ' no tiene cotizacion en ge_cotizaciones para la fecha actual.');
                            END IF;
                            INSERT INTO IT.CB_RUBROS_BCO_EXTERIOR
                                (COD_RUBRO, DESCRIPCION, PAIS, CIUDAD, COD_MONEDA)
                            VALUES
                                (r.RUBRO, r.DESCRIPCION, r.PAIS, r.CIUDAD, r.COD_MONEDA);

                        WHEN 'U' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_EXTERIOR: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20031,
                                    'CB_RUBROS_BCO_EXTERIOR: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            SELECT COUNT(1) INTO v_count
                              FROM ge_cotizaciones
                             WHERE cod_moneda = r.COD_MONEDA
                               AND fecha = (SELECT fec_actual FROM ge_calendarios WHERE cod_modulo = 1);
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_EXTERIOR: COD_MONEDA=' || r.COD_MONEDA
                                                      || ' no tiene cotizacion en ge_cotizaciones para la fecha actual'
                                );
                                RAISE_APPLICATION_ERROR(-20033,
                                    'CB_RUBROS_BCO_EXTERIOR: COD_MONEDA=' || r.COD_MONEDA
                                    || ' no tiene cotizacion en ge_cotizaciones para la fecha actual.');
                            END IF;
                            UPDATE IT.CB_RUBROS_BCO_EXTERIOR
                            SET DESCRIPCION = r.DESCRIPCION,
                                PAIS        = r.PAIS,
                                CIUDAD      = r.CIUDAD,
                                COD_MONEDA  = r.COD_MONEDA
                            WHERE COD_RUBRO = r.RUBRO;

                        WHEN 'D' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_RUBROS_BCO_EXTERIOR: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20032,
                                    'CB_RUBROS_BCO_EXTERIOR: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            DELETE FROM IT.CB_RUBROS_BCO_EXTERIOR
                            WHERE COD_RUBRO = r.RUBRO;
                    END CASE;

                WHEN 'MONTO CONTIGENCIA' THEN

                    SELECT COUNT(1) INTO v_count
                    FROM IT.CB_MTO_CONTG_RUBROS
                    WHERE COD_RUBRO = r.RUBRO;

                    CASE upper(r.ACCION)
                        WHEN 'I' THEN
                            IF v_count > 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_MTO_CONTG_RUBROS: ya existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20040,
                                    'CB_MTO_CONTG_RUBROS: ya existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            IF (R.PONDERACION is null or R.PONDERACION NOT IN (0, 20, 50, 100)) OR R.ORDEN IS NULL THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_MTO_CONTG_RUBROS: Ponderacion incorrecta u ORDEN nulo para RUBRO=' || R.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20041,
                                    'CB_MTO_CONTG_RUBROS: error con el rubro = ' || R.RUBRO|| ' Ponderacion incorrecta u orden null');
                            END IF;
                            INSERT INTO IT.CB_MTO_CONTG_RUBROS
                                (COD_RUBRO, DESCRIPCION, PONDERACION, ORDEN)
                            VALUES
                                (r.RUBRO, r.DESCRIPCION, r.PONDERACION, r.ORDEN);

                        WHEN 'U' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_MTO_CONTG_RUBROS: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20041,
                                    'CB_MTO_CONTG_RUBROS: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            IF (R.PONDERACION is null or R.PONDERACION NOT IN (0, 20, 50, 100)) OR R.ORDEN IS NULL THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_MTO_CONTG_RUBROS: Ponderacion incorrecta u ORDEN nulo para RUBRO=' || R.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20041,
                                    'CB_MTO_CONTG_RUBROS: error con el rubro = ' || R.RUBRO|| ' Ponderacion incorrecta u orden null');
                            END IF;
                            UPDATE IT.CB_MTO_CONTG_RUBROS
                            SET DESCRIPCION = r.DESCRIPCION,
                                PONDERACION = r.PONDERACION,
                                ORDEN       = r.ORDEN
                            WHERE COD_RUBRO = r.RUBRO;

                        WHEN 'D' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: CB_MTO_CONTG_RUBROS: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20042,
                                    'CB_MTO_CONTG_RUBROS: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            DELETE FROM IT.CB_MTO_CONTG_RUBROS
                            WHERE COD_RUBRO = r.RUBRO;
                    END CASE;

                WHEN 'PLANTILLA DE SOLVENCIA' THEN
                if r.rubro is not null then
                   SELECT COUNT(1) INTO v_count
                    FROM IT.SB_SOL_CONFIGURACIONES
                    WHERE 1 = 1 
                      AND COD_RUBRO = r.RUBRO;
                else 
                    SELECT COUNT(1) INTO v_count
                    FROM IT.SB_SOL_CONFIGURACIONES
                    WHERE 1 = 1 
                      AND orden = r.orden
                      AND COD_RUBRO is null;
                end if;

                    CASE upper(r.ACCION)
                        WHEN 'I' THEN
                            IF v_count > 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: SB_SOL_CONFIGURACIONES: ya existe COD_RUBRO=' || r.RUBRO||' para este orden'|| r.orden
                                );
                                RAISE_APPLICATION_ERROR(-20050,
                                    'SB_SOL_CONFIGURACIONES: ya existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            IF R.ORDEN IS NULL OR (r.CATEGORIA IS NULL or r.CATEGORIA not in (1,2,3,4)) THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: SB_SOL_CONFIGURACIONES: ORDEN nulo o CATEGORIA nula para RUBRO=' || R.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20041,
                                    'SB_SOL_CONFIGURACIONES: error con el rubro = ' || R.RUBRO|| ' orden null o categoria is null');
                            END IF;
                            INSERT INTO IT.SB_SOL_CONFIGURACIONES
                                (COD_RUBRO, DESCRIPCION, CLASIFICACION, ORDEN, CATEGORIA, COD_RUBRO_RTP)
                            VALUES
                                (r.RUBRO, r.DESCRIPCION, SUBSTR(r.CLASIFICACION,1,1), r.ORDEN, r.CATEGORIA, r.COD_RUBRO_RPT);

                        WHEN 'U' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: SB_SOL_CONFIGURACIONES: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20051,
                                    'SB_SOL_CONFIGURACIONES: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            IF R.ORDEN IS NULL OR (r.CATEGORIA IS NULL or r.CATEGORIA not in (1,2,3,4))THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: SB_SOL_CONFIGURACIONES: ORDEN nulo o CATEGORIA nula para RUBRO=' || R.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20041,
                                    'SB_SOL_CONFIGURACIONES: error con el rubro = ' || R.RUBRO|| ' orden null o categoria is null');
                            END IF;
                            if r.RUBRO is not null then
                                UPDATE IT.SB_SOL_CONFIGURACIONES
                                SET DESCRIPCION   = r.DESCRIPCION,
                                    CLASIFICACION = SUBSTR(r.CLASIFICACION,1,1),
                                    ORDEN         = r.ORDEN,
                                    CATEGORIA     = r.CATEGORIA,
                                    COD_RUBRO_RTP = r.COD_RUBRO_RPT
                                WHERE COD_RUBRO = r.RUBRO;
                            else 
                                UPDATE IT.SB_SOL_CONFIGURACIONES
                                SET DESCRIPCION   = r.DESCRIPCION,
                                    CLASIFICACION = SUBSTR(r.CLASIFICACION,1,1),
                                    COD_RUBRO     = r.RUBRO,
                                    CATEGORIA     = r.CATEGORIA,
                                    COD_RUBRO_RTP = r.COD_RUBRO_RPT
                                WHERE ORDEN       = r.ORDEN
								   AND COD_RUBRO IS NULL;
                            end if;

                        WHEN 'D' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: SB_SOL_CONFIGURACIONES: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20052,
                                    'SB_SOL_CONFIGURACIONES: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            if r.RUBRO is not null then
                                DELETE FROM IT.SB_SOL_CONFIGURACIONES
                                WHERE COD_RUBRO = r.RUBRO;
                            else 
                                DELETE FROM IT.SB_SOL_CONFIGURACIONES
                                WHERE ORDEN  = r.ORDEN
								  AND COD_RUBRO IS NULL;
                            end if;
                    END CASE;

                WHEN 'PRATIMONIO EFECTIVO' THEN

                    SELECT COUNT(1) INTO v_count
                    FROM IT.TMP_COD_RUBRO_FILTRO
                    WHERE COD_RUBRO = r.RUBRO;

                    CASE upper(r.ACCION)
                        WHEN 'I' THEN
                            IF v_count > 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: TMP_COD_RUBRO_FILTRO: ya existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20060,
                                    'TMP_COD_RUBRO_FILTRO: ya existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            INSERT INTO IT.TMP_COD_RUBRO_FILTRO
                                (COD_RUBRO, DESCRIPCION, SECCION, ACTIVO, ORDEN,
                                 USU_CREACION, FEC_CREACION, USU_MODIFICACION, FEC_MODIFICACION)
                            VALUES
                                (r.RUBRO, r.DESCRIPCION, r.SECCION, NVL(r.ACTIVO,'S'), NVL(r.ORDEN,0),
                                 USER, SYSDATE, USER, SYSDATE);

                        WHEN 'U' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: TMP_COD_RUBRO_FILTRO: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20061,
                                    'TMP_COD_RUBRO_FILTRO: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            UPDATE IT.TMP_COD_RUBRO_FILTRO
                            SET DESCRIPCION      = r.DESCRIPCION,
                                SECCION          = r.SECCION,
                                ACTIVO           = NVL(r.ACTIVO,'S'),
                                ORDEN            = NVL(r.ORDEN,0),
                                USU_MODIFICACION = USER,
                                FEC_MODIFICACION = SYSDATE
                            WHERE COD_RUBRO = r.RUBRO;

                        WHEN 'D' THEN
                            IF v_count = 0 THEN
                                IT.PAS_SOL.PR_REGISTRAR_LOG(
                                    p_id_ejecucion => v_id_ejecucion,
                                    p_tipo_log     => 'ERROR',
                                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: TMP_COD_RUBRO_FILTRO: no existe COD_RUBRO=' || r.RUBRO
                                );
                                RAISE_APPLICATION_ERROR(-20062,
                                    'TMP_COD_RUBRO_FILTRO: no existe COD_RUBRO=' || r.RUBRO);
                            END IF;
                            DELETE FROM IT.TMP_COD_RUBRO_FILTRO
                            WHERE COD_RUBRO = r.RUBRO;
                    END CASE;

                ELSE
                    IT.PAS_SOL.PR_REGISTRAR_LOG(
                        p_id_ejecucion => v_id_ejecucion,
                        p_tipo_log     => 'ERROR',
                        p_mensaje      => 'PRS_ACT_SOL_RUBROS: Reporte no reconocido: ' || r.REPORTE
                    );
                    RAISE_APPLICATION_ERROR(-20099,
                        'Reporte no reconocido: ' || r.REPORTE);

            END CASE;

            v_ok := v_ok + 1;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO sp_registro;
                v_error := SUBSTR(SQLERRM, 1, 500);
                v_err   := v_err + 1;
                IT.PAS_SOL.PR_REGISTRAR_LOG(
                    p_id_ejecucion => v_id_ejecucion,
                    p_tipo_log     => 'WARNING',
                    p_mensaje      => 'PRS_ACT_SOL_RUBROS: Error en registro - RUBRO=' || r.RUBRO
                                      || ' | REPORTE=' || r.REPORTE
                                      || ' | ACCION=' || r.ACCION
                                      || ' | ' || v_error
                );
        END;

    END LOOP;

    COMMIT;
    EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.SB_SOL_RUBROS_TMP';

    IT.PAS_SOL.PR_REGISTRAR_LOG(
        p_id_ejecucion       => v_id_ejecucion,
        p_tipo_log           => 'SUCCESS',
        p_mensaje            => 'PRS_ACT_SOL_RUBROS: Proceso completado. OK: ' || v_ok || ' | Errores: ' || v_err,
        p_cantidad_registros => v_ok
    );

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IT.PAS_SOL.PR_REGISTRAR_LOG(
            p_id_ejecucion  => v_id_ejecucion,
            p_tipo_log      => 'ERROR',
            p_mensaje       => 'PRS_ACT_SOL_RUBROS: Error inesperado: ' || SQLERRM,
            p_detalle_error => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
        BEGIN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.SB_SOL_RUBROS_TMP';
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        RAISE;

END PRS_ACT_SOL_RUBROS;
/

GRANT EXECUTE ON IT.PRS_ACT_SOL_RUBROS TO IT_TEMPORAL;
CREATE OR REPLACE PUBLIC SYNONYM PRS_ACT_SOL_RUBROS FOR IT.PRS_ACT_SOL_RUBROS;