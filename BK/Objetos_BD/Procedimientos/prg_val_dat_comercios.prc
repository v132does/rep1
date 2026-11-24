CREATE OR REPLACE PROCEDURE IT.prg_val_dat_comercios( p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                                                      p_cod_ente   IN ge_entes.cod_ente%TYPE,
                                                      p_error      OUT VARCHAR2,
                                                      p_respuesta  OUT VARCHAR2
                                                     ) IS
  v_cod_persona ba_personas.cod_persona%TYPE;
  v_existe      VARCHAR2(1);
                                                      
BEGIN
  IF p_nro_cuenta IS NULL THEN
     p_error     := '01';
     p_respuesta := 'Debe ingresar un numero de Cuenta';
     RETURN;
  END IF;

  IF p_cod_ente IS NULL THEN
     p_error     := '02';
     p_respuesta := 'Debe ingresar un codigo de Ente';
     RETURN;
  END IF;

  BEGIN
    SELECT g.cod_persona
      INTO v_cod_persona
      FROM ge_cta_clientes g
     WHERE g.nro_cuenta = p_nro_cuenta
       AND g.relacion   = 'P';
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        v_cod_persona := NULL;
        p_error       := '03';
        p_respuesta   := 'La cuenta ingresada no existe';
        RETURN;
     WHEN OTHERS THEN
        v_cod_persona := NULL;
        p_error       := '04';
        p_respuesta   := 'Error al obtener Datos de la cuenta '||SQLERRM;
        RETURN;
  END;

  IF v_cod_persona IS NOT NULL THEN

    BEGIN
     SELECT 'S'
       INTO v_existe
       FROM ge_entes e
      WHERE e.cod_persona = v_cod_persona
        AND e.cod_ente    = p_cod_ente
        AND e.tipo        = 'PA';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
          v_existe    := 'N';
          p_error     := '05';
          p_respuesta := 'El ente ingresado no existe';
          RETURN;
      WHEN OTHERS THEN
          v_existe    := 'N';
          p_error     := '06';
          p_respuesta := 'Ocurrio un error al obtener datos del Ente '||SQLERRM;
          RETURN;
    END;

  END IF;

  IF nvl( p_error, '00' ) = '00' THEN
     p_error     := '00';
     p_respuesta := 'OK';
  END IF;

END;
/

