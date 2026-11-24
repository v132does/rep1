create or replace package body it.pag_pre is

  function fu_tie_pre_aprobado(p_cod_persona   in ge_pro_pre_aprobados.cod_persona%type,
                               p_cod_modulo    in ge_pro_pre_aprobados.cod_modulo%type,
                               p_cod_modalidad in ge_pro_pre_aprobados.cod_modalidad%type,
                               p_ind_atm       in varchar2,
                               p_datos         out tp_datosCuota) return number is
    v_user            ba_usuarios.cod_usuario%type := user;
    v_usu_atm   ba_usuarios.cod_usuario%type := 'ATM';  -- ATM
    v_usu_hb_emp    ba_usuarios.cod_usuario%type := 'HBANKJ';
    v_usu_hb_fis    ba_usuarios.cod_usuario%type := 'HBANKF';
    v_sal_min_vigente ge_movimientos.monto%type;
    v_can_sal_min     ge_movimientos.monto%type;
  --
  begin
     BEGIN
        select a.mto_max_cuota,
               a.plz_12_meses, a.plz_18_meses, a.plz_24_meses, a.plz_30_meses,
               a.plz_36_meses, a.plz_42_meses, a.plz_48_meses, a.plz_54_meses,
               a.plz_60_meses, a.min_plazo, a.max_plazo, a.min_monto, a.max_monto,
               a.cod_sub_modalidad      -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
          into p_datos.montoMaxCuota,
               p_datos.plazo12, p_datos.plazo18, p_datos.plazo24, p_datos.plazo30,
               p_datos.plazo36, p_datos.plazo42, p_datos.plazo48, p_datos.plazo54,
               p_datos.plazo60, p_datos.plazoMinimo, p_datos.plazoMaximo, p_datos.montoMinimo, p_datos.montoMaximo,
               p_datos.CodSubModalidad  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
          from ge_pro_pre_aprobados a
         where a.cod_persona = p_cod_persona
           and a.estado = 'V'
           and a.cod_modulo = p_cod_modulo
           and a.cod_modalidad = p_cod_modalidad
           and fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',a.cod_modulo,a.cod_modalidad) = 'S'
           and a.nro_solicitud is null
           and (v_user in (v_usu_hb_emp,v_usu_hb_fis ) and nvl(a.ind_hab_hb,'N') = 'S' or   -- Usuario HBANKJ
                substr(v_user,1,3) = v_usu_atm and nvl(a.ind_hab_atm,'N') = 'S')  --  Usuario ATM
           and ( a.cod_campana in( select distinct c.cod_campana
                                 from cr_campanas c
                                where pag_cal.FU_OBT_FEC_ACTUAL(6) >= c.fec_inicio  -- DYDMR-9386 MAO AGO/2018
                                  and ( pag_cal.FU_OBT_FEC_ACTUAL(6) <= c.fec_vencimiento or c.fec_vencimiento is null )
                                   )
             or a.cod_campana is null )
           and a.lote = ( select max(x.lote)
                            from ge_pro_pre_aprobados x
                           where x.cod_persona = a.cod_persona
                             and x.estado = 'V'
                             and x.cod_modulo = p_cod_modulo
                             and x.cod_modalidad = p_cod_modalidad
                             and fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',a.cod_modulo,a.cod_modalidad) = 'S'
                             and (v_user in (v_usu_hb_emp,v_usu_hb_fis ) and nvl(a.ind_hab_hb,'N') = 'S' or  -- Usuario HBANKJ
                                  substr(v_user,1,3) = v_usu_atm and nvl(a.ind_hab_atm,'N') = 'S')  -- Usuario ATM
                             and x.nro_solicitud is null
                             and ( x.cod_campana = a.cod_campana or x.cod_campana is null )
                        );
        -- obtenemos el plazo minimo en base a definiciones de plazos
        IF nvl(p_datos.plazo12, 0) > 0 AND p_datos.plazoMaximo >= 12 THEN
           p_datos.plazoMinimo := 12;
        ELSIF nvl(p_datos.plazo18, 0) > 0 AND p_datos.plazoMaximo >= 18 THEN
           p_datos.plazoMinimo := 18;
        ELSIF nvl(p_datos.plazo24, 0) > 0 AND p_datos.plazoMaximo >= 24 THEN
           p_datos.plazoMinimo := 24;
        ELSIF nvl(p_datos.plazo30, 0) > 0 AND p_datos.plazoMaximo >= 30 THEN
           p_datos.plazoMinimo := 30;
        ELSIF nvl(p_datos.plazo36, 0) > 0 AND p_datos.plazoMaximo >= 36 THEN
           p_datos.plazoMinimo := 36;
        ELSIF nvl(p_datos.plazo42, 0) > 0 AND p_datos.plazoMaximo >= 42 THEN
           p_datos.plazoMinimo := 42;
        ELSIF nvl(p_datos.plazo48, 0) > 0 AND p_datos.plazoMaximo >= 48 THEN
           p_datos.plazoMinimo := 48;
        ELSIF nvl(p_datos.plazo54, 0) > 0 AND p_datos.plazoMaximo >= 54 THEN
           p_datos.plazoMinimo := 54;
        ELSIF nvl(p_datos.plazo60, 0) > 0 AND p_datos.plazoMaximo >= 60 THEN
           p_datos.plazoMinimo := 60;
        END IF;

        -- obtenemos el plazo maximo en base a definiciones de plazos
        IF nvl(p_datos.plazo60, 0) > 0 AND p_datos.plazoMaximo >= 60 THEN
           p_datos.montoMaximo := p_datos.plazo60;
        ELSIF nvl(p_datos.plazo54, 0) > 0 AND p_datos.plazoMaximo >= 54 THEN
           p_datos.montoMaximo := p_datos.plazo54;
        ELSIF nvl(p_datos.plazo48, 0) > 0 AND p_datos.plazoMaximo >= 48 THEN
           p_datos.montoMaximo := p_datos.plazo48;
        ELSIF nvl(p_datos.plazo42, 0) > 0 AND p_datos.plazoMaximo >= 42 THEN
           p_datos.montoMaximo := p_datos.plazo42;
        ELSIF nvl(p_datos.plazo36, 0) > 0 AND p_datos.plazoMaximo >= 36 THEN
           p_datos.montoMaximo := p_datos.plazo36;
        ELSIF nvl(p_datos.plazo30, 0) > 0 AND p_datos.plazoMaximo >= 30 THEN
           p_datos.montoMaximo := p_datos.plazo30;
        ELSIF nvl(p_datos.plazo24, 0) > 0 AND p_datos.plazoMaximo >= 24  THEN
           p_datos.montoMaximo := p_datos.plazo24;
        ELSIF nvl(p_datos.plazo18, 0) > 0 AND p_datos.plazoMaximo >= 18 THEN
           p_datos.montoMaximo := p_datos.plazo18;
        ELSIF nvl(p_datos.plazo12, 0) > 0 AND p_datos.plazoMaximo >= 12 THEN
           p_datos.montoMaximo := p_datos.plazo12;
        END IF;

        -- validamos el monto maximo que pueda pagar
        IF p_datos.montoMaximo > p_datos.montoMaxCuota * p_datos.plazoMaximo THEN
           p_datos.montoMaximo := p_datos.montoMaxCuota * p_datos.plazoMaximo;
        END IF;

        -- si no tiene monto minimo, copiamos el maximo como minimo
        IF p_datos.montoMinimo IS NULL THEN
           p_datos.montoMinimo := p_datos.montoMaximo;
        END IF;

        -- si no tiene un monto, retornamos que no posee
        IF p_datos.montoMaximo IS NULL THEN
           RETURN -1;
        END IF;

        -- validacion de salario minimo
        begin
           select sal_min_vigente
             into v_sal_min_vigente
             from pr_parametros
            where rownum = 1;

           v_can_sal_min := to_number(fug_obt_pardinamico('MAX_CAN_SAL_MIN_PRE_APR_ATM'));

           if p_datos.montoMaximo > round((nvl(v_sal_min_vigente,0) * nvl(v_can_sal_min,0))) then
              return -2;
           end if;
        exception
           when no_data_found then
              null;
        end;

        -- validaciones de requisitos preaprobados
        if fut_val_req_pre_aprobados(p_cod_persona) = false then
           return -3;
        end if;

        -- verificacion de persona
        --Flexibilidad si es ATM/HB se levanta la restricción
        if user in (v_usu_hb_emp,v_usu_hb_fis ) OR USER LIKE '%ATM%' then
           null;
        else
            if nvl(fug_ver_verificacion(p_cod_persona), 'x') <> 'S' then
               return -4;
        end if;
   end if;
        --DYDMR-6823 06/06/2017 Sólo se valida que estee verificado sino son canales digitales
        if user in (v_usu_hb_emp,v_usu_hb_fis ) OR USER LIKE '%ATM%' then
           RETURN 1;
        else
          -- validar persona verificada
          if nvl(fug_obt_pardinamico('VER_PERSONA', p_cod_modulo, p_cod_modalidad, 'GS', fug_obt_ofi_oficial(p_cod_persona)), 'x') <> 'S' then
             return -5;
          end if;
        end if;

        RETURN 1;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           RETURN -1;
        WHEN OTHERS THEN
           RETURN -99;
     END;
  end;

  procedure pr_obt_tar_afinidad(p_val_maximo   IN ba_cod_referencias.val_maximo%type,
                                p_abreviatura  IN ba_cod_referencias.abreviatura%type,
                                p_afinidad     OUT ba_cod_referencias.val_minimo%type,
                                p_sub_afinidad OUT ba_cod_referencias.val_minimo%type,
                                p_significado  OUT ba_cod_referencias.significado%type) is
  begin
     p_afinidad := null;
     p_sub_afinidad := null;
     p_significado := null;

     select substr(val_minimo, 1, 6), substr(val_minimo, 7, 2), significado
       into p_afinidad, p_sub_afinidad, p_significado
       from ba_cod_referencias
      where dominio = 'EQU_AFINIDAD'
        and val_maximo = p_val_maximo
        and abreviatura = p_abreviatura;
  exception
     when others then
        null;
  end;

  function fu_tie_tar_aprobada(p_cod_persona  in ba_personas.cod_persona%type,
                               p_lin_aprobada out ge_cli_aprobados_atm_tmp.lin_aprobada%type,
                               p_afinidad     out ge_cli_aprobados_atm_tmp.afinidad%type,
                               p_sub_afinidad out ge_cli_aprobados_atm_tmp.clase%type,
                               p_moneda       out ba_monedas.cod_moneda%TYPE) return number is
     v_retorno number := 0;
  begin
     p_moneda := pag_gen.fu_obt_mon_local;
     p_lin_aprobada := null;
     p_afinidad     := null;
     p_sub_afinidad := null;

     begin
        select a.lin_aprobada, a.afinidad, a.clase
          into p_lin_aprobada, p_afinidad, p_sub_afinidad
          from ge_cli_aprobados_atm_tmp a
         where a.cod_persona = p_cod_persona
           and nvl(a.acepta,'N') != 'S' -- Para que vuelva a mostrar si no es aceptado.
           and a.fec_baja >= pag_cal.FU_OBT_FEC_ACTUAL(5)
           and a.det_error is null;

        if p_afinidad is null or p_sub_afinidad is null then
           return -1;
        end if;
        -- la persona no debe ser inhibida
        if fug_obt_es_per_inhi(p_cod_persona) = 'S' then
           return -1;
        end if;
        -- cantidad de días ultima apertura tarjeta
        if fu_obt_can_dia_tarjeta(p_cod_persona) <= 180 then
           return -1;
        end if;
        -- si no existe solicitud pendiente
        if fu_obt_tar_can_solicitudes(p_cod_persona) > 0 then
           return -1;
        end if;
      exception
        when others then
          v_retorno := -1;
      end;
      return v_retorno;
  end;

  function fu_obt_mad_tarjeta(p_afinidad     in ta_tipos.afinidad%type,
                              p_sub_afinidad in ta_tipos.sub_afinidad%type) return number is
     v_retorno ge_modalidades.cod_modalidad%type := null;
  begin
     select distinct cod_modalidad
       into v_retorno
       from ta_tipos t
      where t.afinidad = p_afinidad
        and nvl(t.sub_afinidad, '00') = nvl(p_sub_afinidad, '00');
     return v_retorno;
  exception
     when others then
        return null;
  end;

  function fu_obt_nro_simulacion(p_cod_persona   in ba_personas.cod_persona%type,
                                 p_cod_modulo    in pr_simulaciones.cod_modulo%type,
                                 p_cod_modalidad in pr_simulaciones.cod_modalidad%type,
                                 p_monto         in pr_simulaciones.monto%type,
                                 p_cuotas        in pr_simulaciones.can_cuotas%type default null) return number is
     v_nro_simulacion pr_simulaciones.nro_simulacion%type;
  begin
     select max(nro_simulacion)
       into v_nro_simulacion
       from pr_simulaciones a
      where a.cod_persona = p_cod_persona
        and a.monto = p_monto
        and a.cod_modulo = p_cod_modulo
        and a.cod_modalidad = p_cod_modalidad
        and a.can_cuotas = nvl(p_cuotas, a.can_cuotas);
     return v_nro_simulacion;
  exception
     when others then
        return -1;
  end;

  -- obtener datos del preaprobado
  procedure pr_obt_dat_simulacion(p_nro_simulacion in pr_simulaciones.nro_simulacion%type,
                                  p_monto         out pr_simulaciones.monto%type,
                                  p_plazo         out pr_simulaciones.can_cuotas%type,
                                  p_cuota         out pr_simulaciones.monto%type,
                                  p_cod_moneda    out pr_simulaciones.cod_moneda%type,
                                  p_val_tasa      out pr_simulaciones.val_tasa%type,
                                  p_fec_pri_venc  out pr_simulaciones.fec_pri_vencimiento%type,
                                  p_tas_des_com   out pr_simulaciones.tot_interes%type,
                                  p_fec_inicio    out pr_simulaciones.fec_inicio%type,
                                  p_cotizacion    out pr_simulaciones.cotizacion%type,
                                  p_tot_interes   out pr_simulaciones.tot_interes%type,
                                  p_tot_cargos    out pr_simulaciones.tot_cargos%type,
                                  p_tip_monto     out varchar2,
                                  p_mto_edilicio  out pr_simulaciones.mto_edilicio%type,
                                  p_tip_interes   out ba_cod_referencias.significado%type) is
     v_cod_modulo    ge_modalidades.cod_modulo%type;
     v_cod_modalidad ge_modalidades.cod_modalidad%type;
     v_redondeo      number(2);
     --
     v_fec_pri_vencimiento_ori date;
     v_especial varchar2(1);
     v_usu_hb_emp    ba_usuarios.cod_usuario%type := 'HBANKJ';
     v_usu_hb_fis    ba_usuarios.cod_usuario%type := 'HBANKF';
  begin
 
     begin
        select a.cod_modalidad, a.cod_moneda, a.cod_modulo,
        a.monto, a.val_tasa, fec_pri_vencimiento,
               a.fec_inicio, a.cotizacion, a.tot_interes, a.tot_cargos, decode(a.tip_monto, 'B', 'Bruto', 'Neto') tipo,
               a.mto_edilicio, fue_obt_des_refcodes('TIP_INTERES', nvl(a.tip_interes, 'V'))
          into v_cod_modalidad, p_cod_moneda, v_cod_modulo, p_monto, p_val_tasa, p_fec_pri_venc,
               p_fec_inicio, p_cotizacion, p_tot_interes, p_tot_cargos, p_tip_monto,
               p_mto_edilicio, p_tip_interes
          from pr_simulaciones a
         where a.nro_simulacion = p_nro_simulacion;

        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad, p_cod_moneda);
     exception
       /* when too_many_rows then
           raise_application_error(-20000, 'Existe mas de una solicitud para la persona ' || p_cod_persona);*/
        when no_data_found then
           raise_application_error(-20000, 'No existe solicitud ' || p_nro_simulacion);
     end;
     --Ajuste para digitales
      --Verificamos si es normal especial, solo para digital
  v_especial:='N';
  IF  upper(user) in (v_usu_hb_emp,v_usu_hb_fis ) then
    v_fec_pri_vencimiento_ori:= add_months(p_fec_inicio,1);
    if v_fec_pri_vencimiento_ori <> p_fec_pri_venc then
      v_especial:='S';
    end if;
  end if;
  --Si es normal logica anterior
  if  v_especial ='N' then
     begin
        select count(*), /*round(*/sum(nvl(mto_capital, 0) + nvl(mto_interes, 0)) /*/ count(*), v_redondeo)*/
          into p_plazo, p_cuota
          from pr_sim_cuotas x
         where nro_simulacion = p_nro_simulacion
           and (nvl(mto_capital, 0) > 0 or nvl(mto_interes, 0) > 0)
           and nro_cuota = 1;--> 0;
        select count(*)
          into p_plazo
          from pr_sim_cuotas x
         where nro_simulacion = p_nro_simulacion
           and (nvl(mto_capital, 0) > 0 or nvl(mto_interes, 0) > 0)
           and nro_cuota > 0;
     end;
   else
    --Tomamos de la cuota 2 los datos, la cuota 1 solo interes
     begin
        select count(*), /*round(*/sum(nvl(mto_capital, 0) + nvl(mto_interes, 0)) /*/ count(*), v_redondeo)*/
          into p_plazo, p_cuota
          from pr_sim_cuotas x
         where nro_simulacion = p_nro_simulacion
           and (nvl(mto_capital, 0) > 0 or nvl(mto_interes, 0) > 0)
           and nro_cuota = 2;--> 0;
        select count(*)
          into p_plazo
          from pr_sim_cuotas x
         where nro_simulacion = p_nro_simulacion
           and (nvl(mto_capital, 0) > 0 or nvl(mto_interes, 0) > 0)
           and nro_cuota > 0;
     end;
   end if;
     -- TODO: ver para obtener de la configuracion
     p_tas_des_com := 2;
  end;

  function fu_es_cli_nomina(p_cod_persona in ba_personas.cod_persona%type) return varchar2 is
     v_nomina        varchar2(1) := 'N';
  begin
     begin
       Select 'S'
         into v_nomina
         from ba_personas pe
        where pe.cod_persona = p_cod_persona
          and (exists (select 1
                         from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g, ge_entes e
                        where cl.nro_cuenta = ah.nro_cuenta
                          and cl.cod_persona = pe.cod_persona
                          and cl.cod_modulo = g.cod_modulo
                          and cl.cod_modalidad = g.cod_modalidad
                          and ah.estado = g.estado
                          and ah.cod_sub_modalidad <> 6
                          and g.activo = 'S'
                          and cl.relacion = 'P'
                          and ah.cod_ente = e.cod_ente
                          and e.tipo = 'SU'
                       )
           or exists (select 1
                        from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g, ge_entes e
                       where cc.nro_cuenta = cl.nro_cuenta
                         and cl.cod_persona = pe.cod_persona
                         and cl.cod_modulo = g.cod_modulo
                         and cl.cod_modalidad = g.cod_modalidad
                         and cc.estado = g.estado
                         and g.activo = 'S'
                         and cl.relacion = 'P'
                         and cc.cod_ente = e.cod_ente
                         and e.tipo = 'SU'
                     )
              );
        return v_nomina;
     exception
       when too_many_rows then
         v_nomina := 'S'; ---Indica que SI existe ente en cuentas del cliente.
       when no_data_found then
         v_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.
       when others then
         v_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.

     end;

     return v_nomina;
  end;

  function fu_es_cta_nomina(p_cod_persona    in ba_personas.cod_persona%type,
                            p_nro_cuenta     in ge_cuentas.nro_cuenta%type,
                            p_cod_modalidad  in ge_cuentas.cod_modalidad%type) return varchar2 is
     v_cta_nomina        varchar2(1) := 'N';
  begin
     if p_cod_modalidad = 31 then
        BEGIN
           Select 'S'
             into v_cta_nomina
             from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g, ge_entes e
            where cl.nro_cuenta = ah.nro_cuenta
              and cl.cod_persona = p_cod_persona
              and cl.cod_modulo = g.cod_modulo
              and cl.cod_modalidad = g.cod_modalidad
              and ah.estado = g.estado
              and ah.cod_sub_modalidad <> 6
              and g.activo = 'S'
              and cl.relacion = 'P'
              and ah.cod_ente is not null
              and ah.nro_cuenta = p_nro_cuenta
              and e.cod_ente = ah.cod_ente
              and e.tipo = 'SU';
        EXCEPTION
           WHEN too_many_rows THEN
              v_cta_nomina := 'S'; ---Indica que SI existe ente en cuentas del cliente.
           WHEN no_data_found THEN
              v_cta_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.
           WHEN others THEN
              v_cta_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.
        END;
     elsif p_cod_modalidad = 41 then
        BEGIN
           Select 'S'
             into v_cta_nomina
             from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g, ge_entes e
            where cc.nro_cuenta = cl.nro_cuenta
              and cl.cod_persona = p_cod_persona
              and cl.cod_modulo = g.cod_modulo
              and cl.cod_modalidad = g.cod_modalidad
              and cc.estado = g.estado
              and g.activo = 'S'
              and cl.relacion = 'P'
              and cc.cod_ente is not null
              and cc.nro_cuenta = p_nro_cuenta
              and e.cod_ente = cc.cod_ente
              and e.tipo = 'SU';
        EXCEPTION
           WHEN too_many_rows THEN
              v_cta_nomina := 'S'; ---Indica que SI existe ente en cuentas del cliente.
           WHEN no_data_found THEN
              v_cta_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.
           WHEN others THEN
              v_cta_nomina := 'N'; --Indica que NO existe ente en cuentas del cliente.
        END;
    end if;

    RETURN v_cta_nomina;

  end;

  function fu_obt_tas_seg_vida(p_cod_modalidad in ge_modalidades.cod_modalidad%type,
                               p_cod_moneda    in ba_monedas.cod_moneda%type default null,
                               p_monto         in ge_movimientos.monto%type default null) return number is
     v_retorno ge_tas_fechas.val_tasa%type;
     v_cod_tasa ge_tasas.cod_tasa%type;
     v_fec_actual ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
     v_cod_transaccion ge_transacciones.cod_transaccion%type := 1521;
  begin
     select a.cod_tasa
       into v_cod_tasa
       from ge_transacciones a
      where a.cod_transaccion = v_cod_transaccion
        and a.cod_modulo = 6
        and a.cod_modalidad = p_cod_modalidad;

     v_retorno := fug_obt_val_tasa(6,
                              p_cod_modalidad,
                              null, -- cod_oficina
                              null, -- p_nro_cuenta
                              p_cod_moneda,
                              p_monto,
                              null, -- p_tas_personalizada
                              v_cod_tasa,
                              v_cod_transaccion,
                              v_fec_actual);

     return v_retorno;
  exception
     when others then
       return -1;
  end;

  procedure pr_obt_sim_cargos(p_nro_simulacion   in pr_simulaciones.nro_simulacion%type,
                              p_des_mto_comision out pr_sim_cargos.monto%type,
                              p_tas_impuesto     out pr_sim_cargos.val_tasa%type) is
  begin
    -- Obtenemos el descuento por comision
    BEGIN
       SELECT c.monto
         INTO p_des_mto_comision
         FROM pr_sim_cargos c
        WHERE c.nro_simulacion = p_nro_simulacion
          AND c.cod_transaccion = 704
          AND ROWNUM=1;
    EXCEPTION
       WHEN OTHERS THEN
          NULL;
    END;

    -- Obtenemos los cargos de impuesto
    BEGIN
       SELECT c.val_tasa
         INTO p_tas_impuesto
         FROM pr_sim_cargos c
        WHERE c.nro_simulacion = p_nro_simulacion
          AND c.cod_transaccion = 709
          AND ROWNUM=1;
    EXCEPTION
       WHEN OTHERS THEN
          NULL;
    END;
  end;

  -- obtiene la tasa maxima de un plazo
  function fu_obt_tas_interes(p_cod_moneda    in ba_monedas.cod_moneda%type,
                              p_cod_modalidad in ge_pro_pre_aprobados.cod_modalidad%type,
                               p_plazo         in ge_pro_pre_aprobados.max_plazo%type,
                               p_cod_sub_modalidad in ge_pro_pre_aprobados.cod_sub_modalidad%type default null -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
                               ) return number is
     v_retorno cr_piz_plazos.tas_interes%type := null;
     -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
     v_cod_sub_modalidad pr_solicitudes.cod_sub_modalidad%type := nvl(p_cod_sub_modalidad,nvl(fug_obt_pardinamico('COD_SUB_MAD_PRE_APR',6,p_cod_modalidad),10));
     --
  begin
     SELECT MAX(a.tas_interes)
       INTO v_retorno
       FROM cr_piz_montos b, cr_piz_plazos a
      WHERE a.cod_modulo = 6
        AND a.cod_modalidad = p_cod_modalidad
        AND a.cod_moneda = p_cod_moneda
        AND b.cod_modulo = a.cod_modulo
        AND b.cod_modalidad = a.cod_modalidad
        AND b.cod_moneda = a.cod_moneda
        AND b.mto_desde = a.mto_desde
        AND a.cod_sub_modalidad = b.cod_sub_modalidad
        AND b.cod_sub_modalidad = v_cod_sub_modalidad  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
        AND p_plazo*30 BETWEEN a.plz_desde AND a.plz_hasta;
     return v_retorno;
  exception
     when others then
       return v_retorno;
  end;

  -- obtiene la tasa y descripcion de una tarjeta preaprobada
  procedure pr_obt_tar_nom_tasa(p_cod_modalidad in ge_modalidades.cod_modalidad%type,
                                p_afinidad      in out varchar2,
                                p_sub_afinidad  in varchar2,
                                p_val_tasa      out ta_cta_tarjetas.tas_int_compra%type,
                                p_nombre        out ge_modalidades.descripcion%type) is
     v_abreviatura ba_cod_referencias.abreviatura%type := p_afinidad;
  begin
     BEGIN
        SELECT DISTINCT t.tas_int_compra, m.descripcion
          INTO p_val_tasa, p_nombre
          FROM ge_modalidades m, ta_cta_tarjetas t
         WHERE m.cod_modulo = t.cod_modulo
           AND m.cod_modalidad = t.cod_modalidad
           AND t.cod_modulo = 5
           AND t.cod_modalidad = p_cod_modalidad
           AND t.tas_int_compra IS NOT NULL
           AND ROWNUM = 1;
     EXCEPTION
        WHEN OTHERS THEN
           p_val_tasa := 43;
     END;

     -- obtener val_minimo y reemplazar la afinidad
     SELECT substr(val_minimo,1,4)
       INTO p_afinidad
       FROM ba_cod_referencias
      WHERE val_maximo = p_sub_afinidad
        AND abreviatura = v_abreviatura
        AND dominio = 'EQU_AFINIDAD';

     IF p_afinidad IN ('0405', '0306') THEN
        p_nombre := p_nombre || ' SHOPPING DEL SOL';
     ELSIF p_afinidad = '2806' THEN
        p_nombre := p_nombre || ' EXPERIENCE';
     END IF;
  end;
  -- si se puede ofertar adelanto tarjeta
  function fu_obt_tar_adelanto(p_cod_persona in ba_personas.cod_persona%type,
                               p_cod_moneda  out ba_monedas.cod_moneda%type,
                               p_monto       out number) return varchar2 is
  begin
     --
     if pag_gen.fu_es_per_fisica(p_cod_persona) = 'N' THEN
        return 'N';
     end if;

     SELECT cu.cod_moneda, 1
       INTO p_cod_moneda, p_monto
       FROM ge_cta_clientes cc, ge_est_cuentas ce, ge_cuentas cu,
       ta_tarjetas t
      WHERE cc.cod_persona = p_cod_persona
        AND cc.cod_persona = t.cod_persona
        AND t.nro_cuenta = cc.nro_cuenta
        AND cc.relacion = 'P'
        AND cc.cod_modulo = 5
        AND cc.cod_modalidad not in (53,55,58,501,502,503)
        AND cu.nro_cuenta = cc.nro_cuenta
        AND ce.cod_modulo = cc.cod_modulo
        AND ce.cod_modalidad = cc.cod_modalidad
        AND ce.estado = cu.estado
        AND ce.activo = 'S'
        AND cu.estado <> 'X'
        AND t.cod_estado = 6
        AND t.vigente = 'S'
        AND ROWNUM = 1;
     RETURN 'S';
  exception
     when others then
        return 'N';
  end;

   --Funcion para obtener la cantidad de días transcurridos desde la fecha de ultima apertura de cuenta de TC hasta la fecha --
  function fu_obt_can_dia_tarjeta( p_cod_persona in ba_personas.cod_persona%type ) return number is
    v_result number;
  begin
    select nvl((pag_cal.fu_obt_fec_actual(1)-max(t.fec_apertura)),181) can_dias --para que pase 180 sino tiene cuenta de tarjetas
      into v_result
      from ta_cta_tarjetas t, ge_cta_clientes c
     where t.nro_cuenta = c.nro_cuenta
       and c.cod_persona = p_cod_persona
       and t.estado != 'C';
    return nvl(v_result,0);
  exception
    when no_data_found then
      return 181; --para que pase 180 sino tiene cuenta de tarjetas
    when others then
      return 0;
  end;

  function fu_obt_tar_can_solicitudes( p_cod_persona  in ba_personas.cod_persona%type ) return number is
    v_result number := 0;
  begin
    select count(*)
      into v_result
      from ta_solicitudes a
     where a.cod_persona = p_cod_persona
       and a.cod_estado not in('TIA','RCH','ANU');
    return v_result;
  exception
    when others then
       return v_result;
  end;

  function fu_tie_seguro(p_cod_persona in  ba_personas.cod_persona%type,
                         p_datos       out tp_datosSeguro) return number is
  v_user     ba_usuarios.cod_usuario%type := user;
  v_segmento ge_det_seguros.seg_cliente%type;--Segmento del cliente(VIP-1, Premiun-2, Nomina-3, Normal-4)
  v_fecha    ge_calendarios.fec_actual%type := pae_cnf.FU_OBT_FEC_ACTUAL(1);
  v_usu_atm   ba_usuarios.cod_usuario%type := 'ATM';  -- ATM
  v_usu_hb_emp    ba_usuarios.cod_usuario%type := 'HBANKJ';
  v_usu_hb_fis    ba_usuarios.cod_usuario%type := 'HBANKF';
  --v_texto    ge_tip_seguros.texto%type;
  cursor c_seg(p_seg_cliente number) is
    select a.cod_tipo,b.texto,b.mto_asegurado,b.mto_cuota,a.cod_ente,a.cod_canal,
           b.tex_lin1,b.tex_lin2,b.tex_lin3,b.tex_lin4,b.tex_lin5,b.tex_lin6,b.tex_lin7,b.tex_lin8
      from ge_tip_seguros a,ge_det_seguros b
     where a.cod_tipo = b.cod_tipo
       and b.seg_cliente = p_seg_cliente
       and a.activo = 'S'
       and (v_user  in (v_usu_hb_emp,v_usu_hb_fis ) and a.cod_canal in (29) or
            v_user = v_usu_atm and a.cod_canal in(28) and rownum = 1)--cambiar por ATM
       and not exists (select 1
                         from ge_cli_seguros g
                        where g.cod_persona = p_cod_persona
                          and g.cod_tip_seguro = a.cod_tipo
                          and g.cod_ente = a.cod_ente
                          and g.estado = 'V')
       and not exists (select 1
                         from ge_rch_seguros r
                        where r.cod_persona = p_cod_persona
                          and r.cod_tip_seguro = a.cod_tipo
                          and r.cod_ente = a.cod_ente
                          and (v_fecha-r.fec_rechazo) < a.can_dias)
      order by a.cod_tipo;
  begin
    if pag_pre.fu_es_cli_nomina(p_cod_persona) = 'S' then
       v_segmento := 3;--Nomina
    else
       begin
         select nvl(a.cod_seg_preferente,4)
           into v_segmento
           from ge_clientes a
          where a.cod_persona = p_cod_persona;
       exception
         when no_data_found then
           v_segmento := 4;--Normal
       end;
    end if;
    for c in c_seg(v_segmento) loop
      p_datos.codigoSeguro   := c.cod_tipo;
      p_datos.montoAsegurado := c.mto_asegurado;
      p_datos.montoCuota     := c.mto_cuota;
      p_datos.codigoEnte     := c.cod_ente;
      if c.cod_canal = 29 then
         p_datos.texto := c.texto;
      else
         p_datos.texto := rpad(c.tex_lin1,38,' ')||rpad(c.tex_lin2,38,' ')||rpad(c.tex_lin3,38,' ')||
                          rpad(c.tex_lin4,38,' ')||rpad(c.tex_lin5,38,' ')||rpad(c.tex_lin6,38,' ')||
                          rpad(c.tex_lin7,38,' ')||rpad(c.tex_lin8,36,' ');
      end if;
    end loop;
    if p_datos.texto is not null then
       return 1;
    else
       return -1;
    end if;
  exception
    when others then
      return -99;
  end;
  function fu_tie_seguro_hb(p_cod_persona in  ba_personas.cod_persona%type,
                            p_lista       out tp_lista_seguros,
                            p_codigoCanal in  VARCHAR2) return number is
  v_user     ba_usuarios.cod_usuario%type := user;
  v_planes   tp_datosSeguro;
  v_count    number := 0;
  cursor c_planes is
      SELECT c.cod_tipo, c.descripcion, c.cod_ente, e.descripcion as nombre_ente, d.secuencia, d.mto_asegurado, d.mto_cuota
      FROM ge_tip_seguros c
      INNER JOIN ge_det_seguros d on c.cod_tipo = d.cod_tipo and c.cod_canal = 29 and c.activo = 'S'
      INNER JOIN ge_entes e on c.cod_ente = e.cod_ente
      AND c.cod_tipo not in (SELECT cod_tip_seguro FROM ge_cli_seguros WHERE estado = 'V' AND cod_persona = p_cod_persona)
      ORDER BY c.cod_tipo, d.mto_asegurado desc;
  begin
    v_count := 0;
    for c in c_planes loop
      if (paw_bas.fu_ver_seg_preaprob(p_codigoCanal, c.cod_tipo)) then
        v_planes.codigoSeguro     := c.cod_tipo;
        v_planes.texto            := c.descripcion;
        v_planes.montoAsegurado   := c.mto_asegurado;
        v_planes.montoCuota       := c.mto_cuota;
        v_planes.codigoEnte       := c.cod_ente;
        v_planes.nombreEnte       := c.nombre_ente;
        p_lista(v_count)          := v_planes;
        v_count := v_count + 1;
      end if;
    end loop;
    return v_count;
  exception
    when others then
      return -99;
  end;
  --
  function fu_obt_mto_cargo(p_nro_simulacion in pr_sim_cuotas.nro_simulacion%type,
                            p_nro_cuota      in pr_sim_cuotas.nro_cuota%type) return number is
    v_monto ge_movimientos.monto%type := 0;
    v_mto_impinteres ge_movimientos.monto%type := 0;
    v_tas_interes ge_tas_fechas.val_tasa%type; 
    v_iva_desglose pr_simulaciones.iva_desglose%type default 'S';
    v_imp_interes  varchar2(1);
    v_cod_modulo   pr_simulaciones.cod_modulo%type;
    v_cod_modalidad pr_simulaciones.cod_modalidad%type; 
    v_cod_moneda pr_simulaciones.cod_moneda%type;
    v_fec_inicio pr_simulaciones.fec_inicio%type;
    v_redondeo number default 0;
    v_mto_interes number;
  begin
    begin
      select pap_pre.fu_obt_cal_mto_seg_vida(s.cod_modalidad,
                                             s.cod_modulo,
                                             s.cod_moneda,
                                             null,
                                             decode(c.sal_anterior,0,s.tot_prestamo,c.sal_anterior),
                                             fug_obt_ent_seguro(s.cod_modulo, s.cod_modalidad, 'V'),
                                             s.fec_inicio,
                                             null,
                                             'F',
                                             s.tot_prestamo)

        into v_monto
        from pr_sim_cuotas c, pr_simulaciones s, pr_sim_cargos ca
        where c.nro_simulacion = s.nro_simulacion
          and ca.nro_simulacion = s.nro_simulacion
          and ca.nro_simulacion = c.nro_simulacion
          and ca.cod_transaccion = 1521
          and s.nro_simulacion = p_nro_simulacion
          and c.nro_cuota = p_nro_cuota;
    exception
      when others then
        v_monto := 0;
    end;
    begin
      select a.iva_desglose, a.cod_modulo, a.cod_modalidad, a.cod_moneda, a.fec_inicio
        into v_iva_desglose, v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_fec_inicio
        from pr_simulaciones a
       where a.nro_simulacion = p_nro_simulacion;
    end;
    begin
      select 'S' into v_imp_interes
        from ge_sol_cargos
       where cod_modulo = v_cod_modulo
         and cod_modalidad = v_cod_modalidad
         and cod_transaccion = 709
         and cod_canal is null
         and cod_campana is null
         and (cod_tip_canal is null);
    exception when others then null;
    end;
    if nvl(v_iva_desglose,'S') = 'S' and nvl(v_imp_interes,'N') = 'S' then
      if v_cod_moneda != pag_gen.fu_obt_mon_local then
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, v_cod_modalidad, v_cod_moneda);
      end if;
      begin
        select a.mto_interes
          into v_mto_interes
          from pr_sim_cuotas a
         where a.nro_simulacion = p_nro_simulacion
           and a.nro_cuota = p_nro_cuota + 1;
      end;
      v_tas_interes := fug_obt_val_tasa(v_cod_modulo,
 				  															v_cod_modalidad,
                                        null, -- cod_oficina
                                        null, -- nro_cuenta
                                        v_cod_moneda,
                                        null, -- mto_transaccion
                                        null, -- tas_personalizada
                                        null, -- cod_tasa
                                        709,
                                        v_fec_inicio);
      v_mto_impinteres := round(v_mto_interes * v_tas_interes / 100, v_redondeo);
    end if;
    return nvl(v_monto,0) + nvl(v_mto_impinteres,0);
  exception
    when others then
       return 0;
  end;
end PAG_PRE;
/

