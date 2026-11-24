CREATE OR REPLACE PROCEDURE IT.PRG_PRO_RIESGO_PLA_CLIENTES AS
    v_cnt_procesados  NUMBER := 0;
    v_cnt_errores     NUMBER := 0;
    v_cod_persona     NUMBER(12);
    v_lis_row         cr_per_riesgo_pla_his%rowtype;
    v_error           varchar2(300);
    exc_per_no_existe EXCEPTION;

    CURSOR c_tmp IS
        SELECT ROWID AS reg_id,
               COD_PERSONA,
               NRO_DOCUMENTO,
               COD_TIP_DOCUMENTO,
               UPPER(NIVEL_RIESGO) AS NIVEL_RIESGO
          FROM IT.CR_PER_RIESGO_PLA_TMP
         WHERE NVL(PROCESADO, 'N') = 'N';
BEGIN
    -- Inicializacion de contexto de aplicacion
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
    -- Fase 1: Procesamiento de registros informados en el archivo (Riesgo Alto y Medio)
    FOR r IN c_tmp LOOP
        BEGIN
            -- Validacion de existencia de cliente en tabla maestra
            BEGIN
                SELECT COD_PERSONA
                  INTO v_cod_persona
                  FROM BA_PERSONAS
                 WHERE COD_PERSONA = r.COD_PERSONA
                    OR (NRO_DOCUMENTO = r.NRO_DOCUMENTO AND COD_TIP_DOCUMENTO = r.COD_TIP_DOCUMENTO);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    raise exc_per_no_existe;
            END;
            -- Validacion de nivel de riesgo permitido
            IF r.NIVEL_RIESGO NOT IN ('ALTO', 'MEDIO', 'BAJO') THEN
                RAISE_APPLICATION_ERROR(-20002, 'Nivel de riesgo invalido: ' || r.NIVEL_RIESGO);
            END IF;
            -----------------
            v_lis_row.cod_persona       := r.cod_persona;
            v_lis_row.nro_documento     := r.nro_documento;
            v_lis_row.cod_tip_documento := r.cod_tip_documento;
            v_lis_row.nivel_riesgo      := r.nivel_riesgo;

              --inserta en tabla ge_per_inhibidas
          BEGIN
            insert into cr_per_riesgo_pla_his values v_lis_row;
          EXCEPTION
            WHEN exc_per_no_existe THEN
              v_error := 'Riesgo o persona no existe, no insertada';
            WHEN OTHERS THEN
              v_error := substr(SQLERRM, 1, 200);
          END;

            -- Marcar registro temporal como procesado
            UPDATE IT.CR_PER_RIESGO_PLA_TMP
               SET PROCESADO = 'S',
                   ERROR_DESC = NULL
             WHERE ROWID = r.reg_id;
            v_cnt_procesados := v_cnt_procesados + 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_cnt_errores := v_cnt_errores + 1;
                v_error := v_error || SUBSTR(SQLERRM, 1, 500);
                UPDATE IT.CR_PER_RIESGO_PLA_TMP
                   SET PROCESADO = 'E',
                       ERROR_DESC = v_error
                 WHERE ROWID = r.reg_id;
        END;
    END LOOP;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Error general en PRG_PRO_RIESGO_PLA_CLIENTES: ' || SQLERRM);
END PRG_PRO_RIESGO_PLA_CLIENTES;
/
