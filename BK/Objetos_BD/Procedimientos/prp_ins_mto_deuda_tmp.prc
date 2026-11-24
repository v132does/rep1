create or replace PROCEDURE    prp_ins_mto_deuda_tmp (P_NRO_CUENTA     IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL)is
Cursor cuotas is
 select
       a.nro_cuota,
       a.fec_vencimiento,
       nvl(a.mto_capital,0) + nvl(a.mto_interes,0) + nvl(a.mto_int_documentado,0) cuota,
       b.cod_oficina,
       b.cod_modulo,
       fug_obt_des_est_cta(b.cod_modulo, b.cod_modalidad, a.estado) estado,
   CASE
         WHEN a.fec_vencimiento<trunc(sysdate) and a.estado!='N' then
           'Vencida'
         WHEN a.fec_vencimiento>=trunc(sysdate) and a.estado!='N' then
           'Pendiente'
         ELSE
           'Pagado' end estadoDesc,
       'Cuota ' || a.nro_cuota descripcion,
       CASE
         WHEN round(a.fec_vencimiento - trunc(sysdate))<=31 and a.estado!='N' THEN
           'SI'
           ELSE
           'NO'
       END mostrar,
       a.fec_ult_pago fecha_pago,
       b.cod_moneda cod_moneda,
       m.descripcion desc_moneda,
       a.nro_cuenta,
       nvl(decode(a.estado, 'N', 0, b.dia_atraso),0) dia_atraso,
 (select round(nvl(pra.fec_ult_pago,nvl(pag_cal.FU_OBT_FEC_ACTUAL(b.cod_modulo),sysdate)) - pra.fec_vencimiento)
         from pr_cuotas pra
       where pra.nro_cuenta = a.nro_cuenta
        and pra.nro_cuota=a.nro_cuota
        and pra.estado<>'N'
        and pra.fec_vencimiento < nvl(pag_cal.FU_OBT_FEC_ACTUAL(b.cod_modulo),sysdate)) dia_atrasoDesc,
       a.mto_capital,
       nvl(a.mto_interes,0) + nvl(a.mto_int_documentado,0) mto_interes,
       (select nvl(sum(t.mto_cargo_cal),0) from pr_cobros t where t.nro_cuenta = a.nro_cuenta and t.nro_cuota = a.nro_cuota)  monto_cargo,
       nvl(sum(gc.monto), 0) monto_pagado,
       (select max(co1.hora)
          from pr_cobros co1
         where co1.nro_cuenta = a.nro_cuenta
           and co1.nro_cuota = a.nro_cuota
           and co1.fecha =
               (select max(co2.fecha)
                  from pr_cobros co2
                 where co2.nro_cuenta = co1.nro_cuenta
                   and co2.nro_cuota = co1.nro_cuota)) hora_pago,
       max(gc.nro_comprobante) nro_transaccion,
       decode(a.estado,'N','Pago Cuota', 'Cuota Pendiente') tip_operacion,
       (select gco.nro_cta_debito
          from ge_comprobantes gco
         where gco.nro_cuenta = a.nro_cuenta
           and gco.nro_cuota = a.nro_cuota
           and gco.nro_comprobante =
               (select max(g.nro_comprobante)
                  from ge_comprobantes g
                 where g.nro_cuenta = gco.nro_cuenta
                   and g.nro_cuota = gco.nro_cuota)) nro_cta_debito,
       fug_obt_paradicional((select max(gco.nro_cta_debito)
                              from ge_comprobantes gco
                             where gco.nro_cuenta = a.nro_cuenta
                               and gco.nro_cuota = a.nro_cuota
                               and gco.nro_comprobante =
                                   (select max(g.nro_comprobante)
                                      from ge_comprobantes g
                                     where g.nro_cuenta = gco.nro_cuenta
                                       and g.nro_cuota = gco.nro_cuota)),
                            'ALIAS_CTA') alias_cta_debito,
       (select nvl(sum(nvl(cuo.mto_capital,0) + nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0)), 0)
          from pr_cuotas cuo
         where cuo.nro_cuenta = a.nro_cuenta
           and cuo.nro_cuota > a.nro_cuota
           and cuo.nro_cuota > 0) +
       (select nvl(sum(nvl(cuo.sal_capital,0) + nvl(cuo.sal_interes,0) + nvl(cuo.mto_int_documentado,0)), 0)
          from pr_cuotas cuo
         where cuo.nro_cuenta = a.nro_cuenta
           and cuo.nro_cuota = a.nro_cuota
           and cuo.nro_cuota > 0) Sal_pend_pago,
       fug_obt_nom_cuenta(a.nro_cuenta) AccountName,
       null nro_cheque,
       null razon_social,
       b.can_cuotas,
       null nombre_banco_librador,
       null fec_emision,
       (select p.nom_completo
            from ge_cta_clientes c, ba_personas p, ba_cod_referencias r
            where c.cod_persona = p.cod_persona
            and dominio = 'RELACION'
            and c.relacion = 'P'
            and c.relacion = r.val_minimo
            AND c.NRO_CUENTA =((select gco.nro_cta_debito
          from ge_comprobantes gco
         where gco.nro_cuenta = a.nro_cuenta
           and gco.nro_cuota = a.nro_cuota
           and gco.nro_comprobante =
               (select max(g.nro_comprobante)
                  from ge_comprobantes g
                 where g.nro_cuenta = gco.nro_cuenta
                   and g.nro_cuota = gco.nro_cuota)))) titular_cta_debito,
       (select nvl(sum(nvl(cuo.mto_capital,0) + nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0) +
           nvl(cuo.mto_int_moratorio,0) + nvl(cuo.mto_int_mor_interes,0) +
           nvl(cuo.mto_int_mor_adelantado,0) + nvl(cuo.mto_int_punitorio,0) +
           nvl(cuo.mto_cargo,0) + nvl(cuo.mto_cargo_iva,0) + nvl(cuo.mto_impuesto,0) +
           nvl(cuo.mto_int_descontado,0)),0)
            from pr_cobros cuo
           where cuo.nro_cuenta = a.nro_cuenta
             and cuo.nro_cuota = a.nro_cuota
             and cuo.nro_cuota > 0) AS MTO_COBRO_CUOTA,
       b.cod_modalidad,
       b.fec_vencimiento fecha_vencimiento,
       b.fec_inicio,
       b.nro_solicitud
  from pr_cuotas        a,
       pr_cta_prestamos b,
       ba_monedas       m,
       pr_sol_cargos    sc,
       ge_comprobantes  gc
 where a.nro_cuenta = b.nro_cuenta
   and a.nro_cuenta = p_nro_cuenta
   and a.nro_cuota > 0
   and b.cod_moneda = m.cod_moneda
   and b.estado != 'N'
   and b.nro_solicitud = sc.nro_solicitud(+)
   and b.cod_modalidad not in (608,610)
   and not exists (select t.cod_transaccion
          from ge_transacciones t
         where t.cod_transaccion = sc.cod_transaccion
           and t.afecta = 'G')
   and a.nro_cuenta = gc.nro_cuenta(+)
   and a.nro_cuota = gc.nro_cuota(+)
   and gc.tip_comprobante(+) = 'PC'
 group by a.nro_cuota,
          a.fec_vencimiento,
          fug_obt_des_est_cta(b.cod_modulo, b.cod_modalidad, a.estado),
          a.nro_cuota,
          a.fec_ult_pago,
          b.cod_moneda,
          m.descripcion,
          a.nro_cuenta,
          b.dia_atraso,
          a.mto_capital,
          a.mto_interes,
          a.estado,
          b.cod_oficina,
          b.cod_modulo,
          b.can_cuotas,
          a.mto_int_documentado,
          b.cod_modalidad,
          b.fec_vencimiento,
          b.fec_inicio,
          b.nro_solicitud
