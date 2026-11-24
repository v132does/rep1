create or replace procedure it.prp_gen_sol_pre_apr_che_rog(p_cod_persona         in ba_personas.cod_persona%type,
                                                           p_mto_solicitado      in number,
                                                           p_can_cuotas          in number,
                                                           p_fec_pri_vencimiento in date,
                                                           p_cod_canal           in number default null,
                                                           p_cod_moneda          in varchar2 default 'GS',
                                                           p_cod_modalidad       in number,
                                                           p_cod_submodalidad    in number,
                                                           p_grabar              in varchar2 default 'S', -- definir si grabara o no los datos en las tablas
                                                           p_mto_consolidado     in number,
                                                           p_clave               in number,
                                                           p_solicitud           in out pr_solicitudes.nro_solicitud%type,
                                                           p_cuotas              out pr_sol_cuotas.mto_capital%type,
                                                           p_cod_error           out number,
                                                           p_msj_error           out varchar2,
                                                           p_cuotas_apx          out pr_sol_cuotas.mto_capital%type) is
  g_lugar     varchar2(250);
  g_msj_error varchar2(4000);
  g_cod_error number(3) default 0;
  --nuevas variables requeridas para pre-aprobado
  v_tip_persona       varchar2(1);
  v_tip_monto         varchar2(1) := 'N';
  v_cod_rub_economico pr_solicitudes.cod_rub_economico%type := fug_obt_pardinamico('COD_RUB_CHE_ROGA');
  v_cod_mod_default   ge_modalidades.cod_modalidad%type := nvl(p_cod_modalidad,668);--fug_obt_pardinamico('COD_MOD_CHE_ROGA');
  v_ori_fondo         number := 1;
  v_cod_banca         number; -- código de banca del cliente
  v_tip_destino       varchar2(1); -- destino del crédito
  v_cod_campana       number; -- código de campaña
  v_cod_usu_promotor  varchar2(10);
  v_cod_usu_oficial   varchar2(10);
  v_cod_departamento  number(3) := null; -- se obtiene de los datos del cliente o en su defecto de la oficina
  v_cod_dep_parametro number(3) := 18; -- departamento de parámetros
  v_tip_documento     number(1) := 1;
  v_cod_sec_credito   number(3) := 702;
  v_per_gracia        number(8);
  v_per_vencimiento   number(4) := 30;
  v_descripcion       varchar2(500) := 'PRESTAMO CHE ROGA PORA'; -- descripción de la operación
  v_nro_cuenta        varchar2(15);
  v_cantidad          number(3);
  v_cod_garantia      pr_gar_tipos.cod_garantia%type;
  --variables del procedimiento
  v_dummy               number(9);
  v_cod_modulo          number(3) := 6;
  v_fec_actual          date := pag_cal.fu_obt_fec_actual(v_cod_modulo);
  v_cod_oficina         number(3) := fug_obt_ofi_usuario(user);
  v_mon_local           varchar2(3) := pag_gen.fu_obt_mon_local;
  v_cotizacion          ge_cotizaciones.val_conversion%type := pag_gen.fu_obt_cotizacion(nvl(pag_gen.fu_obt_mon_local,
                                                                                             pag_gen.fu_obt_mon_local));
  v_lugar               varchar2(200) := null;
  v_exo_impuestos       varchar2(1) := 'N';
  v_tot_prestamo        number(18, 2) := 0; -- total del prestamo
  v_mto_interes         number(18, 2) := 0; -- total de interes
  v_mto_cargo           number(18, 2) := 0;
  v_fec_inicio          date := v_fec_actual;
  v_fec_pri_vencimiento date := nvl(p_fec_pri_vencimiento,
                                    add_months(v_fec_inicio, 1));
  v_fec_vencimiento     date := add_months(v_fec_pri_vencimiento,
                                           p_can_cuotas - 1);
  v_tip_amortizacion    varchar2(1) := 'P';
  v_val_tasa            number;
  v_dia_plazo           number(8);
  v_per_capital         pr_solicitudes.per_vto_capital%type;
  v_nro_solicitud       number(10);
  v_por_ajuste          number;
  v_ttvalor             number(18, 2);
  --datos de los cargos
  v_cod_transaccion number(4);
  v_cod_tas_cargo   number(4);
  v_val_tas_cargo   number;
  v_cod_mon_cargo   varchar2(3);
  v_tpvlpor         varchar2(1);
  v_aplicar         varchar2(3);
  v_tpdetas         varchar2(1);
  v_val_cargo       number(18, 2);
  v_cod_ent_seguro  number(6);
  v_imp_cargo       number(18, 2);
  --variables para calculo de seguro
  v_tas_seguro     number(18, 4);
  v_mto_tot_seguro number(18, 4);
  --control del redondeo
  v_redondeo             number(2) := 0;
  v_can_dia_pri_vcto     number;
  v_can_dia_min_pri_vcto number;
  v_mto_aumento          number;
  v_recalculo            varchar2(1) := 'N';
  v_tae                  number;
  v_tan                  number;
  v_tas_efectiva         cr_piz_plazos.tas_efectiva%type;
  v_mto_adm_anterior     number;
  v_act_gas_anterior     varchar2(1) := 'N';
  v_fin_max              varchar2(1) := 'N';
  v_existe_tc            varchar2(1);
  v_tie_invitado varchar2(1) := 'N';

  --v_cod_per_invi pr_pre_che_roga.cod_per_invitado%type;
  v_rec_tae      varchar2(1) := 'N'; --variable para saber si se esta recalculando gasto_adm y llevando el tae al tope
  --variables de maximización tasa DA-7311 carolinav. 04.12.2022
  v_valor_tasa   pr_sol_tasas.val_tasa%type;
  v_fec_vigencia ge_tas_fechas.fec_vigencia%type;
  v_codi_tasa    ge_tasas.cod_tasa%type;
  v_tipo_valor   ge_tasas.tip_valor%type;
  v_tipo         ge_tasas.tipo%type;
  v_max_tasa     varchar2(1) := 'N';
  v_max_cargos   varchar2(1) := 'N';
  v_tasa_back    pr_sol_tasas.val_tasa%type;
  v_valor_aum    pr_sol_tasas.val_tasa%type;
  v_bandera      varchar2(1);
  v_tas_interes  cr_piz_plazos.tas_interes%type;
  v_tas_minima   cr_piz_plazos.tas_minima%type;
  v_tas_maxima   cr_piz_plazos.tas_maxima%type;
  v_cod_sub_modalidad  pr_solicitudes.cod_sub_modalidad%type;
  -- rutinas internas del procedimiento
  cursor sol_destino(p_nro_cuenta varchar2) is
    select sd.tip_des_especifico, sd.monto
      from pr_sol_destinos sd, pr_cta_prestamos cp
     where cp.nro_solicitud = sd.nro_solicitud
       and cp.nro_cuenta = p_nro_cuenta;
  cursor sol_garantia(p_nro_cuenta varchar2) is
    select nro_garantia, cod_garantia
      from pr_sol_garantias g, pr_cta_prestamos p
     where g.nro_solicitud = p.nro_solicitud
       and p.nro_cuenta = p_nro_cuenta;
  -- rutinas internas del procedimiento
  procedure pr_val_tasa is
    cursor pizarras is
      select a.tas_interes, a.tas_minima, a.tas_maxima, a.tas_efectiva
        from cr_piz_montos b, cr_piz_plazos a
       where a.cod_modulo = v_cod_modulo
         and a.cod_modalidad = nvl(p_cod_modalidad, v_cod_mod_default)
         and a.cod_moneda =
             nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local)
         and b.cod_modulo = a.cod_modulo
         and b.cod_modalidad = a.cod_modalidad
         and b.cod_sub_modalidad = v_cod_sub_modalidad
         and b.cod_moneda = a.cod_moneda
         and b.mto_desde = a.mto_desde
         and p_mto_solicitado between b.mto_desde and b.mto_hasta
         and v_dia_plazo between a.plz_desde and a.plz_hasta;
  begin
    v_lugar := 'OBTENER TASAS DE PIZARRAS';
    open pizarras;
    fetch pizarras
      into v_tas_interes, v_tas_minima, v_tas_maxima, v_tas_efectiva;
    close pizarras;
    if v_val_tasa is null then
      v_val_tasa := nvl(v_tas_interes, 32);
    else
      -- valido la tasa ingresada
      if not v_val_tasa between v_tas_minima and v_tas_maxima then
        g_cod_error := '009';
        g_lugar     := 'Valida Tasa ingresada';
        g_msj_error := 'Tasa fuera de Rango. Verifique la Pizarra';
      end if;
    end if;
  end;
  procedure pr_val_cod_persona is
  begin
    v_lugar := 'OBTENER_CLIENTE ';
    select exo_impuestos,
           cod_usu_oficial,
           cod_usu_promotor,
           cod_oficina,
           cod_departamento
      into v_exo_impuestos,
           v_cod_usu_oficial,
           v_cod_usu_promotor,
           v_cod_oficina,
           v_cod_departamento
      from ba_personas b, ge_clientes g
     where b.cod_persona = g.cod_persona
       and g.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      begin
        select gen.cod_ofi_matriz, 'N', ciu.cod_departamento
          into v_cod_oficina, v_exo_impuestos, v_cod_departamento
          from ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
         where gen.cod_ofi_matriz = ofi.cod_oficina
           and ofi.cod_ciudad = ciu.cod_ciudad
           and ofi.cod_pais = ciu.cod_pais;
      end;
    when others then
      raise_application_error(-20000, 'fu_val_cod_persona ' || sqlerrm);
  end;
  -- validacion del tipo de credito
  procedure pr_val_cod_modalidad is
  begin
    select 0
      into v_dummy
      from ge_modalidades
     where cod_modulo = v_cod_modulo
       and cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default);
  exception
    when no_data_found then
      g_cod_error := '001';
      g_lugar     := 'Valida Modalidad';
      g_msj_error := 'Tipo de Prestamo no habilitado';
    when others then
      g_cod_error := '002';
      g_lugar     := 'Valida Modalidad';
      g_msj_error := 'Error al validar Modalidad ' || sqlerrm;
  end;
  -- validacion del codigo de la moneda
  procedure pr_val_cod_moneda is
  begin
    select 0
      into v_dummy
      from ba_monedas
     where cod_moneda =
           nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local);
  exception
    when no_data_found then
      g_cod_error := '003';
      g_lugar     := 'Valida Moneda';
      g_msj_error := 'Codigo de Moneda inexistente';
    when others then
      g_cod_error := '004';
      g_lugar     := 'Valida Moneda';
      g_msj_error := 'Error al validar moneda ' || sqlerrm;
  end;
  procedure pp_val_dias_gracia is
    v_can_meses number := 0;
  begin
    if p_fec_pri_vencimiento is not null then
      v_can_meses := trunc(months_between(p_fec_pri_vencimiento,
                                          v_fec_actual));
      if v_can_meses <
         nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.fu_obt_mon_local,
                                     pag_gen.fu_obt_mon_local)),
             0) then
        g_cod_error := 8;
        g_lugar     := 'Valida Dias de Gracia';
        g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                       ' no debe ser menor a ' ||
                       nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MIN',
                                               v_cod_modulo,
                                               nvl(v_cod_mod_default,
                                                   v_cod_mod_default),
                                               nvl(pag_gen.fu_obt_mon_local,
                                                   pag_gen.fu_obt_mon_local)),
                           0);
      end if;
      if nvl(pap_sim.g_cod_error, '000') = '000' and
         v_can_meses >
         nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.fu_obt_mon_local,
                                     pag_gen.fu_obt_mon_local)),
             0) then
        g_cod_error := 8;
        g_lugar     := 'Valida Dias de Gracia';
        g_msj_error := 'Periodo de gracia ' || v_can_meses ||
                       ' no debe ser mayor a ' ||
                       nvl(fug_obt_pardinamico('PRE_PER_GRACIA_MAX',
                                               v_cod_modulo,
                                               nvl(v_cod_mod_default,
                                                   v_cod_mod_default),
                                               nvl(pag_gen.fu_obt_mon_local,
                                                   pag_gen.fu_obt_mon_local)),
                           0);
      end if;
    end if;
  end;
  -- procedimiento para obtener el tipo de tasa 
  procedure pr_obt_tipo_de_tasa(ww_cdtrans in number,
                                ww_cddetas in out number,
                                ww_aplicar in out varchar2,
                                ww_tpvlpor in out varchar2,
                                ww_tpdetas in out varchar2,
                                ww_afecta  in out varchar2) is
    v_cuo_ano number;--pr_pre_che_roga.can_cuotas%type;
    v_equipo  varchar2(50);--pr_pre_che_roga.equipamiento%type;
  begin
    v_lugar := 'OBTENER TIPO DE TASA ';
    --- 1. busco la tasa asociada a la transaccion ingresada 
    if ww_cdtrans = 701 then
      if ww_cddetas is null then
        begin
          select nvl(ce.can_cuotas, 0), trim(upper(ce.equipamiento))
            into v_cuo_ano, v_equipo
            from pr_pre_che_roga ce
           where ce.cod_per_solicitante = p_cod_persona
             and ce.estado in ('V','I') -- Puede continuar en la app, si no esta en V-I dara error 'No existe Valor para la Tasa'
             and ce.nro_solicitud is null;
        exception
          when others then
            v_cuo_ano := null;
            v_equipo  := null;
        end;
        --Asigna tasa por tipo de equipamiento y cantidad de años
        if (v_cuo_ano / 12) = 20 and v_equipo = 'SIN EQUIPAMIENTO' then
          ww_cddetas := 365;
        elsif (v_cuo_ano / 12) = 20 and v_equipo = 'SEMI-EQUIPADO' then
          ww_cddetas := 366;
        elsif (v_cuo_ano / 12) = 20 and v_equipo = 'FULL EQUIPADO' then
          ww_cddetas := 367;
        elsif (v_cuo_ano / 12) = 30 and v_equipo = 'SIN EQUIPAMIENTO' then
          ww_cddetas := 368;
        elsif (v_cuo_ano / 12) = 30 and v_equipo = 'SEMI-EQUIPADO' then
          ww_cddetas := 369;
        elsif (v_cuo_ano / 12) = 30 and v_equipo = 'FULL EQUIPADO' then
          ww_cddetas := 370;
        else
          ww_cddetas := 365;
        end if;
        select ta.aplicar, ta.tip_valor, ta.tipo, tr.afecta
          into ww_aplicar, ww_tpvlpor, ww_tpdetas, ww_afecta
          from ge_transacciones tr, ge_tasas ta
         where tr.cod_modulo = v_cod_modulo
           and tr.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
           and tr.cod_transaccion = ww_cdtrans
           and tr.tipo = 'D'
           and tr.cod_tasa is not null
           and tr.cod_tasa = ta.cod_tasa
           and exists
         (select 0
                  from ge_transacciones_det
                 where cod_modulo = v_cod_modulo
                   and cod_modalidad =
                       nvl(v_cod_mod_default, v_cod_mod_default)
                   and cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                   and cod_mod_hijo = tr.cod_modulo
                   and cod_mad_hijo = tr.cod_modalidad
                   and cod_tra_hijo = tr.cod_transaccion);
      else
        select ta.aplicar, ta.tip_valor, ta.tipo
          into ww_aplicar, ww_tpvlpor, ww_tpdetas
          from ge_tasas ta
         where ta.cod_tasa is not null
           and ta.cod_tasa = ww_cddetas;
      end if;
    else
      if ww_cddetas is null then
        select tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo, tr.afecta
          into ww_cddetas, ww_aplicar, ww_tpvlpor, ww_tpdetas, ww_afecta
          from ge_transacciones tr, ge_tasas ta
         where tr.cod_modulo = v_cod_modulo
           and tr.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
           and tr.cod_transaccion = ww_cdtrans
           and tr.tipo = 'D'
           and tr.cod_tasa is not null
           and tr.cod_tasa = ta.cod_tasa
           and exists
         (select 0
                  from ge_transacciones_det
                 where cod_modulo = v_cod_modulo
                   and cod_modalidad =
                       nvl(v_cod_mod_default, v_cod_mod_default)
                   and cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                   and cod_mod_hijo = tr.cod_modulo
                   and cod_mad_hijo = tr.cod_modalidad
                   and cod_tra_hijo = tr.cod_transaccion);
      else
        select ta.aplicar, ta.tip_valor, ta.tipo
          into ww_aplicar, ww_tpvlpor, ww_tpdetas
          from ge_tasas ta
         where ta.cod_tasa is not null
           and ta.cod_tasa = ww_cddetas;
      end if;
    end if;
  exception
    when no_data_found then
      g_cod_error := '010';
      g_lugar     := 'Valida Cargo definido';
      g_msj_error := 'Cargo no definido para Prestamos';
    when others then
      g_cod_error := '011';
      g_lugar     := 'Valida Cargo definido';
      g_msj_error := 'Error al obtener tipo de tasa ' || sqlerrm;
  end;
  -- funcion que obtiene el valor de la tasa fija
  function fu_obt_valor_de_tasa_fija(ww_cddetas in number,
                                     ww_fcinici in date) return number is
    ww_vldetas ge_tas_fechas.val_tasa%type;
  begin
    v_lugar := 'OBTENER VALOR DE TASA FIJA ';
  -- tasa fija, buscar en tasa por fecha
    select val_tasa
      into ww_vldetas
      from ge_tas_fechas f1
     where f1.cod_tasa = ww_cddetas
       and (f1.cod_modalidad is null or
           (f1.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)))
       and (f1.cod_modulo is null or (f1.cod_modulo = v_cod_modulo))
       and (f1.cod_moneda is null or
           (f1.cod_moneda =
           nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local)))
       and (f1.cod_oficina is null or (f1.cod_oficina = v_cod_oficina))
       and f1.nro_cuenta is null
       and f1.fec_vigencia =
           (select max(fec_vigencia)
              from ge_tas_fechas f2
             where f1.cod_tasa = f2.cod_tasa
               and (f2.cod_modalidad is null or
                   (f2.cod_modalidad =
                   nvl(v_cod_mod_default, v_cod_mod_default)))
               and (f2.cod_modulo is null or (f2.cod_modulo = v_cod_modulo))
               and (f2.cod_moneda is null or
                   (f2.cod_moneda =
                   nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local)))
               and (f2.cod_oficina is null or
                   (f2.cod_oficina = v_cod_oficina))
               and f2.fec_vigencia <= ww_fcinici
               and f2.nro_cuenta is null);
    return ww_vldetas;
  exception
    when no_data_found then
   
      return null;
    when others then
    
      return null;
      g_cod_error := '012';
      g_lugar     := 'Valida Tasa Fija';
      g_msj_error := 'Error al obtener la tasa_fija ' || sqlerrm;
     
  end;
  -- funcion que devuelve el valor de la tasa, si es variable
  function fu_obt_valor_de_tasa_variable(ww_cddetas in number,
                                         ww_vlmonto in number,
                                         ww_fcinici in date) return number is
    ww_vldetas number(15, 4);
    cursor tv is
      select tr.val_tasa
        from ge_tasas t, ge_tas_rangos tr
       where t.cod_tasa = tr.cod_tasa
         and t.cod_tasa = ww_cddetas
         and (tr.cod_modulo = v_cod_modulo or tr.cod_modulo is null)
         and (tr.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default) or
             tr.cod_modalidad is null)
         and (tr.cod_moneda =
             nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local) or
             tr.cod_moneda is null)
         and (tr.cod_oficina = v_cod_oficina or tr.cod_oficina is null)
         and tr.val_hasta >= ww_vlmonto
         and tr.nro_cuenta is null
         and tr.fec_vigencia =
             (select max(tra.fec_vigencia)
                from ge_tas_rangos tra
               where tra.cod_tasa = ww_cddetas
                 and (tra.cod_modulo = v_cod_modulo or
                     tra.cod_modulo is null)
                 and (tra.cod_modalidad =
                     nvl(v_cod_mod_default, v_cod_mod_default) or
                     tra.cod_modalidad is null)
                 and (tra.cod_moneda =
                     nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local) or
                     tra.cod_moneda is null)
                 and (tra.cod_oficina = v_cod_oficina or
                     tra.cod_oficina is null)
                 and tra.val_hasta >= ww_vlmonto
                 and tra.nro_cuenta is null
                 and tra.fec_vigencia <= ww_fcinici)
       order by val_hasta;
  begin
    v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
    -- tasa variable, buscar en tabla de tasas variables
    open tv;
    fetch tv
      into ww_vldetas;
    close tv;
    if ww_vldetas is null then
      g_cod_error := '013';
      g_lugar     := 'Valida Tasa Variable';
      g_msj_error := 'No existe Valor para la Tasa ' || to_char(ww_cddetas) ||
                     ' y el Monto ' || to_char(ww_vlmonto) || ' Fecha ' ||
                     to_char(ww_fcinici, 'DD/MM/YYYY');
    end if;
    return ww_vldetas;
  exception
    when no_data_found then
     
      return null;
    when others then
      return null;
      g_cod_error := '005';
      g_lugar     := 'Valida Cantidad Cuotas';
      g_msj_error := 'Ingrese la cantidad de cuotas';
       
  end;
  -- verificacion del codigo de tasa
  procedure pr_obt_datos_cargo(p_cod_seguro in varchar2) is
    v_cod_tasa        number(15);
    v_des_transaccion varchar2(35);
    v_obligatorio     varchar2(2);
    v_afecta          varchar2(5);
  begin
    if v_cod_transaccion in (737, 1271) and v_tip_persona = 'J' and
       nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                               v_cod_modulo,
                               nvl(v_cod_mod_default, v_cod_mod_default),
                               nvl(pag_gen.fu_obt_mon_local,
                                   pag_gen.fu_obt_mon_local)),
           'N') = 'S' then
      -- traer valor de la tasa del seguro
      v_cod_tasa := fug_obt_parentes(p_cod_seguro, 'COD_TAS_JURIDICA');
      if v_cod_tasa is not null then
        select initcap(tr.descripcion),
               ta.cod_tasa,
               ta.aplicar,
               ta.tip_valor,
               ta.tipo,
               dt.obligatorio,
               tr.afecta
          into v_des_transaccion,
               v_cod_tas_cargo,
               v_aplicar,
               v_tpvlpor,
               v_tpdetas,
               v_obligatorio,
               v_afecta
          from ge_transacciones_det dt, ge_transacciones tr, ge_tasas ta
         where tr.cod_modulo = v_cod_modulo
           and tr.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
           and tr.cod_transaccion = v_cod_transaccion
           and tr.tipo = 'D'
           and v_cod_tasa = ta.cod_tasa
           and dt.cod_modulo = v_cod_modulo
           and dt.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
           and dt.cod_transaccion = 358 /* transaccion de desembolso de prestamos */
           and dt.cod_mod_hijo = tr.cod_modulo
           and dt.cod_mad_hijo = tr.cod_modalidad
           and dt.cod_tra_hijo = tr.cod_transaccion;
      else
        g_cod_error := '030';
        g_lugar     := 'Busca datos tasa Per.Juridica';
        g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' ||
                       sqlerrm;
      end if;
    else
      if nvl(g_cod_error, '000') = '000' then
        -- obtengo los datos de la tasa
        pr_obt_tipo_de_tasa(v_cod_transaccion,
                            v_cod_tas_cargo,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas,
                            v_afecta);
      end if;
    end if;
    --- la tasa es de tipo  valor 
    if v_tpdetas = 'F' then
      --- tipo de tasa fijo      
      v_val_tas_cargo := fu_obt_valor_de_tasa_fija(v_cod_tas_cargo,
                                                   v_fec_inicio);
    else
      --- tipo de tasa variable  
      if v_aplicar in ('PI', 'PC', 'PT', 'PL', 'CP', 'IP', 'TP') then
        if v_aplicar in ('PI', 'PC', 'PT', 'PL') then
          -- el primer rango es por plazo
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           v_dia_plazo,
                                                           v_fec_inicio);
        else
          -- tipo de tasa variable  
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_mto_solicitado),
                                                           v_fec_inicio);
        end if;
        if v_aplicar in ('CP', 'IP', 'TP') then
          -- aplicar al capital y plazo, busco ahora el valor por plazo
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                           v_dia_plazo,
                                                           v_fec_inicio);
        end if;
      else
        if v_tpvlpor = 'V' then
          if v_cod_transaccion <> 701 then
            v_imp_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                         nvl(v_tot_prestamo,
                                                             p_mto_solicitado),
                                                         v_fec_inicio);
            v_val_tas_cargo := v_imp_cargo +
                               round(v_imp_cargo * 10 / 100, v_redondeo);
          else
            v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                             nvl(v_tot_prestamo,
                                                                 p_mto_solicitado),
                                                             v_fec_inicio);
          end if;
        else
          v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                           nvl(v_tot_prestamo,
                                                               p_mto_solicitado),
                                                           v_fec_inicio);
        end if;
      end if;
    end if;
    if v_tpvlpor in ('I', 'P', 'F') or
       v_cod_transaccion in (735, 736, 1270, 2) then
      -- porcentajes  o transacciones de seguros
      if v_tpvlpor = 'I' then
        v_cod_mon_cargo := v_mon_local;
      else
        v_cod_mon_cargo := nvl(pag_gen.fu_obt_mon_local,
                               pag_gen.fu_obt_mon_local);
      end if;
    else
      -- en caso de que sean valores 
      v_cod_mon_cargo := nvl(pag_gen.fu_obt_mon_local,
                             pag_gen.fu_obt_mon_local);
      v_val_cargo     := v_val_tas_cargo;
      v_val_tas_cargo := null;
    end if;
  end;
  -- carga de cargos de la propuesta
  procedure pr_gen_cargos(p_recalculo varchar2 default 'N') is
    cursor cargos is
      select distinct decode(a.cod_transaccion,
						 709,
						 1,
						 710,
						 2,
						 a.cod_transaccion) orden, -- solo para ordenamiento
				  a.cod_transaccion,
				  a.cod_ent_seguro,
				  nvl(b.obligatorio, 'N') obligator
	from ge_sol_cargos a, ge_transacciones_det b
   where a.cod_transaccion = b.cod_tra_hijo(+)
	 and a.cod_modulo = b.cod_mod_hijo(+)
	 and a.cod_modalidad = b.cod_mad_hijo(+)
	 and a.cod_modulo = v_cod_modulo
	 and a.cod_modalidad = nvl(v_cod_mod_default, v_cod_mod_default)
	 and ((nvl(v_exo_impuestos, 'N') = 'N') or
		 (nvl(v_exo_impuestos, 'N') = 'S' and
		 nvl(b.obligatorio, 'N') = 'N'))
	 and (((nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
									v_cod_modulo,
									nvl(v_cod_mod_default,
										v_cod_mod_default),
									nvl(pag_gen.fu_obt_mon_local,
										pag_gen.fu_obt_mon_local)),
				'N') = 'S' and
		 (cod_ent_seguro is not null and v_tip_persona != 'F' and
		 cod_ent_seguro = nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',
													  v_cod_modulo,
													  nvl(v_cod_mod_default,
														  v_cod_mod_default),
													  null),
								  '99999')) or
		 (nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
								  v_cod_modulo,
								  nvl(v_cod_mod_default,
									  v_cod_mod_default),
								  nvl(pag_gen.fu_obt_mon_local,
									  pag_gen.fu_obt_mon_local)),
			 'N') = 'N' and
		 cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',
													   v_cod_modulo,
													   nvl(v_cod_mod_default,
														   v_cod_mod_default),
													   null),
								  '9999'))) or
		 (v_tip_persona = 'F' and
		 cod_ent_seguro <> nvl(fug_obt_pardinamico('PRE_COD_ENT_PER_JURIDICAS',
													  v_cod_modulo,
													  nvl(v_cod_mod_default,
														  v_cod_mod_default),
													  null),
								  '99999')) or cod_ent_seguro is null) or
		 nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
								  v_cod_modulo,
								  nvl(v_cod_mod_default,
									  v_cod_mod_default),
								  nvl(pag_gen.fu_obt_mon_local,
									  pag_gen.fu_obt_mon_local)),
			 'N') = 'N')
	 and not (
		   a.cod_transaccion = 703
	   and nvl(fug_obt_pardinamico('CHEROGA_FOGA_SUB_EXC',
								   v_cod_modulo,
								   v_cod_mod_default,
								   null,
								   null,
								   v_cod_sub_modalidad), 'S') = 'N'
	 )
   order by 1;
  begin
    if p_recalculo = 'N' then
      --add da-7311 maximización de tasas - carolinav. 04.12.2022
      delete from pr_sol_cargos where nro_solicitud = v_nro_solicitud;
      --------------------------------------------------------
      for cc in cargos loop
        v_cod_transaccion := cc.cod_transaccion;
        v_cod_ent_seguro  := cc.cod_ent_seguro;
        v_val_tas_cargo   := null;
        v_val_cargo       := null;
        v_cod_tas_cargo   := null;
        v_cod_mon_cargo   := null;
        pr_obt_datos_cargo(cc.cod_ent_seguro);
        if cc.obligator = 'S' or nvl(v_val_cargo, 0) != 0 or
           nvl(v_val_tas_cargo, 0) != 0 then
          if cc.cod_transaccion in (737, 1271) then
            --calculo de seguro total simulando
            v_tas_seguro := v_val_tas_cargo;
          end if;
          begin
            if nvl(p_mto_consolidado, 0) = 0 and
               v_cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           nvl(v_cod_mod_default,
                                                               v_cod_mod_default),
                                                           nvl(pag_gen.fu_obt_mon_local,
                                                               pag_gen.fu_obt_mon_local),
                                                           null),
                                       0) then
              null;
            else
              insert into pr_sol_cargos
                (nro_solicitud,
                 cod_transaccion,
                 fec_tasa,
                 val_tasa,
                 monto,
                 cod_tasa,
                 cod_ent_seguro,
                 cod_moneda,
                 mto_mon_prestamo)
              values
                (v_nro_solicitud,
                 v_cod_transaccion,
                 v_fec_inicio,
                 v_val_tas_cargo,
                 v_val_cargo,
                 v_cod_tas_cargo,
                 cc.cod_ent_seguro,
                 v_cod_mon_cargo,
                 0);
            end if;
          exception
            when others then
              g_cod_error := '020';
              g_lugar     := 'Inserta Cargos';
              g_msj_error := 'Error al insertar los cargos. ' || sqlerrm;
          end;
        end if;
      end loop;
    else
      begin
        update pr_sol_cargos a
           set a.monto            = a.monto + v_mto_aumento,
               a.mto_mon_prestamo = a.mto_mon_prestamo + v_mto_aumento
         where a.nro_solicitud = v_nro_solicitud
           and a.cod_transaccion = 704;
      end;
    end if;
  end;
  -- generacion de cuotas 
  procedure pr_gen_cuotas(ww_neto in varchar2) is
    ww_frances         number;
    ww_tasadiv         number := v_val_tasa / 36500;
    ww_vlsalan         number(18, 2) := v_tot_prestamo;
    ww_ttcuota         number(18, 2) := null;
    ww_dfcuota         number(18, 2);
    ww_ttcapit         number(18, 2) := 0;
    ww_ttrefue         number(18, 2) := 0;
    ww_refreal         number(18, 2) := 0;
    ww_ctrefue         number(6) := 0;
    ww_nro             number(6) := 0;
    ww_veces           number(3) := 0;
    v_val_int_original number(18, 2) := 0;
    --
    v_fec_vto_habil     date;
    v_fec_vto_exacto    date;
    v_fec_vto_habil_ant date;
    v_fec_vcto          date;
    v_sal_cap_anterior  number(18, 2);
    v_dia_interes       number(6);
    v_val_interes       number(18, 2);
    v_ttcuota           number(18, 2);
    v_dia_periodo       number(8);
    v_mto_capital       number(18, 2);
    v_ven_fijo          varchar2(1) := 'S';
    v_per_interes       number := 30;
    v_val_cuota         number;
    ww_redondeo         number(2) := 0; -- redondeo a cero para moneda local
    ww_limite           number := 10; -- limite superior para ajustes de cuotas iguales en moneda local
    v_dias              number;
    v_fec_ven_anterior  date;
    v_mto_seguro        number(18, 2) := 0;
  begin
    -- veo el tipo de redondeo de los calculos 
    ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                       v_cod_modulo,
                                       nvl(v_cod_mod_default,
                                           v_cod_mod_default),
                                       nvl(pag_gen.fu_obt_mon_local,
                                           pag_gen.fu_obt_mon_local),
                                       v_cod_oficina);
    if ww_redondeo != 0 then
      ww_limite := 0.05;
    else
      ww_limite := 1;
    end if;
    if v_ven_fijo is null then
      v_ven_fijo := 'S';
    end if;
    ---
    if v_per_interes = 30 and v_ven_fijo = 'S' then
      v_dias := 30.416666666666666666666666666667;
    else
      v_dias := v_per_interes;
    end if;
    loop
      v_fec_ven_anterior := v_fec_inicio;
      ww_veces           := nvl(ww_veces, 0) + 1;
      -- calculo del valor del metodo frances
      if (power((1 + (ww_tasadiv * v_dias)), (p_can_cuotas - ww_ctrefue)) - 1) > 0 then
        ww_frances := round(((nvl(v_tot_prestamo, 0) - nvl(ww_ctrefue, 0)) *
                            ww_tasadiv * v_dias) /
                            (power((1 + (ww_tasadiv * v_dias)),
                                   (p_can_cuotas - ww_ctrefue)) - 1),
                            ww_redondeo);
      else
        --- para los casos en que la tasa = 0 para que no de division por cero.
        ww_frances := ((nvl(v_tot_prestamo, 0) - nvl(ww_ttrefue, 0))) /
                      ((p_can_cuotas - ww_ctrefue));
      end if;
      v_val_cuota := round((ww_frances *
                           power((1 + (ww_tasadiv * v_dias)), (0))),
                           ww_redondeo) +
                     round((ww_vlsalan * ww_tasadiv * (v_dias)),
                           ww_redondeo);
      if v_per_interes = 30 and (v_ven_fijo = 'S' or ww_ctrefue > 0) then
        v_val_cuota := fup_obt_val_cuota(nvl(v_cod_mod_default,
                                             v_cod_mod_default),
                                         nvl(pag_gen.fu_obt_mon_local,
                                             pag_gen.fu_obt_mon_local),
                                         v_tot_prestamo - nvl(ww_ttrefue, 0),
                                         p_can_cuotas - nvl(ww_ctrefue, 0),
                                         v_val_tasa,
                                         v_fec_inicio,
                                         p_fec_pri_vencimiento);
      end if;
      --- veo el monto fijo de cuota si es de tipo prestamos flexibles -----
      ----------------------------------------------------------------------
      v_mto_interes    := 0;
      ww_vlsalan       := v_tot_prestamo;
      ww_ttcapit       := 0;
      ww_refreal       := 0;
      v_mto_tot_seguro := 0;
      ww_nro           := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
      -- borro las cuotas si existen
      delete from pr_sol_cuotas where nro_solicitud = v_nro_solicitud;
      for cuota in 1 .. p_can_cuotas loop
        if cuota = 1 then
          v_fec_vto_habil  := p_fec_pri_vencimiento;
          v_fec_vto_exacto := p_fec_pri_vencimiento;
        else
          if v_per_interes / 30 = trunc(v_per_interes / 30) then
            -- sumo 1 mes...
            if v_ven_fijo = 'S' then
              v_fec_vcto := add_months(p_fec_pri_vencimiento,
                                       (cuota - 1) *
                                       trunc(v_per_interes / 30));
            else
              v_fec_vcto := p_fec_pri_vencimiento +
                            (((cuota - 1) * v_per_interes));
            end if;
            v_fec_vto_habil_ant := v_fec_vcto;
            v_fec_vto_habil     := v_fec_vcto;
          else
            v_fec_vto_habil := p_fec_pri_vencimiento +
                               (((cuota - 1) * v_per_interes));
          end if;
          v_fec_vto_exacto := p_fec_pri_vencimiento +
                              (((cuota - 1) * v_per_interes));
        end if;
        v_dias             := v_fec_vto_habil - v_fec_ven_anterior;
        v_sal_cap_anterior := ww_vlsalan;
        v_dia_periodo      := v_dias;
        v_dia_interes      := v_dias;
        v_val_interes      := round((ww_vlsalan * ww_tasadiv * v_dias),
                                    ww_redondeo);
        if v_val_int_original > 0 then
          /* es una cuota con refuerzo */
          if ww_neto = 'S' then
            v_mto_capital := v_mto_capital;
          else
            v_mto_capital := v_val_int_original - v_val_interes;
          end if;
          ww_refreal  := nvl(ww_refreal, 0) + nvl(v_mto_capital, 0);
          v_val_cuota := null;
        else
          ww_nro := ww_nro + 1;
          if cuota = 1 and
             abs(v_per_interes - (p_fec_pri_vencimiento - v_fec_inicio)) > 2 then
            v_mto_capital := round((ww_frances *
                                   power((1 + (ww_tasadiv * v_dias)),
                                          (ww_nro - 1))),
                                   ww_redondeo);
          else
            v_mto_capital := v_val_cuota - v_val_interes;
          end if;
        end if;
        v_val_int_original := nvl(v_val_int_original, 0);
        v_ttcuota          := nvl(v_mto_capital, 0) + nvl(v_val_interes, 0);
        ww_dfcuota         := nvl(ww_ttcuota, v_ttcuota) -
                              nvl(v_ttcuota, 0);
        -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
        if (abs(ww_dfcuota) between 0.001 and ww_limite) then
          v_val_interes := v_val_interes + ww_dfcuota;
          v_ttcuota     := v_ttcuota + ww_dfcuota;
        end if;
        -- agregado para calculo de seguro por saldo de capital
        if cuota = 1 then
          v_mto_seguro := round(v_tot_prestamo * (v_tas_seguro / 1000) / 30 *
                                v_dia_interes,
                                ww_redondeo);
        else
          v_mto_seguro := round(ww_vlsalan * (v_tas_seguro / 1000) / 30 *
                                v_dia_interes,
                                ww_redondeo);
        end if;
        v_mto_tot_seguro := nvl(v_mto_tot_seguro, 0) + nvl(v_mto_seguro, 0);
        ww_ttcuota         := v_ttcuota;
        ww_vlsalan         := nvl(ww_vlsalan, 0) - v_mto_capital;
        ww_ttcapit         := nvl(ww_ttcapit, 0) + nvl(v_mto_capital, 0);
        v_mto_interes      := v_mto_interes + nvl(v_val_interes, 0);
        v_fec_ven_anterior := v_fec_vto_habil;
        if nvl(v_mto_capital, 0) < 0 or nvl(v_val_interes, 0) < 0 then
          g_cod_error := '014';
          g_lugar     := 'Valida montos negativos';
          g_msj_error := 'Capital o Interes no puede quedar en negativo. Verifique';
        end if;
        -- inserto el registro en la tabla de cuotas
        insert into pr_sol_cuotas
          (nro_solicitud,
           nro_cuota,
           mto_capital,
           fec_vto_habil,
           fec_vto_exacto,
           val_interes,
           sal_capital,
           sal_cap_anterior,
           dia_periodo,
           dia_transcurridos,
           dia_interes,
           tip_calculo,
           val_int_original,
           val_int_adelantado)
        values
          (v_nro_solicitud,
           cuota,
           nvl(v_mto_capital, 0),
           v_fec_vto_habil,
           v_fec_vto_exacto,
           nvl(v_val_interes, 0),
           ww_vlsalan,
           ww_vlsalan + v_mto_capital,
           v_dia_periodo,
           v_dia_periodo,
           v_dia_interes,
           'V',
           v_val_int_original,
           0);
      end loop;
      if abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 or ww_veces > 12 or
         v_tip_monto = 'N' then
        exit;
      end if;
    end loop;
    ww_dfcuota := nvl(v_tot_prestamo, 0) - nvl(ww_ttcapit, 0);
    if ww_dfcuota <> 0 then
      v_mto_capital := v_mto_capital + ww_dfcuota;
      if nvl(v_val_interes, 0) >= ww_dfcuota and abs(ww_dfcuota) <= 1 then
        /* solo se ajusta si existe interes*/
        v_val_interes := nvl(v_val_interes, 0) - ww_dfcuota;
        v_mto_interes := v_mto_interes - ww_dfcuota;
      else
        v_ttcuota := nvl(v_mto_capital, 0) + nvl(v_val_interes, 0);
      end if;
      -- actualizo la ultima cuota
      update pr_sol_cuotas
         set mto_capital = nvl(v_mto_capital, 0),
             val_interes = nvl(v_val_interes, 0)
       where nro_solicitud = v_nro_solicitud
         and nro_cuota = p_can_cuotas; -- ultima cuota
    end if;
    -- vencimiento final del prestamo es igual al de la ult.cuota--
    update pr_solicitudes
       set fec_vencimiento = v_fec_vto_habil, mto_interes = v_mto_interes
     where nro_solicitud = v_nro_solicitud;
    ---------------------------------------------------------
  exception
    when others then
      g_cod_error := '015';
      g_lugar     := 'Valida Genera Cuotas';
      g_msj_error := 'Error en generar cuotas. ' || sqlerrm;
  end;
  ---------------------------------------------------------
  procedure pr_gen_cuo_iguales(ww_neto in varchar2) is
    ww_frances         number;
    ww_tasadiv         number := v_val_tasa / 36500;
    ww_vlsalan         number(18, 2) := v_tot_prestamo;
    ww_ttcuota         number(18, 2) := null;
    ww_dfcuota         number(18, 2);
    ww_ttcapit         number(18, 2) := 0;
    ww_ttrefue         number(18, 2) := 0;
    ww_refreal         number(18, 2) := 0;
    ww_ctrefue         number(6) := 0;
    ww_nro             number(6) := 0;
    ww_veces           number(3) := 0;
    v_val_int_original number(18, 2) := 0;
    --
    v_fec_vto_habil     date;
    v_fec_vto_exacto    date;
    v_fec_vto_habil_ant date;
    v_fec_vcto          date;
    v_sal_cap_anterior  number(18, 2);
    v_dia_interes       number(6);
    v_val_interes       number(18, 2);
    v_ttcuota           number(18, 2);
    v_dia_periodo       number(8);
    v_mto_capital       number(18, 2);
    v_ven_fijo          varchar2(1) := 'S';
    v_per_interes       number := 30;
    v_val_cuota         number;
    ww_redondeo         number(2) := 0; -- redondeo a cero para moneda local
    ww_limite           number := 10; -- limite superior para ajustes de cuotas iguales en moneda local
    v_dias              number;
    v_fec_ven_anterior  date;
    v_mto_seguro        number(18, 2) := 0;
    -- DA-887 cuotas iguales
    v_int_per_gracia  number(18, 2) := 0;
    v_dia_cal_frances number;
  begin
    -- veo el tipo de redondeo de los calculos
    ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                       v_cod_modulo,
                                       v_cod_mod_default,
                                       pag_gen.fu_obt_mon_local,
                                       v_cod_oficina);
    if ww_redondeo != 0 then
      ww_limite := 0.05;
    else
      ww_limite := 1;
    end if;
    if v_ven_fijo is null then
      v_ven_fijo := 'S';
    end if;
    ---
    v_dia_cal_frances := 30.416666666666666666666666666667;
    loop
      v_fec_ven_anterior := v_fec_inicio;
      ww_veces           := nvl(ww_veces, 0) + 1;
      v_dias := p_fec_pri_vencimiento - v_fec_inicio;
      -- calculo del valor del metodo frances
      if (power((1 + (ww_tasadiv * v_dias)), (p_can_cuotas - ww_ctrefue)) - 1) > 0 then
        ww_frances := round((v_val_tasa / 36500 * v_dia_cal_frances *
                            power((1 +
                                   v_val_tasa / 36500 * v_dia_cal_frances),
                                   (p_can_cuotas - ww_ctrefue))) *
                            (nvl(v_tot_prestamo, 0) - nvl(ww_ttrefue, 0)) /
                            ((power((1 +
                                    v_val_tasa / 36500 * v_dia_cal_frances),
                                    (p_can_cuotas - ww_ctrefue))) - 1),
                            ww_redondeo);
      else
        --- para los casos en que la tasa = 0 para que no de division por cero.
        ww_frances := ((nvl(v_tot_prestamo, 0) - nvl(ww_ttrefue, 0))) /
                      ((p_can_cuotas - ww_ctrefue));
      end if;
      v_val_cuota := round((ww_frances *
                           power((1 + (ww_tasadiv * v_dias)), (0))),
                           ww_redondeo) +
                     round((ww_vlsalan * ww_tasadiv * (v_dias)),
                           ww_redondeo);
      if v_per_interes = 30 and (v_ven_fijo = 'S' or ww_ctrefue > 0) then
        v_val_cuota := fup_obt_val_cuota(v_cod_mod_default,
                                         pag_gen.fu_obt_mon_local,
                                         v_tot_prestamo - nvl(ww_ttrefue, 0),
                                         p_can_cuotas - nvl(ww_ctrefue, 0),
                                         v_val_tasa,
                                         v_fec_inicio,
                                         p_fec_pri_vencimiento);
      end if;
      --- veo el monto fijo de cuota si es de tipo prestamos flexibles 
      ----------------------------------------------------------------------
      v_mto_interes    := 0;
      ww_vlsalan       := v_tot_prestamo;
      ww_ttcapit       := 0;
      ww_refreal       := 0;
      v_mto_tot_seguro := 0;
      ww_nro           := 0; /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
      -- borro las cuotas si existen
      delete from pr_sol_cuotas where nro_solicitud = v_nro_solicitud;
      for cuota in 1 .. p_can_cuotas loop
        if cuota = 1 then
          v_fec_vto_habil  := p_fec_pri_vencimiento;
          v_fec_vto_exacto := p_fec_pri_vencimiento;
        else
          if v_per_interes = 30 then
            -- sumo 1 mes...
            if v_ven_fijo = 'S' then
              v_fec_vcto := add_months(p_fec_pri_vencimiento, (cuota - 1));
            else
              v_fec_vcto := p_fec_pri_vencimiento +
                            (((cuota - 1) * v_dias));
            end if;
            v_fec_vto_habil_ant := v_fec_vcto;
            v_fec_vto_habil     := v_fec_vcto;
          else
            v_fec_vto_habil := p_fec_pri_vencimiento +
                               (((cuota - 1) * v_dias));
          end if;
          v_fec_vto_exacto := p_fec_pri_vencimiento +
                              (((cuota - 1) * v_dias));
        end if;
        v_sal_cap_anterior := ww_vlsalan;
        if cuota = 1 and
           abs(to_char(last_day(p_fec_pri_vencimiento), 'dd') -
               (p_fec_pri_vencimiento - v_fec_inicio)) > 1 then
          /* se hace el calculo del interes por el plazo del periodo de gracia */
          v_dia_periodo    := p_fec_pri_vencimiento - v_fec_inicio;
          v_dia_interes    := p_fec_pri_vencimiento - v_fec_inicio;
          v_int_per_gracia := round((ww_vlsalan * ww_tasadiv *
                                    (v_dias - to_char(last_day(p_fec_pri_vencimiento),
                                                       'dd'))), --v_dia_interes),
                                    ww_redondeo);
          v_int_per_gracia := round(v_int_per_gracia / p_can_cuotas,
                                    ww_redondeo);
          --calcula la porci??e interes solo por 30 dias
          v_val_interes := round((ww_vlsalan * ww_tasadiv *
                                 to_char(last_day(p_fec_pri_vencimiento),
                                          'dd')), --v_dia_interes),
                                 ww_redondeo);
          --debe sumar el v_int_per_gracia para el monto final de todas las cuotas
          v_val_cuota := null;
        else
          v_dia_periodo := v_fec_vto_habil - v_fec_ven_anterior;
          v_dia_interes := v_fec_vto_habil - v_fec_ven_anterior;
          v_val_interes := round((ww_vlsalan * ww_tasadiv * v_dia_interes),
                                 ww_redondeo);
        end if;
        if v_val_int_original > 0 then
          /* es una cuota con refuerzo */
          if ww_neto = 'S' then
            v_mto_capital := v_mto_capital;
          else
            v_mto_capital := v_val_int_original - v_val_interes;
          end if;
          ww_refreal  := nvl(ww_refreal, 0) + nvl(v_mto_capital, 0);
          v_val_cuota := null;
        else
          ww_nro := ww_nro + 1;
          if v_val_cuota is not null and fug_obt_tip_entidad != 'F' then
            v_mto_capital := v_val_cuota - v_val_interes;
          else
            v_mto_capital := ww_frances - v_val_interes;
          end if;
          v_val_cuota := v_mto_capital + v_val_interes;
          if ww_frances > v_val_interes then
            v_mto_capital := ww_frances - v_val_interes;
          else
            v_mto_capital := 0;
          end if;
        end if;
        v_val_int_original := nvl(v_val_int_original, 0);
        v_ttcuota          := nvl(v_mto_capital, 0) + nvl(v_val_interes, 0);
        ww_dfcuota         := nvl(ww_ttcuota, v_ttcuota) -
                              nvl(v_ttcuota, 0);
        -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
        if (abs(ww_dfcuota) between 0.001 and ww_limite) then
          v_val_interes := v_val_interes + ww_dfcuota;
          v_ttcuota     := v_ttcuota + ww_dfcuota;
        end if;
        -- agregado para calculo de seguro por saldo de capital
        if cuota = 1 then
          v_mto_seguro := round(v_tot_prestamo * (v_tas_seguro / 1000) / 30 *
                                v_dia_interes,
                                ww_redondeo);
        else
          v_mto_seguro := round(ww_vlsalan * (v_tas_seguro / 1000) / 30 *
                                v_dia_interes,
                                ww_redondeo);
        end if;
        v_mto_tot_seguro := nvl(v_mto_tot_seguro, 0) + nvl(v_mto_seguro, 0);
        ww_ttcuota         := v_ttcuota;
        ww_vlsalan         := nvl(ww_vlsalan, 0) - v_mto_capital;
        ww_ttcapit         := nvl(ww_ttcapit, 0) + nvl(v_mto_capital, 0);
        v_mto_interes      := v_mto_interes + nvl(v_val_interes, 0) +
                              nvl(v_int_per_gracia, 0);
        v_fec_ven_anterior := v_fec_vto_habil;
        if nvl(v_mto_capital, 0) < 0 or nvl(v_val_interes, 0) < 0 then
          g_cod_error := '014';
          g_lugar     := 'Valida montos negativos';
          g_msj_error := 'Capital o Interes no puede quedar en negativo. Verifique';
        end if;
        -- inserto el registro en la tabla de cuotas
        insert into pr_sol_cuotas
          (nro_solicitud,
           nro_cuota,
           mto_capital,
           fec_vto_habil,
           fec_vto_exacto,
           val_interes,
           sal_capital,
           sal_cap_anterior,
           dia_periodo,
           dia_transcurridos,
           dia_interes,
           tip_calculo,
           val_int_original,
           val_int_adelantado)
        values
          (v_nro_solicitud,
           cuota,
           nvl(v_mto_capital, 0),
           v_fec_vto_habil,
           v_fec_vto_exacto,
           nvl(v_val_interes, 0) + nvl(v_int_per_gracia, 0),
           ww_vlsalan,
           ww_vlsalan + v_mto_capital,
           v_dia_periodo,
           v_dia_periodo,
           v_dia_interes,
           'V',
           v_val_int_original,
           0);
      end loop;
      if abs(nvl(ww_refreal, 0) - nvl(ww_ttrefue, 0)) < 10 or ww_veces > 12 or
         v_tip_monto = 'N' then
        exit;
      end if;
    end loop;
    ww_dfcuota := nvl(v_tot_prestamo, 0) - nvl(ww_ttcapit, 0);
    if ww_dfcuota <> 0 then
      if nvl(v_val_interes, 0) >= ww_dfcuota and abs(ww_dfcuota) <= 1 then
        /* solo se ajusta si existe interes*/
        v_val_interes := nvl(v_val_interes, 0) - ww_dfcuota;
        v_mto_interes := v_mto_interes - ww_dfcuota;
      else
        null;
        if ww_dfcuota < 0 then
          v_mto_capital := v_mto_capital + ww_dfcuota;
        else
          v_mto_capital := v_mto_capital + ww_dfcuota;
        end if;
        v_ttcuota := nvl(v_mto_capital, 0) + nvl(v_val_interes, 0) +
                     nvl(v_int_per_gracia, 0);
      end if;
      -- actualizo la ultima cuota
      update pr_sol_cuotas
         set mto_capital = nvl(v_mto_capital, 0),
             val_interes = nvl(v_val_interes, 0) + nvl(v_int_per_gracia, 0)
       where nro_solicitud = v_nro_solicitud
         and nro_cuota = p_can_cuotas; -- ultima cuota
    end if;
    -- vencimiento final del prestamo es igual al de la ult.cuota
    update pr_solicitudes
       set fec_vencimiento = v_fec_vto_habil, mto_interes = v_mto_interes
     where nro_solicitud = v_nro_solicitud;
    ---------------------------------------------------------
  exception
    when others then
      g_cod_error := '015';
      g_lugar     := 'Valida Genera Cuotas';
      g_msj_error := 'Error en generar cuotas. ' || sqlerrm;
  end;
  function fu_cal_mto_seguro(p_cod_tasa  in number,
                             p_cod_ente  in number,
                             p_monto     in number,
                             p_val_tasa  in number,
                             p_dia_plazo in number,
                             p_dias      in number) return number is
    v_mto_seguro number := 0;
  begin
    if fug_obt_parentes(p_cod_ente, 'COD_TAS_SEG_DESEMPLEO') = p_cod_tasa then
      v_mto_seguro := round((p_monto * p_val_tasa / 100) * p_dia_plazo /
                            p_dias,
                            -3);
    elsif fug_obt_parentes(p_cod_ente, 'COD_TAS_SEG_CANCELACION') =
          p_cod_tasa then
      v_mto_seguro := (p_monto * p_val_tasa / 100) * p_dia_plazo / 365;
    end if;
    return v_mto_seguro;
  end;
  -- calculo de los cargos ----------------------------------------------------
  procedure pr_cal_cargos(p_recalculo varchar2 default 'N') is
    v_mto_equivalente number(18, 2);
    v_cod_tra_ajuste  number(4);
    v_monto           number(18, 2);
    v_per_interes     number := 30;
    v_dias            number;
    v_ven_fijo        varchar2(1) := 'S';
    v_jor_minimo      number(18, 2);
    v_cod_tasa        number(18, 4);
    v_des_transaccion varchar2(35);
    v_obligatorio     varchar2(2);
    v_afecta          varchar2(5);
    v_sal_minimo      number(18, 2) := fuh_obt_sal_minimo;
    v_can_salario     number := nvl(fug_obt_pardinamico('PRE_CAN_SAL_MIN_COMISION'),
                                    5);
    v_can_jor_minimo  number := fug_obt_pardinamico('PRE_CAN_JOR_MINIMOS');
    v_plazo           number;
    --
    v_mto_max_gas_adm      number := fug_obt_pardinamico('MTO_MAX_COM_ADM',
                                                         null,
                                                         null,
                                                         nvl(pag_gen.fu_obt_mon_local,
                                                             pag_gen.fu_obt_mon_local),
                                                         null);
    v_mto_gas_admistrativo number;
    v_actualizar           varchar2(1) default 'S';
    cursor cargos is
      select cod_transaccion,
             cod_tasa,
             cod_ent_seguro,
             val_tasa,
             monto,
             cod_moneda,
             mto_mon_prestamo
        from pr_sol_cargos
       where nro_solicitud = v_nro_solicitud
         for update of monto
       order by decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
  begin
    --- calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
    --- cero los totales de cargo de tipo valor y el total general de cargos -------------
    v_ttvalor              := 0;
    v_mto_cargo            := 0;
    v_cod_tra_ajuste       := null;
    v_mto_gas_admistrativo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                          nvl(pag_gen.fu_obt_mon_local,
                                                              pag_gen.fu_obt_mon_local),
                                                          fug_obt_pardinamico('MTO_TAE',
                                                                              6));
    for cc in cargos loop
      v_mto_equivalente := 0;
      -- para realizar ajustes si es necesario----------
      if v_cod_tra_ajuste is null then
        v_cod_tra_ajuste := cc.cod_transaccion;
      end if;
      -- obtengo los datos de la tasa-----------------
      if cc.cod_transaccion in (737, 1271) and v_tip_persona = 'J' and
         nvl(fug_obt_pardinamico('PRE_SEG_DIF_JURIDICAS',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.fu_obt_mon_local,
                                     pag_gen.fu_obt_mon_local)),
             'N') = 'S' then
        --traer valor de la tasa del seguro
        v_cod_tasa := fug_obt_parentes(cc.cod_ent_seguro,
                                       'COD_TAS_JURIDICA');
        if v_cod_tasa is not null then
          select initcap(tr.descripcion),
                 ta.cod_tasa,
                 ta.aplicar,
                 ta.tip_valor,
                 ta.tipo,
                 dt.obligatorio,
                 tr.afecta
            into v_des_transaccion,
                 v_cod_tas_cargo,
                 v_aplicar,
                 v_tpvlpor,
                 v_tpdetas,
                 v_obligatorio,
                 v_afecta
            from ge_transacciones_det dt, ge_transacciones tr, ge_tasas ta
           where tr.cod_modulo = v_cod_modulo
             and tr.cod_modalidad =
                 nvl(v_cod_mod_default, v_cod_mod_default)
             and tr.cod_transaccion = cc.cod_transaccion
             and tr.tipo = 'D'
             and v_cod_tasa = ta.cod_tasa
             and dt.cod_modulo = v_cod_modulo
             and dt.cod_modalidad =
                 nvl(v_cod_mod_default, v_cod_mod_default)
             and dt.cod_transaccion = 358 /* transaccion de desembolso de prestamos */
             and dt.cod_mod_hijo = tr.cod_modulo
             and dt.cod_mad_hijo = tr.cod_modalidad
             and dt.cod_tra_hijo = tr.cod_transaccion;
        else
          g_cod_error := '030';
          g_lugar     := 'Busca datos tasa Per.Juridica';
          g_msj_error := 'No se encuentra definida la tasa para Seguro de Personas Juridicas. ' ||
                         sqlerrm;
        end if;
      else
        if cc.cod_transaccion = 1521 then
          v_cod_tas_cargo := null;
        else
          v_cod_tas_cargo := cc.cod_tasa;
        end if;
        pr_obt_tipo_de_tasa(cc.cod_transaccion,
                            v_cod_tas_cargo, --cc.cod_tasa,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas,
                            v_afecta);
      end if;
      if cc.cod_transaccion is not null and
         (cc.cod_moneda is null or
         (v_tpvlpor = 'V' and nvl(cc.monto, 0) = 0)) then
        g_cod_error := '016';
        g_lugar     := 'Valida Calculo Cargos';
        g_msj_error := 'Valores nulos en Cargos. Verificar la Trans. ' ||
                       to_char(cc.cod_transaccion);
      end if;
      if v_tpvlpor = 'P' then
        v_mto_equivalente := 0;
        -- la tasa es un porcentaje
        if v_aplicar in ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') then
          -- aplicable al interes 
          if cc.cod_ent_seguro is not null and
             cc.cod_transaccion in (1270, 1271) then
            if v_ven_fijo is null then
              v_ven_fijo := 'S';
            end if;
            ---
            if v_per_interes = 30 and v_ven_fijo = 'S' then
              v_dias := 30.416666666666666666666666666667;
            else
              v_dias := v_per_interes;
            end if;
            if cc.cod_transaccion = 1271 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_mto_interes,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),
                                         v_redondeo);
            end if;
          else
            v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                       v_redondeo);
          end if;
        end if;
        if v_aplicar in ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') then
          -- puede ser un par_ente con el codigo de ente y transaccion
          if cc.cod_ent_seguro is not null and
             cc.cod_transaccion in (1270, 1271) then
            if v_ven_fijo is null then
              v_ven_fijo := 'S';
            end if;
            ---
            if v_per_interes = 30 and v_ven_fijo = 'S' then
              v_dias := 30.416666666666666666666666666667;
            else
              v_dias := v_per_interes;
            end if;
            if cc.cod_transaccion = 1271 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_mto_equivalente := round(fu_cal_mto_seguro(cc.cod_tasa,
                                                           cc.cod_ent_seguro,
                                                           v_tot_prestamo,
                                                           cc.val_tasa,
                                                           v_dia_plazo,
                                                           v_dias),
                                         v_redondeo);
            end if;
          else
            -- es aplicable al capital
            if cc.cod_transaccion = 737 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * cc.val_tasa / 100,
                                         v_redondeo);
            end if;
          end if;
        end if;
        if v_aplicar = 'MO' then
          -- es aplicable al monto de la operacion
          v_plazo := round((v_dia_plazo / 30), 0);
          if cc.cod_ent_seguro is not null and
             cc.cod_transaccion in (1270, 1271) then
            if v_ven_fijo is null then
              v_ven_fijo := 'S';
            end if;
            ---
            if v_per_interes = 30 and v_ven_fijo = 'S' then
              v_dias := 30.416666666666666666666666666667;
            else
              v_dias := v_per_interes;
            end if;
            if cc.cod_transaccion = 1271 then
              v_tas_seguro      := cc.val_tasa;
              v_mto_equivalente := round(v_mto_tot_seguro, v_redondeo);
            else
              v_imp_cargo := 0;
              if cc.cod_transaccion = '709' then
                -- 1era. modificacion DA-6139
                v_imp_cargo := nvl(v_imp_cargo, 0) +
                               trunc(p_mto_solicitado * v_plazo *
                                     cc.val_tasa / 100,
                                     v_redondeo);
              else
                v_imp_cargo := nvl(v_imp_cargo, 0) +
                               round(p_mto_solicitado * v_plazo *
                                     cc.val_tasa / 100,
                                     v_redondeo);
              end if;
              v_mto_equivalente := v_imp_cargo; -- + round(v_imp_cargo * 10/100,v_redondeo);
            end if;
          else
            if cc.cod_ent_seguro is not null then
              v_imp_cargo       := 0;
              v_imp_cargo       := nvl(v_imp_cargo, 0) +
                                   round(p_mto_solicitado * v_plazo *
                                         cc.val_tasa / 100,
                                         v_redondeo);
              v_mto_equivalente := v_imp_cargo; -- + round(v_imp_cargo * 10/100,v_redondeo);
            else
             if cc.cod_transaccion =704 and v_cod_sub_modalidad = 1  then 
              v_imp_cargo       := 0;
              v_imp_cargo       := nvl(v_imp_cargo, 0) +
                                   round((p_mto_solicitado/0.99 * cc.val_tasa / 100),
                                         v_redondeo);
              v_mto_equivalente := v_imp_cargo; -- + round(v_imp_cargo * 10/100,v_redondeo);
              else
               v_imp_cargo       := 0;
               v_imp_cargo       := nvl(v_imp_cargo, 0) +
                                   round(p_mto_solicitado * cc.val_tasa / 100,
                                         v_redondeo);
              v_mto_equivalente := v_imp_cargo;
              end if;
            end if;
          end if;
        end if;
        if v_afecta = 'G' then
          v_mto_equivalente := 0;
          if v_tot_prestamo > 0 then
            v_mto_equivalente := round(v_tot_prestamo * cc.val_tasa / 1000,
                                       v_redondeo);
          end if;
        end if;
        if cc.cod_transaccion in (737, 1271) then
          v_tas_seguro := cc.val_tasa;
        end if;
        if cc.cod_transaccion in (1) and
           (p_mto_solicitado <= v_sal_minimo * nvl(v_can_salario, 0)) then
          v_jor_minimo := round(v_sal_minimo / 26 * v_can_jor_minimo, 0);
          if v_mto_equivalente > v_jor_minimo then
            v_imp_cargo       := 0;
            v_imp_cargo       := v_jor_minimo;
            v_mto_equivalente := v_imp_cargo;
          end if;
        elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           nvl(v_cod_mod_default,
                                                               v_cod_mod_default),
                                                           nvl(pag_gen.fu_obt_mon_local,
                                                               pag_gen.fu_obt_mon_local)),
                                       0) then
          v_imp_cargo       := 0;
          v_imp_cargo       := p_mto_consolidado;
          v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + round(v_imp_cargo * 10/100,v_redondeo);
        end if;
      elsif v_tpvlpor = 'I' then
        v_mto_equivalente := 0;
        -- la tasa es un impuesto
        if v_aplicar in ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') then
          -- aplicable al interes
          if v_dia_plazo < 365 then
            v_mto_equivalente := round(v_mto_interes * v_dia_plazo *
                                       cc.val_tasa / 36500,
                                       v_redondeo);
          else
            v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100,
                                       v_redondeo);
          end if;
        end if;
        if v_aplicar in ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') then
          -- es aplicable al capital 
          if cc.cod_ent_seguro is not null then
            -- es un seguro 
            v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                 round(v_tot_prestamo * cc.val_tasa / 100,
                                       v_redondeo);
          else
            -- es un impuesto sobre el capital 
            if v_dia_plazo < 365 then
              v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * v_dia_plazo *
                                         cc.val_tasa / 36500,
                                         v_redondeo);
            else
              v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                   round(v_tot_prestamo * cc.val_tasa / 100,
                                         v_redondeo);
            end if;
          end if;
        end if;
        if cc.cod_transaccion in (1) and
           (p_mto_solicitado <= v_sal_minimo * nvl(v_can_salario, 0)) then
          v_jor_minimo := round(v_sal_minimo / 26 * v_can_jor_minimo, 0);
          if v_mto_equivalente > v_jor_minimo then
            v_mto_equivalente := v_jor_minimo;
          end if;
        elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           nvl(v_cod_mod_default,
                                                               v_cod_mod_default),
                                                           nvl(pag_gen.fu_obt_mon_local,
                                                               pag_gen.fu_obt_mon_local)),
                                       0) then
          v_imp_cargo       := 0;
          v_imp_cargo       := p_mto_consolidado;
          v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + round(v_imp_cargo * 10/100,v_redondeo);
        end if;
      elsif v_tpvlpor = 'V' then
        -- es un monto valor
        v_mto_equivalente := cc.monto;
        if cc.cod_transaccion in (1) and
           (p_mto_solicitado <= v_sal_minimo * nvl(v_can_salario, 0)) then
          v_jor_minimo := round(v_sal_minimo / 26 * v_can_jor_minimo, 0);
          if v_mto_equivalente > v_jor_minimo then
            v_mto_equivalente := v_jor_minimo;
          end if;
        elsif cc.cod_transaccion = nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                           v_cod_modulo,
                                                           nvl(v_cod_mod_default,
                                                               v_cod_mod_default),
                                                           nvl(pag_gen.fu_obt_mon_local,
                                                               pag_gen.fu_obt_mon_local)),
                                       0) then
          v_imp_cargo       := 0;
          v_imp_cargo       := p_mto_consolidado;
          v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + round(v_imp_cargo * 10/100,v_redondeo);
        end if;
        v_ttvalor := nvl(v_ttvalor, 0) + nvl(v_mto_equivalente, 0);
      elsif v_tpvlpor = 'T' then
        v_plazo         := round((v_dia_plazo / 30), 0);
        v_val_tas_cargo := fu_obt_valor_de_tasa_variable(cc.cod_tasa,
                                                         p_mto_solicitado,
                                                         v_fec_inicio);
        -- volvemos a obtener el tipo de tasa
        pr_obt_tipo_de_tasa(cc.cod_transaccion,
                            v_val_tas_cargo,
                            v_aplicar,
                            v_tpvlpor,
                            v_tpdetas,
                            v_afecta);
        if v_tpvlpor = 'P' then
          v_val_tas_cargo   := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                             v_plazo,
                                                             v_fec_inicio);
          v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                               round(nvl(p_mto_solicitado, v_tot_prestamo) *
                                     v_val_tas_cargo / 100,
                                     v_redondeo);
        elsif v_tpvlpor = 'V' then
          v_val_tas_cargo   := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                             v_plazo,
                                                             v_fec_inicio);
          v_mto_equivalente := nvl(v_mto_equivalente, 0) + v_val_tas_cargo;
        end if;
        --
        if v_mto_max_gas_adm > 0 then
          if nvl(v_tot_prestamo, p_mto_solicitado) <=
             v_mto_gas_admistrativo then
            if v_mto_equivalente > v_mto_max_gas_adm then
              v_mto_equivalente := v_mto_max_gas_adm;
            end if;
          end if;
        end if;
        if p_recalculo = 'S' and cc.cod_transaccion = '704' then
          v_actualizar := 'N';
          begin
            select a.monto - v_mto_aumento
              into v_mto_adm_anterior
              from pr_sol_cargos a
             where a.nro_solicitud = v_nro_solicitud
               and a.cod_transaccion = 704;
          exception
            when no_data_found then
              v_mto_adm_anterior := v_mto_equivalente;
          end;
        end if;
        --
      end if;
      if cc.cod_transaccion =
         nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.fu_obt_mon_local,
                                     pag_gen.fu_obt_mon_local)),
             0) then
        v_imp_cargo       := 0;
        v_imp_cargo       := p_mto_consolidado;
        v_mto_equivalente := p_mto_consolidado; --v_imp_cargo + round(v_imp_cargo * 10/100,v_redondeo);
      end if;
      if cc.cod_transaccion =
         nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                 v_cod_modulo,
                                 nvl(v_cod_mod_default, v_cod_mod_default),
                                 nvl(pag_gen.fu_obt_mon_local,
                                     pag_gen.fu_obt_mon_local)),
             0) then
        v_monto := p_mto_consolidado;
      else
        v_monto := null;
        -- acumular el total de cargos (si el tipo es valor viene directamente aqui -------
        v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
        ------------------------------------------------------------------------------------
      end if;
      if v_tpvlpor in ('I', 'P') then
        /* solo si es porcentaje */
        if cc.cod_moneda =
           nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local) then
          -- moneda del cargo es igual a la moneda de la simulacion ----------------------
          v_monto := v_mto_equivalente;
   
        else
          -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
          v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
        end if;
      end if;
      if nvl(v_actualizar, 'S') = 'S' then
        update pr_sol_cargos
           set mto_mon_prestamo = nvl(v_mto_equivalente, 0),
               monto            = nvl(v_monto, monto)
         where current of cargos;
      end if;
    end loop;
    if v_mto_cargo >= v_tot_prestamo then
      g_cod_error := '017';
      g_lugar     := 'Valida Sumatoria de Cargos';
      g_msj_error := 'Total de Cargos ' || v_mto_cargo ||
                     ' es superior al Total del Prestamo ' ||
                     v_tot_prestamo;
    else
      if v_tip_monto = 'N' and v_tot_prestamo <> p_mto_solicitado then
        -- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste
        null;
      end if;
    end if;
    begin
      select nvl(sum(a.monto), 0)
        into v_mto_cargo
        from pr_sol_cargos a
       where a.nro_solicitud = v_nro_solicitud
         and not exists (select t.cod_transaccion
                from ge_transacciones t
               where t.cod_transaccion = a.cod_transaccion
                 and t.cod_modulo = 6
                 and t.cod_modalidad = v_cod_mod_default
                 and t.afecta = 'G');
    end;
    -- actualizo el total de cargos de  la solicitud
    update pr_solicitudes
       set mto_cargo = v_mto_cargo
     where nro_solicitud = v_nro_solicitud;
  exception
    when others then
      g_cod_error := '018';
      g_lugar     := 'Valida Calculo Cargos';
      g_msj_error := 'Error al calcular cargos ' || sqlerrm;
  end;
  -- elimna solicitud en pendiente de liquidación
  procedure pr_eli_solicitudes is
    v_elimina varchar2(1) := 'N';
  begin
    begin
      select 'S'
        into v_elimina
        from pr_solicitudes s
       where s.nro_solicitud = nvl(p_solicitud, v_nro_solicitud)
         and s.estado = 'L';
    exception
      when no_data_found then
        v_elimina := 'N';
    end;
    if nvl(v_elimina, 'N') = 'S' then
      delete from pr_sol_tasas
       where nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      delete from pr_sol_garantias
       where nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      delete from pr_sol_destinos
       where nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      delete from pr_sol_cargos
       where nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      delete from pr_sol_cuotas
       where nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      delete from pr_solicitudes
       where nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
      delete from ba_tab_dat_adicionales
       where tab_relacion = 'PR_SOLICITUDES'
         and parametro = 'CLA_PRE_APROBADO'
         and referencia = nvl(p_solicitud, v_nro_solicitud);
  --    update pr_pre_che_roga a
  --       set a.nro_solicitud = null
  --     where a.cod_per_solicitante = p_cod_persona
  --       and a.nro_solicitud = nvl(p_solicitud, v_nro_solicitud)
  --       and a.estado in ('V','I');
    else
      g_cod_error := '020';
      g_lugar     := 'Verifica Estado de Solicitud.';
      g_msj_error := 'Solicitud ' || nvl(p_solicitud, v_nro_solicitud) ||
                     ' no puede ser elimnado ' || sqlerrm;
    end if;
  exception
    when others then
      g_cod_error := '019';
      g_lugar     := 'Elimina Solicitud ' ||
                     nvl(p_solicitud, v_nro_solicitud);
      g_msj_error := 'Error al eliminar solicitudes ' || sqlerrm;
  end;
  -- proceso que almacena dato adicional
  procedure pr_ins_clave is
  begin
    insert into ba_tab_dat_adicionales
      (tab_relacion, referencia, parametro, val_parametro)
    values
      ('PR_SOLICITUDES', v_nro_solicitud, 'CLA_PRE_APROBADO', p_clave);
  exception
    when others then
      g_cod_error := '021';
      g_lugar     := 'Inserta Datos Adicionales ' || v_nro_solicitud;
      g_msj_error := 'Error al insertar datos adicionales ' || sqlerrm;
  end;
  -- funcion que retorna el monto de la cuota -----
  function fu_obt_mto_cuota(p_nro_sol in pr_solicitudes.nro_solicitud%type)
    return number is
    v_cuo_sol number;
  begin
    select (sc.mto_capital + sc.val_interes)
      into v_cuo_sol
      from pr_sol_cuotas sc
     where sc.nro_solicitud = p_nro_sol
       and sc.nro_cuota = 1;
    return v_cuo_sol;
  exception
    when others then
      g_cod_error := '033';
      g_lugar     := 'Obtiene Cuota ';
      g_msj_error := 'Error al buscar cuota de la solicitud ' || sqlerrm;
  end;
  function fu_val_sub_modalidad(p_cod_submodalidad         in number) 
    return number is
    v_cod_sub_mod number;
  --vidalrod
  begin
    SELECT COD_SUB_MODALIDAD
      INTO v_cod_sub_mod
      FROM GE_SUB_MODALIDADES
     WHERE cod_modalidad = p_cod_modalidad
       AND cod_sub_modalidad = p_cod_submodalidad;
  return v_cod_sub_mod;
  exception
   when no_data_found then 
        g_cod_error := '122';
        g_lugar     := 'Obtener sub modalidad';
        g_msj_error := 'Error al obtener submodalidad '|| sqlerrm;
          RETURN NULL;
   when too_many_rows then
        g_cod_error := '124';
        g_lugar     := 'Obtener sub modalidad';
        g_msj_error := 'Error al obtener submodalidad '|| sqlerrm;
      RETURN NULL;
   when others then
      g_cod_error := '123';
      g_lugar     := 'Obtiene sub modalidad ';
      g_msj_error := 'Error al buscar sub modalidad ' || sqlerrm;
      RETURN NULL;
  end;  
  function fu_obt_mto_cuota_apx(p_nro_sol in pr_solicitudes.nro_solicitud%type)
    return number is
    v_cuo_sol number;
  begin
    select max(nvl(sc.mto_capital, 0) + nvl(sc.val_interes, 0))
      into v_cuo_sol
      from pr_sol_cuotas sc
     where sc.nro_solicitud = p_nro_sol
       and sc.nro_cuota <> 1;
    return v_cuo_sol;
  exception
    when others then
      g_cod_error := '033';
      g_lugar     := 'Obtiene Cuota ';
      g_msj_error := 'Error al buscar cuota de la solicitud ' || sqlerrm;
  end;
  procedure pr_cal_dif_montos(p_nro_sol in pr_solicitudes.nro_solicitud%type) is
    v_tot_prestamo        pr_solicitudes.tot_prestamo%type;
    v_tot_cuota_solicitud pr_sol_cuotas.mto_capital%type;
    v_mon_ajuste          pr_solicitudes.monto%type;
    v_nro_cuota           pr_sol_cuotas.nro_cuota%type;
  begin
    begin
      select tot_prestamo
        into v_tot_prestamo
        from pr_solicitudes p
       where p.nro_solicitud = p_nro_sol;
    exception
      when others then
        g_cod_error := '110';
        g_lugar     := 'Total prestamo ';
        g_msj_error := 'Error consultar solicitudes' || sqlerrm;
    end;
    begin
      select sum(dp.mto_capital)
        into v_tot_cuota_solicitud
        from pr_sol_cuotas dp
       where dp.nro_solicitud = p_nro_sol;
    exception
      when others then
        g_cod_error := '111';
        g_lugar     := 'Total prestamo ';
        g_msj_error := 'Error consultar sol_cuotas' || sqlerrm;
    end;
    /* verificamos el total de las cuotas en contra partida con el total de la
    solicitud */
    if abs(v_tot_prestamo - v_tot_cuota_solicitud) between 1 and 2 then
      v_mon_ajuste := (v_tot_prestamo - v_tot_cuota_solicitud);
      begin
        select max(nro_cuota)
          into v_nro_cuota
          from pr_sol_cuotas
         where nro_solicitud = p_nro_sol;
      exception
        when others then
          g_cod_error := '112';
          g_lugar     := 'Total prestamo ';
          g_msj_error := 'Error consultar' || sqlerrm;
      end;
      begin
        -- ajustamos la ultima cuota
        update pr_sol_cuotas a
           set a.mto_capital = a.mto_capital + v_mon_ajuste
         where a.nro_solicitud = p_nro_sol
           and a.nro_cuota = v_nro_cuota;
      exception
        when others then
          g_cod_error := '113';
          g_lugar     := 'Error a actualizar la ultima cuota ';
          g_msj_error := 'Error al actualizar la ultima cuota ' || sqlerrm;
      end;
    end if;
  exception
    when others then
      g_cod_error := '033';
      g_lugar     := 'Obtiene Cuota ';
      g_msj_error := 'Error al buscar cuota de la solicitud ' || sqlerrm;
  end;
  --code section
