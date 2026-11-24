CREATE OR REPLACE FUNCTION IT.FUE_OBT_PER_TIP_IVA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS

V_TIP_IVA BA_PERSONAS.TIP_IVA%TYPE;
Begin
    --Obtiene el tipo de contribuyente de la persona
    if p_cod_persona is not null then
        select tip_iva
        into v_tip_iva
        from ba_personas
        where cod_persona = p_cod_persona;
    end if;
    return v_tip_iva;

    exception
       when no_data_found then
           return('Persona no registrada en el Sistema');
End;
/