UNION ALL
  select a.nro_cuota,
       a.fec_vencimiento,
       nvl(a.mto_capital,0) + nvl(a.mto_int_documentado,0) cuota,
       b.cod_oficina,
       b.cod_modulo,
       fug_obt_des_est_cta(b.cod_modulo, b.cod_modalidad, a.estado) estado,
  CASE
         WHEN a.fec_vencimiento<trunc(sysdate) and a.estado!='N' then
           'Vencida'
         WHEN a.fec_vencimiento>=trunc(sysdate) and a.estado!='N' then
           'Pendiente'
         ELSE
           'Pagado' end estadoDesc,
       'Cheque N° ' || cu.nro_cheque descripcion,
       CASE
         WHEN round(a.fec_vencimiento - trunc(sysdate))<=31 and a.estado!='N' THEN
           'SI'
           ELSE
           'NO'
       END mostrar,
       a.fec_ult_pago fecha_pago,
       b.cod_moneda cod_moneda,
       m.descripcion desc_moneda,
       a.nro_cuenta,
       nvl(decode(a.estado, 'N', 0, b.dia_atraso),0) dia_atraso,
       (select round(nvl(pra.fec_ult_pago,nvl(pag_cal.FU_OBT_FEC_ACTUAL(b.cod_modulo),sysdate)) - pra.fec_vencimiento)
         from pr_cuotas pra
       where pra.nro_cuenta = a.nro_cuenta
        and pra.nro_cuota=a.nro_cuota
        and pra.estado<>'N'
        and pra.fec_vencimiento < nvl(pag_cal.FU_OBT_FEC_ACTUAL(b.cod_modulo),sysdate)) dia_atrasoDesc,
       a.mto_capital,
       nvl(a.MTO_INT_DOCUMENTADO,0) mto_interes,
      (select nvl(sum(t.mto_cargo_cal),0) from pr_cobros t where t.nro_cuenta = a.nro_cuenta and t.nro_cuota = a.nro_cuota)  monto_cargo,
       nvl(sum(gc.monto), 0) monto_pagado,
       (select max(co1.hora)
          from pr_cobros co1
         where co1.nro_cuenta = a.nro_cuenta
           and co1.nro_cuota = a.nro_cuota
           and co1.fecha =
               (select max(co2.fecha)
                  from pr_cobros co2
                 where co2.nro_cuenta = co1.nro_cuenta
                   and co2.nro_cuota = co1.nro_cuota)) hora_pago,
       max(gc.nro_comprobante) nro_transaccion,
       decode(a.estado,'N','Pago Cuota', 'Cuota Pendiente') tip_operacion,
       (select gco.nro_cta_debito
          from ge_comprobantes gco
         where gco.nro_cuenta = a.nro_cuenta
           and gco.nro_cuota = a.nro_cuota
           and gco.nro_comprobante =
               (select max(g.nro_comprobante)
                  from ge_comprobantes g
                 where g.nro_cuenta = gco.nro_cuenta
                   and g.nro_cuota = gco.nro_cuota)) nro_cta_debito,
       fug_obt_paradicional((select max(gco.nro_cta_debito)
                              from ge_comprobantes gco
                             where gco.nro_cuenta = a.nro_cuenta
                               and gco.nro_cuota = a.nro_cuota
                               and gco.nro_comprobante =
                                   (select max(g.nro_comprobante)
                                      from ge_comprobantes g
                                     where g.nro_cuenta = gco.nro_cuenta
                                       and g.nro_cuota = gco.nro_cuota)),
                            'ALIAS_CTA') alias_cta_debito,
       (select nvl(sum(nvl(cuo.mto_capital,0) + nvl(cuo.MTO_INT_DOCUMENTADO,0)), 0)
          from pr_cuotas cuo
         where cuo.nro_cuenta = a.nro_cuenta
           and cuo.nro_cuota > a.nro_cuota
           and cuo.nro_cuota > 0) +
       (select nvl(sum(cuo.sal_capital + cuo.SAL_INT_DOCUMENTADO), 0)
          from pr_cuotas cuo
         where cuo.nro_cuenta = a.nro_cuenta
           and cuo.nro_cuota = a.nro_cuota
           and cuo.nro_cuota > 0) Sal_pend_pago,
       fug_obt_nom_cuenta(a.nro_cuenta) AccountName,
       cu.nro_cheque,
       lib.nom_completo razon_social,
       b.can_cuotas,
       ban.descripcion nombre_banco_librador,
       cu.fec_emision,
       (select p.nom_completo
            from ge_cta_clientes c, ba_personas p, ba_cod_referencias r
            where c.cod_persona = p.cod_persona
            and dominio = 'RELACION'
            and c.relacion = 'P'
            and c.relacion = r.val_minimo
            AND c.NRO_CUENTA =((select gco.nro_cta_debito
          from ge_comprobantes gco
         where gco.nro_cuenta = a.nro_cuenta
           and gco.nro_cuota = a.nro_cuota
           and gco.nro_comprobante =
               (select max(g.nro_comprobante)
                  from ge_comprobantes g
                 where g.nro_cuenta = gco.nro_cuenta
                   and g.nro_cuota = gco.nro_cuota)))) titular_cta_debito,
       (select nvl(sum(nvl(cuo.mto_capital,0) + nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0) +
           nvl(cuo.mto_int_moratorio,0) + nvl(cuo.mto_int_mor_interes,0) +
           nvl(cuo.mto_int_mor_adelantado,0) + nvl(cuo.mto_int_punitorio,0) +
           nvl(cuo.mto_cargo,0) + nvl(cuo.mto_cargo_iva,0) + nvl(cuo.mto_impuesto,0) +
           nvl(cuo.mto_int_descontado,0)),0)
            from pr_cobros cuo
           where cuo.nro_cuenta = a.nro_cuenta
             and cuo.nro_cuota = a.nro_cuota
             and cuo.nro_cuota > 0) AS MTO_COBRO_CUOTA,
       b.cod_modalidad,
       b.fec_vencimiento fecha_vencimiento,
       b.fec_inicio,
       b.nro_solicitud
  from pr_cuotas        a,
       pr_cta_prestamos b,
       ba_monedas       m,
       pr_sol_cargos    sc,
       ge_comprobantes  gc,
       ge_che_custodias  cu,
       ge_bancos         ban,
       pr_rel_chq_lib    rel,
       pr_chq_libradores lib
 where a.nro_cuenta = b.nro_cuenta
   and b.cod_modalidad in (608,610)
   and a.nro_cuota > 0
   and b.cod_moneda = m.cod_moneda
   and b.estado != 'N'
   and b.nro_solicitud = sc.nro_solicitud(+)
   and not exists (select t.cod_transaccion
          from ge_transacciones t
         where t.cod_transaccion = sc.cod_transaccion
           and t.afecta = 'G')
   and a.nro_cuenta = gc.nro_cuenta(+)
   and a.nro_cuota = gc.nro_cuota(+)
   and gc.tip_comprobante(+) = 'PC'
   and a.nro_cuenta = cu.nro_referencia(+)
   and a.nro_cuota = cu.nro_cuota(+)
   and ban.cod_banco(+) = cu.cod_banco
   and rel.nro_cheque(+) = cu.nro_cheque
   and lib.nro_documento(+) = rel.nro_documento
   and lib.cod_tip_documento(+) = rel.cod_tip_documento
   and b.nro_cuenta = a.nro_cuenta
   and b.nro_cuenta = p_nro_cuenta
 group by a.nro_cuota,
          a.fec_vencimiento,
          fug_obt_des_est_cta(b.cod_modulo, b.cod_modalidad, a.estado),
          a.fec_ult_pago,
          b.cod_moneda,
          m.descripcion,
          a.nro_cuenta,
          b.dia_atraso,
          a.mto_capital,
          a.mto_int_documentado,
          a.estado,
          b.cod_oficina,
          b.cod_modulo,
          ban.descripcion,
          cu.nro_cheque,
          lib.nom_completo,
          b.can_cuotas,
          cu.fec_emision,
          b.cod_modalidad,
          b.fec_vencimiento,
          b.fec_inicio,
          b.nro_solicitud
   order by 12,1;

