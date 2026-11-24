CREATE OR REPLACE PROCEDURE IT.PRR_VER_ROL_CAN_INTENTOS(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                                     p_cod_modulo    IN ge_dat_rie_eva_intentos.cod_modulo%TYPE,
                                                     p_cod_modalidad IN ge_dat_rie_eva_intentos.cod_modalidad%TYPE) IS
   -- Creado para validar intentos por ROL antes de enviar al motor GRM
   -- DYDMR-47. C.B. 06/03/2014.
   v_cod_rol      ba_roles.cod_rol%TYPE;
   v_can_intentos ge_dat_rie_eva_intentos.can_intentos%type;

BEGIN
   IF not fug_val_usu_rol('ROL_DPTO_COM_EVALUACION', USER) AND not fug_val_usu_rol('ROL_DPTO_RIE_EVALUACION', USER) THEN
     raise_application_error(-20085, 'Usuario no posee habilitado el Rol para el Dpto. de Riesgo o Dpto. Comercial para realizar la Evaluación.');
   END IF;

   IF fug_val_usu_rol('ROL_DPTO_COM_EVALUACION', USER) then
      v_cod_rol := fug_obt_pardinamico('ROL_DPTO_COM_EVALUACION');
      --**obtener la cantidad de intentos
      BEGIN
         SELECT can_intentos
           INTO v_can_intentos
           FROM ge_dat_rie_eva_intentos
          WHERE nro_solicitud = p_nro_solicitud
            AND cod_modulo = p_cod_modulo
            AND cod_modalidad = p_cod_modalidad
            AND cod_rol = v_cod_rol;
      EXCEPTION
         WHEN no_data_found then
            v_can_intentos := 0;
      END;

      IF v_can_intentos >= to_number(fug_obt_pardinamico('CAN_DPTO_COM_EVALUACION', p_cod_modulo, p_cod_modalidad)) THEN
         raise_application_error(-20086, 'Cantidad de Intentos de Simulación para Dpto. Comercial superada.');
      END IF;
   END IF;

   IF fug_val_usu_rol('ROL_DPTO_RIE_EVALUACION', USER) then
      v_cod_rol := fug_obt_pardinamico('ROL_DPTO_RIE_EVALUACION');
       --**obtener la cantidad de intentos
      BEGIN
         SELECT can_intentos
           INTO v_can_intentos
           FROM ge_dat_rie_eva_intentos
          WHERE nro_solicitud = p_nro_solicitud
            AND cod_modulo = p_cod_modulo
            AND cod_modalidad = p_cod_modalidad
            AND cod_rol = v_cod_rol;
      EXCEPTION
         WHEN no_data_found then
            v_can_intentos := 0;
      END;

      IF v_can_intentos >= to_number(fug_obt_pardinamico('CAN_DPTO_RIE_EVALUACION', p_cod_modulo, p_cod_modalidad)) THEN
         raise_application_error(-20087, 'Cantidad de Intentos de Simulación para Dpto. de Riesgos superada.');
      END IF;
   END IF;
EXCEPTION
  WHEN OTHERS THEN
    IF sqlcode <= -20000 then
      raise;
    ELSE
      raise_application_error(-20088, 'Error en (PRP_VER_ROL_CAN_INTENTOS). ' || SQLERRM);
    END IF;
END;
/

