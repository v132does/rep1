CREATE OR REPLACE FUNCTION IT.fug_val_usu_rol
(
   p_parametro   in ge_par_dinamicos.parametro%TYPE,
   p_cod_usuario in ba_usuarios.cod_usuario%TYPE
) RETURN BOOLEAN IS
   v_permiso     BOOLEAN := FALSE;
   v_cod_rol     ba_roles.cod_rol%TYPE := NULL;
   v_tie_permiso VARCHAR2(1);
BEGIN

   v_cod_rol := fug_obt_pardinamico(p_parametro);

   IF v_cod_rol IS NULL THEN
      v_permiso := FALSE;
   ELSE
   
      BEGIN
         SELECT 'S'
           INTO v_tie_permiso
           FROM ba_usu_roles a
          WHERE a.cod_usuario = p_cod_usuario
            AND a.cod_rol = v_cod_rol;
      
      EXCEPTION
         WHEN no_data_found THEN
            v_tie_permiso := 'N';
         WHEN too_many_rows THEN
            v_tie_permiso := 'S';
         WHEN OTHERS THEN
            v_tie_permiso := 'N';
      END;
   
      IF nvl(v_tie_permiso, 'N') = 'S' THEN
         v_permiso := TRUE;
      ELSE
         v_permiso := FALSE;
      END IF;
   END IF;

   RETURN v_permiso;
END;
/