----variables
  v_monto_cobrado      pr_cta_prestamos.sal_capital%type:=null;
  v_error              varchar2(1000);
  v_mensaje            varchar2(1000);
  v_tot_capital        pr_cta_prestamos.sal_capital%type;
  v_tot_interes        pr_cta_prestamos.sal_interes%type;
  v_tot_int_adelantado pr_cta_prestamos.sal_int_adelantado%type;
  v_tot_mora           pr_cta_prestamos.sal_interes%type;
  v_tot_mora_interes   pr_cta_prestamos.sal_interes%type;
  v_tot_mora_int_ade   pr_cta_prestamos.sal_interes%type;
  v_tot_punitorio      pr_cta_prestamos.sal_interes%type;
  v_tot_impuesto       pr_cta_prestamos.sal_interes%type;
  v_tot_cargo          pr_cta_prestamos.sal_capital%type;
  v_tot_cargo_iva      pr_cta_prestamos.sal_capital%type;
  v_tot_int_descontado pr_cuotas.sal_interes%TYPE;
  v_dia_mora           pr_cta_prestamos.dia_atraso%TYPE;
  v_renueva            varchar2(50);
  v_can_capital        varchar2(50);
  v_tip_operacion      varchar2(50);
  v_sal_pen_cuota      number;
  v_moratorio          number;
  v_punitorio          number;
  v_iva                number;
  -------------------
  v_imp_cuota     pr_sol_cargos.monto%type;
  v_val_tar_cargo pr_sol_cargos.val_tasa%type;
  v_car_sin_iva   pr_sol_cargos.val_tasa%type;
  v_nro_solicitud pr_solicitudes.nro_solicitud%type;
  v_car_seg_vida  pr_sol_cargos.monto%type;
  -------------------
  v_ent_seguro      ge_entes.cod_ente%type;
  v_cod_tasa        ge_movimientos.cod_tasa%type;
  v_val_tasa				ge_movimientos.val_tasa%type;
  v_fec_actual      date := pag_cal.fu_obt_fec_actual(6);
  v_imp_seg         ge_movimientos.monto%type;
  v_redondeo				number := 0;
  v_sal_cap_anterior pr_sol_cuotas.sal_cap_anterior%type;
  v_cod_mod_sum_dif  ge_par_dinamicos.val_parametro%type;
  v_est_modulo       ba_modulos.estado%type;
  v_fecha            ge_calendarios.fec_actual%type;
  v_primera_pend     boolean := true;
  v_fec_ven_ant      date := null;
  v_car_acum         number := 0;
  v_car_per          number := 0;

