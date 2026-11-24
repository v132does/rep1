CREATE OR REPLACE PROCEDURE IT.PRB_EJE_PRO_320_AUTOMATICO
IS
    v_sqlerrm       VARCHAR2(1000);
    v_val           NUMBER;
    v_hor_fin       VARCHAR2(10);
    v_continue      VARCHAR2(1);
    v_loopcount     NUMBER := 0;
    v_maxloop       NUMBER;
    v_fec_cierre    DATE;
    v_fec_contable  DATE;
    v_cod_programa  VARCHAR2(50) := 'PRB_EJE_PRO_320_AUTOMATICO';
    v_par_dinamico  VARCHAR2(50) := 'PRO_320_ERR_NO_BLOQUEANTE';
    
    FUNCTION lf_val_cie_finalizado RETURN VARCHAR2    
    IS
    BEGIN
        v_sqlerrm := NULL;
        pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
        RETURN 'S';
    EXCEPTION
        WHEN OTHERS THEN
            v_sqlerrm := 'Error en validación del módulo '||pae_cnf.g_cod_modulo||'. '||sqlerrm;
            RETURN 'N';
    END;
    
    FUNCTION lf_val_fec_mod_contabilidad RETURN VARCHAR2
    IS
    BEGIN     
        v_sqlerrm := NULL;
        SELECT a.fec_anterior, b.fec_actual
        INTO v_fec_cierre, v_fec_contable
        FROM ge_calendarios a, ge_calendarios b
        WHERE a.cod_modulo = 1
        AND b.cod_modulo = 2;
        
        IF v_fec_cierre != v_fec_contable THEN
            v_sqlerrm := 'Error: La fecha del cierre operativo (' || to_char(v_fec_cierre, 'dd/mm/yyyy') || ') no coincide con la del modulo contable (' || to_char(v_fec_contable, 'dd/mm/yyyy') || ')';
            RETURN 'N';
        END IF;
        RETURN 'S';
    EXCEPTION
        WHEN OTHERS THEN
            v_sqlerrm := 'Error: al validar fecha del modulo contable: ' || SQLERRM;
            RETURN 'N';
    END;
    
    PROCEDURE pl_set_max_iteraciones
    IS 
    BEGIN
        SELECT count(1)+1
        INTO v_maxloop
        FROM ge_par_dinamicos
        WHERE parametro = v_par_dinamico;
    EXCEPTION
        WHEN OTHERS THEN
            v_maxloop := 1;
    END;
    
    PROCEDURE lp_obt_fec_fin_proceso
    IS
    BEGIN
        SELECT hor_fin
        INTO v_hor_fin
        FROM ge_procesos
        WHERE cod_proceso = 320;
    END;
    
    FUNCTION lf_finalizo_proceso RETURN VARCHAR2
    IS
    BEGIN
        IF v_hor_fin IS NOT NULL THEN
            RETURN 'S';
        END IF;
        
        RETURN 'N';
    END;
    
    PROCEDURE lp_obt_err_proceso
    IS
    BEGIN
        v_sqlerrm := NULL;
        SELECT error
        INTO v_sqlerrm
        FROM ge_procesos_det
        WHERE cod_proceso = 320
        AND hor_inicio IS NOT NULL
        AND hor_fin IS NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        WHEN OTHERS THEN
            v_sqlerrm := SQLERRM;
    END;
    
    FUNCTION lf_err_bloqueante RETURN VARCHAR2
    IS
    BEGIN
        SELECT 1
        INTO v_val
        FROM GE_PAR_DINAMICOS
        WHERE PARAMETRO = 'PRO_320_ERR_NO_BLOQUEANTE'
        AND INSTR(v_sqlerrm, VAL_PARAMETRO) > 0;
        RETURN 'N';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'S';
        WHEN OTHERS THEN
            v_sqlerrm := SQLERRM;
            RETURN 'S';
    END;
