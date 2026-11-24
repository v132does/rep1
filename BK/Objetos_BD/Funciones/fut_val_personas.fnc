CREATE OR REPLACE FUNCTION IT.FUT_VAL_PERSONAS (P_COD_PERSONA IN VARCHAR2,
                                             P_MODULO IN NUMBER, P_MODALIDAD IN NUMBER,
                                             P_MONEDA IN VARCHAR, P_OFICINA IN NUMBER)
RETURN VARCHAR2 IS
  vmensaje varchar2(1000) := null;
	v_error  varchar2(1000);
  vtip_persona char(1);
	v_nro_documento ba_personas.nro_documento%type;
	v_tip_documento ba_personas.cod_tip_documento%type;
  v_cod_ci        ba_tip_documentos.cod_tip_documento%type;
  v_cod_pasaporte ba_tip_documentos.cod_tip_documento%type;
  v_cod_dni       ba_tip_documentos.cod_tip_documento%type;
  v_cod_cad       ba_tip_documentos.cod_tip_documento%type;  
  v_cod_ruc       ba_tip_documentos.cod_tip_documento%type;
	v_edad          number;
	v_fec_nacimiento date;
  v_cod_pais      ba_per_fisicas.cod_pai_nacionalidad%type;
BEGIN
  -- Busca el tipo de persona
  BEGIN
	  select tipo
	    into vtip_persona
  	  from ba_personas
	   where cod_persona = p_cod_persona;
  exception
	  when others then
      vmensaje := 'Recup.Persona '||sqlerrm;
  End;
  -- Busca el codigo de documento para Cedula de Identidad
  BEGIN
    select min( cod_tip_documento )
      into v_cod_ci
      from ba_tip_documentos
     where tip_persona IN( 'F', 'A' )
       and nvl( estado, 'A' ) <> 'I';
  Exception
    when others then
      v_cod_ci := 1;
  End;
  -- Busca el codigo de documento para Pasaporte
  BEGIN
    select distinct cod_tip_documento
      into v_cod_pasaporte
      from ba_tip_documentos
     where tip_persona IN( 'F', 'A' )
       and descripcion like 'PASAPORTE%'
       and nvl( estado, 'A' ) <> 'I';
  Exception
    when others then
      vmensaje := 'Error al traer datos para el Tipo de documento correspondiente a Pasaporte. '||sqlerrm;
  End;
  -- Busca el codigo de documento para D.N.I.
  BEGIN
    select distinct cod_tip_documento
      into v_cod_dni
      from ba_tip_documentos
     where tip_persona IN( 'F', 'A' )
       and abreviatura = 'DNI'
       and nvl( estado, 'A' ) <> 'I';
  Exception
    when others then
      vmensaje := 'Error al traer datos para el Tipo de documento correspondiente a D.N.I. '||sqlerrm;
  End;
  -- Busca el codigo de documento para Carnet de Admisión Permanente
  BEGIN
    select distinct cod_tip_documento
      into v_cod_cad
      from ba_tip_documentos
     where tip_persona IN( 'F', 'A' )
       and abreviatura = 'CRP'
       and nvl( estado, 'A' ) <> 'I';
  Exception
    when others then
      vmensaje := 'Error al traer datos para el Tipo de documento correspondiente a Certificado de Residencia Permanente '||sqlerrm;
  End;
  -- Busca el codigo de documento para RUC
  Begin
    select min( cod_tip_documento )
      into v_cod_ruc
      from ba_tip_documentos
     where tip_persona IN( 'J', 'A' )
       and nvl( estado, 'A' ) <> 'I';
  Exception
    when others then
      v_cod_ruc := 1;
  End;
  -- Traer el tipo y el nro. de documento
  	begin
  		select nro_documento, cod_tip_documento
  		  into v_nro_documento, v_tip_documento
  		  from ba_personas
  		  where cod_persona = p_cod_persona;
	  exception
  		when others then
  			vmensaje := 'Al recup Persona '||p_cod_persona||'-'||sqlerrm;
  	end;
--*
  --ver tipo de persona y documento
  if vtip_persona = 'F' then
		--verificar documento
	  if v_tip_documento not in( v_cod_ci, v_cod_pasaporte, v_cod_dni, v_cod_cad) then
	  	 vmensaje := 'Documento de la persona '||p_cod_persona||' no corresponde a Documento de Identidad, D.N.I., Certificado de Residencia Permanente, ni Pasaporte. Verifique';
	  else --validar x las dudas
	  	if not FUE_VAL_TIP_DOC(v_tip_documento, v_nro_documento, v_error) then
	  		vmensaje := 'Formato del documento de la persona '||p_cod_persona||' no corresponde '||v_error;
	  	end if;
	  end if;
   --Controlar datos de la persona fisica
  	begin
  		select fec_nacimiento, cod_pai_nacionalidad
  		  into v_fec_nacimiento, v_cod_pais
  		  from ba_per_fisicas
  		  where cod_persona = p_cod_persona;
	  exception
  		when others then
  			vmensaje := 'Al recup Persona '||p_cod_persona||'-'||sqlerrm;
	  end;
    -- Controlar que tenga pais de nacimiento
    if  v_cod_pais is null then
      vmensaje := 'La persona no tiene cargada la nacionalidad.';
    end if;
    -- Controlar que tenga fecha de nacimiento
    if  v_fec_nacimiento is null then
     	vmensaje := 'La persona no tiene cargada la fecha de nacimiento.';
    else
  	  -- calcular y controlar la edad
	    v_edad := trunc((trunc(sysdate)-v_Fec_nacimiento)/365);

      if nvl(PAE_CNF.G_PROGRAMA,'x') IN('GMPROARC','GMARCHIV') then   --El control solo para Altas Masivas
  	    if  v_edad < To_number(fug_obt_pardinamico('EDA_MIN_SOLICITUD', p_modulo, p_modalidad, p_moneda, p_oficina) ) then
           vmensaje := 'La edad minima para solicitar una tarjeta es de '||To_number(fug_obt_pardinamico('EDA_MIN_SOLICITUD', p_modulo, p_modalidad, p_moneda, p_oficina) )||' Años.';
  	    End if;
	      If  v_edad > To_number(fug_obt_pardinamico('EDA_MAX_SOLICITUD', p_modulo, p_modalidad, p_moneda, p_oficina) ) then
           vmensaje := 'La edad máxima para solicitar una tarjeta es de '||To_number(fug_obt_pardinamico('EDA_MAX_SOLICITUD', p_modulo, p_modalidad, p_moneda, p_oficina))||' Años.';
        End if;
      End if;
    End if;
	End if;

  --Para personas Juridicas
  if vtip_persona = 'J' then
		--verificar documento
	  if v_tip_documento <> v_cod_ruc then
	  	 vmensaje := 'Documento de la persona '||p_cod_persona||' no corresponde a Registro Unico del Contribuyente. Verifique.';
	  else --validar x las dudas
	  	if not FUE_VAL_TIP_DOC(v_tip_documento, v_nro_documento, v_error) then
	  		vmensaje := 'Formato del documento de la persona '||p_cod_persona||' no corresponde.';
	  	end if;
	  end if;
  End if;
--
  return vmensaje;
END;
/

