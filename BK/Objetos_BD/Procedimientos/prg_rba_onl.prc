CREATE OR REPLACE PROCEDURE IT.PRG_RBA_ONL (p_cod_persona ge_clientes.cod_persona%type,
                                         p_tip_proceso varchar2 default 'S')
is
  v_uidPeticion       ba_usuarios.cod_usuario%type;
  /*
  p_tip_proceso = S (Scoring Online)
  p_tip_proceso = P (Scoring Online + (Kyc).
  */
  v_tipoProceso       varchar2(1) := p_tip_proceso;
  v_codigoCliente     ge_clientes.cod_persona%type;
  v_tipoPersona       varchar2(1);
  v_fechaAlta         varchar2(10);
  v_indPEP            varchar2(1);
  v_riesgoExtra3      number;
  v_tipoNacionalidad  varchar2(1);
  v_tipoResidencia    varchar2(1);
  v_tipoJuridica      ba_per_juridicas.naturaleza%type;
  v_ocupacion         ba_per_fisicas.cod_profesion%type;
  v_actividad         varchar2(20);
  v_paisNacimiento    ba_paises.cod_pai_iso%type;
  v_paisResidencia    ba_paises.cod_pai_iso%type;
  v_paisNacionalidad  ba_paises.cod_pai_iso%type;
  v_fechaNacimiento   varchar2(10);
  v_fechaConstitucion varchar2(10);
  v_sucursal          ba_oficinas.cod_oficina%type;
  v_segmento          ge_clientes.cod_seg_cliente%type;
  v_xml               clob;
  v_url               varchar2(500) := fug_obt_pardinamico('RBA_URL_WSI_ENV_DATOS');
  v_xmlnsser          varchar2(500) := fug_obt_pardinamico('RBA_XMLNSSER');
  v_xmlnssoapenv      varchar2(500) := fug_obt_pardinamico('RBA_XMLNSSOAPENV');
  v_respuesta         typ_postrespuestaclob;
  v_fec_actual        date default pag_cal.fu_obt_fec_actual(1);
  v_tip_persona       ba_personas.tipo%type;
  v_error             varchar2(1000);
  v_can_intentos      number := 0;
  v_tie_espera        date;
  v_asunto            varchar2(2000);
  v_mje_mail          varchar2(4000);
  v_hini_mail         ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail         ge_ra_log_mail.hor_fin%type;
  v_det_error         ge_ra_log_mail.det_error%type;
  v_dir_mail          varchar2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  v_conn              utl_smtp.connection;
  v_para              VARCHAR2(3000):= fug_obt_pardinamico ('DIR_MAIL_CUMPLIMIENTO');
  v_xml_res           xmltype;

  --procedimiento interno para interpretar xml de respuesta y guardar en la BD.
  procedure pr_rba_xml(p_xml clob)
  is
    v_xmlr        xmltype := xmltype.createxml(p_xml);
    v_cod_persona varchar2(30);
    v_diligencia  varchar2(1);
    v_riesgo      varchar2(1);
    v_can         number := 0;
    v_doc_existe  varchar2(1) := 'N';
    v_val_minimo  varchar2(1);
  begin
    v_cod_persona := v_xmlr.extract('//return/codigoCliente/text()').getStringVal();
    v_diligencia  := v_xmlr.extract('//return/diligencia/text()').getStringVal();
    v_riesgo      := v_xmlr.extract('//return/riesgo/text()').getStringVal();
    --
    for c in ( select nombre, tipo
                 from xmltable('/documentos' passing
                     (select cells
                        from xmltable('//return' passing v_xmlr columns CELLS  XMLTYPE PATH './documentos')
                     )
                     columns nombre VARCHAR(240) PATH './nombre',
                               tipo VARCHAR(1) PATH './tipo'
                             )
             )
    loop
      v_can := v_can + 1;
      -- Limpiar documentos RBA
      if v_can = 1 then
        delete ge_doc_catastros a
         where a.cod_persona = p_cod_persona
           and a.cod_tip_documento not in ('A','C');
      end if;
      -- Validar si existe en referencias
      begin
        select 'S', a.val_minimo
          into v_doc_existe, v_val_minimo
          from ba_cod_referencias a
         where a.dominio = 'CAT_TIP_DOCUMENTO'
           and a.significado = c.nombre;
      exception
        when no_data_found then
          v_doc_existe := 'N';
        when others then
          v_doc_existe := 'N';
      end;
      if v_doc_existe = 'N' then
        begin
          select chr(max(ascii(a.val_minimo)) + 1)
            into v_val_minimo
            from ba_cod_referencias a
           where a.dominio = 'CAT_TIP_DOCUMENTO';
        exception
          when no_data_found then
            v_val_minimo := 'A';
          when others then
            v_val_minimo := 'A';
        end;
        insert into ba_cod_referencias(dominio, significado, val_minimo, abreviatura)
        values('CAT_TIP_DOCUMENTO', c.nombre, v_val_minimo , c.nombre);
      end if;
      -- Inserta los documentos RBA.
      begin
        insert into ge_doc_catastros
          (cod_doc_catastro,
           cod_persona,
           cod_tip_documento,
           estado,
           observacion)
        values
          (s_cod_doc_catastro.Nextval,
           p_cod_persona,
           v_val_minimo,
           'N',
           'Tipo de Documento: '||decode(nvl(c.tipo,'P'),'P','Primario','Secundario')
           );
      end;
    end loop;
    --

    -- Actualiza el Riesgo y Diligencia.
    begin
      update smg_dat_clientes a
         set a.riesgo = v_riesgo,
             a.diligencia = v_diligencia
       where a.cod_cliente = p_cod_persona;

      if sql%notfound then
        insert into smg_dat_clientes(cod_cliente, riesgo, diligencia)
        values(v_cod_persona, v_riesgo, v_diligencia);
      end if;
    end;
  end;

  --
  procedure pr_rba_dil_normal is
    v_cant number := 0;
    cursor c_pf is
     select c.cod_tip_documento, c.observacion
       from ge_doc_catastros c
      where c.cod_tip_documento not in ('A', 'C')
        and c.cod_persona =
            (select a.cod_cliente
               from smg_dat_clientes a
              where a.diligencia = 'N'
                and rowid = (select max(b.rowid)
                               from smg_dat_clientes b, ba_per_fisicas d
                              where d.cod_persona = b.cod_cliente
                                and b.diligencia = 'N'));
    cursor c_pj is
     select c.cod_tip_documento, c.observacion
       from ge_doc_catastros c
      where c.cod_tip_documento not in ('A', 'C')
        and c.cod_persona =
            (select a.cod_cliente
               from smg_dat_clientes a
              where a.diligencia = 'N'
                and rowid = (select max(b.rowid)
                               from smg_dat_clientes b, ba_per_juridicas d
                              where d.cod_persona = b.cod_cliente
                                and b.diligencia = 'N'));
    pragma autonomous_transaction;
  begin
    if v_tipoPersona = 'F' then
      for k in c_pf loop
        v_cant := nvl(v_cant,0) + 1;
        -- Limpiar documentos RBA
        if v_cant = 1 then
          delete ge_doc_catastros a
           where a.cod_persona = p_cod_persona
             and a.cod_tip_documento not in ('A','C');
        end if;
        -- Inserta los documentos RBA.
        begin
          insert into ge_doc_catastros
            (cod_doc_catastro,
             cod_persona,
             cod_tip_documento,
             estado,
             observacion)
          values
            (s_cod_doc_catastro.Nextval,
             p_cod_persona,
             k.cod_tip_documento,
             'N',
             k.observacion
             );
        end;
      end loop;
    else
      for k in c_pj loop
        v_cant := nvl(v_cant,0) + 1;
        -- Limpiar documentos RBA
        if v_cant = 1 then
          delete ge_doc_catastros a
           where a.cod_persona = p_cod_persona
             and a.cod_tip_documento not in ('A','C');
        end if;
        -- Inserta los documentos RBA.
        begin
          insert into ge_doc_catastros
            (cod_doc_catastro,
             cod_persona,
             cod_tip_documento,
             estado,
             observacion)
          values
            (s_cod_doc_catastro.Nextval,
             p_cod_persona,
             k.cod_tip_documento,
             'N',
             k.observacion
             );
        end;
      end loop;
    end if;
    commit;
  end;
  --procedimiento interno para el registro de los mensajes
  PROCEDURE LP_REG_OPERACION(p_mensaje   IN LONG,
                             p_respuesta IN VARCHAR2) is
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    v_respuesta ge_log_rbaonline.respuesta%type;
  BEGIN
    v_respuesta := substr(p_respuesta, 1, 4000);
    insert into ge_log_rbaonline(mensaje    ,
                                  respuesta  )
                           values(p_mensaje  ,
                                  v_respuesta);
   commit;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, sqlerrm);
  END;

  --
  function fu_rie_extra3(p_cod_persona ba_personas.cod_persona%type) return varchar2 is
    v_monto number;
    v_val_riesgo number;
    v_ret varchar2(10);
  begin
    begin
      select decode(a.cod_moneda,'GS',a.mto_pro_credito,fub_con_mon_a_moneda(a.cod_moneda,'GS',a.mto_pro_credito,null,v_fec_actual)) monto
        into v_monto
        from cr_act_esperadas a
       where a.cod_persona = p_cod_persona
         and a.fecha = ( select max(b.fecha)
                           from cr_act_esperadas b
                          where b.cod_persona = p_cod_persona );
    exception
      when others then
        v_monto := 0;
    end;
    /**
      Definiciones (ordenado por prioridad):
      Si el Perfil Transaccional es mayor a Gs.4.000.000.000 retornara el valor de riesgo igual a 10.
      Si el Perfil Transaccional es mayor a Gs.3.000.000.000 retornara el valor de riesgo igual a 8.
      Si el Perfil Transaccional es mayor a Gs.2.000.000.000 retornara el valor de riesgo igual a 6.
      Si el Perfil Transaccional es mayor a Gs.1.000.000.000 retornara el valor de riesgo igual a 4.
      Si el Perfil Transaccional es menor o igual a Gs.1.000.000.000 retornara el valor de riesgo igual a 0.
    **/
    if nvl(v_monto,0) > 4000000000 then
      v_val_riesgo := 10;
    elsif nvl(v_monto,0) > 3000000000 then
      v_val_riesgo := 8;
    elsif nvl(v_monto,0) > 2000000000 then
      v_val_riesgo := 6;
    elsif nvl(v_monto,0) > 1000000000 then
      v_val_riesgo := 4;
    else
      v_val_riesgo := 0;
    end if;
    v_ret := replace(to_char(nvl(v_val_riesgo,0),'00'),chr(32),'');
    return v_ret;
  exception
    when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20000,sqlerrm);
      end if;
  end fu_rie_extra3;

  function fu_ver_log_persona return varchar2 is
    v_existe varchar2(1) := 'N';
  begin
    select distinct 'S'
      into v_existe
      from ge_log_rbaonline a
     where trim(substr(to_char(a.mensaje),
                instr((to_char(a.mensaje)), '<codigoCliente>') + 15,
                6)) = p_cod_persona;

    return v_existe;
  exception
    when no_data_found then
      return 'N';
    when others then
      return 'N';
  end;
  --
  procedure pr_log_programa(p_det_error varchar2) is
      pragma autonomous_transaction;
    begin
      insert into ge_log_errores(cod_programa, campo1, dato1, campo2, dato2, det_error)
      values ('PRG_RBA_ONL','p_cod_persona',p_cod_persona,'p_tip_proceso',p_tip_proceso, p_det_error);
      commit;
    end;
  --
  procedure pr_ver_pro_control(p_xml_respuesta xmltype) is
    v_cod_persona       varchar2(10);
    v_inhibir           varchar2(1) default 'N';
    v_url_crm           varchar2(200);
    v_act_inhibicion    number;
    -- cursor por si haya mas de 1 proceso de control.
    cursor c_datos is
    select extract(value(p),
           '//codProcesosControl/text()').getStringVal() as cod_pro_control
      from Table(Xmlsequence(Extract(p_xml_respuesta, '//return/codProcesosControl'))) p;
  begin
    v_cod_persona := p_xml_respuesta.extract('//return/codigoCliente/text()').getStringVal();
    for k in c_datos loop
      begin
        insert into ge_per_pro_control
        (fecha, cod_persona, cod_pro_control, estado, url_crm)
        values
        (v_fec_actual, v_cod_persona, k.cod_pro_control, 'P', v_url_crm);
      end;
      v_inhibir := 'S';
    end loop;
    if v_inhibir = 'S' then
      -- Realiza Inhibición.
      v_act_inhibicion := pag_rba.fu_act_inhibidos(v_cod_persona, null, 'I');

      if v_act_inhibicion != 0 then
        -- Hay error en la Inhibición.
        pr_log_programa('Error al realizar Inhibición. '||v_act_inhibicion);
      end if;
    end if;
  end;

