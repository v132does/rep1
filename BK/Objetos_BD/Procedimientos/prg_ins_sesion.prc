create or replace procedure it.prg_ins_sesion(p_cod_persona      in bw_ope_claves.cod_persona%type,
                                              p_cod_persona_vinc in bw_ope_claves.cod_per_vinculada%type default null,
                                              p_reenvio          in varchar2 default 'N',
                                              p_cod_error        out number,
                                              p_mail_persona     out ba_personas.dir_correo%type) is

  v_clave       bw_ope_claves.clave%type := null;
  v_cla_impresa bw_ope_claves.cla_impresa%type := null;
  v_existe      varchar2(1);
  v_dir_correo  ba_personas.dir_correo%type;
  v_est_clave   bw_ope_claves.est_clave%type;
begin
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;

  if p_cod_persona_vinc is null then
    begin
      Select 'S', est_clave
        into v_existe, v_est_clave
        from bw_ope_claves t
       where t.cod_persona = p_cod_persona
         and t.tip_clave = 'T'
         and t.cod_per_vinculada is null;
    exception
      when no_data_found then
        v_existe := 'N';
      when too_many_rows then
        v_existe := 'S';
      when others then
        v_existe := 'N';
    end;
  else
    begin
      Select 'S', est_clave
        into v_existe, v_est_clave
        from bw_ope_claves t
       where t.cod_persona = p_cod_persona
         and t.tip_clave = 'T'
         and t.cod_per_vinculada = p_cod_persona_vinc;
    exception
      when no_data_found then
        v_existe := 'N';
      when too_many_rows then
        v_existe := 'S';
      when others then
        v_existe := 'N';
    end;
  end if;

  BEGIN
    /*
      Ticket: BWP-652
      User: GLOPEZ
      Desc.: Buscamos de ba_per_dat_adicionales
    */
    v_dir_correo := fue_tab_dat_adicional('BA_PERSONAS','EMAIL_ONBOARDING',p_cod_persona);
  EXCEPTION
    WHEN OTHERS THEN
      v_dir_correo := null;
  END;

  if v_dir_correo is null and nvl(v_existe, 'N') = 'N' then
    p_cod_error := 2; --No tiene correo asociado
    return;
  else
    p_mail_persona := v_dir_correo;
  end if;

  if (nvl(v_existe, 'S') = 'N' or nvl(p_reenvio, 'N') = 'S') and
     v_dir_correo is not null then
    v_clave := paw_bce.fu_gen_ope_clave(v_clave,
                                        p_cod_persona,
                                        p_cod_persona_vinc,
                                        'C',
                                        'T',
                                        v_cla_impresa);

    if v_clave in ('- 1', '- 2', '- 3', '- 5', '- 6', '- 7') then
      p_cod_error := 1; --Error general
    elsif v_clave = '- 8' then
      p_cod_error := 2; --No tiene correo asociado
    else
      p_cod_error := 0;
    end if;
  else
    if v_est_clave = 'A' then
      p_cod_error := 4; --Estado clave A
    else
      p_cod_error := 3; --Ya tiene clave transaccional
    end if;
  end if;
exception
  when no_data_found then
    raise_application_error(-20000, 'error al crear clave');
end;
/

