CREATE OR REPLACE PROCEDURE IT.PRP_GEN_COM_SEG_VIDA/*(p_nro_cuenta pr_cta_prestamos.nro_cuenta%type default null)*/ IS
  -- PPCARCSV-1 - Automatización de Registros Contables de Comisiones de Seguro MAPFRE -- CN: 04/2016 --
  --1-) Buscar todos los los préstamos que se desembolsaron en la fecha y que tenga asociado el cobro de cargo 736- Comisión por Seguro de Vida.
  --2-) Se deberán excluir las modalidades que se encuentren parametrizadas en el parámetro dinámico MOD_EXC_COM_SEG_VIDA
  --
  v_fec_actual date := pag_cal.fu_obt_fec_actual(6);
  --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
  v_pre_hab_cal_seg_anual ge_par_dinamicos.val_parametro%type;

  -- Prestamos desembolsados en la fecha --
  cursor c_movimientos is
    select a.*
      from ge_movimientos a
     where a.cod_transaccion = 736
       and a.cod_modulo = 6 -- Modulo Préstamos
       and a.reversado = 'N'
       and a.cod_modalidad not in( select pd.cod_modalidad
                                     from ge_par_dinamicos pd
                                    where pd.parametro = 'MOD_EXC_COM_SEG_VIDA'
                                      and nvl(pd.val_parametro,'S') = 'S'
                                      and pd.cod_modulo = 6 )
       --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
       and (((nvl(v_pre_hab_cal_seg_anual,'N') = 'S') and (not exists (select 1
                                                                         from ba_tab_dat_adicionales x, pr_cta_prestamos z
                                                                        where x.tab_relacion = 'PR_SOLICITUDES'
                                                                          and x.parametro = 'PRE_PRO_CTA_SEG_ANUAL'
                                                                          and x.referencia = z.nro_solicitud
                                                                          and z.nro_cuenta = a.nro_cuenta
                                                                          and x.val_parametro = 'S')))
            OR (nvl(v_pre_hab_cal_seg_anual,'N') = 'N'));

  --reversados historicos
  cursor c_rev_historicas is
    select a.*
      from ge_movimientos a
     where a.cod_transaccion = 736
       and a.cod_modulo = 6 -- Modulo Préstamos
       and a.reversado = 'S'
       and a.fecha > a.fec_valor
       and a.cod_modalidad not in( select pd.cod_modalidad
                                     from ge_par_dinamicos pd
                                    where pd.parametro = 'MOD_EXC_COM_SEG_VIDA'
                                      and nvl(pd.val_parametro,'S') = 'S'
                                      and pd.cod_modulo = 6 )
       --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
       and (((nvl(v_pre_hab_cal_seg_anual,'N') = 'S') and (not exists (select 1
                                                                         from ba_tab_dat_adicionales x, pr_cta_prestamos z
                                                                        where x.tab_relacion = 'PR_SOLICITUDES'
                                                                          and x.parametro = 'PRE_PRO_CTA_SEG_ANUAL'
                                                                          and x.referencia = z.nro_solicitud
                                                                          and z.nro_cuenta = a.nro_cuenta
                                                                          and x.val_parametro = 'S')))
            OR (nvl(v_pre_hab_cal_seg_anual,'N') = 'N'));

  --v_hora            ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  --v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
  --v_ent_seguro         ge_entes.cod_ente%type;
  --v_cod_persona        ba_personas.cod_persona%type;
  --v_cod_ofi_origen     ba_usuarios.cod_oficina%type := FUG_OBT_OFI_USUARIO(USER);
  --v_cod_tas_seg_vida   ge_movimientos.cod_tasa%type;
  v_lugar              varchar2(100);
  --v_cod_ente           ge_entes.cod_ente%type := 132;--mapfre
  --v_nro_cta            ge_movimientos.nro_cuenta%type;
  --v_cod_tra_movimiento ge_transacciones.cod_transaccion%type;
  v_cod_oficina          ba_usuarios.cod_oficina%type := fug_obt_pardinamico('COD_OFI_COM_SEGURO');
  -- Variables de registro
  --r_pcpre              pr_cta_prestamos%rowtype;
  r_bamde              cb_asientos_det%rowtype;
  v_nro_asiento        cb_asientos_det.nro_asiento%type;
  v_rub_mapfre         cb_rubros.cod_rubro%type;
  v_rub_comision       cb_rubros.cod_rubro%type := fug_obt_pardinamico('COD_RUB_SEG_COMISION');
  v_nro_linea          cb_asientos_det.nro_linea%type := 0;
  v_val_cotizacion     cb_asientos_det.val_cotizacion%type;
  v_mto_mon_rubro      cb_asientos_det.mto_mon_rubro%type;
  v_mto_mon_local      cb_asientos_det.mto_mon_local%type;
  v_mto_mon_rubro_tot  cb_asientos_det.mto_mon_rubro%type;
  v_mto_mon_local_tot  cb_asientos_det.mto_mon_local%type;
  v_mto_ganancia       number(18,2);
  v_mto_ganancia_rub   number(18,2);
  v_val_tasa           number(18,4);
  v_plazo              number(18);
  v_mto_capital        pr_cta_prestamos.mto_capital%type;
  v_iva                number(2,1) := 1.1;

