CREATE OR REPLACE PROCEDURE IT.PRP_REC_APL_LIMITE(p_nro_linea IN NUMBER DEFAULT NULL) IS
    v_cod_persona       pr_lineas.cod_persona%TYPE;
    v_nro_linea         pr_lineas.nro_linea%TYPE;
    v_val_parametro     ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('NRO_LIN_EXC_REC_LIMIITE');
    v_cotizacion        ge_cotizaciones.val_conversion%type := pag_gen.fu_obt_cotizacion(pag_gen.FU_OBT_MON_FUERTE);
    
    -- Colección para el BULK COLLECT del cursor C0
    TYPE t_cursor0_rec IS RECORD (
        nro_linea    pr_lineas.nro_linea%TYPE,
        estado       pr_lineas.estado%TYPE,
        cod_persona  pr_lineas.cod_persona%TYPE,
        cod_moneda   pr_lineas.cod_moneda%TYPE
    );
    TYPE t_cursor0_tab IS TABLE OF t_cursor0_rec;
    v_cursor0_tab   t_cursor0_tab;

    -- Colección para el BULK COLLECT del cursor C1
    TYPE t_cursor1_rec IS RECORD (
        nro_linea      pv_op_lim_credito.nro_linea%TYPE,
        nro_cuenta     pv_op_lim_credito.nro_cuenta%TYPE,
        nro_sec_padre  pv_op_lim_credito.nro_sec_padre%TYPE,
        cod_moneda     pv_op_lim_credito.cod_mon_apl%TYPE,
        mto_aplicado   NUMBER(18,2)
    );
    TYPE t_cursor1_tab IS TABLE OF t_cursor1_rec;
    v_cursor1_tab   t_cursor1_tab;

    TYPE t_pr_lineas_nro_linea IS TABLE OF pr_lineas.nro_linea%TYPE;

    r_pr_lineas_nro_linea  t_pr_lineas_nro_linea not null := t_pr_lineas_nro_linea();

    -- Cursor C0
    CURSOR c0 IS
        SELECT nro_linea, estado, cod_persona, cod_moneda
          FROM pr_lineas a
         WHERE estado IN ('A','B')
           AND INSTR(NVL(v_val_parametro, '0'), a.nro_linea) = 0 --Para excluir del Cierre--
           AND ((nro_linea = p_nro_linea AND p_nro_linea IS NOT NULL) OR p_nro_linea IS NULL);

    -- Cursor C1
    CURSOR c1 IS
        SELECT nro_linea, MIN(nro_cuenta) nro_cuenta, nro_sec_padre,
               cod_mon_apl cod_moneda, NVL(SUM(NVL(mto_aplicado, 0)), 0) mto_aplicado
          FROM it.gv_lin_gar_credito
         WHERE nro_linea = v_nro_linea
         GROUP BY nro_linea, nro_sec_padre,
         DECODE(nro_sec_padre, 0, nro_cuenta, nro_sec_padre), cod_mon_apl;
    v_ingreso     VARCHAR2(1) := 'N';
    v_act_limite  VARCHAR2(1);
    v_mensaje     VARCHAR2(100);
    v_error       VARCHAR2(1) := 'N';
    v_msj_error   VARCHAR2(500);
    v_modalidad   pr_cta_prestamos.cod_modalidad%type;
    
    FUNCTION lf_ver_solicitud (p_nro IN VARCHAR2) RETURN BOOLEAN IS
            v_existe NUMBER;
        BEGIN
            SELECT 1
              INTO v_existe
              FROM pr_solicitudes
             WHERE nro_solicitud = TO_NUMBER(REPLACE(p_nro, 'Prop.Nro. ', ''));

            RETURN TRUE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN FALSE;
            WHEN OTHERS THEN
                RETURN FALSE;
      END;
