CREATE OR REPLACE PROCEDURE IT.PRG_GEN_INH_PER (P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE,
                                                P_COD_CAUSAL  ge_per_inhibidas.cod_causa%TYPE,
                                                P_ORIGEN      VARCHAR2, 
                                                p_estado      varchar2 default null)
IS
  v_cod_persona ba_personas.cod_persona%TYPE;
  v_nro_orden   ge_per_inhibidas.nro_orden%TYPE;
BEGIN

  -- Verifica si ya existe la persona en GF
  BEGIN
    SELECT cod_persona
      INTO v_cod_persona
      FROM ba_personas
     WHERE cod_persona = P_COD_PERSONA;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_persona := NULL;
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al obtener codigo de persona: ' || SQLERRM);
  END;

  IF v_cod_persona is not null then
      -- Actualizo las inhibiciones, si existe
      UPDATE ge_per_inhibidas a
         SET fec_inicio       = trunc(sysdate),
             origen           = P_ORIGEN,
             detalle          = P_ORIGEN,
             usu_modificacion = USER,
             fec_modificacion = SYSDATE,
             a.estado         = nvl(p_estado,'I')  --'I'
       WHERE cod_persona      = v_cod_persona
         and cod_causa        = P_COD_CAUSAL;

      IF SQL%NOTFOUND THEN
       -- numerador
         select nvl(max(nro_orden),0) + 1
             into v_nro_orden
         from ge_per_inhibidas a
          where cod_persona = p_cod_persona;  
              
        -- No esta en inhibidos
        INSERT INTO ge_per_inhibidas
          (cod_persona, nro_orden, cod_causa, fec_inicio, origen, detalle,
           usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, estado)
        VALUES
          (v_cod_persona, nvl(v_nro_orden,1), P_COD_CAUSAL, trunc(sysdate), P_ORIGEN, P_ORIGEN,
           USER, SYSDATE, USER, SYSDATE, 'I');
      END IF;
   end if;

EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20000, SQLERRM);
END;
/