--funciona traida para poder solucionar el tema de conversion --

FUNCTION fu_obt_mto_car_mensual (p_nro_solicitud         pr_solicitudes.nro_solicitud%TYPE,
                                 p_nro_cuota              pr_sol_cuotas.nro_cuota%type,
                                 p_val_tas_comision       pr_sol_cargos.val_tasa%type,
                                 p_tipo                   varchar2)
RETURN NUMBER
IS
  v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
  v_tip_valor         ge_tasas.tip_valor%type;
  v_tipo              ge_tasas.tipo%type;
  v_fec_actual        date := pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_cod_mon_local			ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_redondeo number(2) :=0;
  v_mto_cargo         pr_sol_cargos.monto%type;
  v_cod_tas_fpy ge_tasas.cod_Tasa%type;
  v_val_tas_cob_fpy ge_tas_fechas.val_tasa%type;--valor de la tasa de cobertura de fogapy
  v_sal_Capital pr_sol_cuotas.sal_cap_anterior%type;
  v_dias            pr_sol_cuotas.dia_periodo%type;
  rg_soli pr_solicitudes%rowtype;
  rg_sim pr_simulaciones%rowtype;
 -- v_cod_mod_che_roga ge_par_dinamicos.val_parametro%Type := nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA'),668);
   v_cod_mod_che_roga      ge_par_dinamicos.val_parametro%type;
  v_fog_cuo_des_dos_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_DES_DOS_ANO');
  v_fog_cuo_has_dos_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_HAS_DOS_ANO');
  v_fog_cuo_des_tre_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_DES_TRE_ANO');
  v_fog_cuo_has_tre_ano ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('FOG_CUO_HAS_TRE_ANO');
  v_por_cob_gar_50 number;
  v_por_cob_gar_30 number;
  v_por_apl_com_fog ge_par_dinamicos.val_parametro%Type := fug_obt_pardinamico('POR_APL_COM_FOG');  
  v_cod_sexo ba_per_fisicas.cod_sexo%type;

