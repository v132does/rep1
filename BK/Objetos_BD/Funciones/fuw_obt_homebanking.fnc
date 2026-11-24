create or replace function it.fuw_obt_homebanking (p_cod_persona     in varchar2,
                                               p_cod_persona_vin in varchar2,
                                               p_tip_param       in char default null)
  return varchar2 is
  v_dat_retorno varchar(300);
begin
  if p_tip_param = 'U' then
    if trim(p_cod_persona_vin) is not null then
      -- Último accesso al Homebanking de la persona juridica --
      Select to_char(max(fec_ult_acceso), 'DD/MM/YYYY HH24:MI:SS')
        into v_dat_retorno
        from bw_ope_claves a
       where a.tip_clave = 'A'
         and a.cod_per_vinculada = p_cod_persona_vin;
    end if;
    if trim(v_dat_retorno) is null then
      -- Último accesso al Homebanking como persona fisica/juridica  --
      Select to_char(max(fec_ult_acceso), 'DD/MM/YYYY HH24:MI:SS')
        into v_dat_retorno
        from bw_ope_claves a
       where a.tip_clave = 'A'
         and a.cod_persona = p_cod_persona
         and nvl(a.cod_per_vinculada,0) = 0;
    end if;
    if trim(v_dat_retorno) is null then
      -- Último accesso al Homebanking como persona fisica/juridica  --
      Select to_char(max(fec_ult_acceso), 'DD/MM/YYYY HH24:MI:SS')
        into v_dat_retorno
        from bw_ope_claves a
       where a.tip_clave = 'A'
         and a.cod_persona = p_cod_persona_vin
         and nvl(a.cod_per_vinculada,0) = 0;
    end if;
  elsif p_tip_param = 'P' then
         if trim(p_cod_persona_vin) is not null then
              -- Tipo de Persona --
              select decode(tipo, 'F', 'FISICAS', 'JURIDICAS')
                into v_dat_retorno
                from ba_personas
               where cod_persona = p_cod_persona_vin;
          else
             -- Tipo de Persona --
              select decode(tipo, 'F', 'FISICAS', 'JURIDICAS')
                into v_dat_retorno
                from ba_personas
               where cod_persona = p_cod_persona;
          end if;
    elsif p_tip_param in ('K','F') then
         -- Claves Token --
         if trim(p_cod_persona_vin) is not null then
          Select max(a.estado)
            into v_dat_retorno
            from bw_otp_seriales a
           where a.tipo =  decode(p_tip_param,'K','V', p_tip_param)
             and a.cod_per_vinculada = p_cod_persona_vin;
        end if;
        if trim(v_dat_retorno) is null then
          Select max(a.estado)
            into v_dat_retorno
            from bw_otp_seriales a
           where a.tipo = decode(p_tip_param,'K','V', p_tip_param)
             and a.cod_persona = p_cod_persona
             and nvl(a.cod_per_vinculada,0) = 0;
        end if;
        if trim(v_dat_retorno) is null then
          Select max(a.estado)
            into v_dat_retorno
            from bw_otp_seriales a
           where a.tipo = decode(p_tip_param,'K','V', p_tip_param)
             and a.cod_persona = p_cod_persona_vin
             and nvl(a.cod_per_vinculada,0) = 0;
        end if;               
        v_dat_retorno := fue_obt_des_refcodes('EST_CLA_OTP',v_dat_retorno);
    elsif p_tip_param in ('A','T') then
               -- Claves Transaccionales --
              if trim(p_cod_persona_vin) is not null then
                  Select a.est_clave
                    into v_dat_retorno
                    from bw_ope_claves a
                   where a.tip_clave = p_tip_param
                     and a.cod_per_vinculada = p_cod_persona_vin;
                end if;
                if trim(v_dat_retorno) is null then
                  Select a.est_clave
                    into v_dat_retorno
                    from bw_ope_claves a
                   where a.tip_clave = p_tip_param
                     and a.cod_persona = p_cod_persona
                     and nvl(a.cod_per_vinculada,0) = 0;
                end if;
                if trim(v_dat_retorno) is null then
                  Select a.est_clave
                    into v_dat_retorno
                    from bw_ope_claves a
                   where a.tip_clave = p_tip_param
                     and a.cod_persona = p_cod_persona_vin
                     and nvl(a.cod_per_vinculada,0) = 0;
                end if;                       
         v_dat_retorno := fue_obt_des_refcodes('EST_CLAVE',v_dat_retorno);
  end if;
  return v_dat_retorno;
exception
  when others then
    return '';
end fuw_obt_homebanking;
/