begin
  begin
    pre_ini_aplicacion;
  end;
  
  pre_cam_for_numerico(',.');
  v_valor_aum := nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',
                                         null,
                                         null,
                                         p_cod_moneda,
                                         null),
                     0);
  g_msj_error := ' ';
  g_cod_error := null;
  --- veo el tipo de redondeo de los calculos ------------------------------------------
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                    6,
                                    nvl(v_cod_mod_default, v_cod_mod_default),
                                    nvl(pag_gen.fu_obt_mon_local,
                                        pag_gen.fu_obt_mon_local));
  ------ verificamos si no tiene solicitud en la nebulosa------------------------------
  if p_solicitud is null then
    begin
--      select a.nro_solicitud
--        into v_nro_solicitud
--        from pr_pre_che_roga a
--       where a.cod_per_solicitante = p_cod_persona
--         and a.estado in ('V','I') -- Visible en app
--         and a.nro_solicitud is not null;
        select a.nro_solicitud
          into v_nro_solicitud
          from pr_solicitudes a
         where 1=1
           and a.cOD_PERSONA = p_cod_persona
           and a.cod_modalidad = p_cod_modalidad
           and a.estado in ('V','I'); 
    exception
      when no_data_found then
        v_nro_solicitud := null;
      when too_many_rows then
      v_nro_solicitud := null;
      --  select max(a.nro_solicitud)
      --    into v_nro_solicitud
      --    from pr_pre_che_roga a
      --   where a.cod_per_solicitante = p_cod_persona
      --     and a.estado in ('V','I') -- Visible en app
      --     and a.nro_solicitud is not null;
      when others then
        v_nro_solicitud := null;
    end;
  end if;
  -- eliminamos la solicitud del cliente -------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    if nvl(p_solicitud, v_nro_solicitud) is not null then
      pr_eli_solicitudes;
    end if;
  end if;
  
  --------------------control cuenta con oferta de tarjeta vigente---------------------
  /* if nvl(g_cod_error, '000') = '000' then not null
    begin
      select 'S'
        into v_existe_tc
        from ta_lin_pre_aprobado t
       where t.estado = 'G'
         and t.cod_persona = p_cod_persona;
    exception
      when no_data_found then
        v_existe_tc := 'N';
      when others then
        g_cod_error := '011';
        g_lugar     := 'Consulta estado Tarjeta';
        g_msj_error := 'Error al consultar estado tarjeta ' || sqlerrm;
    end;
    -- Revisar punto
    if nvl(v_existe_tc, 'N') = 'S' then
     -- g_cod_error := '013';
     -- g_lugar     := 'Persona posee una Linea de credito activa';
     -- g_msj_error := 'Persona posee una Linea de credito activa ';
      update ta_lin_pre_aprobado pp
         set pp.estado = 'V', pp.fec_fin_oferta = trunc(sysdate)
       where pp.cod_persona = p_cod_persona
         and pp.estado in ('G');
    end if;
  end if;*/
  -- valido el código del cliente-------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_val_cod_persona;
  end if;
  -- valido el codigo de la modalidad que recibo----------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_val_cod_modalidad;
  end if;
  -- valido la moneda-------------------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_val_cod_moneda;
  end if;
  -- valido el monto -------------------------------------------------------
  if nvl(g_cod_error, '000') = '000' and nvl(p_mto_solicitado, 0) <= 0 then
    g_cod_error := '005';
    g_lugar     := 'Valida Monto Ingresado';
    g_msj_error := 'Ingrese Monto del Credito';
  end if;
  v_tot_prestamo := p_mto_solicitado;
  -- valido el tipo de monto -----------------------------------------------
  if nvl(g_cod_error, '000') = '000' and
     nvl(v_tip_monto, 'X') not in ('B', 'N') then
    g_cod_error := '006';
    g_lugar     := 'Valida Tipo Monto';
    g_msj_error := 'Tipo de Monto debe ser B-Bruto o N-Neto';
  end if;
  -- valido la cantidad de cuotas ------------------------------------------
  if nvl(g_cod_error, '000') = '000' and nvl(p_can_cuotas, 0) < 1 then
    g_cod_error := '007';
    g_lugar     := 'Valida Cantidad Cuotas';
    g_msj_error := 'Ingrese la cantidad de cuotas';
  end if;
  
  ----desde aqui
  v_can_dia_pri_vcto     := fug_obt_pardinamico('CAN_DIA_PRI_VCTO',
                                                6,
                                                nvl(v_cod_mod_default,
                                                    v_cod_mod_default),
                                                nvl(pag_gen.fu_obt_mon_local,
                                                    pag_gen.fu_obt_mon_local),
                                                v_cod_oficina);
  v_can_dia_min_pri_vcto := fug_obt_pardinamico('CAN_DIA_MIN_PRI_VENCIMIENTO',
                                                6,
                                                nvl(v_cod_mod_default,
                                                    v_cod_mod_default),
                                                nvl(pag_gen.fu_obt_mon_local,
                                                    pag_gen.fu_obt_mon_local),
                                                v_cod_oficina);
  if v_can_dia_min_pri_vcto is null then
    v_can_dia_min_pri_vcto := 15;
  end if;
  ---
  if nvl(g_cod_error, '000') = '000' and p_fec_pri_vencimiento is null then
    g_cod_error := '008';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Ingrese Primer Vencimiento del Prestamo.';
  end if;
  -- valido la fecha del primer vencimiento --------------------------------
  if nvl(g_cod_error, '000') = '000' and
     p_fec_pri_vencimiento <= v_fec_actual and
     nvl(v_cod_mod_default, v_cod_mod_default) <> 660 then
    g_cod_error := '009';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Primer Vencimiento debe ser posterior a la fecha de Hoy';
  end if;
  -- controla los dias del primer vencimiento...
  if nvl(g_cod_error, '000') = '000' and
     ((p_fec_pri_vencimiento - v_fec_actual) > v_can_dia_pri_vcto) then
    g_cod_error := '010';
    g_lugar     := 'Valida Primer vencimiento';
    g_msj_error := 'Primer Vencimiento no debe ser posterior a los ' ||
                   v_can_dia_pri_vcto || ' dias.';
  end if;
  -- controla los dias del primer vencimiento...
  if nvl(g_cod_error, '000') = '000' and
     ((p_fec_pri_vencimiento - v_fec_actual) < v_can_dia_min_pri_vcto) then
    g_cod_error := '010';
    g_lugar     := 'Valida Primer Vencimiento';
    g_msj_error := 'Primer Vencimiento no debe ser menor a los ' ||
                   v_can_dia_min_pri_vcto || ' dias.';
  end if;
  if nvl(g_cod_error, '000') = '000' and
     nvl(fug_obt_pardinamico('PRE_MOD_AFD',
                             6,
                             nvl(v_cod_mod_default, v_cod_mod_default),
                             nvl(pag_gen.fu_obt_mon_local,
                                 pag_gen.fu_obt_mon_local)),
         'N') = 'S' then
    pp_val_dias_gracia;
  end if;
  
  -- valido el tipo de persona  --------------------------------------------
  begin
    select pe.tipo
      into v_tip_persona
      from ba_personas pe
     where pe.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      v_tip_persona := null;
  end;
  --------------------------------------------------------------------------
  if nvl(g_cod_error, '000') = '000' and v_tip_persona is null then
    g_cod_error := '009';
    g_lugar     := 'Valida Tipo Persona';
    g_msj_error := 'Ingrese el tipo de persona';
  end if;
  -- valido el tipo de persona  --------------------------------------------
  if nvl(g_cod_error, '000') = '000' and v_tip_persona is not null and
     v_tip_persona not in ('F', 'J') then
    g_cod_error := '010';
    g_lugar     := 'Valida Tipo Persona';
    g_msj_error := 'Valor incorrecto. (Tipo F-Fisica/ J-Juridica)';
  end if;
  v_dia_plazo   := add_months(p_fec_pri_vencimiento, p_can_cuotas - 1) -
                   v_fec_inicio;
  v_per_gracia  := v_fec_pri_vencimiento - v_fec_inicio;
  v_per_capital := 30;
     --obtengo la submodalidad segun oferta 
  if nvl(g_cod_error, '000') = '000' then    
     v_cod_sub_modalidad := fu_val_sub_modalidad(p_cod_submodalidad);
     if nvl(v_cod_sub_modalidad,0) = 0 then 
        g_cod_error := '126';
        g_lugar     := 'Obtener sub modalidad';
        g_msj_error := 'Error al obtener submooodalidad '||v_cod_sub_modalidad;
     end if;
  end if;
  
  -- valido la tasa de interes -----------da-7311------
  if nvl(g_cod_error, '000') = '000' and nvl(v_max_tasa, 'N') <> 'S' then
    pr_val_tasa;
  end if;
  v_nro_solicitud := null;
  --- recupero secuencia negativa para solicitud auxiliar
  if nvl(g_cod_error, '000') = '000' then
    -- asigno el número de la solicitud -----------------------------------------
    if p_grabar = 'S' then
      select s_nro_sol_prestamos.nextval into v_nro_solicitud from dual;
    else
      --- recupero secuencia negativa para solicitud auxiliar
      select s_nro_sol_negativo.nextval into v_nro_solicitud from dual;
    end if;
    --------------------------------------------------------------------------
    -----------------------------------------------------------------------
    /*begin
      select a.cod_pla_pre_aprobado
        into v_cod_pla_pre_aprobado
        from pr_pre_aprobados a
       where a.cod_persona = p_cod_persona
         and a.estado in ('g', 'c');
    exception
      when no_data_found then
        g_cod_error := '037';
        g_lugar     := 'valida rubro economico';
        g_msj_error := 'cliente no posee oferta de pre-aprobado vigente)';
      when too_many_rows then
        select a.cod_pla_pre_aprobado
          into v_cod_pla_pre_aprobado
          from pr_pre_aprobados a
         where a.cod_persona = p_cod_persona
           and a.estado in ('g', 'c')
           and a.fec_ini_oferta =
               (select max(b.fec_ini_oferta)
                  from pr_pre_aprobados b
                 where b.cod_persona = a.cod_persona
                   and b.estado in ('g', 'c'));
    end;*/
    ---------- obtengo el rubro de la tabla de pre-aprobados------------------
    /*begin
      select pa.cod_rub_economico
        into v_cod_rub_economico
        from pr_pre_aprobados pa
       where pa.cod_persona = p_cod_persona
         and pa.cod_pla_pre_aprobado = v_cod_pla_pre_aprobado
         and pa.estado in ('g', 'c');
    exception
      when others then
        v_cod_rub_economico := null;
    end;*/
    -- v_cod_rub_economico := '970000';
    -- inserto el registro en la tabla de solicitudes ------------------------
    begin
    
      -- obtengo el tipo destino en caso de ser nulo ---------------------------
      if v_tip_destino is null then
        v_tip_destino := fup_obt_tip_destino(p_cod_persona,
                                             p_cod_modalidad,
                                             p_cod_moneda,
                                             v_tot_prestamo - v_mto_interes,
                                             null,
                                             p_mto_solicitado,
                                             p_can_cuotas);
      end if;
      insert into pr_solicitudes
        (nro_solicitud,
         descripcion,
         monto,
         tip_amortizacion,
         dia_plazo,
         fec_vencimiento,
         mto_interes,
         per_vto_capital,
         per_gracia,
         cod_persona,
         fec_inicio,
         tip_monto,
         tot_prestamo,
         cod_modulo,
         cod_modalidad,
         cod_moneda,
         cod_oficina,
         fec_pri_vencimiento,
         cod_sec_credito,
         cod_departamento,
         tip_documento,
         exo_impuesto,
         cod_usu_promotor,
         cod_canal,
         cod_campana,
         tip_destino,
         cod_banca,
         tip_renovacion,
         cod_ori_fondo,
         por_ori_fondo,
         cod_rub_economico,
         estado,
         est_verificacion,
         cod_sub_modalidad)
      values
        (v_nro_solicitud,
         nvl(v_descripcion, 'PROMO PRE-APROBADO CHE ROGA.'),
         p_mto_solicitado,
         v_tip_amortizacion,
         v_dia_plazo,
         v_fec_vencimiento,
         v_mto_interes,
         v_per_capital,
         v_per_gracia,
         p_cod_persona,
         v_fec_inicio,
         v_tip_monto,
         v_tot_prestamo,
         v_cod_modulo,
         nvl(v_cod_mod_default, v_cod_mod_default),
         nvl(pag_gen.fu_obt_mon_local, pag_gen.fu_obt_mon_local),
         v_cod_oficina,
         v_fec_pri_vencimiento,
         v_cod_sec_credito,
         nvl(v_cod_departamento, v_cod_dep_parametro),
         v_tip_documento,
         v_exo_impuestos,
         v_cod_usu_promotor,
         p_cod_canal,
         v_cod_campana,
         v_tip_destino,
         v_cod_banca,
         'A',
         v_ori_fondo,
         100,
         nvl(v_cod_rub_economico, 970000),
         'S',
         decode(nvl(v_cod_mod_default, v_cod_mod_default), 660, 'N', 'S'),
         v_cod_sub_modalidad);
    exception
      when others then
        g_cod_error := '019';
        g_lugar     := 'Inserta Propuesta';
        g_msj_error := 'Error al insertar la propuesta. ' || sqlerrm;
    end;
  end if;
  <<recalculo>>
  if nvl(v_max_tasa, 'N') = 'S' then
    delete from pr_sol_cargos c
     where c.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
    delete from pr_sol_cuotas cu
     where cu.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
    delete from pr_sol_tasas t
     where t.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
    delete from pr_sol_garantias g
     where g.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
    delete from pr_sol_destinos o
     where o.nro_solicitud = nvl(p_solicitud, v_nro_solicitud);
  end if;
  -- genero los cargos por defecto
  if nvl(g_cod_error, '000') = '000' then
    pr_gen_cargos(v_recalculo);
  end if;
  -- generar cuotas --------------------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_gen_cuo_iguales('N');
  end if;
  -- calculo los cargos ----------------------------------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_cal_cargos(v_recalculo);
  end if;
  -- verifico el tipo de prestamo
  if nvl(g_cod_error, '000') = '000' then
    if v_tip_monto = 'B' then
      v_tot_prestamo := p_mto_solicitado;
    else
      select sum(nvl(a.monto, 0))
        into v_mto_cargo
        from pr_sol_cargos a
       where a.nro_solicitud = v_nro_solicitud
         and a.cod_transaccion != nvl(fug_obt_pardinamico('PRE_TRA_MTO_CONSOLIDADO',
                                                          v_cod_modulo,
                                                          nvl(v_cod_mod_default,
                                                              v_cod_mod_default),
                                                          nvl(pag_gen.fu_obt_mon_local,
                                                              pag_gen.fu_obt_mon_local),
                                                          null),
                                      0);
      --- monto ingresado es el neto -----------------------------------------------------
      v_por_ajuste := (p_mto_solicitado - (nvl(v_mto_cargo, 0) - v_ttvalor)) * 100 /
                      (p_mto_solicitado + v_ttvalor);
      --- calculo del nuevo capital (monto bruto -----------------------------------------
      v_tot_prestamo := round((p_mto_solicitado * 100 / v_por_ajuste),
                              v_redondeo);
      --- vuelvo a generar las cuotas y calcular los cargos ------------------------------
      if nvl(g_cod_error, '000') = '000' then
        pr_gen_cuo_iguales('S');
      end if;
      -- recalculo los cargos ------------------------------------------------------------
      if nvl(g_cod_error, '000') = '000' then
        pr_cal_cargos(v_recalculo);
      end if;
      while nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <>
            p_mto_solicitado loop
        v_por_ajuste := p_mto_solicitado -
                        (nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0));
        if v_por_ajuste = 1 then
          --para evitar que se cuelgue el proceso
          v_tot_prestamo := p_mto_solicitado + nvl(v_mto_cargo, 0);
        else
          v_tot_prestamo := v_tot_prestamo + v_por_ajuste;
          --- vuelvo a generar las cuotas y calcular los cargos ------------------------------
          if nvl(g_cod_error, '000') = '000' then
            pr_gen_cuo_iguales('S');
          end if;
          -- recalculo los cargos ------------------------------------------------------------
          if nvl(g_cod_error, '000') = '000' then
            pr_cal_cargos(v_recalculo);
          end if;
        end if;
      end loop;
      -- actualizo el total del prestamo -------------------------------------------------
      if nvl(g_cod_error, '000') = '000' then
        update pr_solicitudes
           set tot_prestamo = v_tot_prestamo--, estado = 'L'
         where nro_solicitud = v_nro_solicitud;
      end if;
      ------------------------------------------------------------------------------------
    end if;
    if v_recalculo = 'N' then
      -- busca la cantidad de registros en pr_sol_destinos para calcular un promedio con el monto del cheque.
      begin
        select count(*)
          into v_cantidad
          from pr_sol_destinos sd, pr_cta_prestamos cp
         where cp.nro_solicitud = sd.nro_solicitud
           and cp.nro_cuenta = v_nro_cuenta;
      exception
        when others then
          g_cod_error := '023';
          g_lugar     := 'Buscar datos de la tabla pr_sol_destinos ';
          g_msj_error := 'Error al buscar destinos ' || sqlerrm;
      end;
      --
      if v_cantidad = 0 then
        v_cantidad := 1;
        begin
          insert into pr_sol_destinos
            (nro_solicitud, tip_des_especifico, monto)
          values
            (v_nro_solicitud,
             3,
             decode(nvl(v_cod_mod_default, v_cod_mod_default),
                    660,
                    round(p_mto_solicitado / v_cantidad, 2),
                    v_tot_prestamo));
        exception
          when others then
            g_cod_error := '024';
            g_lugar     := 'Inserta PR_SOL_DESTINOS ';
            g_msj_error := 'Error al insertar destinos ' || sqlerrm;
        end;
      else
        --inserta en pr_sol_destinos
        for s in sol_destino(v_nro_cuenta) loop
          begin
            insert into pr_sol_destinos
              (nro_solicitud, tip_des_especifico, monto)
            values
              (v_nro_solicitud,
               decode(nvl(v_cod_mod_default, v_cod_mod_default),
                      660,
                      s.tip_des_especifico,
                      3),
               decode(nvl(v_cod_mod_default, v_cod_mod_default),
                      660,
                      round(p_mto_solicitado / v_cantidad, 2),
                      v_tot_prestamo));
          exception
            when others then
              g_cod_error := '025';
              g_lugar     := 'Inserta PR_SOL_DESTINOS ';
              g_msj_error := 'Error al insertar destinos ' || sqlerrm;
          end;
        end loop;
      end if;
      
      -- busca la cantidad de registros en pr_sol_garantias para calcular un promedio con el monto del cheque.
      /*v_cantidad := 0;
      begin
        select count(*)
          into v_cantidad
          from pr_sol_garantias g, pr_cta_prestamos cp
         where cp.nro_solicitud = g.nro_solicitud
           and cp.nro_cuenta = v_nro_cuenta;
      exception
        when others then
          g_cod_error := '026';
          g_lugar     := 'Busca PR_SOL_GARANTIAS ';
          g_msj_error := 'Error al buscar garantias ' || sqlerrm;
      end;
      if v_cantidad = 0 then
        v_cantidad := 1;
        -- obtiene el código de garantía "a sola firma".
        begin
          select cod_garantia
            into v_cod_garantia
            from pr_gar_tipos
           where descripcion like '%SOLA%FIRMA%';
          -- se inserta la garantía
          insert into pr_sol_garantias
            (nro_solicitud, cod_garantia, mto_aplicado)
          values
            (v_nro_solicitud,
             v_cod_garantia,
             decode(nvl(v_cod_mod_default, v_cod_mod_default),
                    660,
                    round(p_mto_solicitado / v_cantidad, 2),
                    v_tot_prestamo));
        exception
          when others then
            g_cod_error := '027';
            g_lugar     := 'Inserta PR_SOL_GARANTIAS ';
            g_msj_error := 'Error al insesrtar garantias ' || sqlerrm;
        end;
      else
        -- inserta en pr_sol_garantias
        for g in sol_garantia(v_nro_cuenta) loop
          begin
            insert into pr_sol_garantias
              (nro_solicitud, nro_garantia, cod_garantia, mto_aplicado)
            values
              (v_nro_solicitud,
               g.nro_garantia,
               g.cod_garantia,
               round(p_mto_solicitado / v_cantidad, 2));
          exception
            when others then
              g_cod_error := '028';
              g_lugar     := 'Inserta PR_SOL_GARANTIAS ';
              g_msj_error := 'Error al insesrtar garantias ' || sqlerrm;
          end;
        end loop;
      end if;
      begin
        select 'S', cod_per_invitado
          into v_tie_invitado, v_cod_per_invi
          from pr_pre_che_roga cp
         where cp.cod_per_solicitante = p_cod_persona
           and cp.cod_per_invitado is not null
           and cp.estado in ('V','I');
      exception
        when no_data_found then
          v_tie_invitado := 'N';
        when others then
          g_cod_error := '026';
          g_lugar     := 'Busca PR_SOL_GARANTIAS ';
          g_msj_error := 'Error al buscar garantias ' || sqlerrm;
      end;
      if v_tie_invitado = 'N' then
        -- obtiene el código de garantía "a sola firma".
        begin
          select cod_garantia
            into v_cod_garantia
            from pr_gar_tipos
           where descripcion like '%SOLA%FIRMA%';
          -- se inserta la garantía
          insert into pr_sol_garantias
            (nro_solicitud, cod_garantia, mto_aplicado)
          values
            (v_nro_solicitud,
             v_cod_garantia,
             decode(nvl(v_cod_mod_default, v_cod_mod_default),
                    660,
                    round(p_mto_solicitado / v_cantidad, 2),
                    v_tot_prestamo));
        exception
          when others then
            g_cod_error := '027';
            g_lugar     := 'Inserta PR_SOL_GARANTIAS ';
            g_msj_error := 'Error al insesrtar garantias ' || sqlerrm;
        end;
      else
        -- inserta en pr_sol_garantias
        v_cantidad := 1;
        begin
          select cod_garantia
            into v_cod_garantia
            from pr_gar_tipos
           where descripcion like '%CODEUDORES%';
          -- se inserta la garantía
          insert into pr_sol_garantias
            (nro_solicitud, cod_garantia, nro_garantia, mto_aplicado)
          values
            (v_nro_solicitud,
             v_cod_garantia,
             v_cod_per_invi,
             decode(nvl(v_cod_mod_default, v_cod_mod_default),
                    660,
                    round(p_mto_solicitado / v_cantidad, 2),
                    v_tot_prestamo));
        exception
          when others then
            g_cod_error := '027';
            g_lugar     := 'Inserta PR_SOL_GARANTIAS ';
            g_msj_error := 'Error al insesrtar garantias ' || sqlerrm;
        end;
      end if;
*/
      /*para calcular la diferencia de la solicitud*/
      pr_cal_dif_montos(v_nro_solicitud);
      
      -- finalmente inserto la cuota 0 ------------------------------------------------------
      begin
        insert into pr_sol_cuotas
          (nro_solicitud,
           nro_cuota,
           fec_vto_exacto,
           fec_vto_habil,
           val_interes,
           val_int_adelantado,
           mto_capital,
           sal_capital,
           dia_transcurridos,
           dia_interes,
           dia_periodo)
        values
          (v_nro_solicitud,
           0,
           v_fec_inicio,
           v_fec_inicio,
           0,
           0,
           0,
           v_tot_prestamo,
           0,
           0,
           0);
      exception
        when others then
          g_cod_error := '029';
          g_lugar     := 'Inserta PR_SOL_CUOTAS ';
          g_msj_error := 'Error al insesrtar cuotas ' || sqlerrm;
      end;
      -- inserto el registro de la tasa ----------------------------------------------------
      begin
        insert into pr_sol_tasas
          (nro_solicitud,
           fec_vigencia,
           val_tasa,
           tip_cobro,
           per_vencimiento)
        values
          (v_nro_solicitud,
           v_fec_inicio,
           v_val_tasa,
           'V',
           v_per_vencimiento);
      exception
        when others then
          g_cod_error := '030';
          g_lugar     := 'Inserta PR_SOL_TASAS ';
          g_msj_error := 'Error al insesrtar Tasas ' || sqlerrm;
      end;
    end if;
    --maximizacion de tasa da - 7311 carolina v.
    v_codi_tasa := 351;
    begin
      pag_gen.pr_obt_val_tasa(v_cod_modulo,
                              p_cod_modalidad,
                              v_cod_oficina,
                              null,
                              p_cod_moneda,
                              p_mto_solicitado,
                              'S',
                              v_codi_tasa /*out*/,
                              null,
                              v_fec_actual,
                              v_valor_tasa /*out*/,
                              v_fec_vigencia /*out*/,
                              v_tipo_valor /*out*/,
                              v_tipo /*out*/,
                              null);
    exception
      when others then
        v_max_tasa := 'X';
    end;
    if nvl(v_max_tasa, 'N') <> 'X' and
       (p_mto_solicitado between pag_gen.fu_obt_val_minimo and
        pag_gen.fu_obt_val_maximo) and
       nvl(fug_obt_pardinamico('VAL_INI_AUMTASA',
                               null,
                               null,
                               p_cod_moneda,
                               null),
           0) <> 0 then
      v_max_tasa := 'S';
    else
      v_max_tasa := 'N';
    end if;
    --controla que no maximize ambos, tasa y cargos
    if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),
             ',' || v_cod_mod_default || ',') > 0 and
       p_mto_solicitado <=
       fug_obt_pardinamico('MTO_SOL_MAX_ADM',
                           6,
                           v_cod_mod_default,
                           p_cod_moneda) then
      v_max_cargos := 'S';
    else
      v_max_cargos := 'N';
    end if;
    if nvl(v_max_cargos, 'N') = 'S' and nvl(v_max_tasa, 'N') = 'S' then
      g_cod_error := '037';
      g_lugar     := 'Max. de tasa y cargos se solapan';
      g_msj_error := 'Ajustar los parámetros de max. tasa y cargos' ||
                     sqlerrm;
    end if;
    if nvl(g_cod_error, '000') = '000' then
      if nvl(v_max_tasa, 'X') = 'S' then
        begin
          pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
        exception
          when others then
            g_cod_error    := '036';
            g_lugar        := 'Busca la TAE';
            g_msj_error    := 'Error al buscar la TAE ' || sqlerrm;
            v_tas_efectiva := 0;
        end;
        if nvl(v_tas_efectiva, 0) <> 0 then
          if nvl(v_tae, 0) > nvl(v_tas_efectiva, 0) and
             nvl(v_tasa_back, 0) > 0 then
            v_val_tasa  := nvl(v_tasa_back, 0);
            v_valor_aum := round((v_valor_aum / 2), 3);
            if (nvl(v_val_tasa + v_valor_aum, 0) between
               nvl(v_tas_minima, 0) and nvl(v_tas_maxima, 0)) then
              v_val_tasa := v_val_tasa + v_valor_aum;
              v_bandera  := 'N';
              goto recalculo;
            end if;
          elsif nvl(v_tae, 0) < nvl(v_tas_efectiva, 0) then
            if nvl(v_bandera, 'S') = 'S' then
              v_tasa_back := v_val_tasa;
              if (nvl(v_val_tasa + v_valor_aum, 0) between
                 nvl(v_tas_minima, 0) and nvl(v_tas_maxima, 0)) then
                v_val_tasa := v_val_tasa + v_valor_aum;
                goto recalculo;
              end if;
            end if;
          end if;
        end if;
      end if;
      
      --fin de maximización de tasa da-7311
      --
      -- maximización de cargos
      if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),
               ',' || v_cod_mod_default || ',') > 0 and
         p_mto_solicitado <=
         fug_obt_pardinamico('MTO_SOL_MAX_ADM',
                             6,
                             v_cod_mod_default,
                             p_cod_moneda) then
        pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
        if nvl(v_tas_efectiva, 0) <> 0 then
          if v_tae > nvl(v_tas_efectiva, 0) then
            if nvl(v_mto_adm_anterior, 0) > 0 then
              begin
                update pr_sol_cargos a
                   set a.monto            = v_mto_adm_anterior,
                       a.mto_mon_prestamo = v_mto_adm_anterior
                 where a.nro_solicitud = v_nro_solicitud
                   and a.cod_transaccion = 704;
              end;
            else
              v_fin_max := 'S';
            end if;
            if v_rec_tae = 'N' then
              g_cod_error := '040';
              g_lugar     := 'Controla TAE';
              g_msj_error := 'TAE de la propuesta supera el limite. Verificar Propuesta';
            end if;
            v_act_gas_anterior := 'S';
            goto seguir;
          else
            if (v_tas_efectiva - v_tae) >= 0.02 then
              if nvl(v_mto_aumento, 0) = 0 then
                v_mto_aumento := nvl(fug_obt_pardinamico('MTO_AUM_GAS_ADM',
                                                         null,
                                                         null,
                                                         p_cod_moneda,
                                                         null),
                                     0);
              end if;
              if v_mto_aumento > 0 then
                v_recalculo := 'S';
                v_rec_tae   := 'S';
                goto recalculo;
              end if;
            else
              v_fin_max := 'S';
            end if;
          end if;
        end if;
      end if;
      <<seguir>>
      if nvl(v_act_gas_anterior, 'N') = 'S' and nvl(v_fin_max, 'N') = 'N' then
        v_mto_aumento := round((v_mto_aumento / 2), 0);
        if v_mto_aumento > 100 then
          v_recalculo := 'S';
          goto recalculo;
        else
          v_act_gas_anterior := 'N';
          v_fin_max          := 'S';
          goto recalculo;
        end if;
      end if;
      --
      begin
        update pr_sol_garantias a
           set a.mto_aplicado = v_tot_prestamo
         where a.nro_solicitud = v_nro_solicitud;
      end;
      if instr(fug_obt_pardinamico('MAD_VAL_TAE_GAS_ADM'),
               ',' || v_cod_mod_default || ',') > 0 and
         p_mto_solicitado <=
         fug_obt_pardinamico('MTO_SOL_MAX_ADM',
                             6,
                             v_cod_mod_default,
                             p_cod_moneda) and (v_rec_tae = 'S') then
        -- borro la cuota 0 por si existe
        delete from pr_sol_cuotas
         where nro_solicitud = v_nro_solicitud
           and nro_cuota = 0;
        begin
          insert into pr_sol_cuotas
            (nro_solicitud,
             nro_cuota,
             fec_vto_exacto,
             fec_vto_habil,
             val_interes,
             val_int_adelantado,
             mto_capital,
             sal_capital,
             dia_transcurridos,
             dia_interes,
             dia_periodo)
          values
            (v_nro_solicitud,
             0,
             v_fec_inicio,
             v_fec_inicio,
             0,
             0,
             0,
             v_tot_prestamo,
             0,
             0,
             0);
        exception
          when others then
            g_cod_error := '039';
            g_lugar     := 'Inserta cuota 0 PR_SOL_CUOTAS ';
            g_msj_error := 'Error al insesrtar cuotas ' || sqlerrm;
        end;
        --
        pr_cal_dif_montos(v_nro_solicitud);
      end if;
      ----- actualizamos las planillas del pre-aprobado -------------------------------------
     /* begin
        update pr_pre_che_roga a
           set a.nro_solicitud = v_nro_solicitud --, a.estado = 'G'
         where a.cod_per_solicitante = p_cod_persona
           and a.estado in ('V','I');
      exception
        when others then
          g_cod_error := '031';
          g_lugar     := 'Actualiza pr_pre_che_roga ';
          g_msj_error := 'Error al actualizar pr_pre_che_roga ' || sqlerrm;
      end;*/
    end if;
  end if;
  -- inserto la clave.----------------------------------
  if nvl(g_cod_error, '000') = '000' then
    pr_ins_clave;
  end if;
  if nvl(g_cod_error, '000') = '000' then
    pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
    if nvl(v_tae, 0) > nvl(v_tas_efectiva, 0) then
      g_cod_error := '052';
      g_lugar     := 'Supera TAE';
      g_msj_error := 'Valor obtenido :' || v_tae || ' valor pizzarra:' ||
                     v_tas_efectiva;
    end if;
  end if;
  
  if nvl(g_cod_error, '000') = '000' then
    p_solicitud  := v_nro_solicitud;
    p_cuotas     := fu_obt_mto_cuota(v_nro_solicitud);
    p_cuotas_apx := fu_obt_mto_cuota_apx(v_nro_solicitud);
    p_cod_error  := 0;
    p_msj_error  := g_msj_error;
    prg_ins_log_programas('PRP_GEN_SOL_PRE_APR_CHE_ROG',
                          'MTO. SOL ' || p_mto_solicitado || ' CANT. CUO ' ||
                          p_can_cuotas || ' MONEDA ' || p_cod_moneda ||
                          ' MODALIDAD ' || p_cod_modalidad,
                          p_cod_persona,
                          null);
    commit;
  else
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
  end if;
end;
/