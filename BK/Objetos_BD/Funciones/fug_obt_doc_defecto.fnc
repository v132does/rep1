CREATE OR REPLACE FUNCTION IT.FUG_OBT_DOC_DEFECTO
 (P_TIPO IN BA_PERSONAS.TIPO%TYPE
 )
 RETURN VARCHAR2
 IS
v_val_defecto varchar2(100);
BEGIN
   if p_tipo = 'F' then
     select min(cod_tip_documento)
       into v_val_defecto
       from ba_tip_documentos
      where (tip_persona = p_tipo or tip_persona ='A')
        and estado = 'A'
        ---and abreviatura = 'DNI';
        and abreviatura = 'CI';
   else --para jurídicas es CUIT
     select min(cod_tip_documento)
       into v_val_defecto
       from ba_tip_documentos
      where (tip_persona = p_tipo or tip_persona ='A')
        and estado = 'A'
        ---and abreviatura = 'CUIT';
        and abreviatura = 'RUC';
   end if;
   return v_val_defecto;
exception
   when no_data_found then
      return null;
   when others then
      raise_application_error(-20000, 'Obt. doc. x defecto para '||p_tipo||'. '||sqlerrm);
END;
/