--------------------------------------------------------------------------------------------
procedure pr_obt_dat_cuenta(p_nro_cuenta varchar2) is
  v_existe      varchar2(1);
  v_modulo      pr_cta_prestamos.cod_modulo%type;
  v_modalidad   pr_cta_prestamos.cod_modalidad%type;
  v_tot_interes pr_cuotas.mto_interes%type;
  v_tot_documen pr_cuotas.mto_int_documentado%type;
  v_capital     pr_cta_prestamos.mto_capital%type;
  begin
    begin
      select (a.fec_vencimiento-a.fec_inicio),a.mto_capital,a.cod_modulo,a.cod_modalidad
        into v_plazo,v_capital,v_modulo,v_modalidad
        from pr_cta_prestamos a
       where a.nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        raise_application_error(-20000,
                                'No existe Cuenta ' || p_nro_cuenta);
      WHEN OTHERS THEN
        raise_application_error(-20001,
                                'Buscar plazo cuenta ' || p_nro_cuenta || '-' || SQLERRM);
    end;
    begin
      select 'S'
        into v_existe
        from GE_MODALIDADES
       where cod_modulo = v_modulo
         and cod_modalidad = v_modalidad
         and FUP_OBT_TIP_DESCUENTO(cod_modalidad) in ('F', 'C', 'D');
    exception
      when no_data_found then
        null;
      when others then
        raise_application_error(-20002,
                                'Buscar tipo de prestamo ' || p_nro_cuenta || '-' || SQLERRM);
    end;
    if v_existe = 'S' then
       --descuento de documento
       select nvl(sum(nvl(mto_interes,0)),0), nvl(sum(nvl(mto_int_documentado,0)),0)
         into v_tot_interes, v_tot_documen
         from pr_cuotas
        where nro_cuenta = p_nro_cuenta
          and nro_cuota  > 0;
       v_mto_capital := nvl(v_capital,0) + nvl(v_tot_interes,0) + nvl(v_tot_documen,0);
    else
       v_mto_capital := v_capital;
    end if;
  end;
