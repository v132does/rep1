create or replace procedure it.prg_ini_cas_kyccrm(p_cod_persona varchar2, p_tipo varchar2 default 'A') is
  v_fec_actual     date := pag_cal.fu_obt_fec_actual(1);
  v_url            varchar2(100) := fug_obt_pardinamico('CRM_URL_WSI_ENV_DATOS');
  v_respuesta      typ_postrespuestaclob;
  v_xml            clob;
  v_entityid       varchar2(500); -- código entity del caso ya creado.
  v_error          varchar2(1000);
  v_usuGestor      ba_usuarios.cod_usuario%type;
  v_isBusiness     varchar2(10);
  v_regPersona     ba_personas%rowtype;
  v_regPerFisica   ba_per_fisicas%rowtype;
  v_regPerJuridica ba_per_juridicas%rowtype;
  v_fecNacimiento  varchar2(10);
  v_email          varchar2(100);
  v_direccion      varchar2(100);
  v_firsName       varchar2(60);
  v_lastName       varchar2(60);
  v_telephone1     varchar2(60);
  -- Parámetros de Tipificación del Caso en CRM.
  v_tipNiv1        varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV1');
  v_tipNiv2        varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV2');
  v_tipNiv3f       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV3F');
  v_tipNiv4f       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV4F');
  v_tipNiv5f       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV5F');
  v_tipNiv6f       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV6F');
  v_tipNiv3j       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV3J');
  v_tipNiv4j       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV4J');
  v_tipNiv5j       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV5J');
  v_tipNiv6j       varchar2(200) := fug_obt_pardinamico('CRM_TIP_KYC_NIV6J');
  v_xml_res        xmltype;
  --procedimiento para log de los mensajes
  procedure lp_reg_operacion(p_mensaje   in long,
                             p_respuesta in varchar2) is
  pragma autonomous_transaction;
    v_respuesta ge_log_env_webservice.respuesta%type;
  begin
    v_respuesta := substr(p_respuesta, 1, 4000);
    insert into ge_log_env_webservice(proceso, mensaje, respuesta)
    values('PRG_INI_CAS_KYCCRM', p_mensaje, v_respuesta);
   commit;
  exception
    when others then
      raise_application_error(-20000, sqlerrm);
  end;
  function lf_obt_entityid return varchar2 is
    v_entityid varchar2(500);
    v_len      number;
  begin
    select distinct url_crm
      into v_entityid
      from ge_per_pro_control
     where cod_persona = p_cod_persona
       and fecha = v_fec_actual;
    v_len := length(v_entityid) - 1;
    -- Se busca el entity para los casos donde no se pudo obtener la url
    if substr(v_entityid,1,1) = 'E' then 
      return substr(v_entityid,2,v_len);
    else
      return null;
    end if;
  end;
  --
  procedure lp_obt_respuesta(p_xmlres xmltype) is
    pragma autonomous_transaction;
    v_resUrlCaso  varchar2(1000);
    v_resEntityId varchar2(1000);
    v_db_name     varchar2(40);
  begin
    select upper(sys_context('USERENV', 'DB_NAME'))
      into v_db_name
      from dual;
    begin
      v_resUrlCaso := p_xmlres.extract('//return/urlCaso/text()').getStringVal();
    exception
      when others then null;
    end;
    --
    begin
      v_resEntityId := p_xmlres.extract('//return/entityId/text()').getStringVal();
    exception
      when others then null;
    end;
    if v_resUrlCaso is not null then
      v_resUrlCaso := replace(v_resUrlCaso,'&amp;','&');
      if v_db_name != 'BBVA' then
        v_resUrlCaso := replace(v_resUrlCaso,'bbvapycrmdev01:80','crmdev02.py.igrupobbva');
      end if;
      begin
        update ge_per_pro_control a
           set a.url_crm = v_resUrlCaso
         where a.cod_persona = p_cod_persona
           and a.fecha = v_fec_actual;
      exception
        when others then
          v_error := 'Al actualizar url en ge_per_pro_control '||sqlerrm;
      end;
    elsif v_resEntityId is not null then
      begin
        update ge_per_pro_control a
           set a.url_crm = 'E'||v_resEntityId
         where a.cod_persona = p_cod_persona
           and a.fecha = v_fec_actual;
      exception
        when others then
          v_error := 'Al actualizar entityId en ge_per_pro_control '||sqlerrm;
      end;
    else
      v_error := 'No se pudo obtener datos desde CRM.';
    end if;
    commit;
  end;
  procedure lp_gen_xml is
  begin
    if p_tipo = 'A' then -- A= Alta del caso en crm.
      v_xml := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dat="http://datos.crm.krba.bbva.com/"> <soapenv:Header/> <soapenv:Body> <dat:createIncident> <arg0>';
      v_direccion := fue_obt_dat_personas(p_cod_persona,'DIR');
      v_usuGestor := fug_obt_cod_usu_oficial(p_cod_persona);
      v_email     := trim(replace(replace(v_regPersona.Dir_Correo,chr(10),''),chr(13),''));
      if v_regPersona.Tipo = 'F' then
        v_firsName      := trim(v_regPerFisica.Pri_Nombre||' '||v_regPerFisica.Seg_Nombre);
        v_lastName      := trim(v_regPerFisica.Pri_Apellido||' '||v_regPerFisica.Seg_Apellido);
        v_fecNacimiento := to_char(v_regPerFisica.Fec_Nacimiento,'YYYY-MM-DD');
        v_telephone1    := fue_obt_tel_principa(p_cod_persona);
        v_xml := v_xml||' <birthdate>'||v_fecNacimiento||'</birthdate>';
        v_xml := v_xml||' <documentNumber>'||v_regPersona.Nro_Documento||'</documentNumber>';
        v_xml := v_xml||' <firstname>'||trim(v_firsName)||'</firstname>';
        v_xml := v_xml||' <lastname>'||trim(v_lastName)||'</lastname>';
        v_xml := v_xml||' <email>'||v_email||'</email>';
        v_xml := v_xml||' <telephone1>'||trim(v_telephone1)||'</telephone1>';
        v_xml := v_xml||' <address>'||trim(v_direccion)||'</address>';
        v_xml := v_xml||' <clientNumber>'||v_regPersona.Cod_Persona||'</clientNumber>';
        v_xml := v_xml||' <userCode>'||v_usuGestor||'</userCode>';
        v_xml := v_xml||' <isBusiness>'||v_isBusiness||'</isBusiness>';
      else
        v_xml := v_xml||' <name>'||trim(v_regPerJuridica.Raz_Social)||'</name>';
        v_xml := v_xml||' <accountNumber>'||v_regPerJuridica.Cod_Persona||'</accountNumber>';
        v_xml := v_xml||' <documentNumber>'||v_regPersona.Nro_Documento||'</documentNumber>';
        v_xml := v_xml||' <telephone1>'||trim(v_telephone1)||'</telephone1>';
        v_xml := v_xml||' <address>'||trim(v_direccion)||'</address>';
        v_xml := v_xml||' <userCode>'||v_usuGestor||'</userCode>';
        v_xml := v_xml||' <isBusiness>'||v_isBusiness||'</isBusiness>';
      end if;
      --
      if v_tipNiv1 is not null then
        v_xml := v_xml||' <nivel1Id>'||v_tipNiv1||'</nivel1Id>';
      end if;
      if v_tipNiv2 is not null then
        v_xml := v_xml||' <nivel2Id>'||v_tipNiv2||'</nivel2Id>';
      end if;
      --
      if v_regPersona.Tipo = 'F' then
        if v_tipNiv3f is not null then
          v_xml := v_xml||' <nivel3Id>'||v_tipNiv3f||'</nivel3Id>';
        end if;
        if v_tipNiv4f is not null then
          v_xml := v_xml||' <nivel4Id>'||v_tipNiv4f||'</nivel4Id>';
        end if;
        if v_tipNiv5f is not null then
          v_xml := v_xml||' <nivel5Id>'||v_tipNiv5f||'</nivel5Id>';
        end if;
        if v_tipNiv6f is not null then
          v_xml := v_xml||' <nivel6Id>'||v_tipNiv6f||'</nivel6Id>';
        end if;
      else
        if v_tipNiv3j is not null then
          v_xml := v_xml||' <nivel3Id>'||v_tipNiv3j||'</nivel3Id>';
        end if;
        if v_tipNiv4j is not null then
          v_xml := v_xml||' <nivel4Id>'||v_tipNiv4j||'</nivel4Id>';
        end if;
        if v_tipNiv5j is not null then
          v_xml := v_xml||' <nivel5Id>'||v_tipNiv5j||'</nivel5Id>';
        end if;
        if v_tipNiv6j is not null then
          v_xml := v_xml||' <nivel6Id>'||v_tipNiv6j||'</nivel6Id>';
        end if;
      end if;
      --
      v_xml := v_xml||' </arg0> </dat:createIncident> </soapenv:Body> </soapenv:Envelope>';
    elsif p_tipo = 'C' then -- solo consulta URL del caso ya creado.
      v_entityid := lf_obt_entityid;
      v_xml := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dat="http://datos.crm.krba.bbva.com/"> <soapenv:Header/> <soapenv:Body> <dat:getIncident>';
      v_xml := v_xml||'<arg0>'||v_entityid||'</arg0>';
      v_xml := v_xml||'</dat:getIncident> </soapenv:Body> </soapenv:Envelope>';
    end if;
  exception
    when others then
      raise_application_error(-20000, sqlerrm);
  end;

begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
  begin
    select * into v_regPersona from ba_personas
    where cod_persona = p_cod_persona;
  exception
    when no_data_found then
      v_error := 'Código de Persona Inexistente.';
  end;
  --
  begin
    select * into v_regPerFisica from ba_per_fisicas
    where cod_persona = p_cod_persona;
  exception
    when no_data_found then null;
  end;
  --
  begin
    select * into v_regPerJuridica from ba_per_juridicas
    where cod_persona = p_cod_persona;
  exception
    when no_data_found then null;
  end;
  if v_regPersona.Tipo = 'F' then
    v_isBusiness := 'FALSE';
  else
    v_isBusiness := 'TRUE';
  end if;
  --
  lp_gen_xml;
  v_respuesta := fug_wsi_env_rba(v_xml,v_url);
  lp_reg_operacion(v_xml,substr(v_respuesta.error ||' - '||v_respuesta.codigoError ||' - '|| nvl(v_respuesta.respuesta,v_respuesta.descripcionRespuesta), 1, 4000));

  if v_respuesta.error = 'N' then
    v_xml_res := xmltype(v_respuesta.respuesta);
    lp_obt_respuesta(v_xml_res);
  else
    if instr(v_respuesta.descripcionRespuesta,'HTTP request failed') > 0 then
      v_error := 'Solicitud HTTP fallida.';
      raise_application_error(-20000,v_error);
    else
      v_error := v_respuesta.respuesta;
      raise_application_error(-20000,v_error);
    end if;
  end if;
exception
  when others then
    if v_error is not null then
      raise_application_error(-20000,v_error);
    else
      raise_application_error(-20000,nvl(v_respuesta.respuesta,v_respuesta.descripcionRespuesta)||sqlerrm);
    end if;
end;
/

