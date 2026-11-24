create or replace package body it.pag_tdi is

procedure pr_act_tas_interpolada is

v_val_tas_final        ge_tas_rangos_tmp.val_tasa%type;
v_ran_proximo          ge_tas_rangos_tmp.val_hasta%type;

v_error                varchar2(200);

v_fec_actual           ge_calendarios.fec_actual%type   := pag_cal.fu_obt_fec_actual(1);

Cursor c_tasas is
    select g.cod_tasa,
           g.cod_modulo,
           g.cod_modalidad,
           g.nro_cuenta,
           g.fec_vigencia,
           g.cod_oficina,
           g.cod_moneda,
           g.val_hasta,
           to_number(r.val_maximo) ran_proximo,
           g.cod_sub_modalidad
      from ge_tas_rangos_tmp g, ba_cod_referencias r,
           ge_par_dinamicos mon
     where r.dominio = 'DEP_INT_REL_RAN_TAS_CURVA'
       and g.val_hasta = to_number(r.val_minimo)
       and mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
       and mon.cod_moneda = g.cod_moneda
       and mon.val_parametro = 'S'
       and g.cod_modulo not in (5)
       and g.val_hasta <= 999999;

pragma autonomous_transaction;
begin

   /*Actualizar siguiente val_hasta y val_tasa para cada punto definido de la curva*/
   for tas in c_tasas loop

       begin
          v_val_tas_final:=  pag_tdi.fu_obt_val_tas_interpolada (
                             p_cod_modulo        => tas.cod_modulo,
                             p_cod_modalidad     => tas.cod_modalidad,
                             p_cod_sub_modalidad => tas.cod_sub_modalidad,
                             p_cod_oficina       => tas.cod_oficina,
                             p_nro_cuenta        => tas.nro_cuenta,
                             p_cod_moneda        => tas.cod_moneda,
                             p_dia_interpolar    => tas.ran_proximo,
                             p_cod_tasa          => tas.cod_tasa,
                             p_fec_fin           => v_fec_actual,
                             p_fec_vigencia      => tas.fec_vigencia,
                             p_cod_persona        => NULL,
                             p_cod_ente          => NULL);


    exception
      when others then
          prg_act_log_procesos('PRG_OBT_INT_CUR_TASA','PRG_OBT_INT_CUR_TASA',
          trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
          'P_COD_MODULO =>'|| tas.cod_modulo||',
          P_COD_MODALIDAD =>'|| tas.cod_modalidad||',
          P_COD_OFICINA =>'|| tas.cod_oficina||',
          P_NRO_CUENTA =>'|| tas.nro_cuenta||',
          P_COD_MONEDA =>'|| tas.cod_moneda||',
          P_MTO_TRANSACCION =>'|| tas.ran_proximo||',
          P_TAS_PERSONALIZADA =>'|| 'N'||',
          P_COD_TASA =>'|| tas.cod_tasa||',
          P_COD_TRANSACCION =>'||null||',
          P_FEC_FINAL =>'|| v_fec_actual||',
          P_VAL_TASA =>'|| v_val_tas_final||',
          P_FEC_VIGENCIA =>'|| tas.fec_vigencia||',
          P_COD_PERSONA =>'|| NULL||',
          P_COD_SUB_MODALIDAD =>'|| tas.cod_sub_modalidad);

          v_error := 'Obt. valores para interpolacion Mod.: '|| tas.COD_MODULO ||
                     ' Modal: '|| tas.COD_MODALIDAD ||'-' ||sqlerrm;
    end;
     if v_val_tas_final is not null then
       v_ran_proximo:= fug_con_numero(tas.ran_proximo);
       v_val_tas_final := fug_con_numero(v_val_tas_final);
      begin
          update ge_tas_rangos_tmp r
             set r.val_has_siguiente = tas.ran_proximo,
                 r.val_tas_siguiente = v_val_tas_final
           where r.cod_tasa = tas.cod_tasa
             and r.cod_modulo = tas.cod_modulo
             and r.cod_modalidad = tas.cod_modalidad
             and nvl(r.nro_cuenta, 'x') = nvl(tas.nro_cuenta, 'x')
             and r.fec_vigencia = tas.fec_vigencia
             and nvl(r.cod_oficina, 0) = nvl(tas.cod_oficina, 0)
             and r.cod_moneda = tas.cod_moneda
             and r.val_hasta = tas.val_hasta
             and nvl(r.cod_sub_modalidad, 0) = nvl(tas.cod_sub_modalidad, 0);
        commit;
      exception
        when others then
                    prg_act_log_procesos('PRG_OBT_INT_CUR_TASA','PRG_OBT_INT_CUR_TASA-upd',
                                  trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
                                  'P_COD_MODULO =>'|| tas.cod_modulo||',
                                  P_COD_MODALIDAD =>'|| tas.cod_modalidad||',
                                  P_COD_OFICINA =>'|| tas.cod_oficina||',
                                  P_NRO_CUENTA =>'|| tas.nro_cuenta||',
                                  P_COD_MONEDA =>'|| tas.cod_moneda||',
                                  P_MTO_TRANSACCION =>'|| v_ran_proximo||',
                                  P_TAS_PERSONALIZADA =>'|| 'N'||',
                                  P_COD_TASA =>'|| tas.cod_tasa||',
                                  P_COD_TRANSACCION =>'||null||',
                                  P_FEC_FINAL =>'|| v_fec_actual||',
                                  P_VAL_TASA =>'|| v_val_tas_final||',
                                  P_FEC_VIGENCIA =>'|| tas.fec_vigencia||',
                                  P_COD_PERSONA =>'|| NULL||',
                                  P_COD_SUB_MODALIDAD =>'|| tas.cod_sub_modalidad);

          v_error := 'Act. valores para interpolacion Mod.: '|| tas.COD_MODULO ||
                     ' Modal: '|| tas.COD_MODALIDAD ||'-' ||sqlerrm;
      end;
   end if;
 END LOOP;

exception
  when others then
    raise_application_error(-20000, v_error ||sqlerrm);
end;


procedure pr_ins_ge_tas_interpolada (p_fec_vig_anterior date,
                                     p_sig_fec_vigencia date) is

pragma autonomous_transaction;
begin

execute immediate ('truncate table ge_tas_interpolada');

  insert into ge_tas_interpolada
    select r.cod_tasa,
           p_sig_fec_vigencia,
           r.cod_oficina,
           r.cod_moneda,
           r.cod_modulo,
           r.cod_modalidad,
           r.nro_cuenta,
           r.val_hasta,
           r.val_tasa,
           r.cod_sub_modalidad,
           r.no_actualizable,
           r.val_extension,
           r.cod_persona,
           r.observaciones,
           r.fec_vencimiento,
           r.cod_ente,
           null,
           null,
           r.val_tasa,
           decode(r.cod_moneda,'GS','ML','ME')
      from ge_tas_rangos r, ge_par_dinamicos mon
     where r.cod_tasa in (777, 778)
       and r.fec_vigencia = p_fec_vig_anterior
       and mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
       and mon.cod_moneda = r.cod_moneda
       and mon.val_parametro = 'S';

commit;
exception
  when others then
    raise_application_error(-20000,'Error al insertar ge_tas_interpolada '||sqlerrm);

end;
procedure pr_ins_tas_pro_ponderada is

v_fec_actual           ge_calendarios.fec_actual%type   := pag_cal.fu_obt_fec_actual(1);

pragma autonomous_transaction;
begin

     begin
       insert into ge_cal_tas_pro_ponderada_tmp (
                   nro_cuenta,
                   nro_cuota,
                   mto_capital,
                   fec_vencimiento,
                   sal_capital,
                   mto_cap_adelantado,
                   dia_transcurrido,
                   val_tas_interpolada,
                   val_tas_pro_ponderada,
                   cod_tasa)
           (select p.nro_cuenta,
                   p.nro_cuota,
                   p.mto_capital,
                   p.fec_vencimiento,
                   p.sal_capital,
                   p.mto_cap_adelantado,
                   (p.fec_vencimiento - g.fec_apertura) dia_transcurrido,
                   null,
                   null,
                   null
             from pr_cuotas p, ge_cta_dep_internos_tmp g
            where p.nro_cuenta = g.nro_cuenta
              and nvl(g.val_tasa,0) = 0
              and g.cod_modulo = 6
              and not exists (select 1
                                from ge_cta_dat_adicionales gc
                               WHERE gc.parametro = 'POR_TAS_DEP_INTERNO'
                                 AND gc.nro_cuenta = g.nro_cuenta
                                 AND gc.val_parametro IS NOT NULL));
            commit;
       exception
         when others then
          raise_application_error(-20002, 'Error al realizar calculo de TPP' ||sqlerrm);
       end;

      begin
      insert into ge_cal_tas_pro_ponderada_tmp (
                  nro_cuenta,
                  nro_cuota,
                  mto_capital,
                  fec_vencimiento,
                  sal_capital,
                  mto_cap_adelantado,
                  dia_transcurrido,
                  val_tas_interpolada,
                  val_tas_pro_ponderada)
          (select ah.nro_cuenta,
                  ah.nro_cuota,
                  ah.mto_cuota,
                  ah.fec_vencimiento,
                  g.monto,
                  null,
                  (ah.fec_vencimiento - g.fec_apertura),
                  null,
                  null
             from ah_pro_cuotas ah, ge_cta_dep_internos_tmp g
            where g.nro_cuenta = ah.nro_cuenta
              and nvl(g.val_tasa,0) = 0
              and g.cod_modulo = 3
              and g.cod_modalidad = 38
              and not exists (select 1
                                from ge_cta_dat_adicionales gc
                               WHERE gc.parametro = 'POR_TAS_DEP_INTERNO'
                                 AND gc.nro_cuenta = g.nro_cuenta
                                 AND gc.val_parametro IS NOT NULL));
            commit;
        exception
         when others then
          raise_application_error(-20002, 'Error al realizar calculo de TPP '||sqlerrm);
       end;


end;
procedure pr_cal_tas_pro_ponderada (p_nro_cuenta    in     ge_cuentas.nro_cuenta%type,
                                    p_cod_tasa      in     ge_cal_tas_pro_ponderada_tmp.cod_tasa%type,
                                    p_val_tas_tpp   in out ge_tas_rangos.val_tasa%type
                                    ) is

v_fec_actual           ge_calendarios.fec_actual%type   := pag_cal.fu_obt_fec_actual(1);
v_val_tas_tpp          ge_cal_tas_pro_ponderada_tmp.val_tas_pro_ponderada%type;
v_capital              ge_cal_tas_pro_ponderada_tmp.mto_capital%type;
v_mto_original         ge_cal_tas_pro_ponderada_tmp.mto_capital%type;
v_cal_tas_tpp          ge_cal_tas_pro_ponderada_tmp.val_tas_pro_ponderada%type;
v_cod_tasa             ge_cal_tas_pro_ponderada_tmp.cod_tasa%type := p_cod_tasa;
v_val_tas_interpolada  ge_cal_tas_pro_ponderada_tmp.val_tas_pro_ponderada%type;
v_dia_transcurido      ge_cal_tas_pro_ponderada_tmp.dia_transcurrido%type;

cursor c_tas_interpoladas is
select r.nro_cuenta,
       r.nro_cuota,
       p.mon_original mto_original,
       nvl(r.mto_capital, 0) Mto_capital,
       nvl(r.mto_cap_adelantado, 0) Mto_cap_adelantado,
       p.cod_modulo,
       p.cod_modalidad,
       p.cod_sub_modalidad,
       p.cod_oficina,
       p.cod_moneda,
       r.dia_transcurrido
   from ge_cal_tas_pro_ponderada_tmp r, ge_cta_dep_internos_tmp p
 where r.nro_cuenta = p_nro_cuenta
   and r.nro_cuenta = p.nro_cuenta
   and r.dia_transcurrido >= 0
   and r.nro_cuota > 0
   and (nvl(r.mto_capital,0) <> 0
       or nvl(r.mto_cap_adelantado,0) <> 0);


pragma autonomous_transaction;
   TYPE cursor1_type IS TABLE OF c_tas_interpoladas%ROWTYPE;
   reg cursor1_type;



function lf_obt_mto_capital (p_nro_cuenta ge_cta_dep_internos_tmp.nro_cuenta%type)
         return number is

v_mto_capital   ah_pro_cuotas.mto_cuota%type;
begin
  select sum(c.mto_cuota)
    into v_mto_capital
    from ah_pro_cuotas c
   where c.nro_cuenta = p_nro_cuenta;

  return nvl(v_mto_capital, 0);

exception
  when others then
    return nvl(v_mto_capital, 0);
end;

begin

--actualización dia transcurrido por inconsistencia
update ge_cal_tas_pro_ponderada_tmp e
   set e.dia_transcurrido = 0
 where e.dia_transcurrido < 1
   and e.nro_cuenta = p_nro_cuenta;


OPEN c_tas_interpoladas;
   LOOP
      FETCH c_tas_interpoladas BULK COLLECT
         INTO reg LIMIT 100;
         FOR i IN 1 .. reg.count LOOP

         if reg(i).dia_transcurrido < 1 then
           v_dia_transcurido := 0;
         else
           v_dia_transcurido :=  reg(i).dia_transcurrido;
         end if;


          v_val_tas_interpolada:= pag_tdi.fu_obt_val_tas_interpolada
                                        (reg(i).cod_modulo,
                                         reg(i).cod_modalidad,
                                         reg(i).cod_sub_modalidad,
                                         reg(i).cod_oficina,
                                         reg(i).nro_cuenta,
                                         reg(i).cod_moneda,
                                         v_dia_transcurido,-- dia interpolar
                                         v_cod_tasa,
                                         v_fec_actual, --fec_fin
                                         v_fec_actual, -- fec_actual
                                         null,
                                         null);

         if reg(i).cod_modulo = 3 and reg(i).cod_modalidad = 38 then
            v_mto_original :=  lf_obt_mto_capital(reg(i).nro_cuenta);
         else
            v_mto_original := reg(i).mto_original;
         end if;
          if v_val_tas_interpolada <> 0 then
             v_capital := reg(i).Mto_capital + reg(i).Mto_cap_adelantado;
             v_cal_tas_tpp := v_capital / v_mto_original * v_val_tas_interpolada;
          else
            v_cal_tas_tpp := 0;
          end if;

           begin
             update ge_cal_tas_pro_ponderada_tmp t
                set t.val_tas_pro_ponderada = v_cal_tas_tpp,
                    t.val_tas_interpolada   = v_val_tas_interpolada
              where t.nro_cuenta = reg(i).nro_cuenta
                and t.nro_cuota = reg(i).nro_cuota;
           exception
             when others then
               raise_application_error(-20003,
                                       'Error al actualizar TPP ' || reg(i)
                                       .nro_cuota || ' - ' || sqlerrm);
           end;
     commit;
     end loop;
     EXIT WHEN c_tas_interpoladas%NOTFOUND;
END LOOP;


   select sum(r.val_tas_pro_ponderada)
     into v_val_tas_tpp
     from ge_cal_tas_pro_ponderada_tmp r
    where r.nro_cuenta = p_nro_cuenta;

   p_val_tas_tpp := nvl(v_val_tas_tpp,999);

end;


procedure pr_ins_ge_tas_rangos_tmp  is
v_fec_vig_max    ge_tas_rangos.fec_vigencia%type;

pragma autonomous_transaction;
begin

execute immediate ('truncate table ge_tas_rangos_tmp');

    select max(r.fec_vigencia)
      into v_fec_vig_max
      from ge_tas_rangos r
     where r.cod_tasa = 777;

  insert into ge_tas_rangos_tmp (cod_tasa,
           fec_vigencia,
           cod_oficina,
           cod_moneda,
           cod_modulo,
           cod_modalidad,
           nro_cuenta,
           val_hasta,
           val_tasa,
           cod_sub_modalidad,
           no_actualizable,
           val_extension,
           cod_persona,
           observaciones,
           fec_vencimiento,
           cod_ente)
    select r.cod_tasa,
           r.fec_vigencia,
           r.cod_oficina,
           r.cod_moneda,
           r.cod_modulo,
           r.cod_modalidad,
           r.nro_cuenta,
           r.val_hasta,
           r.val_tasa,
           r.cod_sub_modalidad,
           r.no_actualizable,
           r.val_extension,
           r.cod_persona,
           r.observaciones,
           r.fec_vencimiento,
           r.cod_ente
      from ge_tas_rangos r, ge_par_dinamicos mon
     where r.cod_tasa in (777, 778)
       and mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
       and mon.cod_moneda = r.cod_moneda
       and mon.val_parametro = 'S'
       and r.fec_vigencia = v_fec_vig_max;

commit;
exception
  when others then
    raise_application_error(-20000,'Error al insertar ge_tas_interpolada '||sqlerrm);

end;

function fu_obt_val_tas_interpolada
                        (p_cod_modulo in ba_modulos.cod_modulo%type
                         ,p_cod_modalidad in ge_modalidades.cod_modalidad%type
                         ,p_cod_sub_modalidad in number
                         ,p_cod_oficina in ba_oficinas.cod_oficina%type
                         ,p_nro_cuenta in ge_cuentas.nro_cuenta%type
                         ,p_cod_moneda in ba_monedas.cod_moneda%type
                         ,p_dia_interpolar in ge_tas_rangos.val_hasta%type
                         ,p_cod_tasa in ge_tas_rangos.cod_tasa%type
                         ,p_fec_fin in date
                         ,p_fec_vigencia in ge_tas_rangos.fec_vigencia%type
                         ,p_cod_persona in ba_personas.cod_persona%type default null
                         ,p_cod_ente  in ge_entes.cod_ente%type default null)
                         return number is

/**LCabrera - Octubre/2019**/
/** FunciÃƒÂ³n que retorna el valor interpolado de una tasa **/
/**Para el correcto funcionamiento previamente se deben actualizar los valores de la curva
  y se tuvo que haber obtenido los dos valores rango y tasa siguiente**/

v_dia_tasa0         ge_tas_rangos.val_hasta%type;
v_dia_tasa1         ge_tas_rangos.val_hasta%type;
v_dia_tasax         ge_tas_rangos.val_hasta%type := p_dia_interpolar;
v_val_tasa0         ge_tas_rangos.val_tasa%type;
v_val_tasa1         ge_tas_rangos.val_tasa%type;
v_val_tasax         ge_tas_rangos.val_tasa%type;
v_fec_final         date  := pag_cal.fu_obt_fec_actual(1);
v_interpolar        varchar2(1);

begin

  If v_dia_tasax < 1 then
    v_dia_tasax := 0;
  End if;


  begin
    select distinct 'N'
      into v_interpolar
      from ba_cod_referencias r
     where r.dominio = 'DEP_INT_REL_RAN_TAS_CURVA'
       and to_number(r.val_minimo) = v_dia_tasax;
  exception
    when no_data_found then
      v_interpolar := 'S';
    when others then
      v_interpolar := 'S';
  end;



If v_interpolar = 'S' then
 begin
    select g.val_hasta,
           nvl(g.val_tasa,-999) val_tasa,
           g.val_has_siguiente,
           nvl(g.val_tas_siguiente,-999) val_tasa_siguiente
      into v_dia_tasa0, v_val_tasa0, v_dia_tasa1, v_val_tasa1
      from ge_tas_rangos_tmp g, ge_par_dinamicos mon
     where mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
       and mon.cod_moneda = g.cod_moneda
       and mon.val_parametro = 'S'
       and g.val_has_siguiente is not null
       and g.val_tas_siguiente is not null
       and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
       AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) =
           nvl(p_cod_modalidad, -1)
       AND g.cod_sub_modalidad = p_cod_sub_modalidad
       AND nvl(g.cod_oficina, nvl(p_cod_oficina, -1)) =
           nvl(p_cod_oficina, -1)
       AND nvl(cod_ente, nvl(p_cod_ente, -1)) = nvl(p_cod_ente, -1)
       AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
       AND nro_cuenta = p_nro_cuenta
       AND cod_tasa = p_cod_tasa
       and g.val_hasta <= NVL(v_dia_tasax, 0)
       and g.val_has_siguiente >= NVL(v_dia_tasax, 0);
  exception
  when no_data_found then
    begin
      select g.val_hasta,
           nvl(g.val_tasa,-999) val_tasa,
           g.val_has_siguiente,
           nvl(g.val_tas_siguiente,-999) val_tasa_siguiente
        into v_dia_tasa0, v_val_tasa0, v_dia_tasa1, v_val_tasa1
        from ge_tas_rangos_tmp g, ge_par_dinamicos mon
       where mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
         and mon.cod_moneda = g.cod_moneda
         and mon.val_parametro = 'S'
         and g.val_has_siguiente is not null
         and g.val_tas_siguiente is not null
         and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
         AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) =
           nvl(p_cod_modalidad, -1)
         AND nvl(g.cod_sub_modalidad,p_cod_sub_modalidad) = p_cod_sub_modalidad
         AND nvl(g.cod_oficina, nvl(p_cod_oficina, -1)) =
           nvl(p_cod_oficina, -1)
         AND nvl(cod_ente, nvl(p_cod_ente, -1)) = nvl(p_cod_ente, -1)
         AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
         AND nro_cuenta IS NULL
         AND g.cod_tasa = p_cod_tasa
         and g.cod_persona = p_cod_persona
         and g.val_hasta <= NVL(v_dia_tasax, 0)
         and g.val_has_siguiente >= NVL(v_dia_tasax, 0);
    exception
      when no_data_found then
        begin
          select g.val_hasta,
               nvl(g.val_tasa,-999) val_tasa,
               g.val_has_siguiente,
               nvl(g.val_tas_siguiente,-999) val_tasa_siguiente
            into v_dia_tasa0, v_val_tasa0, v_dia_tasa1, v_val_tasa1
            from ge_tas_rangos_tmp g
           where g.val_has_siguiente is not null
             and g.val_tas_siguiente is not null
             and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
             AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
             AND g.cod_sub_modalidad = p_cod_sub_modalidad
             AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'X')) = nvl(p_cod_moneda, 'X')
             AND cod_tasa = p_cod_tasa
             and g.val_hasta <= NVL(v_dia_tasax, 0)
             and g.val_has_siguiente >= NVL(v_dia_tasax, 0);
        exception
          when no_data_found then
              begin
                select g.val_hasta,
                     nvl(g.val_tasa,-999) val_tasa,
                     g.val_has_siguiente,
                     nvl(g.val_tas_siguiente,-999) val_tasa_siguiente
                  into v_dia_tasa0, v_val_tasa0, v_dia_tasa1, v_val_tasa1
                  from ge_tas_rangos_tmp g
                 where g.val_has_siguiente is not null
                   and g.val_tas_siguiente is not null
                   and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
                   AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) = nvl(p_cod_modalidad, -1)
                   AND g.cod_sub_modalidad is null
                   AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'X')) = nvl(p_cod_moneda, 'X')
                   AND cod_tasa = p_cod_tasa
                   and g.val_hasta <= NVL(v_dia_tasax, 0)
                   and g.val_has_siguiente >= NVL(v_dia_tasax, 0);
              exception
                when no_data_found then
                  v_dia_tasa0 := null;
                  v_val_tasa0 := null;
                  v_dia_tasa1 := null;
                  v_val_tasa1 := null;
              end;
          end; 
   end;

 end;

  ---Formula para obtener la interpolaciÃƒÂ³n de la curva Tasa de Interes
  if v_dia_tasa0 is not null and v_dia_tasa1 is not null then
       v_val_tasax := ROUND(v_val_tasa0 +
                        ((v_dia_tasax - v_dia_tasa0)/(v_dia_tasa1-v_dia_tasa0))*
                        (v_val_tasa1 - v_val_tasa0),2);

        return nvl(v_val_tasax,-1);
  else
    return nvl(v_val_tasax,-1);
  end if;

