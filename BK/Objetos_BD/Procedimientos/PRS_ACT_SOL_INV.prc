-- =====================================================================
-- PROCEDIMIENTO: IT.PRS_ACT_SOL_INV
-- Descripción  : Transfiere el inventario de colocaciones desde la
--                tabla staging SB_SOL_INV_TMP hacia CB_SOLVENCIA_INV,
--                aplicando validaciones y conversiones de tipo.
--                Al finalizar trunca SB_SOL_INV_TMP.
-- Esquema      : IT
-- =====================================================================
create or replace PROCEDURE IT.PRS_ACT_SOL_INV
AS
    -- ---------------------------------------------------------------
    -- Variables de control
    -- ---------------------------------------------------------------
    v_id_ejecucion      VARCHAR2(36);
    v_total_tmp         NUMBER := 0;
    v_insertados        NUMBER := 0;
    v_rechazados        NUMBER := 0;
    v_ts_inicio         TIMESTAMP;

    -- ---------------------------------------------------------------
    -- Cursor de lectura de staging
    -- ---------------------------------------------------------------
    CURSOR c_staging IS
        SELECT TRUNC(FECHA) FECHA,
               TIP_DEUDOR,
               NRO_CUENTA,
               COD_PERSONA,
               NRO_DOCUMENTO,
               NOMBRE,
               COD_MODULO,
               COD_MODALIDAD,
               MODAL,
               COD_OFICINA,
               DESC_OFI,
               COD_MONEDA,
               TIP_SALDO,
               SITUACION,
               ESTADO,
               FEC_APERTURA,
               FEC_VENCIMIENTO,
               VAL_TASA,
               COD_RUBRO,
               DES_RUBRO,
               SAL_ACTUAL
          FROM IT.SB_SOL_INV_TMP;

    -- ---------------------------------------------------------------
    -- Variables de trabajo por fila
    -- ---------------------------------------------------------------
    v_fecha             DATE;
    v_fec_apertura      DATE;
    v_fec_vencimiento   DATE;
    v_cod_rubro         NUMBER;
    v_fila_valida       BOOLEAN;
    v_motivo_rechazo    VARCHAR2(500);