BEGIN
    -- Registrar el nombre en action
    DBMS_APPLICATION_INFO.SET_ACTION('PRP_REC_APL_LIMITE');
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRP_REC_APL_LIMITE, Iniciando');
    
    DBMS_MVIEW.REFRESH('gv_lin_gar_credito');
    
    -- BULK COLLECT del cursor C0
    OPEN c0;
    FETCH c0 BULK COLLECT INTO v_cursor0_tab;
    CLOSE c0;
   
    -- Progreso del procesamiento
    FOR i IN 1 .. v_cursor0_tab.COUNT LOOP
        -- Monitoreo del avance cada 10000 registros o al final
        IF MOD(i, 10000) = 0 OR i = v_cursor0_tab.COUNT THEN
            v_mensaje := 'Procesando línea ' || i || ' de ' || v_cursor0_tab.COUNT;
            DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
        END IF;

        v_cod_persona := v_cursor0_tab(i).cod_persona;
        v_nro_linea   := v_cursor0_tab(i).nro_linea;
    --verifico que modalidad tiene la linea
    BEGIN
       SELECT nvl(p.cod_modalidad,0) 
         INTO v_modalidad
         FROM pr_cta_prestamos p, pr_lineas l
        WHERE p.nro_linea = l.nro_linea
          AND l.nro_linea = v_nro_linea
          AND ROWNUM =1;
    EXCEPTION
        WHEN OTHERS THEN
          v_modalidad:= null;
    END;
    -- Verifico si la persona está asociada a un ente de tipo Asociación
    --y verifico el parámetro de ente de actualización de línea de crédito
        BEGIN
            SELECT NVL(fug_obt_parentes(e.cod_ente, 'ASO_ACT_LIN_CREDITO'), 'S')
              INTO v_act_limite
              FROM ge_entes e
             WHERE e.cod_persona = v_cod_persona
               AND e.tipo = 'AS';
        EXCEPTION
            WHEN OTHERS THEN
               v_act_limite := 'S';
        END;

        IF v_act_limite = 'S' THEN
         IF ( nvl(fug_obt_pardinamico('COD_MOD_EXC_LINEAS',6,v_modalidad),'N') = 'S' AND p_nro_linea IS NOT NULL)
       OR
       (nvl(fug_obt_pardinamico('COD_MOD_EXC_LINEAS',6,v_modalidad),'N') = 'N' ) THEN
            UPDATE pr_lineas
               SET mto_aplicado = 0
             WHERE nro_linea = v_nro_linea;
	--
            UPDATE pr_lin_tip_garantias
               SET mto_aplicado = 0
             WHERE nro_linea = v_nro_linea;
    	--
            UPDATE pr_lin_tip_gar_mad
               SET mto_aplicado = 0
             WHERE nro_linea = v_nro_linea;
	-- 
           END IF; 
            v_ingreso := 'N';

	-- BULK COLLECT del cursor C1
            OPEN c1;
            FETCH c1 BULK COLLECT INTO v_cursor1_tab;
            CLOSE c1;

            FOR j IN 1 .. v_cursor1_tab.COUNT LOOP
                DECLARE
                    v_mto_aplicar NUMBER(18, 2) := 0;
                    v_es_valido BOOLEAN := TRUE;
                BEGIN
                    -- Validar si existe la solicitud de prestamos
                    IF v_cursor1_tab(j).nro_cuenta LIKE 'Prop.Nro.%' THEN
                        v_es_valido := lf_ver_solicitud(v_cursor1_tab(j).nro_cuenta);
                        IF v_es_valido = FALSE THEN
                          v_error := 'S';
                          v_msj_error := (REPLACE(v_cursor1_tab(j).nro_cuenta, 'Prop.Nro. ', ''))||'-'||v_msj_error;
                         END IF;
                    END IF;
                  IF v_es_valido THEN
                   v_ingreso := 'S';

                    prp_apl_lim_credito(
                        v_nro_linea,
                        v_cursor1_tab(j).nro_cuenta,
                        v_cursor1_tab(j).nro_sec_padre,
                        'N'
                    );

            --Convertir solo si las monedas de la garantía (v_cursor1_tab(j).cod_moneda) y de la línea (v_cursor0_tab(i).cod_moneda) son diferentes
            -- Convertir monto con la función de cambio de GS
                    IF v_cursor0_tab(i).cod_moneda <> v_cursor1_tab(j).cod_moneda THEN
                        v_mto_aplicar := pag_gen.fu_con_mon_a_moneda(
                            v_cursor1_tab(j).cod_moneda,
                            v_cursor0_tab(i).cod_moneda,
                            v_cursor1_tab(j).mto_aplicado
                        );
                    ELSE
                       IF ( nvl(fug_obt_pardinamico('COD_MOD_EXC_LINEAS',6,v_modalidad),'N') = 'S' AND p_nro_linea IS NOT NULL)
                        OR
                            (nvl(fug_obt_pardinamico('COD_MOD_EXC_LINEAS',6,v_modalidad),'N') = 'N' ) THEN
                        v_mto_aplicar := v_cursor1_tab(j).mto_aplicado;
                        ELSE
                        v_mto_aplicar :=0;
                       END IF; 
                    END IF;

                    pap_gar.pr_act_lin_aplicado(v_nro_linea, v_mto_aplicar);
                  end if;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20000, 'Error al aplicar al límite ' || v_cursor1_tab(j).nro_cuenta || ' - ' || SQLERRM);
                END;
            END LOOP;

            IF v_ingreso = 'S' THEN
                r_pr_lineas_nro_linea.EXTEND;
                r_pr_lineas_nro_linea(r_pr_lineas_nro_linea.COUNT) := v_cursor0_tab(i).nro_linea;
            END IF;
        END IF;
    END LOOP;

    FORALL i IN 1 .. r_pr_lineas_nro_linea.COUNT
        UPDATE pr_lineas
           SET cotizacion = v_cotizacion
         WHERE nro_linea = r_pr_lineas_nro_linea(i);
     IF v_error = 'S' THEN
       pag_cie.PR_INS_LOG('Sol. Prestamos error: '||v_msj_error, it.pag_cie.c_log_WARN, 'AUTONOMOUS_TRANSACTION');
     END IF; 
     -- Dejar null la acción para que no quede en memoria 
     DBMS_APPLICATION_INFO.SET_ACTION(NULL);
     DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);    
END;
/