BEGIN
  v_por_cob_gar_50 := to_number(nvl(fug_obt_pardinamico('POR_COB_GAR_50',668),0.5),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''');--0.8;--to_number(nvl(fug_obt_pardinamico('POR_COB_GAR_50',v_cod_mod_che_roga),0.5)); --80
  v_por_cob_gar_30 := to_number(nvl(fug_obt_pardinamico('POR_COB_GAR_30',668),0.8),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''');--0.5;--to_number(nvl(fug_obt_pardinamico('POR_COB_GAR_30',v_cod_mod_che_roga),0.3)); --50

  -- si viene desde la propuesta
  if p_tipo ='PRO' then
      BEGIN
       SELECT *
         INTO rg_soli
         FROM pr_solicitudes
       WHERE nro_solicitud = p_nro_solicitud;
     EXCEPTION
       WHEN OTHERS THEN
         return 0;
     END;
     --
     if rg_soli.cod_moneda <> v_cod_mon_local then
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', rg_soli.cod_modulo, rg_soli.cod_modalidad, rg_soli.cod_moneda, rg_soli.cod_oficina, rg_soli.cod_sub_modalidad);
     end if;
     v_cod_mod_che_roga:= nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', rg_soli.cod_modulo,rg_soli.cod_modalidad),'N'); 
     -- obtiene la tasa de cobertura de fogapy
     v_cod_tas_fpy := fug_obt_pardinamico('COD_TAS_COB_FOGAPY',rg_soli.cod_modulo, rg_soli.cod_modalidad, rg_soli.cod_moneda, rg_soli.cod_oficina, rg_soli.cod_sub_modalidad);
     -- diferentes condiciones para CHE ROGA
    -- if rg_soli.cod_modalidad = v_cod_mod_che_roga then
    if v_cod_mod_che_roga = 'S' then
       begin
         select sal_cap_anterior, dia_periodo
           into v_sal_capital, v_dias
           from pr_sol_cuotas
          where nro_solicitud = p_nro_solicitud
            and nro_cuota = p_nro_cuota;
       exception
         when no_data_found then
           return 0;
       end;
     else
    --- obtiene valor de tasa de cobertura
     pag_gen.pr_obt_val_tasa(rg_soli.cod_modulo, rg_soli.cod_modalidad,
                             null, null, rg_soli.cod_moneda,
                               null /*monto*/, 'S', v_cod_tas_fpy, null, --transaccion
                               v_fec_actual, v_val_tas_cob_fpy, v_fec_vigencia, v_tip_valor, v_tipo,rg_soli.cod_persona, rg_soli.cod_sub_modalidad);

      begin
        select sal_cap_anterior, dia_periodo
          into v_sal_capital, v_dias
          from pr_sol_cuotas
         where nro_solicitud = p_nro_solicitud
           and nro_cuota = p_nro_cuota + 1;
      exception
        when no_data_found then
          return 0;
      end;
     end if;
	begin
      select COD_SEXO
        into v_cod_sexo 	  
	    from ba_per_fisicas p , pr_solicitudes s
	   where 1=1
		 and s.cod_persona = p.cod_persona
		 and s.nro_solicitud = p_nro_solicitud;
      exception 
      when others then
      v_cod_sexo := 'M';
      end;
	  if upper(v_cod_sexo) = 'F' then 
	  v_por_apl_com_fog := v_por_apl_com_fog * 0.5;
	  end if;
       --dbms_output.put_line('v_cod_mod_che_roga: '||v_cod_mod_che_roga || ' rg_soli.cod_modalidad: '||rg_soli.cod_modalidad);
         --dbms_output.put_line('Cuo: '||p_nro_cuota || ' Capital: '||v_sal_Capital||' periodo: '||v_dias );
        if (p_nro_cuota between v_fog_cuo_des_dos_ano and v_fog_cuo_has_dos_ano and v_cod_mod_che_roga = 'S') then
            v_sal_capital := v_sal_capital * v_por_cob_gar_50; --80
            v_mto_cargo :=  round(((v_sal_capital * v_por_apl_com_fog /100) / 12 /** 1.10*/) ,v_redondeo); -- sin iva incluido porque en el cobro le sumaremos
        elsif (p_nro_cuota between v_fog_cuo_des_tre_ano and v_fog_cuo_has_tre_ano and v_cod_mod_che_roga = 'S') then
            v_sal_capital := v_sal_capital * v_por_cob_gar_30; -- 50
            v_mto_cargo :=  round(((v_sal_capital * v_por_apl_com_fog /100) / 12 /** 1.10*/) ,v_redondeo);
        else
            v_mto_cargo :=  round(((v_sal_capital* v_val_tas_cob_fpy/100) * p_val_tas_comision * v_dias / 36500) ,v_redondeo);
        end if;

        RETURN v_mto_cargo;
             --
  end if;

  --- si viene de la simulacion
  if p_tipo ='SIM' then
     BEGIN
       SELECT *
         INTO rg_sim
         FROM pr_simulaciones
       WHERE nro_simulacion = p_nro_solicitud;
     EXCEPTION
       WHEN OTHERS THEN
         return 0;
     END;
     --
     if rg_sim.cod_moneda <> v_cod_mon_local then
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', rg_sim.cod_modulo, rg_sim.cod_modalidad, rg_sim.cod_moneda, null, rg_sim.cod_sub_modalidad);
     end if;
     -- obtiene la tasa de cobertura de fogapy
     v_cod_tas_fpy := fug_obt_pardinamico('COD_TAS_COB_FOGAPY',rg_sim.cod_modulo, rg_sim.cod_modalidad, rg_sim.cod_moneda,null, rg_sim.cod_sub_modalidad);

    --- obtiene valor de tasa de Cobertura
     pag_gen.pr_obt_val_tasa(rg_sim.cod_modulo, rg_sim.cod_modalidad,
                             null, null, rg_sim.cod_moneda,
                               null /*monto*/, 'S', v_cod_tas_fpy, NULL, --Transaccion
                               v_fec_actual, v_val_tas_cob_fpy, v_fec_vigencia, v_tip_valor, v_tipo,rg_sim.cod_persona, rg_sim.cod_sub_modalidad);


      begin
          select sal_anterior, per_dias
            into v_sal_Capital, v_dias
            from pr_sim_cuotas
          where nro_simulacion = p_nro_solicitud
           and nro_cuota = p_nro_cuota + 1;
         exception
         when no_data_found then
             return 0;
         end;

         --dbms_output.put_line('Cuo: '||p_nro_cuota || ' Capital: '||v_sal_Capital||' periodo: '||v_dias );

        v_mto_cargo :=  ROUND(((v_sal_Capital* v_val_tas_cob_fpy/100) * p_val_tas_comision * v_dias / 36500) ,v_redondeo);

        RETURN v_mto_cargo;
  end if;


