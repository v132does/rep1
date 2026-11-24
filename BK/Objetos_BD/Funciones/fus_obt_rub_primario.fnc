CREATE OR REPLACE FUNCTION IT.FUS_OBT_RUB_PRIMARIO
 (p_cod_persona      IN ba_personas.cod_persona%type,
  p_cod_rub_primario IN sb_crc_operaciones_det.cod_rub_primario%type,
  p_nro_operacion    IN sb_crc_operaciones_det.nro_operacion%type,
  p_cod_modulo       IN sb_crc_operaciones_det.cod_modulo%type)
 RETURN VARCHAR2
 IS
 v_tip_persona       ba_personas.tipo%type;
 v_cod_rub_primario  ba_personas.cod_rub_primario%type;
 v_cod_ente          cc_cta_corrientes.cod_ente%type; 
BEGIN
  IF p_cod_rub_primario IS NULL OR 
        instr(fug_obt_pardinamico('EXC_COD_RUB_PRIMARIO'), p_cod_rub_primario, 1, 1) > 0 THEN
     IF p_nro_operacion NOT LIKE '%#%#%' THEN
        BEGIN
          SELECT tipo
            INTO v_tip_persona
            FROM ba_personas
           WHERE cod_persona = p_cod_persona;
        EXCEPTION
          WHEN OTHERS THEN
            v_tip_persona := 'F';
        END;
        IF v_tip_persona = 'F' THEN
           IF p_cod_modulo = 3 THEN
              BEGIN
                SELECT cod_ente
                  INTO v_cod_ente
                  FROM ah_cta_vistas
                 WHERE nro_cuenta = substr(p_nro_operacion, 1, 10);
              EXCEPTION
                WHEN OTHERS THEN
                  v_cod_ente := null;
              END;
           ELSIF p_cod_modulo = 4 THEN
              BEGIN
                SELECT cod_ente
                  INTO v_cod_ente
                  FROM cc_cta_corrientes
                 WHERE nro_cuenta = substr(p_nro_operacion, 1, 10);
              EXCEPTION
                WHEN OTHERS THEN
                  v_cod_ente := null;
              END;
           END IF;   
           IF v_cod_ente IS NOT NULL THEN
              v_cod_rub_primario := fug_obt_pardinamico('SIB_COD_RUB_PRIMARIO');
           ELSE
              v_cod_rub_primario := null;
           END IF;   
        ELSE
           v_cod_rub_primario := null;
        END IF;
     ELSE 
        v_cod_rub_primario := fug_obt_pardinamico('SIB_COD_RUB_PRIMARIO', 6);         
     END IF;   
  ELSE
     v_cod_rub_primario := p_cod_rub_primario;
  END IF;
     
  RETURN v_cod_rub_primario;

END;
/