else

 begin
    select nvl(g.val_tasa,-999) val_tasa
      into v_val_tasa0
      from ge_tas_rangos_tmp g, ge_par_dinamicos mon
     where mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
       and mon.cod_moneda = g.cod_moneda
       and mon.val_parametro = 'S'
       and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
       AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) =
           nvl(p_cod_modalidad, -1)
       AND nvl(g.cod_sub_modalidad, p_cod_sub_modalidad) = p_cod_sub_modalidad
       AND nvl(g.cod_oficina, nvl(p_cod_oficina, -1)) =
           nvl(p_cod_oficina, -1)
       AND nvl(cod_ente, nvl(p_cod_ente, -1)) = nvl(p_cod_ente, -1)
       AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
       AND nro_cuenta = p_nro_cuenta
       AND cod_tasa = p_cod_tasa
       and g.val_hasta = NVL(v_dia_tasax, 0);
  exception
  when no_data_found then
    begin
      select nvl(g.val_tasa,-999) val_tasa
        into v_val_tasa0
        from ge_tas_rangos_tmp g, ge_par_dinamicos mon
       where mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
         and mon.cod_moneda = g.cod_moneda
         and mon.val_parametro = 'S'
         and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
         AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) =
             nvl(p_cod_modalidad, -1)
         AND g.cod_sub_modalidad = p_cod_sub_modalidad
         AND nvl(g.cod_oficina, nvl(p_cod_oficina, -1)) =
             nvl(p_cod_oficina, -1)
         AND nvl(cod_ente, nvl(p_cod_ente, -1)) = nvl(p_cod_ente, -1)
         AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
         AND nro_cuenta IS NULL
         AND cod_tasa = p_cod_tasa
         and cod_persona = p_cod_persona
         and g.val_hasta = NVL(v_dia_tasax, 0);
    exception
      when no_data_found then
        begin
          select nvl(g.val_tasa,-999) val_tasa
            into v_val_tasa0
            from ge_tas_rangos_tmp g, ge_par_dinamicos mon
           where mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
             and mon.cod_moneda = g.cod_moneda
             and mon.val_parametro = 'S'
             and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
             AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) =
                                      nvl(p_cod_modalidad, -1)
             AND g.cod_sub_modalidad = p_cod_sub_modalidad
             AND nvl(g.cod_oficina, nvl(p_cod_oficina, -1)) =
                                    nvl(p_cod_oficina, -1)
             AND nvl(cod_ente, nvl(p_cod_ente, -1)) = nvl(p_cod_ente, -1)
             AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
             AND nro_cuenta IS NULL
             and cod_persona IS NULL
             AND cod_tasa = p_cod_tasa
             and g.val_hasta = NVL(v_dia_tasax, 0);
        exception
          when no_data_found then
            begin
              select nvl(g.val_tasa,-999) val_tasa
                into v_val_tasa0
                from ge_tas_rangos_tmp g, ge_par_dinamicos mon
               where mon.parametro = 'DEP_INT_MONEDAS' ---Monedas habilitadas
                 and mon.cod_moneda = g.cod_moneda
                 and mon.val_parametro = 'S'
                 and nvl(g.cod_modulo, nvl(p_cod_modulo, -1)) = nvl(p_cod_modulo, -1)
                 AND nvl(g.cod_modalidad, nvl(p_cod_modalidad, -1)) =
                                          nvl(p_cod_modalidad, -1)
                 AND g.cod_sub_modalidad is null
                 AND nvl(g.cod_oficina, nvl(p_cod_oficina, -1)) =
                                        nvl(p_cod_oficina, -1)
                 AND nvl(cod_ente, nvl(p_cod_ente, -1)) = nvl(p_cod_ente, -1)
                 AND nvl(g.cod_moneda, nvl(p_cod_moneda, 'x')) = nvl(p_cod_moneda, 'x')
                 AND nro_cuenta IS NULL
                 and cod_persona IS NULL
                 AND cod_tasa = p_cod_tasa
                 and g.val_hasta = NVL(v_dia_tasax, 0);
            exception
              when no_data_found then
                v_val_tasa0 := null;
            end;
        end;
    end;
   return nvl(v_val_tasa0,-999);
 end;
end if;


Exception
  when no_data_found then
       v_val_tasax := -97;
       return v_val_tasax;
  when others then
       raise_application_error(-20000,'Error para dÃƒÂ­a '||v_dia_tasax||'-'||sqlerrm);
       v_val_tasax := -98;
       return v_val_tasax;
end;



END pag_tdi;
/