BEGIN
    v_ts_inicio    := SYSTIMESTAMP;
    v_id_ejecucion := LOWER(
        SUBSTR(SYS_GUID(), 1, 8)  || '-' ||
        SUBSTR(SYS_GUID(), 9, 4)  || '-' ||
        SUBSTR(SYS_GUID(), 13, 4) || '-' ||
        SUBSTR(SYS_GUID(), 17, 4) || '-' ||
        SUBSTR(SYS_GUID(), 21, 12)
    );

    -- -----------------------------------------------------------
    -- 1. Registrar inicio del proceso
    -- -----------------------------------------------------------
    IT.PAS_SOL.PR_REGISTRAR_LOG(
        p_id_ejecucion => v_id_ejecucion,
        p_tipo_log     => 'INFO',
        p_mensaje      => 'PRS_ACT_SOL_INV: Inicio de carga de inventario de colocaciones'
    );

    -- -----------------------------------------------------------
    -- 2. Validar que la tabla staging tenga registros
    -- -----------------------------------------------------------
    SELECT COUNT(*) INTO v_total_tmp FROM IT.SB_SOL_INV_TMP;

    IF v_total_tmp = 0 THEN
        IT.PAS_SOL.PR_REGISTRAR_LOG(
            p_id_ejecucion => v_id_ejecucion,
            p_tipo_log     => 'ERROR',
            p_mensaje      => 'PRS_ACT_SOL_INV: La tabla SB_SOL_INV_TMP no contiene registros. Proceso abortado.'
        );
        RAISE_APPLICATION_ERROR(-20001,
            'PRS_ACT_SOL_INV: La tabla SB_SOL_INV_TMP esta vacia. Cargue el archivo antes de ejecutar el proceso.');
    END IF;

    IT.PAS_SOL.PR_REGISTRAR_LOG(
        p_id_ejecucion       => v_id_ejecucion,
        p_tipo_log           => 'INFO',
        p_mensaje            => 'PRS_ACT_SOL_INV: Registros encontrados en staging',
        p_cantidad_registros => v_total_tmp
    );

    -- -----------------------------------------------------------
    -- 3. Eliminar de destino los registros cuya fecha coincida
    --    con las fechas presentes en staging (recarga idempotente)
    -- -----------------------------------------------------------
    DELETE FROM IT.CB_SOLVENCIA_INV
     WHERE TRUNC(FECHA) IN (
               SELECT DISTINCT TRUNC(FECHA)
                 FROM IT.SB_SOL_INV_TMP
                WHERE FECHA IS NOT NULL
           );

    IT.PAS_SOL.PR_REGISTRAR_LOG(
        p_id_ejecucion       => v_id_ejecucion,
        p_tipo_log           => 'INFO',
        p_mensaje            => 'PRS_ACT_SOL_INV: Registros previos eliminados de CB_SOLVENCIA_INV',
        p_cantidad_registros => SQL%ROWCOUNT
    );

    -- -----------------------------------------------------------
    -- 4. Procesamiento fila a fila con validaciones
    -- -----------------------------------------------------------
    FOR r IN c_staging LOOP

        v_fila_valida      := TRUE;
		v_fec_apertura    := NULL;
		v_fec_vencimiento := NULL;

        -- Validar y convertir FECHA (obligatoria)
        BEGIN
            IF r.FECHA IS NULL THEN
                v_fila_valida    := FALSE;
                v_motivo_rechazo := 'FECHA nula o vacia';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_fila_valida    := FALSE;
        END;

        -- Validar NRO_CUENTA (obligatorio)
        IF v_fila_valida AND r.NRO_CUENTA IS NULL THEN
            v_fila_valida    := FALSE;
            v_motivo_rechazo := 'NRO_CUENTA nulo';
        END IF;

        -- Validar COD_RUBRO (obligatorio)
        IF v_fila_valida THEN
            IF r.COD_RUBRO IS NULL OR TRIM(r.COD_RUBRO) IS NULL THEN
                v_fila_valida    := FALSE;
                v_motivo_rechazo := 'COD_RUBRO nulo o vacio';
            END IF;
        END IF;

        -- Convertir FEC_APERTURA (no bloquea si falla, queda NULL)
        BEGIN
            IF r.FEC_APERTURA IS NOT NULL AND TRIM(r.FEC_APERTURA) IS NOT NULL THEN
                v_fec_apertura := TO_DATE(r.FEC_APERTURA, 'MM/DD/YYYY');
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_fec_apertura := NULL;
        END;

        -- Convertir FEC_VENCIMIENTO (no bloquea si falla, queda NULL)
        BEGIN
            IF r.FEC_VENCIMIENTO IS NOT NULL AND TRIM(r.FEC_VENCIMIENTO) IS NOT NULL THEN
                v_fec_vencimiento := TO_DATE(r.FEC_VENCIMIENTO, 'MM/DD/YYYY');
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                v_fec_vencimiento := NULL;
        END;

        -- -------------------------------------------------------
        -- Insertar fila válida
        -- -------------------------------------------------------
        IF v_fila_valida THEN
            INSERT INTO IT.CB_SOLVENCIA_INV (
                FECHA,
                TIP_DEUDOR,
                NRO_CUENTA,
                COD_PERSONA,
                NRO_DOCUMENTO,
                NOMBRE,
                COD_MODULO,
                COD_MODALIDAD,
                MODAL,
                COD_OFICINA,
                DESC_OFI,
                COD_MONEDA,
                TIP_SALDO,
                SITUACION,
                ESTADO,
                FEC_APERTURA,
                FEC_VENCIMIENTO,
                VAL_TASA,
                COD_RUBRO,
                DES_RUBRO,
                SAL_ACTUAL
            ) VALUES (
                r.fecha,
                r.TIP_DEUDOR,
                r.NRO_CUENTA,
                r.COD_PERSONA,
                r.NRO_DOCUMENTO,
                r.NOMBRE,
                r.COD_MODULO,
                r.COD_MODALIDAD,
                r.MODAL,
                r.COD_OFICINA,
                r.DESC_OFI,
                r.COD_MONEDA,
                r.TIP_SALDO,
                r.SITUACION,
                r.ESTADO,
                v_fec_apertura,
                v_fec_vencimiento,
                r.VAL_TASA,
                r.cod_rubro,
                r.DES_RUBRO,
                r.SAL_ACTUAL
            );
            v_insertados := v_insertados + 1;

        ELSE
            -- Registrar rechazo en log
            v_rechazados := v_rechazados + 1;
            IT.PAS_SOL.PR_REGISTRAR_LOG(
                p_id_ejecucion => v_id_ejecucion,
                p_tipo_log     => 'WARNING',
                p_mensaje      => 'PRS_ACT_SOL_INV: Fila rechazada - Cuenta: '
                                  || TO_CHAR(r.NRO_CUENTA)
                                  || ' | Motivo: ' || v_motivo_rechazo
            );
        END IF;

    END LOOP;

    -- -----------------------------------------------------------
    -- 5. Validar que se hayan insertado registros
    -- -----------------------------------------------------------
    IF v_insertados = 0 THEN
        ROLLBACK;
        IT.PAS_SOL.PR_REGISTRAR_LOG(
            p_id_ejecucion       => v_id_ejecucion,
            p_tipo_log           => 'ERROR',
            p_mensaje            => 'PRS_ACT_SOL_INV: No se inserto ningun registro. '
                                    || 'Total rechazados: ' || v_rechazados
                                    || '. Verifique los datos en SB_SOL_INV_TMP.',
            p_cantidad_registros => v_rechazados
        );
        RAISE_APPLICATION_ERROR(-20002,
            'PRS_ACT_SOL_INV: Ninguna fila paso las validaciones. '
            || 'Registros en staging: ' || v_total_tmp
            || ' | Rechazados: ' || v_rechazados);
    END IF;

    -- -----------------------------------------------------------
    -- 6. Confirmar transacción antes de truncar
    -- -----------------------------------------------------------
    COMMIT;

    -- -----------------------------------------------------------
    -- 7. Truncar tabla staging (DDL — autonomo al commit anterior)
    -- -----------------------------------------------------------
    EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.SB_SOL_INV_TMP';

    -- -----------------------------------------------------------
    -- 8. Registrar finalización exitosa
    -- -----------------------------------------------------------
    IT.PAS_SOL.PR_REGISTRAR_LOG(
        p_id_ejecucion       => v_id_ejecucion,
        p_tipo_log           => 'SUCCESS',
        p_mensaje            => 'PRS_ACT_SOL_INV: Proceso completado. '
                                || 'Staging: '    || v_total_tmp
                                || ' | Insertados: ' || v_insertados
                                || ' | Rechazados: ' || v_rechazados,
        p_cantidad_registros => v_insertados,
        p_tiempo_ms          => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_ts_inicio)) * 1000
    );

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IT.PAS_SOL.PR_REGISTRAR_LOG(
            p_id_ejecucion  => v_id_ejecucion,
            p_tipo_log      => 'ERROR',
            p_mensaje       => 'PRS_ACT_SOL_INV: Error inesperado: ' || SQLERRM,
            p_detalle_error => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
        RAISE_APPLICATION_ERROR(-20099,
            'PRS_ACT_SOL_INV: Error inesperado: ' || SQLERRM);

END PRS_ACT_SOL_INV;

/

GRANT EXECUTE ON IT.PRS_ACT_SOL_INV TO IT_TEMPORAL;
CREATE OR REPLACE PUBLIC SYNONYM PRS_ACT_SOL_INV FOR IT.PRS_ACT_SOL_INV;
