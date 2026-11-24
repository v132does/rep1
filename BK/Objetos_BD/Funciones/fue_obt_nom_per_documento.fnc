CREATE OR REPLACE FUNCTION IT.FUE_OBT_NOM_PER_DOCUMENTO
 (P_nro_documento IN BA_PERSONAS.nro_documento%TYPE,
 P_COD_PERSONA IN OUT BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS

V_NOM_COMPLETO BA_PERSONAS.NOM_COMPLETO%TYPE;

Begin
   begin
     --Obtiene el Nombre completo de la persona x el nro d documento Tipo cédula
     select nom_completo, cod_persona
       into v_nom_completo, p_cod_persona
       from ba_personas
      where nro_documento = p_nro_documento
        and cod_tip_documento = 1;
   exception
     when too_many_rows then 
       RAISE_APPLICATION_ERROR(-20000,'Varias Personas con igual nro.documento ');
     when no_data_found then
       -- Si no tiene cédula busca por otro Tipo de Documento
       begin
         --Obtiene el Nombre completo de la persona x el nro d documento
         select nom_completo, cod_persona
           into v_nom_completo, p_cod_persona
           from ba_personas
          where nro_documento = p_nro_documento
            and rownum = 1;
       exception
         when too_many_rows then 
           RAISE_APPLICATION_ERROR(-20000,'Varias Personas con igual nro.documento ');
         when no_data_found then
           v_nom_completo := null;  
         when OTHERS then
           RAISE_APPLICATION_ERROR(-20000,'Recup.Persona '||sqlerrm);    
       end;
     when OTHERS then
       RAISE_APPLICATION_ERROR(-20000,'Recup.Persona '||sqlerrm);    
   end;
   --
   return v_nom_completo;         
End;
/

