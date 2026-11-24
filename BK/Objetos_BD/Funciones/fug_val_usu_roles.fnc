CREATE OR REPLACE FUNCTION IT.fug_val_usu_roles (p_cod_usuario  in ba_usuarios.cod_usuario%TYPE,
                                                 p_parametro    in ge_par_dinamicos.parametro%TYPE
                                                 ) RETURN VARCHAR2 IS
   v_cod_rol     VARCHAR2(1000):= NULL;
   v_tie_permiso VARCHAR2(1)   := 'N';
BEGIN
   --obtener cadena de roles configurado en el parámetro
   v_cod_rol := fug_obt_pardinamico(p_parametro);

   IF v_cod_rol IS NULL THEN
      v_tie_permiso := 'N';
   ELSE
   --Verifica el rol del usuario vs. el parámetro
      BEGIN
         SELECT 'S'
           INTO v_tie_permiso
           FROM ba_usu_roles a
          WHERE a.cod_usuario = p_cod_usuario
            AND INSTR(v_cod_rol, ','||a.cod_rol||',') > 0;

      EXCEPTION
         WHEN no_data_found THEN
            v_tie_permiso := 'N';
         WHEN too_many_rows THEN
            v_tie_permiso := 'S';
         WHEN OTHERS THEN
            v_tie_permiso := 'N';
      END;
   END IF;

   RETURN v_tie_permiso;
END;
/
