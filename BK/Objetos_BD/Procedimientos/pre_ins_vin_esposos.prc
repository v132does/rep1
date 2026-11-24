CREATE OR REPLACE PROCEDURE IT.PRE_INS_VIN_ESPOSOS
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_PER_VINCULO IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 IS
BEGIN
   BEGIN
      insert into ba_vinculos(cod_persona, cod_per_vinculo, tipo)
      values (p_cod_persona, p_cod_per_vinculo, 'E');
      exception
         when dup_val_on_index then null;
   END;
   BEGIN
      insert into ba_vinculos(cod_persona, cod_per_vinculo, tipo)
      values (p_cod_per_vinculo, p_cod_persona, 'E');
      exception
         when dup_val_on_index then null;
   END;
END;
/

