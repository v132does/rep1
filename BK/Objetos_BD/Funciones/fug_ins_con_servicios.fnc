CREATE OR REPLACE FUNCTION IT.fug_ins_con_servicios(p_sesion      IN VARCHAR2,
                                                    p_codCanal    IN VARCHAR2,
                                                    p_codServicio IN VARCHAR2,
                                                    p_usuario     IN typ_contratarserviciousuario default null)
  RETURN typ_contratarservicio IS
  v_parametros      VARCHAR2(4000) := null;
  retValidarSesion  paw_bem.typ_validarSesion;
  v_cod_canal       VARCHAR2(3);
  v_retorno         typ_contratarservicio := typ_contratarservicio;
  v_cod_persona_emp ba_personas.cod_persona%type;
  v_cod_persona_usu ba_personas.cod_persona%type;
  v_codigoUsuario   VARCHAR2(10);
  v_dominio         VARCHAR2(100) := 'CON_TIP_SERVICIOS';
  v_existe          VARCHAR2(1);
  v_inf_json        long := null;
  v_nombre_emp      ba_per_juridicas.raz_social%type;
  v_nro_documento   ba_personas.nro_documento%type;
  v_nom_cliente     ba_personas.nom_completo%type;
  v_nro_doc_cliente ba_personas.nro_documento%type;
  v_error           varchar2(2) := '0';
  v_dir_empresa     ba_personas.Dir_Correo%type;
  v_ciu_empresa     ba_ciudades.descripcion%type;
  v_tip_empresa     ba_per_juridicas.naturaleza%type;
  v_tel_empresa     ba_telefonos.telefono%type;
  v_cod_rub_pri     ba_personas.cod_rub_primario%type;
  v_ocupacion       ba_cod_referencias.significado%type;
  v_direccion       ba_direcciones.direccion%type; 
  v_correo_emp      ba_personas.Dir_Correo%type;
  v_correo_int      ba_personas.Dir_Correo%type;
  /** Constantes de tipo de Bitacora */
  --https://itti-digital.atlassian.net/browse/NVB-3811
  bitacora_error   CONSTANT VARCHAR2(3) := 'ERR';
  bitacora_entrada CONSTANT VARCHAR2(3) := 'ENT';
  bitacora_salida  CONSTANT VARCHAR2(3) := 'SAL';
  PROCEDURE pr_insertarBitacora(p_codigoPersona       IN VARCHAR2 DEFAULT NULL,
                                p_codigoCanal         IN VARCHAR2 DEFAULT NULL,
                                p_codSesion           IN VARCHAR2 DEFAULT NULL,
                                p_tipoMensaje         IN VARCHAR2 DEFAULT NULL,
                                p_codigoEmpresa       IN VARCHAR2 DEFAULT NULL,
                                p_datos               IN VARCHAR2 DEFAULT NULL,
                                p_tipo                IN VARCHAR2 DEFAULT NULL,
                                p_numeroTelefono      IN VARCHAR2 DEFAULT NULL,
                                p_codigoError         IN VARCHAR2 DEFAULT NULL,
                                p_observacion         IN VARCHAR2 DEFAULT NULL,
                                p_codigoMotivo        IN VARCHAR2 DEFAULT NULL,
                                p_numeroCuentaDebito  IN VARCHAR2 DEFAULT NULL,
                                p_numeroCuentaCredito IN VARCHAR2 DEFAULT NULL,
                                p_monto               IN NUMBER DEFAULT NULL,
                                p_codigoMoneda        IN VARCHAR2 DEFAULT NULL,
                                p_dato2               IN CLOB DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO bw_bitacoras
      (COD_PERSONA,
       COD_CANAL,
       COD_SESION,
       COD_TIP_MENSAJE,
       COD_PER_VINCULADA,
       DATO,
       TIPO,
       DATO2)
    VALUES
      (p_codigoPersona,
       p_codigoCanal,
       p_codSesion,
       p_tipoMensaje,
       p_codigoEmpresa,
       SUBSTR(p_datos, 1, 4000),
       p_tipo,
       p_dato2);
  
    IF p_tipo = BITACORA_ERROR and p_observacion is not null THEN
      insert into bw_log_incidencias
        (nro_telefono,
         cod_error,
         usu_insercion,
         fec_insercion,
         observacion,
         nro_caja,
         cod_tip_mensaje,
         cod_persona,
         nro_cta_debito,
         nro_cta_credito,
         monto,
         cod_moneda,
         cod_motivo)
      values
        (p_numeroTelefono,
         p_codigoError,
         user,
         sysdate,
         p_observacion,
         p_codigoCanal,
         p_tipoMensaje,
         p_codigoPersona,
         p_numeroCuentaDebito,
         p_numeroCuentaCredito,
         p_monto,
         p_codigoMoneda,
         p_codigoMotivo);
    END IF;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
  FUNCTION fu_generarBitacora(error                in varchar2,
                              nombreRespuesta      in varchar2,
                              descripcionRespuesta in varchar2,
                              mensajesAdicionales  in varchar2 := NULL)
    RETURN VARCHAR2 IS
    v_linea    VARCHAR2(1000);
    v_paquete  VARCHAR2(1000);
    v_llamador VARCHAR2(1000);
    v_duenho   VARCHAR2(1000);
  BEGIN
    OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
    RETURN v_paquete || '.' || v_linea || sys_context('USERENV', 'ACTION') || ' Userid:' || sys_context('USERENV',
                                                                                                        'SESSION_USER') || ' Ip:' || sys_context('USERENV',
                                                                                                                                                 'IP_ADDRESS') || ' isDBA:' || sys_context('USERENV',
                                                                                                                                                                                           'ISDBA') || ' Error:' ||(CASE
                                                                                                                                                                                                                    error WHEN 'S' THEN 'T' WHEN 'N' THEN 'F' END) || ' nombreRespuesta:' || nombreRespuesta || ' descripcionRespuesta:' || descripcionRespuesta;
  END;
  PROCEDURE pr_env_alerta(p_cod_persona  in ba_personas.cod_persona%type,
                          p_tip_producto in ge_mai_onb_templates.tip_producto%type,
                          p_inf_json     in ba_env_correos.parametros%type,
                          p_dir_correo   in ba_env_correos.mai_destinatario%type,
                          p_salida       out varchar2) IS
    /*
    || Envía alertas
    */
    v_cod_persona ba_personas.cod_persona%type := p_cod_persona;
    v_dir_mail    ba_env_correos.mai_destinatario%type := p_dir_correo;
    v_error       varchar2(2) := '0';
  begin
  
    if v_dir_mail is not null then
      begin
        insert into it.ba_env_correos
          (cod_persona,
           tip_producto,
           estado,
           fec_registro,
           parametros,
           mai_destinatario)
        values
          (p_cod_persona,
           p_tip_producto,
           'P',
           sysdate,
           p_inf_json,
           v_dir_mail);
      
      exception
        when others then
          v_error  := '01';
          p_salida := v_error;
      end;
    end if;
  p_salida:='0';
  exception
    when others then
      v_error  := '01';
      p_salida := v_error;
  end pr_env_alerta;
begin
  pre_cam_for_numerico('.,');
  v_cod_canal  := paw_bem.depurarAlfanumerico(p_codCanal, 3);
  v_parametros := 'fug_Ins_Con_Servicios' || ' Sesion: ' || p_sesion ||
                  ' Canal: ' || p_codCanal || ' CodServicio: ' ||
                  p_codServicio;

  pr_insertarBitacora(retValidarSesion.codigoPersona,
                      v_cod_canal,
                      p_sesion,
                      retValidarSesion.codigoEmpresa,
                      v_parametros,
                      bitacora_entrada);

  --valido la sesión del cliente 
  retValidarSesion := paw_bem.fu_validarSesion(p_sesion, p_codCanal);
  IF retValidarSesion.error = 'S' THEN
    v_retorno.error                := retValidarSesion.error;
    v_retorno.nombreRespuesta      := retValidarSesion.nombreRespuesta;
    v_retorno.descripcionRespuesta := retValidarSesion.descripcionRespuesta;
    RETURN v_retorno;
  END IF;
  v_codigoUsuario   := fug_obt_user_sesion(p_sesion);
  v_cod_persona_emp := nvl(retValidarSesion.codigoEmpresa,
                           retValidarSesion.codigoPersona);
  v_cod_persona_usu := retValidarSesion.codigoPersona;
  -- valido el codigo de servicio recibido
  begin
    select 'S'
      into v_existe
      from ba_cod_referencias
     where dominio = v_dominio
       and val_minimo = p_codServicio;
  exception
    when no_data_found then
      v_existe := 'N';
    when others then
      v_existe := 'N';
  end;
   -- Busca datos de la empresa
  begin
    select raz_social,
           a.nro_documento,
           fue_per_dat_adicional(j.cod_persona, 'EMAIL_ONB_EMPRESAS'),
           j.naturaleza,
           fue_tab_dat_adicional('BA_PERSONAS',
                                 'CELULAR_ONBOARDING',
                                 j.cod_persona),
           a.cod_rub_primario
      into v_nombre_emp,
           v_nro_documento,
           v_dir_empresa,
           v_tip_empresa,
           v_tel_empresa,
           v_cod_rub_pri
      from ba_per_juridicas j, ba_personas a
     where j.cod_persona = v_cod_persona_emp
       and a.cod_persona = j.cod_persona;
  exception
    when no_data_found then
         v_nro_documento := null;
         v_nombre_emp:= null;
    when others then
         v_nro_documento := null;
         v_nombre_emp:= null;
  end;
  begin
    select ciu.descripcion,d.direccion
      into v_ciu_empresa,v_direccion
      from ba_direcciones d, ba_personas a,ba_ciudades ciu
     where d.cod_persona = a.cod_persona
       and a.cod_persona = v_cod_persona_emp
       and d.tipo= 'L'
        and d.principal= 'S'
        and ciu.cod_ciudad=d.cod_ciudad
        and ciu.cod_pais=d.cod_pais;
  exception
    when no_data_found then
      v_ciu_empresa:= null;
    when others then
      v_ciu_empresa:= null;
  end; 
   begin
     select b.significado into v_ocupacion
       from ge_rub_economicos t, ba_cod_referencias b
      where t.cod_rub_economico = v_cod_rub_pri
        and b.dominio = 'ONB_EMP_OCUPACIONES'
        and b.val_maximo = t.cod_rub_economico;
  exception 
    when no_data_found then
          v_ocupacion := null;
   when others then 
     v_ocupacion := null;
   end;
   
   -- Busca nombre de la persona que realizó la solicitud
  if v_cod_persona_usu is not null then
    BEGIN
     
      select b.nom_completo, b.nro_documento
        into v_nom_cliente, v_nro_doc_cliente
        from ba_personas b
       where b.cod_persona = v_cod_persona_usu;
    
    EXCEPTION
      when no_data_found then
        v_nom_cliente     := null;
        v_nro_doc_cliente := null;
      when others then
        v_nom_cliente     := null;
        v_nro_doc_cliente := null;
    END;
  end if;

  if nvl(v_existe, 'N') = 'S' then
    if p_codServicio = 'CON_PAG_PRO' then
      --PAGO A PROVEEDORES
    
      begin
        --Texto sugerido
        v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"nombres":' || '"' || v_nom_cliente || '"' || ',' ||
                      '"numeroDocumento":' || '"' || v_nro_doc_cliente || '"' || ',' ||
                      '"empresa.ruc":' || '"' || v_nro_documento || '"' || '}';
        v_correo_emp:=v_dir_empresa;
      
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSPP'),
                      v_inf_json,
                      v_correo_emp,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
      if v_error = '0' then
       --envio de correo interno
      begin
        --Texto sugerido
        v_inf_json := '{' || '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.tipEmpresa":' || '"' || v_tip_empresa|| '"' || ',' ||
                      '"empresa.ruc":' || '"' || v_nro_documento || '"' || ',' ||
                      '"empresa.correo":' || '"' || v_dir_empresa|| '"' || ',' ||
                      '"empresa.ciudad":' || '"' || v_ciu_empresa || '"' || ',' ||
                      '"empresa.telefono":' || '"' || v_tel_empresa || '"' || ',' ||
                      '"empresa.act_eco":' || '"' || v_ocupacion || '"' || ',' ||
                      '"empresa.direccion":' || '"' || v_direccion || '"' || ',' ||
                      '"nombres":' || '"' || v_nom_cliente || '"' || ',' ||
                      '"numeroDocumento":' || '"' || v_nro_doc_cliente || '"' || '}';
      
     v_correo_int:= fug_obt_pardinamico('CON_DIR_CORREO');
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSPPI'),
                      v_inf_json,
                      v_correo_int,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
    end if;
    elsif p_codServicio = 'CON_PAG_SAL' then
      begin
       v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"nombres":' || '"' || v_nom_cliente || '"' || ',' ||
                      '"numeroDocumento":' || '"' || v_nro_doc_cliente || '"' || ',' ||
                      '"empresa.ruc":' || '"' || v_nro_documento || '"' || '}';
                     
        v_correo_emp:=v_dir_empresa;
        --Texto sugerido
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSPS'),
                      v_inf_json,
                      v_correo_emp,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
      if v_error = '0' then
       --envio de correo interno
      begin
        --Texto sugerido
        v_inf_json := '{' || '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.tipEmpresa":' || '"' || v_tip_empresa|| '"' || ',' ||
                      '"empresa.ruc":' || '"' || v_nro_documento || '"' || ',' ||
                      '"empresa.correo":' || '"' || v_dir_empresa|| '"' || ',' ||
                      '"empresa.ciudad":' || '"' || v_ciu_empresa || '"' || ',' ||
                      '"empresa.telefono":' || '"' || v_tel_empresa || '"' || ',' ||
                      '"empresa.act_eco":' || '"' || v_ocupacion || '"' || ',' ||
                      '"empresa.direccion":' || '"' || v_direccion || '"' || ',' ||
                      '"nombres":' || '"' || v_nom_cliente || '"' || ',' ||
                      '"numeroDocumento":' || '"' || v_nro_doc_cliente || '"' || '}';
      v_correo_int:= fug_obt_pardinamico('CON_DIR_CORREO');
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSPSI'),
                      v_inf_json,
                     v_correo_int,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
    end if;
    elsif p_codServicio = 'CON_COM_ADH' then

      begin
       v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"nombres":' || '"' || v_nom_cliente || '"' || ',' ||
                      '"numeroDocumento":' || '"' || v_nro_doc_cliente || '"' || ',' ||
                      '"empresa.ruc":' || '"' || v_nro_documento || '"' || '}';
                     
        v_correo_emp:=v_dir_empresa;
        --Texto sugerido
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSCA'),
                      v_inf_json,
                      v_correo_emp,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
       if v_error = '0' then
       --envio de correo interno
      begin
        --Texto sugerido
        v_inf_json := '{' || '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.tipEmpresa":' || '"' || v_tip_empresa|| '"' || ',' ||
                      '"empresa.ruc":' || '"' || v_nro_documento || '"' || ',' ||
                      '"empresa.correo":' || '"' || v_dir_empresa|| '"' || ',' ||
                      '"empresa.ciudad":' || '"' || v_ciu_empresa || '"' || ',' ||
                      '"empresa.telefono":' || '"' || v_tel_empresa || '"' || ',' ||
                      '"empresa.act_eco":' || '"' || v_ocupacion || '"' || ',' ||
                      '"empresa.direccion":' || '"' || v_direccion || '"' || ',' ||
                      '"nombres1":' || '"' || p_usuario.Nombre1 || '"' || ',' ||
                      '"numeroDocumento1":' || '"' || p_usuario.Nrodocumento1 || '"' || ',' ||
                      '"correo1":' || '"' ||  p_usuario.CorreoElectronico1 || '"' || ',' ||
                      '"numeroCelular1":' || '"' || p_usuario.telefono1|| '"' || ',' ||
                      '"nombres2":' || '"' || p_usuario.Nombre2 || '"' || ',' ||
                      '"numeroDocumento2":' || '"' || p_usuario.Nrodocumento2 || '"' || ',' ||
                      '"correo2":' || '"' ||  p_usuario.CorreoElectronico2 || '"' || ',' ||
                      '"numeroCelular2":' || '"' || p_usuario.telefono2|| '"' || ',' ||
                      '"nombres3":' || '"' || p_usuario.Nombre3 || '"' || ',' ||
                      '"numeroDocumento3":' || '"' || p_usuario.Nrodocumento3 || '"' || ',' ||
                      '"correo3":' || '"' ||  p_usuario.CorreoElectronico3 || '"' || ',' ||
                      '"numeroCelular3":' || '"' || p_usuario.telefono3|| '"' || ',' ||
                      '"nombres4":' || '"' || p_usuario.Nombre4 || '"' || ',' ||
                      '"numeroDocumento4":' || '"' || p_usuario.Nrodocumento4 || '"' || ',' ||
                      '"correo4":' || '"' ||  p_usuario.CorreoElectronico4 || '"' || ',' ||
                      '"numeroCelular4":' || '"' || p_usuario.telefono4|| '"' || ',' ||
                      '"nombres5":' || '"' || p_usuario.Nombre5 || '"' || ',' ||
                      '"numeroDocumento5":' || '"' || p_usuario.Nrodocumento5 || '"' || ',' ||
                      '"correo5":' || '"' ||  p_usuario.CorreoElectronico5 || '"' || ',' ||
                     '"numeroCelular5":' || '"' || p_usuario.telefono5 || '"' || '}';
       v_correo_int:= fug_obt_pardinamico('CON_DIR_CORREO');
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSCAI'),
                      v_inf_json,
                      v_correo_int,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
    end if;
    elsif p_codServicio = 'CON_PUN_WEP' then
  
      begin
       v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"nombres":' || '"' || v_nom_cliente || '"' || ',' ||
                      '"numeroDocumento":' || '"' || v_nro_doc_cliente || '"' || ',' ||
                      '"empresa.ruc":' || '"' || v_nro_documento || '"' || '}';
        v_correo_emp:=v_dir_empresa;        
      
        --Texto sugerido
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSPW'),
                      v_inf_json,
                      v_correo_emp,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
       if v_error = '0' then
       --envio de correo interno
      begin
        --Texto sugerido
        v_inf_json := '{' || '"empresa.nombreEmp":' || '"' || v_nombre_emp || '"' || ',' ||
                      '"empresa.tipEmpresa":' || '"' || v_tip_empresa|| '"' || ',' ||
                      '"num_documento":' || '"' || v_nro_documento || '"' || ',' ||
                      '"empresa.correo":' || '"' || v_dir_empresa|| '"' || ',' ||
                      '"empresa.ciudad":' || '"' || v_ciu_empresa || '"' || ',' ||
                      '"empresa.telefono":' || '"' || v_tel_empresa || '"' || ',' ||
                      '"empresa.act_eco":' || '"' || v_ocupacion || '"' || ',' ||
                      '"empresa.direccion":' || '"' || v_direccion || '"' || ',' ||
                      '"nombres1":' || '"' || p_usuario.Nombre1 || '"' || ',' ||
                      '"numeroDocumento1":' || '"' || p_usuario.Nrodocumento1 || '"' || ',' ||
                      '"correo1":' || '"' ||  p_usuario.CorreoElectronico1 || '"' || ',' ||
                      '"numeroCelular1":' || '"' || p_usuario.telefono1|| '"' || ',' ||
                      '"nombres2":' || '"' || p_usuario.Nombre2 || '"' || ',' ||
                      '"numeroDocumento2":' || '"' || p_usuario.Nrodocumento2 || '"' || ',' ||
                      '"correo2":' || '"' ||  p_usuario.CorreoElectronico2 || '"' || ',' ||
                      '"numeroCelular2":' || '"' || p_usuario.telefono2|| '"' || ',' ||
                      '"nombres3":' || '"' || p_usuario.Nombre3 || '"' || ',' ||
                      '"numeroDocumento3":' || '"' || p_usuario.Nrodocumento3 || '"' || ',' ||
                      '"correo3":' || '"' ||  p_usuario.CorreoElectronico3 || '"' || ',' ||
                      '"numeroCelular3":' || '"' || p_usuario.telefono3|| '"' || ',' ||
                      '"nombres4":' || '"' || p_usuario.Nombre4 || '"' || ',' ||
                      '"numeroDocumento4":' || '"' || p_usuario.Nrodocumento4 || '"' || ',' ||
                      '"correo4":' || '"' ||  p_usuario.CorreoElectronico4 || '"' || ',' ||
                      '"numeroCelular4":' || '"' || p_usuario.telefono4|| '"' || ',' ||
                      '"nombres5":' || '"' || p_usuario.Nombre5 || '"' || ',' ||
                      '"numeroDocumento5":' || '"' || p_usuario.Nrodocumento5 || '"' || ',' ||
                      '"correo5":' || '"' ||  p_usuario.CorreoElectronico5 || '"' || ',' ||
                     '"numeroCelular5":' || '"' || p_usuario.telefono5 || '"' || '}';
       v_correo_int:= fug_obt_pardinamico('CON_DIR_CORREO');
        --Insertar correo para la empresa
        pr_env_alerta(v_cod_persona_emp,
                      fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                 'ENVNOTCSPWI'),
                      v_inf_json,
                     v_correo_int,
                      v_error);
      
      exception
        when others then
          v_error := '01';
      end;
    end if;
    end if;
    if v_error = '0' then
      v_retorno.nombreRespuesta      := '0';
      v_retorno.descripcionRespuesta := 'Solicitud registrada con exito. ';
      v_retorno.error                := 'N';
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          null,
                          retValidarSesion.codigoEmpresa,
                          v_parametros || ' ' ||
                          fu_generarBitacora(v_retorno.error,
                                             v_retorno.nombreRespuesta,
                                             v_retorno.descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      return v_retorno;
    else
      v_retorno.nombreRespuesta      := 'PRO_CON_SER_02';
      v_retorno.descripcionRespuesta := 'Error en envio de correo.-' ||
                                        p_codServicio;
      v_retorno.error                := 'S';
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          NULL,
                          retValidarSesion.codigoEmpresa,
                          v_parametros || ' ' ||
                          fu_generarBitacora(v_retorno.error,
                                             v_retorno.nombreRespuesta,
                                             v_retorno.descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      return v_retorno;
    end if;
  elsif nvl(v_existe, 'N') = 'N' then
    v_retorno.nombreRespuesta      := 'PRO_CON_SER_01';
    v_retorno.descripcionRespuesta := 'Error en p_codServicio recibido.-' ||
                                      p_codServicio;
    v_retorno.error                := 'S';
    pr_insertarBitacora(retValidarSesion.codigoPersona,
                        p_codCanal,
                        p_sesion,
                        NULL,
                        retValidarSesion.codigoEmpresa,
                        v_parametros || ' ' ||
                        fu_generarBitacora(v_retorno.error,
                                           v_retorno.nombreRespuesta,
                                           v_retorno.descripcionRespuesta,
                                           null),
                        BITACORA_ERROR);
    return v_retorno;
  end if;
end;
/

