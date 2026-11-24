create or replace function it.fug_gen_new_session(p_ruc      in ba_personas.nro_documento%type,
                                                  p_user_id  in ba_personas.cod_persona%type,
                                                  p_canal    in bw_aut_sesiones.cod_canal%type default 999)
  return typ_inisesion is
  PRAGMA AUTONOMOUS_TRANSACTION;

  v_cod_per_ruc       ba_personas.cod_persona%type;
  v_cod_per_doc       ba_personas.cod_persona%type;
  v_det_error         ge_log_errores.det_error%type;
  v_ret               typ_mensajerespuesta := typ_mensajerespuesta;
  v_retorno           typ_inisesion := typ_inisesion;
  v_cod_sesion        bw_aut_sesiones.cod_sesion%type;
  v_codusuariooficial ge_clientes.cod_usu_oficial%type;
  v_cod_oficina       ge_clientes.cod_oficina%type;
  v_nro_documento     ba_personas.nro_documento%type;
  v_existe_vinculo    varchar2(1);
  v_fec_ult_acceso    date;
  v_salt              varchar2(32);
  v_authtoken         varchar2(32);
  v_password          varchar2(32);
  fecha_hora_actual   constant date := sysdate;

begin
  --se busca los datos de la empresa
  begin
    select t.nom_completo, t.cod_persona, t.cod_persona
      into v_retorno.companyname,
           v_retorno.externalcompanycode,
           v_cod_per_ruc
      from ba_personas t
     where t.nro_documento = p_ruc;
  exception
    when no_data_found then
      v_retorno.error             := 'S';
      v_retorno.error_code        := 'ERROR_RUC';
      v_retorno.error_description := 'No se encuentra el RUC';
      v_retorno.access_token      := null;
      return v_retorno;
    when others then
      v_retorno.error             := 'S';
      v_retorno.error_code        := 'ERROR_RUC';
      v_retorno.error_description := 'No se encuentra el RUC';
      v_retorno.access_token      := null;
      v_det_error                 := 'Ruc: ' || p_ruc || ' Error Cod. ' || v_retorno.error_code || ' - ' || sqlerrm;
      prg_ins_log_programas('FUG_GEN_NEW_SESSION', v_det_error, p_ruc, null);
      return v_retorno;
  end;

  --se busca datos de la persona
  begin
    select b.nom_completo,
           (Select t.val_parametro
              from ba_tab_dat_adicionales t
             where t.parametro = 'EMAIL_ONBOARDING'
               and t.referencia = b.cod_persona),
           b.cod_persona,
           a.cod_usu_oficial,
           d.direccion,
           it.fue_obt_des_ciudad(nvl(d.cod_pais, 1), nvl(d.cod_ciudad, 1)),
           f.cod_sexo,
           to_char(f.fec_nacimiento, 'YYYYMMDD'),
           it.fue_obt_des_pais(f.cod_pai_nacionalidad),
           nvl(b.cod_pai_documento, b.cod_pais),
           b.cod_tip_documento,
           (Select t.val_parametro
              from ba_tab_dat_adicionales t
             where t.parametro = 'CELULAR_ONBOARDING'
               and t.referencia = b.cod_persona),
           'TRUE',
           b.cod_persona,
           a.cod_oficina,
           b.nro_documento
      into v_retorno.fullname,
           v_retorno.email,
           v_retorno.clientcode,
           v_codusuariooficial,
           v_retorno.address_description,
           v_retorno.city,
           v_retorno.gender,
           v_retorno.birthdate,
           v_retorno.birthcountry,
           v_retorno.countryCodBt,
           v_retorno.documentClientTypeBT,
           v_retorno.cel,
           v_retorno.conditions_accepted,
           v_cod_per_doc,
           v_cod_oficina,
           v_nro_documento
      from ge_clientes a, ba_personas b, ba_direcciones d, ba_per_fisicas f
     where a.cod_persona = b.cod_persona
       and b.cod_persona = d.cod_persona(+)
       and d.principal(+) = 'S'
       and b.cod_persona = f.cod_persona
       and b.cod_persona = p_user_id;
  exception
    when no_data_found then
      v_retorno.error             := 'S';
      v_retorno.error_code        := 'ERROR_DOC';
      v_retorno.error_description := 'No se encuentra el Documento';
      v_retorno.access_token      := null;
      return v_retorno;
    when others then
      v_retorno.error             := 'S';
      v_retorno.error_code        := 'ERROR_DOC';
      v_retorno.error_description := 'No se encuentra el Documento';
      v_retorno.access_token      := null;
      v_det_error                 := 'Cod_per: ' || p_user_id || ' Error_Cod. ' || v_retorno.error_code ||
                                     ' - ' || v_retorno.error_description || ' - ' || sqlerrm;
      prg_ins_log_programas('FUG_GEN_NEW_SESSION', v_det_error, p_user_id, null);
      return v_retorno;
  end;

  --se busca el vinculo
  begin
    select 'S', t.cod_perfil
      into v_existe_vinculo, v_retorno.profile
      from ba_vinculos t
     where t.cod_persona = v_cod_per_ruc
       and t.cod_per_vinculo = v_cod_per_doc
       and t.tipo = 'OH';
  exception
    when no_data_found then
      v_retorno.error             := 'S';
      v_retorno.error_code        := 'ERROR_VINCULO';
      v_retorno.error_description := 'No se encuentra el Vinculo';
      v_retorno.access_token      := null;
      return v_retorno;
    when others then
      v_retorno.error             := 'S';
      v_retorno.error_code        := 'ERROR_VINCULO';
      v_retorno.error_description := 'No se encuentra el Vinculo';
      v_retorno.access_token      := null;
      v_det_error                 := 'Per_ruc: ' || v_cod_per_ruc || ' Per_doc: ' || v_cod_per_doc ||
                                     ' Error Cod. ' || v_retorno.error_code || ' - ' || sqlerrm;
      prg_ins_log_programas('FUG_GEN_NEW_SESSION', v_det_error, null, null);
      return v_retorno;
  end;
  --se busca la sesion si existe
  if nvl(v_existe_vinculo, 'N') = 'S' then
    begin
      for rec in (
        select t.cod_sesion
          from bw_aut_sesiones t
         where t.cod_persona = v_cod_per_doc
           and t.cod_canal = p_canal
      ) loop
        v_cod_sesion := rec.cod_sesion;

        if v_cod_sesion is not null then
          v_ret := it.paw_bem.fu_eliminarsesion(p_sesionusuario => v_cod_sesion);
          if v_ret.error = 'S' then
            v_det_error := 'Error: ' || v_ret.error || ' nombreRespuesta: ' || v_ret.nombrerespuesta || ' - ' ||
                           'descripcionRespuesta: ' || v_ret.descripcionrespuesta;
            prg_ins_log_programas('FUG_GEN_NEW_SESSION', v_det_error, v_cod_per_doc, null);
          end if;
        end if;
      end loop;
    exception
      when others then
        v_det_error := 'Excepción al procesar sesiones: ' || sqlerrm;
        prg_ins_log_programas('FUG_GEN_NEW_SESSION', v_det_error, v_cod_per_doc, null);
    end;
