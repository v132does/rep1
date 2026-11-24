CREATE OR REPLACE FUNCTION IT.FUG_OBT_DIR_MAIL_PER
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS

RESULT BA_PERSONAS.DIR_CORREO%TYPE;
Begin 
    SELECT DIR_CORREO
      INTO Result
      from BA_PERSONAS
      where cod_persona = p_cod_persona; 
      if Result is null then
        Begin  
           select a.dir_correo
             into result
             from ba_mails a
            where a.cod_persona = P_COD_PERSONA
              and a.principal = 'S';
        Exception
           when no_data_found then
              select a.dir_correo
                into result
                from ba_mails a
               where a.cod_persona = P_COD_PERSONA
                 and rownum = 1;
        End;
   end if;
   return(Result);
Exception
   when others then
      return null;
End;
/

