CREATE OR REPLACE FUNCTION IT.fug_obt_ofi_usu_rrhh RETURN VARCHAR2 IS
   v_cod_oficina ba_oficinas.cod_oficina%TYPE;
   v_error       VARCHAR2(1000);
BEGIN
   --Obtiene la oficina del usuario de RRHH para la recuperación del Nro. de Hoja de Seguridad
   IF fug_val_usu_rol('ROL_GEN_CLA_RRHH', USER) THEN
      v_cod_oficina := fug_obt_pardinamico('COD_OFI_GEN_CLA_RRHH');
      v_error       := 'No se encuentra el valor del parámetro correspondiente a la oficina del Dpto. de RRHH.';
   ELSE
      v_cod_oficina := fug_obt_ofi_usuario(USER);
      v_error       := 'No se encuentra la oficina del usuario. Verifique!';
   END IF;

   IF v_cod_oficina IS NULL THEN
      raise_application_error(-20001, v_error);
   ELSE
      RETURN(v_cod_oficina);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'FUG_OBT_OFI_USU_RRHH ' || SQLERRM);
END;
/

