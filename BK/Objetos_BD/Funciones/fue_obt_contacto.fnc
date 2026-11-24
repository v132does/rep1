CREATE OR REPLACE FUNCTION IT.FUE_OBT_CONTACTO
 (P_COD_PERSONA IN VARCHAR2
 )
 RETURN VARCHAR
 IS

V_CONTACTO BA_VINCULOS.COD_PER_VINCULO%TYPE;

Begin
    --Obtiene el Contacto de la persona
    select b.cod_per_vinculo
      into v_contacto
    from ba_vinculos b
    where b.tipo = 'CA'
    and b.cod_persona = p_cod_persona;
   return(v_contacto);
exception
   when others then
     return ' ';
End;
/

