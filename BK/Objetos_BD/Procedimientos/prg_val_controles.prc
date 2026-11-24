CREATE OR REPLACE PROCEDURE IT.PRG_VAL_CONTROLES IS

    PRAGMA AUTONOMOUS_TRANSACTION;
    CURSOR c_controles IS
        SELECT cod_control, descripcion, observacion, sql_control, 
               sql_correccion, prioridad, tip_correccion, autocorregir
          FROM GE_CON_PROCESOS
         WHERE estado = 'A'
         ORDER BY TO_NUMBER(prioridad) ASC;

    v_sql_dinamico   CLOB;
    v_sql_real       CLOB;
    v_error          VARCHAR2(2000);
    v_fecha          DATE;
    v_reg_detectadas NUMBER := 0;
    v_reg_corregidas NUMBER := 0;
    v_det_mod        VARCHAR2(4000);

BEGIN
    BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; END; 
    v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(1);
    
    FOR ctrl IN c_controles LOOP
        v_reg_detectadas := 0;
        v_reg_corregidas := 0;
        
        BEGIN
            
            -- Marcamos como verificado lo que estaba pendiente
            UPDATE GE_LOG_CONTROLES
               SET est_correccion = 'CORREGIDO (VERIFICADO)'
             WHERE fecha = v_fecha 
               AND cod_control = ctrl.cod_control
               AND est_correccion IN ('NUEVO ERROR', 'SCRIPT GENERADO', 'PERSISTE ERROR','REQUIERE MANUAL');

            -- Si vuelve a salir, cambiamos el estado
            v_sql_dinamico := 
                'UPDATE GE_LOG_CONTROLES dest ' ||
                '   SET dest.est_correccion = ''PERSISTE ERROR'' ' ||
                ' WHERE dest.fecha = :1 AND dest.cod_control = :2 ' ||
                '   AND dest.clave IN (SELECT clave FROM (' || ctrl.sql_control || '))';
            EXECUTE IMMEDIATE v_sql_dinamico USING v_fecha, ctrl.cod_control;

            --Insertamos solo registros inéditos en el día
            v_sql_dinamico :=
                'INSERT INTO GE_LOG_CONTROLES ' ||
                '(fecha, cod_control, nro_registro, cod_usuario, descripcion, observacion, clave, prioridad, est_correccion) ' ||
                'SELECT :1, :2, ROWNUM + NVL((SELECT MAX(nro_registro) FROM GE_LOG_CONTROLES WHERE fecha = :3 AND cod_control = :4), 0), ' ||
                'USER, :5, :6, clave, :7, ''NUEVO ERROR'' ' ||
                'FROM (' || ctrl.sql_control || ') src ' ||
                'WHERE NOT EXISTS (SELECT 1 FROM GE_LOG_CONTROLES dest WHERE dest.fecha = :8 AND dest.cod_control = :9 AND dest.clave = src.clave)';
            
            EXECUTE IMMEDIATE v_sql_dinamico 
               USING v_fecha, ctrl.cod_control, v_fecha, ctrl.cod_control, 
                     ctrl.descripcion, ctrl.observacion, TO_CHAR(ctrl.prioridad), 
                     v_fecha, ctrl.cod_control;
            
            -- Calculamos cuántos registros quedaron activos para procesar correcciones
            SELECT COUNT(1) INTO v_reg_detectadas
              FROM GE_LOG_CONTROLES
             WHERE fecha = v_fecha 
               AND cod_control = ctrl.cod_control
               AND est_correccion IN ('NUEVO ERROR', 'PERSISTE ERROR');

            IF v_reg_detectadas > 0 AND ctrl.sql_correccion IS NOT NULL THEN
              
                --ESTRATEGIA MASIVA ('M')
                IF ctrl.tip_correccion = 'M' THEN
                    v_sql_real := REPLACE(ctrl.sql_correccion, ':fecha', '''' || TO_CHAR(v_fecha, 'DD/MM/YYYY') || '''');
                    
                    IF NVL(ctrl.autocorregir,'N') = 'S' THEN
                        -- Ejecutamos la corrección
                        EXECUTE IMMEDIATE ctrl.sql_correccion USING v_fecha;
                        v_reg_corregidas := SQL%ROWCOUNT;
                        
                        UPDATE GE_LOG_CONTROLES
                           SET est_correccion = 'AUTOCORREGIDO MASIVO',
                               msj_auditoria = 'Se corrigieron ' || v_reg_corregidas || ' filas masivamente.',
                               det_Sql = v_sql_real
                         WHERE fecha = v_fecha 
                           AND cod_control = ctrl.cod_control
                           AND est_correccion IN ('NUEVO ERROR', 'PERSISTE ERROR');
                    ELSE
                        UPDATE GE_LOG_CONTROLES
                           SET est_correccion = 'SCRIPT GENERADO',
                               det_Sql = v_sql_real
                         WHERE fecha = v_fecha 
                           AND cod_control = ctrl.cod_control
                           AND est_correccion IN ('NUEVO ERROR', 'PERSISTE ERROR');
                    END IF;
                       
                --ESTRATEGIA INDIVIDUAL ('I')
                ELSIF ctrl.tip_correccion = 'I' THEN
                    
                    -- Filtramos solo las cuentas que están pendientes de arreglar
                    FOR reg IN (
                        SELECT nro_registro, 
                               TRIM(REGEXP_SUBSTR(clave, '(nro_cuenta|cod_persona|nro_solicitud|nro_linea)\s*=\s*([^, ]+)', 1, 1, 'i', 2)) AS cuenta_extraida
                          FROM GE_LOG_CONTROLES 
                         WHERE fecha = v_fecha 
                           AND cod_control = ctrl.cod_control
                           AND est_correccion IN ('NUEVO ERROR', 'PERSISTE ERROR')
                    ) LOOP
                        BEGIN
                            IF reg.cuenta_extraida IS NOT NULL THEN
                                
                                --PREPARAMOS EL SCRIPT PARA DET_SQL
                                v_sql_real := REPLACE(ctrl.sql_correccion, ':1', '''' || TO_CHAR(v_fecha, 'DD/MM/YYYY') || '''');
                                v_sql_real := REPLACE(v_sql_real, ':2', reg.cuenta_extraida);
                                v_sql_real := REGEXP_REPLACE(v_sql_real, ':3\s*:=.*?;', '/* Asignacion de auditoria automatica omitida */', 1, 0, 'n');
                                v_sql_real := REGEXP_REPLACE(v_sql_real, 'BEGIN', 
                                'BEGIN' || CHR(10) || 
                                '               -- Inicializacion manual' || CHR(10) || 
                                '               pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; PAE_CNF.G_PROGRAMA := ''GPPROFIN'';' || CHR(10), 
                                1, 1, 'i');
                                
                                IF NVL(ctrl.autocorregir,'N') = 'S' THEN
                                    v_det_mod := NULL;
                                    EXECUTE IMMEDIATE ctrl.sql_correccion 
                                        USING v_fecha, reg.cuenta_extraida, OUT v_det_mod;
                                        
                                    UPDATE GE_LOG_CONTROLES
                                       SET est_correccion = 'AUTOCORREGIDO',
                                           msj_auditoria = NVL(v_det_mod, 'Corregido exitosamente'),
                                           det_sql = v_sql_real
                                     WHERE fecha = v_fecha 
                                       AND cod_control = ctrl.cod_control 
                                       AND nro_registro = reg.nro_registro;
                                ELSE
                                    UPDATE GE_LOG_CONTROLES
                                       SET est_correccion = 'SCRIPT GENERADO',
                                           det_sql = v_sql_real
                                     WHERE fecha = v_fecha 
                                       AND cod_control = ctrl.cod_control 
                                       AND nro_registro = reg.nro_registro;
                                END IF;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS THEN
                                v_error := SQLERRM;
                                UPDATE GE_LOG_CONTROLES
                                   SET est_correccion = 'ERROR EJECUCION PLSQL',
                                       msj_auditoria = SUBSTR(v_error, 1, 490)
                                 WHERE fecha = v_fecha 
                                   AND cod_control = ctrl.cod_control 
                                   AND nro_registro = reg.nro_registro;
                        END;
                    END LOOP;                
                END IF;
                
            ELSE
                -- Si hay errores detectados pero el control NO tiene script
                IF v_reg_detectadas > 0 THEN
                    UPDATE GE_LOG_CONTROLES
                       SET est_correccion = 'REQUIERE MANUAL'
                     WHERE fecha = v_fecha 
                       AND cod_control = ctrl.cod_control
                       AND est_correccion IN ('NUEVO ERROR', 'PERSISTE ERROR');
                END IF;
            END IF;
            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                v_error := SQLERRM;
                INSERT INTO GE_LOG_CONTROLES
                    (fecha, cod_control, nro_registro, cod_usuario, descripcion, observacion, est_correccion, msj_auditoria)
                VALUES
                    (v_fecha, ctrl.cod_control, NVL((SELECT MAX(nro_registro) FROM GE_LOG_CONTROLES WHERE fecha = v_fecha AND cod_control = ctrl.cod_control),0)+1, 
                     USER, 'FALLO EN SCRIPT SQL', 'Error al ejecutar la consulta principal del control.', 'ERROR SQL CONTROL', SUBSTR(v_error, 1, 490));
                COMMIT;
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        v_error := SQLERRM;
        RAISE_APPLICATION_ERROR(-20000, 'Error general en PRG_VAL_CONTROLES: ' || v_error);
END PRG_VAL_CONTROLES;
/
