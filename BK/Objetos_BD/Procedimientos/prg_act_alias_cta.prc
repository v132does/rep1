create or replace procedure it.prg_act_alias_cta(p_nro_cuenta in ge_cta_dat_adicionales.nro_cuenta%type,
                                                 p_alias      in ge_cta_dat_adicionales.val_parametro%type,
                                                 p_tipo       in varchar2, --C --> cuentas y T--> tarjetas
                                                 p_cod_error  out number,
                                                 p_men_error  out varchar2) IS
  v_existe    number(2);
  v_par_alias ge_cta_dat_adicionales.parametro%type;
begin

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  -----------------------------
  p_cod_error := 0;

  if nvl(p_tipo, 'X') = 'C' then
    v_par_alias := 'ALIAS_CTA';
  elsif nvl(p_tipo, 'X') = 'T' then
    v_par_alias := 'ALIAS_TARJETA';
  else
    p_cod_error := 999;
    p_men_error := 'Tipo de alias ' || p_tipo || ' no existente';
    prg_ins_log_programas('PRG_ACT_ALIAS_CTA',
                          substr(p_men_error, 1, 4000));
    RETURN;
  end if;

  if nvl(p_tipo, 'X') = 'T' then
    begin
      select count(*)
        into v_existe
        from ah_tar_debitos d
       where d.nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        p_cod_error := 999;
        p_men_error := 'Cuenta ' || p_nro_cuenta ||
                       ' no tiene tarjeta asociada';
        prg_ins_log_programas('PRG_ACT_ALIAS_CTA',
                              substr(p_men_error, 1, 4000));
        RETURN;
    end;

    IF nvl(v_existe, 0) = 0 THEN
      p_cod_error := 999;
      p_men_error := 'Cuenta ' || p_nro_cuenta ||
                     ' no tiene tarjeta activa asociada';
      prg_ins_log_programas('PRG_ACT_ALIAS_CTA',
                            substr(p_men_error, 1, 4000));
      RETURN;
    END IF;
  end if;
  IF NVL(p_cod_error, 0) = 0 THEN
    v_existe := 0;
    begin
      select count(*)
        into v_existe
        from ge_cta_dat_adicionales c,
             ge_cuentas             b,
             ge_cta_def_adicionales a
       where a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and b.nro_cuenta = p_nro_cuenta
         and b.nro_cuenta = c.nro_cuenta
         and c.parametro = v_par_alias
         and c.parametro = a.parametro;
    exception
      when no_data_found then
        v_existe := 0;
    end;
    if nvl(v_existe, 0) != 0 then
      update ge_cta_dat_adicionales c
         set c.val_parametro = p_alias
       where c.nro_cuenta = p_nro_cuenta
         and c.parametro = v_par_alias;

      if sql%notfound then
        p_cod_error := 999;
        p_men_error := 'No se pudo actualizar alias ' || p_alias ||
                       'para la cta ' || p_nro_cuenta;
        prg_ins_log_programas('PRG_ACT_ALIAS_CTA',
                              substr(p_men_error, 1, 4000));
      end if;
    else

      insert into ge_cta_dat_adicionales
        (nro_cuenta, parametro, val_parametro)
      values
        (p_nro_cuenta, v_par_alias, p_alias);
    end if;
  END IF;
exception
  when others then
    p_cod_error := 999;
    p_men_error := 'Error al actualizar alias de la cuenta. ' || sqlerrm;
    prg_ins_log_programas('PRG_ACT_ALIAS_CTA',
                          substr(p_men_error, 1, 4000));
end;
/

