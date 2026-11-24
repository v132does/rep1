CREATE OR REPLACE FUNCTION IT.FUE_OBT_COD_PERSONA_DOC(P_COD_TIP_DOCUMENTO IN NUMBER, P_NRO_DOCUMENTO IN VARCHAR2)
 RETURN VARCHAR2 IS
  v_cod_persona ba_personas.cod_persona%type;
BEGIN
    select cod_persona
     into v_cod_persona
     from ba_personas p
    where cod_tip_documento = P_COD_TIP_DOCUMENTO
      and nro_documento = P_NRO_DOCUMENTO;
return v_cod_persona;
    exception
       when no_data_found then
           if P_COD_TIP_DOCUMENTO IN (3,5) THEN --'CRP'/'CRC'
              Begin
                select cod_persona
                  into v_cod_persona
                  from ba_personas p
                 where nro_documento = P_NRO_DOCUMENTO
                   and cod_tip_documento <> 38;
                return v_cod_persona;
                exception
                   when others then
                      return null;         
              End;  
           else
               return null;
           end if;    
END;
/

