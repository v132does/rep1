CREATE OR REPLACE PROCEDURE IT.PRP_CAM_ESTADOS 
 IS
    v_usu_mig_excluir    VARCHAR2(30);
    v_fec_inicio         ge_calendarios.fec_actual%TYPE;
    v_fec_actual         ge_calendarios.fec_actual%TYPE;
    v_hora               ge_movimientos.hora%TYPE;
    v_nro_secuencia      ge_movimientos.nro_secuencia%TYPE := 0;
    v_existe             VARCHAR2(1);
    v_total_procesado    NUMBER := 0;    
    -- Excepción específica para el NOWAIT (ORA-00054: recurso ocupado)
    e_resource_busy      EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_resource_busy, -54);
    
    CURSOR mae_cur(p_usu_excluir VARCHAR2) IS
        SELECT p.cod_modulo, 
               p.cod_modalidad, 
               p.cod_oficina, 
               p.nro_cuenta,
               ca.estado AS estado, 
               ca.fec_vencimiento,
               fup_obt_categoria(cli.cat_automatica, cli.cat_subjetiva) AS categoria
          FROM pr_cta_prestamos p
         CROSS APPLY (
             SELECT c.estado, c.fec_vencimiento
               FROM pr_cuotas c
              WHERE c.nro_cuenta = p.nro_cuenta
                AND c.nro_cuota > 0
                AND c.estado <> 'N'
                AND ((p.estado = 'C' AND c.estado = 'C') OR (p.estado <> 'C'))
              ORDER BY c.nro_cuota
              FETCH FIRST 1 ROW ONLY
         ) ca
          JOIN ge_cta_clientes ccl ON p.nro_cuenta = ccl.nro_cuenta
          JOIN ge_clientes cli     ON ccl.cod_persona = cli.cod_persona
         WHERE p.cod_modulo = 6
           AND p.cod_modalidad NOT IN (63, 64, 606, 603, 670, 671)
           AND p.estado NOT IN ('N', 'I')
           AND (p_usu_excluir IS NULL OR p.usu_insercion <> p_usu_excluir)
           AND ccl.relacion = 'P'
         ORDER BY p.nro_cuenta;

    TYPE t_mae_cur IS TABLE OF mae_cur%ROWTYPE;
    v_tab_mae t_mae_cur;
    
BEGIN
    it.pag_cie.PR_AT_INS_LOG(11,99,'PRP_CAM_ESTADOS', 'Inicio...', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
    -- Registro de inicio
    DBMS_APPLICATION_INFO.SET_ACTION('PRP_CAM_ESTADOS');
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRP_CAM_ESTADOS, Iniciando');
    -- Inicialización de fechas y parámetros
    pag_cal.PR_OBT_DAT_CALENDAR(6);
    v_fec_actual := pag_cal.g_fec_actual;    
    v_fec_inicio := CASE 
                        WHEN v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL THEN pag_cal.G_ULT_DIA_MES 
                        ELSE v_fec_actual 
                    END;                        
    v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
    v_hora            := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
    v_hora            := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
  
    OPEN mae_cur(v_usu_mig_excluir);
    LOOP
        FETCH mae_cur BULK COLLECT INTO v_tab_mae LIMIT 1000;
        EXIT WHEN v_tab_mae.COUNT = 0;
        
        FOR i IN 1 .. v_tab_mae.COUNT LOOP
            v_total_procesado := v_total_procesado + 1;         
            
            IF MOD(v_total_procesado, 1000) = 0 THEN
                DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Procesado: ' || v_total_procesado);
            END IF;            
            -- 1. PUNTO DE CONTROL: Marcamos el inicio de este registro individual
            SAVEPOINT sp_registro;            
            BEGIN
                -- Bloqueo de registro
                SELECT 'S' INTO v_existe 
                  FROM pr_cta_prestamos 
                 WHERE nro_cuenta = v_tab_mae(i).nro_cuenta 
                   FOR UPDATE NOWAIT;                
                -- Control de secuencia 
                IF v_nro_secuencia + 10 > 990 THEN
                    v_nro_secuencia := 0;
                    v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
                END IF;                
                -- Llamada al proceso de negocio
                pap_mes.pr_cam_situacion(
                    v_tab_mae(i).cod_modulo, v_tab_mae(i).cod_modalidad,
                    v_tab_mae(i).cod_oficina, v_tab_mae(i).nro_cuenta,
                    v_tab_mae(i).categoria, v_fec_inicio, v_hora, v_nro_secuencia
                );                                                  
            EXCEPTION
                WHEN e_resource_busy THEN
                    -- Registro bloqueado
                    it.pag_cie.PR_AT_INS_LOG(11, 99, 'PRP_CAM_ESTADOS', 'Registro bloqueado saltado: '||v_tab_mae(i).nro_cuenta, it.pag_cie.c_log_TRACE, 'OUT', SYSDATE);
                    CONTINUE;                    
                WHEN OTHERS THEN
                    -- 2. CORRECCIÓN CRÍTICA: Deshace SOLO los cambios de ESTA cuenta errónea
                    ROLLBACK TO sp_registro; 
                    it.pag_cie.PR_AT_INS_LOG(11, 99, 'PRP_CAM_ESTADOS', 'Error en cuenta '|| v_tab_mae(i).nro_cuenta ||': '||SQLERRM, it.pag_cie.c_log_TRACE, 'OUT', SYSDATE);                   
                    CONTINUE;
            END;                 
        END LOOP;  
        COMMIT;            
    END LOOP; 
    CLOSE mae_cur;    
    -- LIMPIAR la salida
    DBMS_APPLICATION_INFO.SET_ACTION(NULL);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
    it.pag_cie.PR_AT_INS_LOG(11, 99, 'PRP_CAM_ESTADOS', 'FIN! Total: '||v_total_procesado, it.pag_cie.c_log_TRACE, 'OUT', SYSDATE);
END PRP_CAM_ESTADOS;
