create or replace procedure it.prg_val_tas_rec_preaprobado(p_msj_error out varchar2) is
  c_tasa_ref   number := 980;
  v_plazos     varchar2(1000);
  v_cod_mod    ge_tas_rangos.cod_modulo%type;
  v_cod_mad    ge_tas_rangos.cod_modalidad%type;
  v_cod_submad ge_tas_rangos.cod_sub_modalidad%type;
  v_plz12      ge_tas_rangos.val_tasa%type; 
  v_plz18      ge_tas_rangos.val_tasa%type; 
  v_plz24      ge_tas_rangos.val_tasa%type;
  v_plz30      ge_tas_rangos.val_tasa%type;
  v_plz36      ge_tas_rangos.val_tasa%type;
  v_plz42      ge_tas_rangos.val_tasa%type;
  v_plz48      ge_tas_rangos.val_tasa%type;
  v_plz54      ge_tas_rangos.val_tasa%type;
  v_plz60      ge_tas_rangos.val_tasa%type;
  CURSOR cr_pre_apr_tmp IS 
  SELECT * FROM ge_pro_pre_aprobados_tmp;
begin
  p_msj_error := null;
  for k in cr_pre_apr_tmp loop
    if k.cod_modalidad = 68 then
      begin
        select a.cod_modulo, a.cod_modalidad, a.cod_sub_modalidad,
               max(decode(a.val_hasta,12,a.val_tasa)) as plazo12,
               max(decode(a.val_hasta,18,a.val_tasa)) as plazo18,
               max(decode(a.val_hasta,24,a.val_tasa)) as plazo24,
               max(decode(a.val_hasta,30,a.val_tasa)) as plazo30,
               max(decode(a.val_hasta,36,a.val_tasa)) as plazo36,
               max(decode(a.val_hasta,42,a.val_tasa)) as plazo42,
               max(decode(a.val_hasta,48,a.val_tasa)) as plazo48,
               max(decode(a.val_hasta,54,a.val_tasa)) as plazo54,
               max(decode(a.val_hasta,60,a.val_tasa)) as plazo60
          into v_cod_mod, v_cod_mad, v_cod_submad, 
               v_plz12, v_plz18, v_plz24, v_plz30, v_plz36, v_plz42, v_plz48, v_plz54, v_plz60
          from ge_tas_rangos a 
         where a.cod_tasa = c_tasa_ref 
           and a.cod_modulo = k.cod_modulo
           and a.cod_modalidad = k.cod_modalidad
           and a.cod_sub_modalidad = k.cod_sub_modalidad
        group by a.cod_modulo, a.cod_modalidad, a.cod_sub_modalidad;
      exception
        when no_data_found then
          p_msj_error := 'Tasa '||c_tasa_ref||' No Configurada para el Módulo: '||k.cod_modulo||
                         ' - Modalidad: '||k.cod_modalidad||' - Sub-Modalidad: '||k.cod_sub_modalidad||
                         '. Configure y vuelva a procesar.';
        when others then null;
      end;
      if p_msj_error is not null then
        exit;
      end if;
      -- Validación Plazo 12
      if nvl(k.plz_12_meses,0) > 0 and nvl(v_plz12,0) <= 0 then
        v_plazos := '12';
      end if;
      -- Plazo 18
      if nvl(k.plz_18_meses,0) > 0 and  nvl(v_plz18,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 18';
        else
          v_plazos := '18';
        end if;
      end if;
      -- Plazo 24
      if nvl(k.plz_24_meses,0) > 0 and nvl(v_plz24,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 24';
        else
          v_plazos := '24';
        end if;
      end if;
      -- Plazo 30
      if nvl(k.plz_30_meses,0) > 0 and nvl(v_plz30,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 30';
        else
          v_plazos := '30';
        end if;
      end if;
      -- Plazo 36
      if nvl(k.plz_36_meses,0) > 0 and nvl(v_plz36,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 36';
        else
          v_plazos := '36';
        end if;
      end if;
      -- Plazo 42
      if nvl(k.plz_42_meses,0) > 0 and nvl(v_plz42,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 42';
        else
          v_plazos := '42';
        end if;
      end if;
      -- Plazo 48
      if nvl(k.plz_48_meses,0) > 0 and nvl(v_plz48,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 48';
        else
          v_plazos := '48';
        end if;
      end if;
      -- Plazo 54
      if nvl(k.plz_54_meses,0) > 0 and nvl(v_plz54,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 54';
        else
          v_plazos := '54';
        end if;
      end if;
      -- Plazo 60
      if nvl(k.plz_60_meses,0) > 0 and nvl(v_plz60,0) <= 0 then
        if v_plazos is not null then
          v_plazos := v_plazos||', 60';
        else
          v_plazos := '60';
        end if;
      end if;
      -- Mensaje de error por plazo
      if v_plazos is not null then
        if instr(v_plazos,',') > 0 then
          v_plazos := ' - Plazos: '||v_plazos;
        else
          v_plazos := ' - Plazo: '||v_plazos;
        end if;
        p_msj_error := 'Tasa '||c_tasa_ref||' No Configurada para el Módulo: '||k.cod_modulo||
                       ' - Modalidad: '||k.cod_modalidad||' - Sub-Modalidad: '||k.cod_sub_modalidad||
                       v_plazos||'. Configure y vuelva a procesar.';
        if p_msj_error is not null then
          exit;
        end if;
      end if;
    end if;
  end loop;
end;
/