end if;

  -- se busca la fecha de ultimo acceso
  begin
    v_retorno.first_login := 'N';
    select max(t.fec_ult_acceso)
      into v_fec_ult_acceso
      from bw_per_dispositivos t
     where t.cod_persona = v_cod_per_doc
       and t.cod_per_vinculada = v_cod_per_ruc;

  if v_fec_ult_acceso is null then
    v_fec_ult_acceso      := sysdate;
    v_retorno.first_login := 'S';
  end if;

  exception
    when no_data_found then
      v_fec_ult_acceso      := sysdate;
      v_retorno.first_login := 'S';
    when others then
      v_fec_ult_acceso      := sysdate;
      v_retorno.first_login := 'S';
      v_det_error           := 'Per_ruc: ' || v_cod_per_ruc || 'Per_doc: ' || v_cod_per_doc || ' Error Cod. ' ||
                               v_retorno.error_code || ' - ' || sqlerrm;
      prg_ins_log_programas('FUG_GEN_NEW_SESSION', v_det_error, v_cod_per_doc, null);
  end;

  --obtener datos del oficial
  begin
    select substr(nvl(u.nombre, ' '), 1, 50),
           substr(nvl(u.telefono, '6188000'), 1, 10),
           nvl(u.dir_correo, fug_obt_dir_correo) dir_correo
      into v_retorno.manager_name,
           v_retorno.manager_phone_number,
           v_retorno.manager_email
      from ba_usuarios u
     where cod_usuario = v_codusuariooficial;
  exception
    when others then
      v_retorno.profiledescription := 'SIN PERFIL ASIGNADO';
  end;

  --obtener datos de la sucursal
  begin
    Select t.cod_oficina,
           t.cod_oficina,
           t.descripcion,
           it.fue_obt_des_ciudad(nvl(t.cod_pais, 1), nvl(t.cod_ciudad, 1)),
           it.fue_obt_des_pais(t.cod_pais),
           t.direccion,
           t.telefono
      into v_retorno.branch_id,
           v_retorno.branch_number,
           v_retorno.branch_name,
           v_retorno.branch_city,
           v_retorno.branch_country,
           v_retorno.branch_address,
           v_retorno.branch_phone_number
      from ba_oficinas t
     where t.cod_oficina = v_cod_oficina;
  exception
    when others then
      v_retorno.profiledescription := 'SIN PERFIL ASIGNADO';
  end;

  --obtener descripcion del perfil
  if nvl(v_retorno.error, 'N') = 'N' then
    begin
      select p.descripcion
        into v_retorno.profiledescription
        from bw_perfiles p
       where p.cod_perfil = v_retorno.profile;
    exception
      when others then
        v_retorno.profiledescription := 'SIN PERFIL ASIGNADO';
    end;
  end if;

  if nvl(v_retorno.error, 'N') = 'N' then
    -- valida que un cliente tenga permitido ver encuestas de opinator
    v_retorno.survey := 'N';
    if nvl(fug_obt_es_per_inhi(v_cod_per_ruc), 'X') = 'N' and
       nvl(fug_es_empleado(v_cod_per_ruc), 'X') = 'N' then
      v_retorno.survey := 'S';
    end if;
    -- verificacion de estado de clave transaccional
    -- retorno 1 tiene una clave transaccional y no tiene que hacer nada
    -- retorno 3 tiene que cambiar su clave
    -- retorno 2 ya tiene clave en bw_ope_claves
    v_retorno.transactional_key_status := it.paw_seg.fu_verificarclavetransaccional(v_cod_per_doc, v_cod_per_ruc);
    v_retorno.esvip := paw_bce.fu_es_vip(nvl(v_cod_per_ruc, v_cod_per_doc));
  end if;
  ----------------------------------------------------------------------------------------------------
  if nvl(v_retorno.error, 'N') = 'N' then
    -- generar salt aleatorio salt = md5(random_string)
    select paw_bce.fu_enc_md5(dbms_random.string('P', 20)) salt into v_salt from dual;
    v_authtoken := paw_bce.fu_enc_md5(v_password || v_salt || p_canal);

    -- se inserta la sesion
    insert into bw_aut_sesiones
      (cod_persona,
       cod_per_vinculada,
       cod_perfil,
       cod_canal,
       fec_ult_actividad,
       cod_sesion)
    values
      (v_retorno.clientcode,
       v_retorno.externalcompanycode,
       v_retorno.profile,
       p_canal,
       fecha_hora_actual,
       v_authtoken);
    commit;
    v_retorno.access_token := v_authtoken;
  end if;
  ----------------------------------------------------------------------------------------------------
  if nvl(v_retorno.error, 'N') = 'N' then
    v_retorno.error                  := 'N';
    v_retorno.error_code             := 'OP_APROBADA';
    v_retorno.error_description      := 'Operacion realizada con exito.';
    v_retorno.documentclientnumber   := v_nro_documento;
    v_retorno.last_access            := to_char(v_fec_ult_acceso, 'YYYYMMDD HH24MISS');
    v_retorno.employee               := nvl(fug_es_empleado(v_cod_per_ruc), 'N');
    v_retorno.clientCodeDtm          := '';
    v_retorno.is_acceso_session_itgf := 'FALSE';
  end if;
  return v_retorno;
end fug_gen_new_session;
/