EXCEPTION
when others then
  raise_application_error(-20001,'Error al calcular cargo Fogapy '||sqlerrm);
END;
--termina funcion migrada de pap_fpy
BEGIN
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;

     DELETE FROM IT.PR_PRE_MTO_DEUDA_TMP P WHERE P.NRO_CUENTA = P_NRO_CUENTA;
     COMMIT;

      -- obtener datos de fogavi (una sola vez)
      begin
        select car.val_tasa, s.nro_solicitud
          into v_val_tar_cargo, v_nro_solicitud
          from pr_solicitudes s, pr_sol_cargos car
         where s.estado = 'A'
           and car.nro_solicitud = s.nro_solicitud
           and car.cod_transaccion = 703
           and exists (select 1
                  from pr_cta_prestamos cc
                 where cc.nro_solicitud = s.nro_solicitud
                   and cc.nro_cuenta = p_nro_cuenta);
      exception
        when no_data_found then
          v_val_tar_cargo := 0;
          v_nro_solicitud := 0;
        when others then
          v_val_tar_cargo := 0;
          v_nro_solicitud := 0;
      end;
      -- obtener datos de seguro de vida (una sola vez)
      begin
        select cod_ent_seguro
          into v_ent_seguro
          from pr_sol_cargos s
         where cod_transaccion = 1521
           and exists (select 1
                  from pr_cta_prestamos cc
                 where cc.nro_solicitud = s.nro_solicitud
                   and cc.nro_cuenta = p_nro_cuenta);
      exception
        when no_data_found then
          v_ent_seguro := null;
        when others then
          v_ent_seguro := null;
      end;

      v_cod_Tasa  := nvl(fug_obt_parentes(v_ent_seguro,'COD_TAS_SEG_VIDA'),0);

      /*****************************************************************************************/      
      -- Julio Cesar Leguizamon G.
      -- Si los modulos ya no estan abiertos debo calcular la deuda con la siguiente fecha habil
      /*****************************************************************************************/
      v_est_modulo := pae_cnf.fu_obt_est_modulo(6);
      IF v_est_modulo = 2 THEN
         v_fecha := pag_cal.fu_obt_fec_actual(6);
      else
         v_fecha := pag_cal.fu_obt_fec_proxima(6);
      end if;      

   FOR cu in cuotas LOOP
      -- Busco los datos de atrasos en las cuentas que tiene el client..
         v_cod_mod_sum_dif := nvl(fug_obt_pardinamico('COD_MOD_SUM_DIF',cu.cod_modulo,cu.cod_modalidad), 0);
         v_tot_capital := null;
         v_tot_interes := null;
         v_tot_int_adelantado := null;
         v_tot_mora := null;
         v_tot_mora_interes := null;
         v_tot_mora_int_ade := null;
         v_tot_punitorio := null;
         v_tot_impuesto := null;
         v_tot_cargo := null;
         v_tot_cargo_iva := null;
         v_tot_int_descontado := null;
         v_dia_mora := null;
         v_renueva := null;
         v_can_capital := null;
         v_tip_operacion := null;
         v_car_sin_iva := 0;
         v_imp_cuota   := 0;
         v_car_seg_vida := 0;
         v_sal_cap_anterior := 0;
         v_imp_seg := 0;
         -- llamada al procedimiento para obtener la deuda del préstamo
         pap_pre.pr_obt_deu_prestamo(P_NRO_CUENTA,
                                     v_fecha,
                                     cu.nro_cuota,
                                     cu.nro_cuota,
                                     cu.cod_oficina,
                                     v_monto_cobrado,
                                     v_error,
                                     v_mensaje,
                                     v_tot_capital,
                                     v_tot_interes,
                                     v_tot_int_adelantado,
                                     v_tot_mora,
                                     v_tot_mora_interes,
                                     v_tot_mora_int_ade,
                                     v_tot_punitorio,
                                     v_tot_impuesto,
                                     v_tot_cargo,
                                     v_tot_cargo_iva,
                                     v_tot_int_descontado,
                                     v_dia_mora,
                                     360,
                                     'C',--P_CANCELA,
                                     v_renueva,
                                     v_can_capital,
                                     v_tip_operacion);

             --('IM','IN','IA','MO','MI','PU','CA','CG')
          if cu.cod_modalidad = v_cod_mod_sum_dif then
             -- Columna "Deuda" del simulador: cargo crudo de PAP_PRE, sin PRP_OBT_CAR_PRESTAMO
             if cu.estadodesc <> 'Pagado' and not v_primera_pend then
               -- cuota posterior a la primera pendiente: PAP_PRE arrastra todos los cargos vigentes hasta su vencimiento, se deja solo el cargo de su periodo
               select nvl(sum(round(monto * 1.1, 0)), 0)
                 into v_car_acum
                 from pr_cta_gastos
                where nro_cuenta = p_nro_cuenta
                  and cod_modalidad = cu.cod_modalidad
                  and fec_ult_pago is null
                  and ((fec_ini_vigencia <= cu.fec_vencimiento or fec_ini_vigencia is null) and nro_solicitud is not null
                       or (fec_vencimiento >= v_fecha or fec_vencimiento is null) and nro_solicitud is null);
               select nvl(sum(round(monto * 1.1, 0)), 0)
                 into v_car_per
                 from pr_cta_gastos
                where nro_cuenta = p_nro_cuenta
                  and cod_modalidad = cu.cod_modalidad
                  and fec_ult_pago is null
                  and ((fec_ini_vigencia <= cu.fec_vencimiento and fec_ini_vigencia > v_fec_ven_ant and nro_solicitud is not null)
                       or (fec_vencimiento >= v_fecha or fec_vencimiento is null) and nro_solicitud is null);
               v_tot_cargo := greatest(nvl(v_tot_cargo, 0) - v_car_acum, 0) + v_car_per;
             end if;
             if cu.estadodesc <> 'Pagado' then
               v_primera_pend := false;
               v_fec_ven_ant := cu.fec_vencimiento;
             end if;

                v_sal_pen_cuota := nvl(v_tot_impuesto,0) +
                               (nvl(v_tot_interes,0) + nvl(v_tot_int_descontado,0))+
                                nvl(v_tot_int_adelantado, 0)+
                                nvl(v_tot_mora, 0)+
                                nvl(v_tot_mora_interes, 0) +
                                nvl(v_tot_punitorio, 0) +
                                nvl(v_tot_capital, 0);

             -- suma los cargos solo si no esta pagada la cuota
             if v_sal_pen_cuota > 0 then
                v_sal_pen_cuota := v_sal_pen_cuota + nvl(v_tot_cargo, 0);
             end if;
          else
                v_sal_pen_cuota := nvl(v_tot_impuesto,0) +
                               (nvl(v_tot_interes,0) + nvl(v_tot_int_descontado,0))+
                                nvl(v_tot_int_adelantado, 0)+
                                nvl(v_tot_mora, 0)+
                                nvl(v_tot_mora_interes, 0) +
                                nvl(v_tot_punitorio, 0) +
                                nvl(v_tot_capital, 0) +
                                nvl(v_tot_cargo, 0);

          end if;
             --MO
             v_moratorio    := nvl(v_tot_mora, 0);

             --PU
             v_punitorio    := nvl(v_tot_punitorio, 0);

             --CI
             v_iva          := nvl(v_tot_cargo_iva, 0);

         BEGIN
          INSERT INTO  IT.PR_PRE_MTO_DEUDA_TMP pr
            ( nro_cuota,
              fec_vencimiento,
              cuota,
              sal_pen_cuota,
              moratorio,
              punitorio,
              iva,
              estado,
              estadodesc,
              descripcion,
              mostrar,
              fecha_pago,
              cod_moneda,
              desc_moneda,
              nro_cuenta,
              dia_atraso,
              dia_atrasodesc,
              mto_capital,
              mto_interes,
              mto_cargo,
              mto_pagado,
              hora_pago,
              nro_transaccion,
              tip_operacion,
              nro_cta_debito,
              alias_cta_debito,
              sal_pen_pago,
              accountname,
              nro_cheque,
              razon_social,
              can_cuotas,
              nombre_banco_librador,
              fec_emision,
              titular_cta_debito,
              mto_cobro_cuota,
              tot_cargo)
          values
            (cu.nro_cuota,
             cu.fec_vencimiento,
             cu.cuota,
             v_sal_pen_cuota,
             v_moratorio,
             v_punitorio,
             v_iva,
             cu.estado,
             cu.estadodesc,
             cu.descripcion,
             cu.mostrar,
             cu.fecha_pago,
             cu.cod_moneda,
             cu.desc_moneda,
             cu.nro_cuenta,
             cu.dia_atraso,
             cu.dia_atrasodesc,
             cu.mto_capital,
             cu.mto_interes,
             cu.monto_cargo,
             cu.monto_pagado,
             cu.hora_pago,
             cu.nro_transaccion,
             cu.tip_operacion,
             cu.nro_cta_debito,
             cu.alias_cta_debito,
             cu.sal_pend_pago,
             cu.accountname,
             cu.nro_cheque,
             cu.razon_social,
             cu.can_cuotas,
             cu.nombre_banco_librador,
             cu.fec_emision,
             cu.titular_cta_debito,
             cu.mto_cobro_cuota,
             v_tot_cargo);
        EXCEPTION
          WHEN no_data_found THEN
               raise_application_error(-20000,
                            'prp_ins_mto_deuda_tmp_v2 Cuenta: ' || P_NRO_CUENTA || '-' ||
                            sqlerrm);
        END;
   END LOOP;
   COMMIT;
   EXCEPTION
          WHEN others THEN
            raise_application_error(-20000,
                            sqlerrm);

END;
/