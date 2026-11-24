CREATE OR REPLACE FUNCTION IT.fug_ind_produccion RETURN VARCHAR2 IS
   v_db_prod ge_par_dinamicos.val_parametro%TYPE := lower(fug_obt_pardinamico('BD_PROD'));
   v_db_name ge_par_dinamicos.val_parametro%TYPE;
BEGIN
   -- Tomar las Variables SID Base de Datos
   BEGIN
      SELECT sys_context('USERENV','DB_UNIQUE_NAME')
        INTO v_db_name
        FROM dual;
   EXCEPTION
      WHEN OTHERS THEN
         v_db_name := NULL;
   END;

   IF instr( (','||v_db_name||','), (','||v_db_prod||',')) > 0 AND
      v_db_name IS NOT NULL THEN
      -- Si la Base es Produccion salir
      RETURN 'S';
   ELSE
      RETURN 'N';
   END IF;
END;
/