begin
  /*  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
    select user uidPeticion,--
           a.cod_persona codigoCliente,--
           b.tipo tipoPersona,--
           trim(to_char(trunc(a.fec_insercion),'rrrr-mm-dd')) fechaAlta,--
           g.pep indPEP,--
           decode(b.cod_pais,1,'N','E') tipoNacionalidad,--
           decode(c.pais,null,null,decode(c.pais,1,'R','N')) tipoResidencia,--
           decode(b.tipo,'J',substr(nvl(d.naturaleza,'OTRA'),1,4),null) tipoJuridica,
           e.cod_profesion ocupacion,--
           nvl(f.cod_actividad, b.cod_rub_primario) actividad,
           decode(b.tipo,'F', pai_ast.fu_obt_cod_iso_pais(a.cod_persona,'N',b.cod_pais), null) paisNacimiento,--
           pai_ast.fu_obt_cod_iso_pais(a.cod_persona,'D',c.pais) paisResidencia,--
           decode(b.tipo,'F', pai_ast.fu_obt_cod_iso_pais(null,'N',e.cod_pai_nacionalidad), null) paisNacionalidad,--
           decode(b.tipo,'F',nvl(to_char(e.fec_nacimiento,'rrrr-mm-dd'),to_date('0001/01/01','rrrr-mm-dd')),null) fechaNacimiento,  -- 01/01/0001 por defecto para personas físicas
           trim(to_char(d.fec_apertura,'rrrr-mm-dd')) fechaConstitucion,--
           a.cod_oficina sucursal,--
           a.cod_seg_cliente segmento,--
           b.tipo
      into v_uidPeticion,
           v_codigoCliente,
           v_tipoPersona,
           v_fechaAlta,
           v_indPEP,
           v_tipoNacionalidad,
           v_tipoResidencia,
           v_tipoJuridica,
           v_ocupacion,
           v_actividad,
           v_paisNacimiento,
           v_paisResidencia,
           v_paisNacionalidad,
           v_fechaNacimiento,
           v_fechaConstitucion,
           v_sucursal,
           v_segmento,
           v_tip_persona
      from ge_clientes a,
           ba_personas b,
           ( select dir.cod_persona persona, pai.cod_pais pais, pai.cod_pai_iso
               from ba_direcciones dir, ba_paises pai
              where dir.principal = 'S'
                and dir.cod_pais = pai.cod_pais) c,
           ba_per_juridicas d,
           ba_per_fisicas e,
           ( select a.cod_persona cod_persona, a.val_parametro cod_actividad
                 from ba_per_dat_adicionales a
                where a.parametro = 'DTM_RIESGO'
                  and a.val_parametro != '777' ) f,
           cr_inf_fondos g
     where a.cod_persona = p_cod_persona
       and a.cod_persona = b.cod_persona
       and b.cod_persona = c.persona(+)
       and b.cod_persona = d.cod_persona(+)
       and b.cod_persona = e.cod_persona(+)
       and g.cod_persona(+) = b.cod_persona
       and f.cod_persona(+) = b.cod_persona;
      --
    v_xml := '<soapenv:Envelope xmlns:soapenv="'||v_xmlnssoapenv||'" xmlns:ser="'||v_xmlnsser||'"> <soapenv:Header/> <soapenv:Body> <ser:getConsultaOnline> <arg0>';
    v_xml := v_xml||' <uidPeticion>'||v_uidPeticion||'</uidPeticion>';
    v_xml := v_xml||' <tipoProceso>'||v_tipoProceso||'</tipoProceso>';
    v_xml := v_xml||' <codigoCliente>'||v_codigoCliente||'</codigoCliente>';
    v_xml := v_xml||' <tipoPersona>'||v_tipoPersona||'</tipoPersona>';
    v_xml := v_xml||' <fechaAlta>'||v_fechaAlta||'</fechaAlta>';
    -- Indicador PEP.
    if v_indPEP is not null then
      v_xml := v_xml||' <indPEP>'||v_indPEP||'</indPEP>';
    end if;
    v_riesgoExtra3 := fu_rie_extra3(v_codigoCliente);
    if v_riesgoExtra3 is not null then
      v_xml := v_xml||' <riesgoExtra3>'||v_riesgoExtra3||'</riesgoExtra3>';
    end if;
    if v_tipoNacionalidad is not null and v_tip_persona = 'F' then
      v_xml := v_xml||' <tipoNacionalidad>'||v_tipoNacionalidad||'</tipoNacionalidad>';
    end if;
    if v_tipoResidencia is not null and v_tip_persona = 'F' then
      v_xml := v_xml||' <tipoResidencia>'||v_tipoResidencia||'</tipoResidencia>';
    end if;
    if v_tipoJuridica is not null and v_tip_persona = 'J' then
      v_xml := v_xml||' <tipoJuridica>'||v_tipoJuridica||'</tipoJuridica>';
    end if;
    if v_ocupacion is not null and v_tip_persona = 'F' then
      v_xml := v_xml||' <ocupacion>'||v_ocupacion||'</ocupacion>';
    end if;
    if v_actividad is not null then
      v_xml := v_xml||' <actividad>'||v_actividad||'</actividad>';
    end if;
    if v_paisNacimiento is not null and v_tip_persona = 'F' then
      v_xml := v_xml||' <paisNacimiento>'||v_paisNacimiento||'</paisNacimiento>';
    end if;
    if v_paisResidencia is not null then
      v_xml := v_xml||' <paisResidencia>'||v_paisResidencia||'</paisResidencia>';
    end if;
    if v_paisNacionalidad is not null then
      v_xml := v_xml||' <paisNacionalidad>'||v_paisNacionalidad||'</paisNacionalidad>';
    end if;
    if v_fechaNacimiento is not null and v_tip_persona = 'F' then
      v_xml := v_xml||' <fechaNacimiento>'||v_fechaNacimiento||'</fechaNacimiento>';
    end if;
    if v_fechaConstitucion is not null and v_tip_persona = 'J' then
      v_xml := v_xml||' <fechaConstitucion>'||v_fechaConstitucion||'</fechaConstitucion>';
    end if;
    if v_sucursal is not null then
      v_xml := v_xml||' <sucursal>'||v_sucursal||'</sucursal>';
    end if;
    if v_segmento is not null then
      v_xml := v_xml||' <segmento>'||v_segmento||'</segmento>';
    end if;

    v_xml := v_xml||'</arg0> </ser:getConsultaOnline> </soapenv:Body> </soapenv:Envelope>';

    <<reintento>>
    v_respuesta := fug_wsi_env_rba(v_xml,v_url,'POST');
    lp_reg_operacion(v_xml,substr(v_respuesta.error || ' - ' ||v_respuesta.codigoError ||' - ' || nvl(v_respuesta.respuesta,v_respuesta.descripcionRespuesta), 1, 4000));
   

    -- Respuesta ok
    if nvl(v_respuesta.error,'S') = 'N' then
      -- Verificar si hay Proceso de Control
      v_xml_res := xmltype(v_respuesta.respuesta);
      pr_ver_pro_control(v_xml_res);

      if v_respuesta.respuesta is not null then
        pr_rba_xml(v_respuesta.respuesta);
      end if;
    else
      if v_can_intentos < fug_obt_pardinamico('CAN_INT_ENV_RBA') then
        v_can_intentos := v_can_intentos + 1;
        v_tie_espera   := pai_int.smg_sleep(fug_obt_pardinamico('TIE_ESP_ENV_RBA'));
        GOTO reintento;
      else
        -- Enviarl Mail a Cumplimiento Normativo
        v_asunto     := 'RBA-KYC: Existen Errores en el proceso de envío de datos: '||v_fec_actual||'.';
        v_mje_mail   := 'Informamos que ocurrió un error en el envío de datos de alta de la Persona '
                        ||v_codigoCliente||' '||fue_obt_nom_persona(v_codigoCliente)||'. '||chr(10)
                        ||'Estos datos no ingresaron en forma Online a RBA. Serán ingresados en el '
                        ||'proceso de aprovisionamiento nocturno.';
        v_det_error  := null;
        v_hini_mail  := to_char(sysdate,'hh24:mi:ss');
        BEGIN
           v_conn := it_mail.begin_mail(v_dir_mail  ,
                                        v_para      ,
                                        v_asunto    ,
                                        it_mail.multipart_mime_type);
           it_mail.attach_text(v_conn      ,
                               v_mje_mail  ,
                               'text/plain');
           it_mail.end_mail(v_conn);
        EXCEPTION
          when utl_smtp.transient_error or utl_smtp.permanent_error then
              begin
                  utl_smtp.quit(v_conn);
              exception
                  when utl_smtp.transient_error or utl_smtp.permanent_error then
                       null;
              end;
              v_det_error := substr(sqlerrm,1,4000);
        END;
        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
        -- Insertamos en la tabla de log  si ocurrió algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail (fec_envio  ,
                                        nom_archivo,
                                        dir_correo ,
                                        mensaje    ,
                                        det_error  ,
                                        hor_inicio ,
                                        hor_fin    )
                                VALUES (SYSDATE    ,
                                        null       ,
                                        v_para     ,
                                        v_asunto   ,
                                        v_det_error,
                                        v_hini_mail,
                                        v_hfin_mail);
            COMMIT;
        END IF;
        --
        pr_rba_dil_normal;
        if instr(v_respuesta.descripcionRespuesta,'HTTP request failed') > 0 then
          v_error := 'Solicitud HTTP fallida.';
          raise_application_error(-20000,v_error);
        elsif v_respuesta.respuesta = 'Servicio RBA no habilitado' then
          v_error := 'Servicio RBA no habilitado';
          raise_application_error(-20000,v_error);
        end if;
      end if;
    end if;
    commit;*/
    null;
exception
  when no_data_found then
    raise_application_error(-20000,'Persona '||p_cod_persona||' Inexistente.');
  when others then
    if v_error is not null then
      raise_application_error(-20000,v_error);
    else
      raise_application_error(-20000,nvl(v_respuesta.respuesta,v_respuesta.descripcionRespuesta)||sqlerrm);
    end if;
end;
/

