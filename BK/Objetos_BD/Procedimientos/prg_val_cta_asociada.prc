create or replace procedure it.prg_val_cta_asociada (p_cod_persona varchar2,
                                                  p_nro_cuenta varchar2,
                                                  p_tipo varchar2,
                                                  p_mensaje out varchar2,
                                                  p_bloqueo out varchar2)
is
  v_es_perfisica     varchar2(1);
  v_cta_deb_asociada varchar2(1) default 'N';
  v_cta_cre_asociada varchar2(1) default 'N';
  v_relacion         varchar2(2) default 'xx';
BEGIN
  p_bloqueo := 'S';
  -- recuperar si la persona es física o no.
  v_es_perfisica := pag_gen.fu_es_per_fisica(p_cod_persona);
  -- Obtener el tipo de relación entre el deudor y la cuenta asociada.
  begin
    select a.relacion
      into v_relacion
      from ge_cta_clientes a
     where a.nro_cuenta = p_nro_cuenta
       and a.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      v_relacion := 'xx';
    when others then
      v_relacion := 'xx';
  end;
  --
  v_cta_deb_asociada := nvl(fue_tab_dat_adicional('GE_CLIENTES',
                                                  'CTA_DEB_ASOCIADA',
                                                  p_cod_persona),
                            'N');

  v_cta_cre_asociada := nvl(fue_tab_dat_adicional('GE_CLIENTES',
                                                  'CTA_CRE_ASOCIADA',
                                                  p_cod_persona),
                            'N');
  -- Persona Física
  if v_es_perfisica = 'S' and v_relacion != 'xx' then -- tiene alguna relación se puede continuar.
    if v_relacion = 'P' then
      p_mensaje := null;
    else
      p_mensaje := 'El Titular de la Cuenta no es el mismo que el Deudor.';
    end if;
    p_bloqueo := 'N';
  elsif v_es_perfisica = 'S' and v_relacion = 'xx' then -- no tiene ninguna relación con la cta.
    p_mensaje := 'El Titular de la Cuenta no está relacionado al Deudor.';
    if p_tipo = 'D' then -- D = debito automático, debito en cta por cobro de cuotas, cancelación total, parcial y rrr.
      if v_cta_deb_asociada = 'S' then
        p_bloqueo := 'N';
      else
        p_bloqueo := 'S';
      end if;
    else
      if v_cta_cre_asociada = 'S' then
        p_bloqueo := 'N';
      else
        p_bloqueo := 'S';
      end if;
    end if;
  -- Persona Jurídica
  elsif v_es_perfisica = 'N' and v_relacion != 'P' then
    p_mensaje := 'El Titular de la Cuenta no es el mismo que el Deudor.';
    if p_tipo = 'D' then
      if v_cta_deb_asociada = 'S' then
        p_bloqueo := 'N';
      else
        p_bloqueo := 'S';
      end if;
    else
      if v_cta_cre_asociada = 'S' then
        p_bloqueo := 'N';
      else
        p_bloqueo := 'S';
      end if;
    end if;
  else
    p_bloqueo := 'N';
  end if;
 
 if nvl(fug_obt_pardinamico('VAL_CTA_ASOCIADAS'),'N') = 'N' then
   p_bloqueo := 'N';
 end if; 
END;
/

