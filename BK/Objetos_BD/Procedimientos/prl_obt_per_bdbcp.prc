CREATE OR REPLACE PROCEDURE IT.PRL_OBT_PER_BDBCP
 (p_nro_documento  in  ba_personas.nro_documento%type,
 p_tip_documento in out ba_personas.cod_tip_documento%type,
 p_cod_pais in out ba_personas.cod_pais%type,
 p_nombre in out ba_personas.nom_completo%type,
 p_apellido in out ba_personas.nom_completo%type,
 p_tipo in out ba_personas.tipo%type,
 p_fec_nacimiento in out ba_per_fisicas.fec_nacimiento%type,
 p_msj_error in out varchar2 )

 IS
   v_tip_documento varchar2(3);
   v_abr_pais      varchar2(3);
   v_tipo          number(3);

begin
  --Obtener los datos de la persona de la tabla enviada por BCP
  begin
/*  ANULADO SOLO PORQUE NO ESTA CREADA LA TABLA PERSONAS_REF,
    FAVOR HABILITAR CUANDO SE CREE ESTA TABLA  
    select rf_tipo_ident, rf_pais_swift, rf_nombre, rf_apellido, 
           rf_tipo_per, rf_fecha_nac
      into v_tip_documento, v_abr_pais, p_nombre, p_apellido,
           v_tipo, p_fec_nacimiento
      from personas_ref 
     where rf_numero = p_nro_documento	 
	    and rownum <=1
  order by rf_tipo_ident;*/
  null;
    exception
       when too_many_rows then
         p_msj_error := 'Varias Personas con igual documento '||p_nro_documento;
			return;
       when no_data_found then
         p_msj_error := 'Persona Inexistente en Base del BCP.';
			return;
       when others then
         p_msj_error := 'Recup.Persona BCP '||substr(sqlerrm,1,300);
			return;
  end;
  
  --determinar el tipo de persona
  if nvl(v_tipo,0) = 0 then
     p_tipo:='F'; --física
  else
     p_tipo:='J'; --jurídica
  end if;
  
  --determinar la nacionalidad
  if v_abr_pais is not null then
     p_cod_pais := 1;
  else
     p_cod_pais := 1;
  end if;
  
  --determinar el tipo de documento
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
exception
  when others then
    If p_msj_error is not null then
      raise;
    else
      raise_application_error(-20000,'Obt.Persona '||sqlerrm);
    End if;
end;
/

