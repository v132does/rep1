CREATE OR REPLACE PROCEDURE IT.PRL_OBT_DAT_PER_BCP
 (p_nro_documento  in  ba_personas.nro_documento%type,
 p_tip_documento in out ba_personas.cod_tip_documento%type,
 p_cod_pais in out ba_personas.cod_pais%type,
 p_nombre in out ba_personas.nom_completo%type,
 p_apellido in out ba_personas.nom_completo%type,
 p_msj_error in out varchar2,
 p_abr_tip_doc in out ba_tip_documentos.abreviatura%type,
 p_cod_pai_iso in out ba_paises.cod_pai_iso%type )

 IS
   v_tip_documento varchar2(3);
   v_abr_pais      varchar2(3);
   v_tipo          number(3);

begin
  --Obtener los datos de la persona de la tabla enviada por BCP 
  begin
   /* select rf_tipo_ident, rf_pais_swift, rf_nombre, rf_apellido
      into v_tip_documento, v_abr_pais, p_nombre, p_apellido
      from personas_ref 
     where rf_numero = p_nro_documento
     order by rf_tipo_ident;*/
      select p.cod_tip_documento, pa.cod_pai_iso, fe.pri_nombre, fe.pri_apellido
      into v_tip_documento, v_abr_pais, p_nombre, p_apellido
      from ba_personas p , ba_per_fisicas fe, ba_paises pa
     where p.nro_documento= p_nro_documento
      and p.cod_persona = fe.cod_persona
      and p.cod_pais = pa.cod_pais
      and rownum <=1
  order by p.cod_tip_documento;
    exception
       when too_many_rows then
         p_msj_error := 'Varias Personas con igual documento '||p_nro_documento;
      return;
       when no_data_found then
         p_msj_error := 'Inexistente';
      return;
       when others then
         p_msj_error := 'Recup.Persona BCP '||substr(sqlerrm,1,300);
      return;
  end;
  
    --Obtener el tipo de documento
  if v_tip_documento is not null then
     begin
       select min(cod_tip_documento)
         into p_tip_documento
         from ba_tip_documentos
        where abreviatura = v_tip_documento;
     exception
        when others then
           p_tip_documento := 1; --CI
     end;
  else              
     p_tip_documento := 1; --CI
  end if;
  
  --Obtener la nacionalidad
  if v_abr_pais is not null then
     begin
       select min(cod_pais)
         into p_cod_pais
         from ba_paises
        where cod_pai_iso = v_abr_pais;
     exception
        when others then
           p_cod_pais := 1; --CI
     end;
  else
     p_cod_pais := 1;
  end if;
  p_abr_tip_doc := v_tip_documento;
  p_cod_pai_iso := v_abr_pais;
exception
  when others then
    If p_msj_error is not null then
      raise;
    else
      raise_application_error(-20000,'Obt.Persona '||sqlerrm);
    End if;
end;
/