BEGIN
    pre_ini_aplicacion; 
    pae_cnf.G_COD_MODULO:=1;
    
    -- valida que el cierre operativo haya finalizado. En caso contrario no se ejecuta el proceso.
    IF lf_val_cie_finalizado = 'N' THEN
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => v_cod_programa,
                                 p_det_error    => v_sqlerrm,
                                 p_cod_persona  => null,
                                 p_nro_cuenta   => null);
        RETURN;
    END IF;
    
    -- valida si la fecha del modulo contable coincide con la del cierre operativo. En caso contrario no se ejecuta el proceso.
    IF lf_val_fec_mod_contabilidad = 'N' THEN
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => v_cod_programa,
                                 p_det_error    => v_sqlerrm,
                                 p_cod_persona  => null,
                                 p_nro_cuenta   => null);
        RETURN;
    END IF;
    
    PRG_INS_LOG_PROGRAMAS( p_cod_programa => v_cod_programa,
                                 p_det_error    => 'Inicia el proceso 320 (FIN DE DIA CONTABLE)',
                                 p_cod_persona  => null,
                                 p_nro_cuenta   => null);

    -- setea el maximo de iteraciones en base a la cantidad de errores no bloqueantes                             
    pl_set_max_iteraciones;
    
    LOOP
        v_sqlerrm := null;
        --Si alcanzo la cantidad maxima de iteraciones se detiene el proceso
        IF v_loopcount >= v_maxloop THEN
            v_sqlerrm := 'Se alcanzo el limite de iteraciones ' || v_maxloop;
            EXIT;
        END IF;
        
        v_loopcount := v_loopcount + 1;
        
        -- ejecuta el proceso 320
        BEGIN
            PRG_EJE_PROCESOS(pae_cnf.fu_obt_fec_actual(2), 'F', 320);
        EXCEPTION
            WHEN OTHERS THEN
                v_sqlerrm := SQLERRM;
                EXIT;
        END;
        -- obtengo la hora de finalizacion del proceso para saber si se completo la ejecucion
        lp_obt_fec_fin_proceso;
        
        --valida si el proceso 320 se completo
        IF lf_finalizo_proceso = 'S' THEN
            EXIT;
        END IF;
        -- si dio error algun paso 
        -- obtengo el error
        lp_obt_err_proceso;
        --Si no obtuvo error termina
        IF v_sqlerrm IS NULL THEN
            EXIT;
        END IF;
        
        --valido si es un error no bloqueante
        IF lf_err_bloqueante = 'S' THEN
            EXIT;
        END IF;
        
        -- Si es un error no bloqueante completo la hora de finalizacion del paso y vuelvo a iterar
        UPDATE GE_PROCESOS_DET
        SET hor_fin = to_char(SYSDATE, 'hh24:mi:ss')
        WHERE COD_PROCESO = 320
        AND hor_inicio IS NOT NULL
        AND hor_fin IS NULL;
        
        COMMIT;
        
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => v_cod_programa,
                                 p_det_error    => 'Se omite error y continua el proceso: '||v_sqlerrm,
                                 p_cod_persona  => null,
                                 p_nro_cuenta   => null);
    END LOOP;
    
    -- Si hubo error lo logueo
    IF v_sqlerrm IS NOT NULL THEN
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => v_cod_programa,
                                     p_det_error    => 'Se detiene la ejecucion por: ' || v_sqlerrm,
                                     p_cod_persona  => null,
                                     p_nro_cuenta   => null);
    ELSE               
        -- Si no logueo la finalizacion
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => v_cod_programa,
                                     p_det_error    => 'Finaliza el proceso 320 (FIN DE DIA CONTABLE)',
                                     p_cod_persona  => null,
                                     p_nro_cuenta   => null);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => v_cod_programa,
                                     p_det_error    => 'Se detiene la ejecucion por: ' || SQLERRM,
                                     p_cod_persona  => null,
                                     p_nro_cuenta   => null);
END;