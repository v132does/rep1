create or replace procedure it.prg_obt_onb_empresa(p_nro_documento   in ba_personas.nro_documento%type,
                                                   p_hizo_onboarding out varchar2,
                                                   p_cod_error       out number,
                                                   p_mensaje         out varchar2) is
  v_det_error varchar2(4000);
  v_persona   ba_personas.cod_persona%type;

begin
  p_hizo_onboarding := 'N';

  IF p_nro_documento IS NULL THEN
    p_cod_error := 1;
    p_mensaje   := 'La persona no puede ser nula';
    RETURN;
  END IF;

  begin
    Select t.cod_persona
      into v_persona
      from ba_personas t
     where t.nro_documento = p_nro_documento;
  exception
    when no_data_found then
      p_hizo_onboarding := 'N';
      p_cod_error       := 1;
      p_mensaje         := 'La persona no puede ser nula';
    when too_many_rows then
      p_hizo_onboarding := 'S';
      p_cod_error       := 0;
      p_mensaje         := null;
    when others then
      p_hizo_onboarding := 'N';
      v_det_error       := substr('Ocurrió un error durante la consulta' || sqlerrm, 1, 4000);
      p_cod_error       := 2;
      p_mensaje         := 'Ocurrió un error durante la consulta';
  end;

  begin
    Select 'S'
      into p_hizo_onboarding
      from ba_per_dat_adicionales t
     where t.cod_persona = v_persona
       and t.parametro = 'EMAIL_ONB_EMPRESAS';
  exception
    when no_data_found then
      p_hizo_onboarding := 'N';
      p_cod_error       := 0;
      p_mensaje         := null;
    when too_many_rows then
      p_hizo_onboarding := 'S';
      p_cod_error       := 0;
      p_mensaje         := null;
    when others then
      p_hizo_onboarding := 'N';
      v_det_error       := substr('Ocurrió un error durante la consulta' || sqlerrm, 1, 4000);
      p_cod_error       := 3;
      p_mensaje         := 'Ocurrió un error durante la consulta';
  end;

  if nvl(p_cod_error, 0) != 0 then
    it.prg_ins_log_programas('PRG_OBT_ONB_EMPRESA', substr(p_cod_error || ' - ' || v_det_error, 1, 4000), null);
  else
    p_cod_error       := 0;
    p_mensaje         := null;
  end if;

exception
  when others then
    p_hizo_onboarding := 'N';
    p_cod_error       := 999;
    p_mensaje         := 'Ocurrió un error inesperado';
    v_det_error       := substr('Ocurrió un error inesperado' || sqlerrm, 1, 4000);
    it.prg_ins_log_programas('PRG_OBT_ONB_EMPRESA', substr(p_cod_error || ' - ' || v_det_error, 1, 4000), null);
end prg_obt_onb_empresa;
/