--------------------------------
--  EMPIEZA EL PROCEDIMIENTO  --
--------------------------------
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
  /*desembolsos del dia*/
  v_pre_hab_cal_seg_anual := nvl(fug_obt_pardinamico('PRE_HAB_CAL_SEG_ANUAL'),'N');

  for reg in c_movimientos loop
    r_bamde := null;  --Inicializar registro movimiento
    v_nro_linea         := 0;
    v_mto_mon_rubro     := 0;
    v_mto_mon_local     := 0;
    v_mto_mon_rubro_tot := 0;
    v_mto_mon_local_tot := 0;
    v_mto_ganancia      := 0;
    v_mto_ganancia_rub  := 0;
    pr_obt_dat_cuenta(reg.nro_cuenta);
    /*
    -- Generar el asiento por el total del cargo por seguro. Debito
    */
    --buscar datos dependiendo de la moneda
    v_val_tasa := fug_obt_val_tasa(reg.cod_modulo,
                                   reg.cod_modalidad,
                                   null,
                                   null,
                                   reg.cod_moneda,
                                   v_plazo,
                                   null,
                                   339,
                                   null,
                                   v_fec_actual);
    if reg.cod_moneda = 'GS' then
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'GS');
       v_mto_mon_local_tot := reg.monto;
       --v_mto_mon_local_tot := round(((v_mto_capital*v_val_tasa)/100)/v_iva,0);
    else
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'USD');
       --v_val_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
       --v_mto_mon_rubro_tot := round(((v_mto_capital*v_val_tasa)/100)/v_iva,2);
       v_mto_mon_rubro_tot := reg.monto;
       v_mto_mon_local_tot := round(v_mto_mon_rubro_tot*reg.cotizacion,0);
    end if;
    --
    v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
    prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
    v_nro_linea := v_nro_linea + 1;
    --
    r_bamde.fecha          := reg.fecha;
    r_bamde.cod_oficina    := v_cod_oficina;
    r_bamde.nro_asiento    := v_nro_asiento;
    r_bamde.nro_linea      := v_nro_linea;
    r_bamde.cod_rubro      := v_rub_mapfre;
    r_bamde.referencia     := reg.nro_cuenta;
    r_bamde.tip_movimiento := 'D';
    r_bamde.mto_mon_rubro  := v_mto_mon_rubro_tot;--moneda extranjera
    r_bamde.mto_mon_local  := v_mto_mon_local_tot;--moneda local
    r_bamde.descripcion    := 'Desembolso Cuenta '||reg.nro_cuenta; --DYDMR-6535 - Incidencia SAU - Seguro en Transito MAPFRE
    --r_bamde.referencia
    r_bamde.protegido      := 'N';
    r_bamde.actualizado    := 'N';
    r_bamde.val_cotizacion := nvl(reg.cotizacion,0);
    r_bamde.distribuido    := 'N';
    r_bamde.ref_movimiento := reg.nro_documento4;
    pab_dep.PR_INS_ASI_MANUALES(r_bamde);

    /*
    -- Generar el asiento por la comision del cargo por seguro mapfre. Credito
    */
    --buscar datos dependiendo de la moneda
    --buscar la tasa
    v_val_tasa := fug_obt_val_tasa(reg.cod_modulo,
                                   reg.cod_modalidad,
                                   null,
                                   null,
                                   reg.cod_moneda,
                                   v_plazo,
                                   null,
                                   345,
                                   null,
                                   v_fec_actual);
    if reg.cod_moneda = 'GS' then
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'GS');
       --v_mto_mon_local := reg.monto;
       v_mto_mon_local := round(((v_mto_capital*v_val_tasa)/100)/v_iva,0);
    else
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'USD');
       --v_val_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
       v_mto_mon_rubro := round(((v_mto_capital*v_val_tasa)/100)/v_iva,2);
       v_mto_mon_local := round(v_mto_mon_rubro*reg.cotizacion,0);
    end if;

    v_nro_linea := v_nro_linea + 1;
    --
    r_bamde.fecha          := reg.fecha;
    r_bamde.cod_oficina    := v_cod_oficina;
    r_bamde.nro_asiento    := v_nro_asiento;
    r_bamde.nro_linea      := v_nro_linea;
    r_bamde.cod_rubro      := v_rub_mapfre;
    r_bamde.tip_movimiento := 'C';
    r_bamde.mto_mon_rubro  := v_mto_mon_rubro;--moneda extranjera
    r_bamde.mto_mon_local  := v_mto_mon_local;--moneda local
    r_bamde.referencia     := reg.nro_cuenta; --DYDMR-6535 - Incidencia SAU - Seguro en Transito MAPFRE
    r_bamde.descripcion    := 'Desembolso Cuenta '||reg.nro_cuenta; --DYDMR-6535 - Incidencia SAU - Seguro en Transito MAPFRE
    --r_bamde.referencia
    r_bamde.protegido      := 'N';
    r_bamde.actualizado    := 'N';
    r_bamde.val_cotizacion := nvl(reg.cotizacion,0);
    r_bamde.distribuido    := 'N';
    r_bamde.ref_movimiento := reg.nro_documento4;
    pab_dep.PR_INS_ASI_MANUALES(r_bamde);

    /*
    -- Generar el asiento para el rubro ganacia. Credito
    */
    if reg.cod_moneda = 'GS' then
       v_mto_ganancia := round(v_mto_mon_local_tot - v_mto_mon_local,0);
    else
       v_mto_ganancia_rub := round((v_mto_mon_rubro_tot - v_mto_mon_rubro),2);
       --v_mto_ganancia     := round((v_mto_mon_rubro_tot - v_mto_mon_rubro) * reg.cotizacion,0);
       v_mto_ganancia     := v_mto_mon_local_tot - v_mto_mon_local;
    end if;
    v_nro_linea := v_nro_linea + 1;
    --
    r_bamde.fecha          := reg.fecha;
    r_bamde.cod_oficina    := v_cod_oficina;
    r_bamde.nro_asiento    := v_nro_asiento;
    r_bamde.nro_linea      := v_nro_linea;
    r_bamde.cod_rubro      := v_rub_comision;
    r_bamde.tip_movimiento := 'C';
    r_bamde.mto_mon_rubro  := 0.00/*v_mto_ganancia_rub*/;--moneda extranjera--DYDMR-8332 - Rubro de Resultado en GS no debe tener saldo ME.-
    r_bamde.mto_mon_local  := v_mto_ganancia;--moneda local
    r_bamde.referencia     := reg.nro_cuenta;
    r_bamde.descripcion    := 'Desembolso Cuenta '||reg.nro_cuenta; --DYDMR-6535 - Incidencia SAU - Seguro en Transito MAPFRE
    --r_bamde.referencia
    r_bamde.protegido      := 'N';
    r_bamde.actualizado    := 'N';
    r_bamde.val_cotizacion := nvl(reg.cotizacion,0);
    r_bamde.distribuido    := 'N';
    r_bamde.ref_movimiento := reg.nro_documento4;
    pab_dep.PR_INS_ASI_MANUALES(r_bamde);
    --DYDMR-4322 09.09.16
    --insertar registros para invetario de resultado
    insert into cb_dat_asientos_det
      (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, nro_cuenta, cod_persona)
    values
      (reg.fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_rub_comision, 'C', reg.nro_cuenta, reg.cod_persona);
  end loop;

  /*reversiones de desembolsos historicos*/
  for reg in c_rev_historicas loop
    r_bamde := null;  --Inicializar registro movimiento
    v_nro_linea         := 0;
    v_mto_mon_rubro     := 0;
    v_mto_mon_local     := 0;
    v_mto_mon_rubro_tot := 0;
    v_mto_mon_local_tot := 0;
    v_mto_ganancia      := 0;
    v_mto_ganancia_rub  := 0;
    pr_obt_dat_cuenta(reg.nro_cuenta);
    /*
    -- Generar el asiento por el total del cargo por seguro. Credito
    */
    --buscar datos dependiendo de la moneda
    v_val_tasa := fug_obt_val_tasa(reg.cod_modulo,
                                   reg.cod_modalidad,
                                   null,
                                   null,
                                   reg.cod_moneda,
                                   v_plazo,
                                   null,
                                   339,
                                   null,
                                   v_fec_actual);
    if reg.cod_moneda = 'GS' then
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'GS');
       v_mto_mon_local_tot := abs(reg.monto);
       --v_mto_mon_local_tot := round(((v_mto_capital*v_val_tasa)/100)/v_iva,0);
    else
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'USD');
       --v_val_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
       --v_mto_mon_rubro_tot := round(((v_mto_capital*v_val_tasa)/100)/v_iva,2);
       v_mto_mon_rubro_tot := abs(reg.monto);
       v_mto_mon_local_tot := round(v_mto_mon_rubro_tot*reg.cotizacion,0);
    end if;
    --
    v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
    prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
    v_nro_linea := v_nro_linea + 1;
    --
    r_bamde.fecha          := reg.fecha;
    r_bamde.cod_oficina    := v_cod_oficina;
    r_bamde.nro_asiento    := v_nro_asiento;
    r_bamde.nro_linea      := v_nro_linea;
    r_bamde.cod_rubro      := v_rub_mapfre;
    r_bamde.tip_movimiento := 'C';
    r_bamde.mto_mon_rubro  := v_mto_mon_rubro_tot;--moneda extranjera
    r_bamde.mto_mon_local  := v_mto_mon_local_tot;--moneda local
    r_bamde.referencia     := reg.nro_cuenta;
    r_bamde.descripcion    := 'Desembolso Cuenta '||reg.nro_cuenta; --DYDMR-6535 - Incidencia SAU - Seguro en Transito MAPFRE
    --r_bamde.referencia
    r_bamde.protegido      := 'N';
    r_bamde.actualizado    := 'N';
    r_bamde.val_cotizacion := nvl(reg.cotizacion,0);
    r_bamde.distribuido    := 'N';
    r_bamde.ref_movimiento := reg.nro_documento4;
    pab_dep.PR_INS_ASI_MANUALES(r_bamde);

    /*
    -- Generar el asiento por la comision del cargo por seguro mapfre. Debito
    */
    --buscar datos dependiendo de la moneda
    --buscar la tasa
    v_val_tasa := fug_obt_val_tasa(reg.cod_modulo,
                                   reg.cod_modalidad,
                                   null,
                                   null,
                                   reg.cod_moneda,
                                   v_plazo,
                                   null,
                                   345,
                                   null,
                                   v_fec_actual);
    if reg.cod_moneda = 'GS' then
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'GS');
       --v_mto_mon_local := reg.monto;
       v_mto_mon_local := round(((v_mto_capital*v_val_tasa)/100)/v_iva,0);
    else
       v_rub_mapfre := fug_obt_pardinamico('COD_RUB_SEG_ENTE', NULL, NULL, 'USD');
       --v_val_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
       v_mto_mon_rubro := round(((v_mto_capital*v_val_tasa)/100)/v_iva,2);
       v_mto_mon_local := round(v_mto_mon_rubro*reg.cotizacion,0);
    end if;

    v_nro_linea := v_nro_linea + 1;
    --
    r_bamde.fecha          := reg.fecha;
    r_bamde.cod_oficina    := v_cod_oficina;
    r_bamde.nro_asiento    := v_nro_asiento;
    r_bamde.nro_linea      := v_nro_linea;
    r_bamde.cod_rubro      := v_rub_mapfre;
    r_bamde.tip_movimiento := 'D';
    r_bamde.mto_mon_rubro  := v_mto_mon_rubro;--moneda extranjera
    r_bamde.mto_mon_local  := v_mto_mon_local;--moneda local
    r_bamde.referencia     := reg.nro_cuenta;
    r_bamde.descripcion    := 'Desembolso Cuenta '||reg.nro_cuenta; --DYDMR-6535 - Incidencia SAU - Seguro en Transito MAPFRE
    --r_bamde.referencia
    r_bamde.protegido      := 'N';
    r_bamde.actualizado    := 'N';
    r_bamde.val_cotizacion := nvl(reg.cotizacion,0);
    r_bamde.distribuido    := 'N';
    r_bamde.ref_movimiento := reg.nro_documento4;
    pab_dep.PR_INS_ASI_MANUALES(r_bamde);

    /*
    -- Generar el asiento para el rubro ganacia. Debito
    */
    if reg.cod_moneda = 'GS' then
       v_mto_ganancia := round(v_mto_mon_local_tot - v_mto_mon_local,0);
    else
       v_mto_ganancia_rub := round((v_mto_mon_rubro_tot - v_mto_mon_rubro),2);
       --v_mto_ganancia     := round((v_mto_mon_rubro_tot - v_mto_mon_rubro) * reg.cotizacion,0);
       v_mto_ganancia     := v_mto_mon_local_tot - v_mto_mon_local;
    end if;
    v_nro_linea := v_nro_linea + 1;
    --
    r_bamde.fecha          := reg.fecha;
    r_bamde.cod_oficina    := v_cod_oficina;
    r_bamde.nro_asiento    := v_nro_asiento;
    r_bamde.nro_linea      := v_nro_linea;
    r_bamde.cod_rubro      := v_rub_comision;
    r_bamde.tip_movimiento := 'D';
    r_bamde.mto_mon_rubro  := 0.00/*v_mto_ganancia_rub*/;--moneda extranjera--DYDMR-8332 - Rubro de Resultado en GS no debe tener saldo ME.-
    r_bamde.mto_mon_local  := v_mto_ganancia;--moneda local
    r_bamde.referencia     := reg.nro_cuenta;
    r_bamde.descripcion    := 'Desembolso Cuenta '||reg.nro_cuenta; --DYDMR-6535 - Incidencia SAU - Seguro en Transito MAPFRE
    --r_bamde.referencia
    r_bamde.protegido      := 'N';
    r_bamde.actualizado    := 'N';
    r_bamde.val_cotizacion := nvl(reg.cotizacion,0);
    r_bamde.distribuido    := 'N';
    r_bamde.ref_movimiento := reg.nro_documento4;
    pab_dep.PR_INS_ASI_MANUALES(r_bamde);
    --DYDMR-4322 09.09.16
    --insertar registros para invetario de resultado
    insert into cb_dat_asientos_det
      (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, nro_cuenta, cod_persona)
    values
      (reg.fecha, 31, v_nro_asiento, v_nro_linea, v_rub_comision, 'D', reg.nro_cuenta, reg.cod_persona);
  end loop;
Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar cargos por seguro de Vidas.'||' - '||v_lugar||' Error : '||sqlerrm);
END;
/

