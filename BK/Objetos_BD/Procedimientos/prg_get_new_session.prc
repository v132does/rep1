create or replace procedure it.prg_get_new_session(p_ruc               in ba_personas.nro_documento%type,
                                                   p_user_id           in ba_personas.cod_persona%type,
                                                   p_error             out varchar2,
                                                   p_error_code        out varchar2,
                                                   p_error_description out varchar2,
                                                   p_access_token      out varchar2) is

  v_cod_per_ruc    ba_personas.cod_persona%type;
  v_cod_per_doc    ba_personas.cod_persona%type;
  v_det_error      ge_log_errores.det_error%type;
  v_ret            typ_mensajeRespuesta := typ_mensajerespuesta;
  v_cod_sesion     bw_aut_sesiones.cod_sesion%type;
  v_existe_vinculo varchar2(1);

begin
  --se busca el cod_persona de la empresa
  begin
    select t.cod_persona
      into v_cod_per_ruc
      from ba_personas t
     where t.nro_documento = p_ruc;
  exception
    when no_data_found then
      p_error             := 'S';
      p_error_code        := 'ERROR_RUC';
      p_error_description := 'No se encuentra el RUC';
      p_access_token      := null;
      return;
    when others then
      p_error             := 'S';
      p_error_code        := 'ERROR_RUC';
      p_error_description := 'No se encuentra el RUC';
      p_access_token      := null;
      v_det_error         := 'Ruc : ' || p_ruc || ' Error: Cod. ' || p_error_code || ' - ' || sqlerrm;
      prg_ins_log_programas('PRG_GET_NEW_SESSION', v_det_error, p_ruc, null);
      return;
  end;

  --se busca el cod_persona de la persona
  begin
    select t.cod_persona
      into v_cod_per_doc
      from ba_personas t
     where t.cod_persona = p_user_id;
  exception
    when no_data_found then
      p_error             := 'S';
      p_error_code        := 'ERROR_DOC';
      p_error_description := 'No se encuentra el Documento';
      p_access_token      := null;
      return;
    when others then
      p_error             := 'S';
      p_error_code        := 'ERROR_DOC';
      p_error_description := 'No se encuentra el Documento';
      p_access_token      := null;
      v_det_error         := 'Cod_per : ' || v_cod_per_doc || ' Error: Cod. ' || p_error_code || ' - ' || sqlerrm;
      prg_ins_log_programas('PRG_GET_NEW_SESSION', v_det_error, v_cod_per_doc, null);
      return;
  end;

  --se busca el vinculo
  begin
    select 'S'
      into v_existe_vinculo
      from ba_vinculos t
     where t.cod_persona = v_cod_per_ruc
       and t.cod_per_vinculo = v_cod_per_doc
       and t.tipo = 'OH';
  exception
    when no_data_found then
      p_error             := 'S';
      p_error_code        := 'ERROR_VINCULO';
      p_error_description := 'No se encuentra el Vinculo';
      p_access_token      := null;
      return;
    when others then
      p_error             := 'S';
      p_error_code        := 'ERROR_VINCULO';
      p_error_description := 'No se encuentra el Vinculo';
      p_access_token      := null;
      v_det_error         := 'cod_per_ruc : ' || v_cod_per_ruc || 'cod_per_doc : ' || v_cod_per_doc ||
                             ' Error: Cod. ' || p_error_code || ' - ' || sqlerrm;
      prg_ins_log_programas('PRG_GET_NEW_SESSION', v_det_error, null, null);
      return;
  end;
  --se busca la sesion si existe
  if nvl(v_existe_vinculo, 'N') = 'S' then
    begin
      Select t.cod_sesion
        into v_cod_sesion
        from bw_aut_sesiones t
       where t.cod_persona = v_cod_per_doc
         and t.cod_per_vinculada = v_cod_per_ruc
         and t.cod_canal = 999;
    exception
      when others then
        v_cod_sesion := null;
    end;
    --se elimina la sesion
    if v_cod_sesion is not null then
      v_ret := it.paw_bem.fu_eliminarSesion(p_sesionUsuario => v_cod_sesion);
      v_det_error         := 'Error : ' || v_ret.error  || ' nombreRespuesta: ' || v_ret.nombreRespuesta || ' - ' ||
                             ' descripcionRespuesta: ' || v_ret.descripcionRespuesta;
      prg_ins_log_programas('PRG_GET_NEW_SESSION', v_det_error, p_ruc, null);
    end if;
  end if;
  
  if nvl(p_error, 'N') = 'N' then
    p_error             := 'N';
    p_error_code        := 'OP_APROBADA';
    p_error_description := 'Operacion realizada con exito.';
    p_access_token      := null;
  end if;

exception
  when others then
    v_det_error         := v_det_error || ' - Error: ' || sqlerrm;
    p_error             := 'S';
    p_error_code        := 'ERROR_PROCESO';
    p_error_description := 'Error en el proceso de Logueo ';
    p_access_token      := null;
    prg_ins_log_programas('PRG_GET_NEW_SESSION', v_det_error, null, null);
end prg_get_new_session;
/
