CREATE OR REPLACE PROCEDURE IT.PRP_PRO_SEG_CUO_DISTR IS

--------------------------------------------------------------
--Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)-------
--Generacion movimientos y contabilizacion cobro a ganancias--
--------------------------------------------------------------

v_fec_actual      date := pae_cnf.fu_obt_fec_actual(6);
v_fec_ven_cuota pr_cuotas.fec_vencimiento%type;

-- Cursor de los cobros de cargos por seguro en cuotas de la fecha
Cursor c_cobros is
Select t.fecha, t.hora, t.nro_cuenta, t.cod_Transaccion, t.cod_moneda,
       c.cod_ent_seguro, t.monto, t.nro_secuencia, t.cod_usuario
       ,t.nro_documento, t.nro_documento2, t.nro_documento3, t.cod_modulo,
       t.cod_modalidad, t.cod_oficina, t.cod_tra_padre,
       t.cod_ofi_origen, t.cod_mod_padre, t.cod_mad_padre
  from Ge_sol_Cargos c, ge_movimientos t--, ba_tab_dat_adicionales d
 where t.cod_tra_padre in (360,362,359,364)  -- cobros de cuotas, cancelacion anticip. parcial, cancelacion total, debito automatico prestamos
   and t.estado = 'N'
   and t.reversado = 'N'
   AND T.COD_TRANSACCION = 1521
   and exists (select tr.cod_transaccion from ge_transacciones tr
                where tr.cod_modulo = t.cod_modulo
                  and tr.cod_modalidad = t.cod_modalidad
                  and tr.cod_transaccion = t.cod_Transaccion
                  and tr.afecta = 'G')   -- G= Afecta Seguro en cuotas
   and c.cod_modulo    = t.cod_modulo
   and c.cod_modalidad = t.cod_modalidad
   and c.cod_transaccion = t.cod_transaccion
   and exists (select 1
                 from ba_tab_dat_adicionales x, pr_solicitudes y, pr_cta_prestamos z
                where z.nro_cuenta = t.nro_cuenta
                  and y.nro_solicitud = z.nro_solicitud
                  and x.tab_relacion = 'PR_SOLICITUDES'
                  and x.parametro = 'PRE_IND_CUO_CAL_SEGURO'
                  and x.referencia = y.nro_solicitud
                  and x.val_parametro = 'S')
 order by nro_cuenta, cod_transaccion, fecha, hora; --BBVASOP-1022. CB.
--
v_importe         ge_movimientos.monto%type;
v_cuenta          pr_cta_prestamos.nro_cuenta%type;
v_cargo_iva       pr_sol_cargos.monto%type;
v_imp_restante    pr_sol_cargos.monto%type;
v_fec_vigencia    pr_cuotas.fec_vencimiento%type;
v_redondeo_ml     number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
v_redondeo        number;
v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
v_hora            ge_movimientos.hora%type;
v_cod_usuario     ge_movimientos.cod_usuario%type;
v_cod_mon_local   ge_movimientos.cod_moneda%type  := pag_gen.fu_obt_mon_local;
v_cotizacion      ge_movimientos.cotizacion%type;
v_cta_cre         ge_movimientos.nro_cuenta%type;
v_cod_tasa        ge_movimientos.cod_tasa%type;
v_cod_tas_seg_vida ge_movimientos.cod_tasa%type;
v_tas_prima       ge_movimientos.cod_tasa%type;
v_val_Tasa        ge_movimientos.val_tasa%type;
v_val_tas_prima   ge_movimientos.val_tasa%type;
v_val_tas_seg_vida ge_movimientos.val_tasa%type;
v_tip_Valor       ge_Tasas.Tip_Valor%type;
v_tipo            ge_Tasas.Tipo%type;
v_cod_ofi_origen  ba_usuarios.cod_oficina%type;
v_tra_padre       ge_transacciones.cod_transaccion%type;
v_cod_transaccion ge_transacciones.cod_transaccion%type;
v_cod_persona     ba_personas.cod_persona%type;
v_cod_gar_hipotecaria  number;
v_val_edilicio         pr_gar_hipotecarias.val_edilicio%type := 0;
v_val_edilicio_mon     pr_gar_hipotecarias.val_edilicio%type := 0;
v_tot_val_edilicio     pr_gar_hipotecarias.val_edilicio%type := 0;
v_mto_capital     number;
-- Variables de registro
r_pcpre           pr_cta_prestamos%rowtype;
r_gmovi           ge_movimientos%rowtype;
v_cod_rubro       cb_rubros.cod_rubro%type;
v_nro_cta_aux     ge_movimientos.nro_cuenta%type;
v_fec_vencimiento pr_cta_prestamos.fec_vencimiento%type;
v_fec_inicio      pr_cta_prestamos.fec_inicio%type;
v_cod_ent_seguro  pr_sol_cargos.cod_ent_seguro%type;
--------------------------------------------------------------------------------------------
function Fu_redondear_centena(p_importe in number)  return number is
v_imp number;
v_imp_cen number;

begin
  if  p_importe/100 = trunc(p_importe/100) then  -- esta bien
    v_imp_cen := p_importe;
  else
    v_imp := round(p_importe / 100);
    v_imp_cen := v_imp * 100;
    loop
      if v_imp_cen >= p_importe then
        exit;
      end if;
      v_imp_cen := v_imp_Cen + 100;
    end loop;
  End if;
  return v_imp_Cen;
END;

--------------------------------------------------------------------------------------------
--  EMPIEZA EL PROCEDIMIENTO
--------------------------------------------------------------------------------------------
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
  --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_hora := to_char(sysdate,'hh24:mi:ss');
  v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
------------------------------------------------------------------------------------------------
--4  ESTA PARTE ES PARA GENERAR LOS MOVIMIENTOS DE COBROS DE SEGUROS EN CUOTAS
-------------------------------------------------------------------------------------------------
 v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
 v_nro_secuencia := 0;
 For reg in C_cobros loop
    if v_nro_cta_aux is null then -- BBVASOP-1022 CB.
       v_nro_cta_aux := reg.nro_cuenta;
    elsif v_nro_cta_aux <> reg.nro_cuenta then
       v_nro_cta_aux := reg.nro_cuenta;
       v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
       v_nro_secuencia := 0;
    end if;

    --PN 01/06/2015 ITGF - Rev.Histórica no Genera Mov.Inversos - SC 16659
    v_tas_prima := null;
    v_val_tas_prima := null;
    --Traer los datos del prestamo
    pap_pre.pr_obt_dat_prestamo(reg.nro_cuenta, r_pcpre);
     v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
    --Traer codigo de persona
    begin
        v_cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
    exception
        when others then
          v_cod_persona := null;
    end;

   v_cod_gar_hipotecaria := fug_obt_pardinamico('COD_GAR_HIPOTECARIA',r_pcpre.cod_modulo,null,null,null);

   --Total Tasación de la Garantias Hipotecarias
   v_val_edilicio     := 0;
   v_val_edilicio_mon := 0;
   v_tot_val_edilicio := 0;

    if reg.cod_Transaccion = 1521 then

       /*ITGF - Diferencia - Rubro Seguro a Cobrar SC 10441 PMN: se obtienen las tasas
         ingresadas a fin de mes por prp_gen_car_seg_vida */
       Select fec_vencimiento
         into v_fec_ven_cuota
         from pr_cuotas
        where nro_cuenta = reg.nro_cuenta
          and nro_cuota = 0;

       begin
           select cod_ent_seguro
             into v_cod_ent_seguro
             from pr_sol_cargos s, pr_cta_prestamos p
            where nro_cuenta = reg.nro_cuenta
              and s.nro_solicitud = p.nro_solicitud
              and cod_transaccion = 1521;
       exception
            when no_data_found then
              v_cod_ent_seguro := FUG_OBT_ENT_SEGURO(6, reg.cod_modalidad, 'V');
            when others then
              raise_application_error(-20000,
                          'No encuentra código de Aseguradora. Verifique la solicitud del prestamo '||reg.nro_cuenta);
       end;

       v_mto_capital := r_pcpre.sal_cap_batch;  -- r_pcpre.sal_capital ;

       ------
       if fug_obt_tip_ente(v_cod_ent_seguro) = 'SE' then
            if r_pcpre.cod_moneda = v_cod_mon_local then
               v_cta_cre := fug_obt_parentes(v_cod_ent_seguro, 'NRO_CTA_SEG_MON_LOCAL');
               v_cod_rubro := fug_obt_parentes(v_cod_ent_seguro, 'COD_RUB_MON_LOCAL');
            else
               v_cta_cre := fug_obt_parentes(v_cod_ent_seguro, 'NRO_CTA_SEG_MON_FUERTE');
               v_cod_rubro := fug_obt_parentes(v_cod_ent_seguro, 'COD_RUB_MON_FUERTE');
            end if;
       end if;
    End if;
    -- Obtener fecha de inicio y vencimiento del prestamo.
    begin
      select a.fec_vencimiento, a.fec_inicio
        into v_fec_vencimiento, v_fec_inicio
        from pr_cta_prestamos a
       where a.nro_cuenta = reg.nro_cuenta;
    end;

    --Traer el monto para la distribucion--
           select a.cod_tas_ref1, a.val_tas_ref1, a.cod_tas_ref2, a.val_tas_ref2,
                  sum(nvl(a.monto,0)),
                  sum(nvl(a.mto_car_dis_com_seguro,0) + nvl(a.mto_car_dis_com_banco,0)),
                  sum(nvl(a.mto_car_dis_iva_seguro,0) + nvl(a.mto_car_dis_iva_banco,0))
             into v_cod_tas_seg_vida, v_val_tas_seg_vida, v_tas_prima, v_val_tas_prima,
                  v_imp_restante, v_importe, v_cargo_iva
             from pr_cta_gas_seguros a, pr_cta_gastos x
            where a.nro_cuenta = reg.nro_cuenta
              and a.estado = 'G'
              and x.nro_cuenta = a.nro_cuenta
              and x.fec_ult_pago = reg.fecha
              and x.hor_ult_pago = reg.hora
              and x.cod_ref_gasto = a.cod_ref_gasto
            group by a.cod_tas_ref1, a.val_tas_ref1, a.cod_tas_ref2, a.val_tas_ref2;

    -- OMM 20/09/2011 No generar Movimientos con monto Cero
    if nvl(abs(v_imp_restante),0) > 0 then

        v_tra_padre       := reg.cod_tra_padre;
        v_cod_transaccion := 1526;
        v_cod_ofi_origen  := reg.cod_ofi_origen;
        v_cod_usuario     := reg.cod_usuario;
        v_hora            := reg.hora;
        --Traer el maximo nro de secuencia del movimiento--
        select max(x.nro_secuencia)
          into v_nro_secuencia
          from ge_movimientos x
         where x.fecha = reg.fecha
           and x.hora = reg.hora
           and x.cod_usuario = reg.cod_usuario;


        -- Se mueve aca está porcion para obtener el cargo de iva  DYDMR-6544 16/10/2017
         -- Se calcula el I.V.A.   s/ el Cargo ---------------------------------
        v_cod_tasa := null;
        pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                0, 'N', v_cod_tasa, 517, --Transaccion
                                pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);

       -- Inserta el movimiento
        if v_nro_secuencia > 990 then
          v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
          v_nro_secuencia := 0;
        end if;
        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_tra_padre;  -- Cobro de Cargos por seguro en cuotas
        r_gmovi.cod_transaccion    := v_cod_transaccion; -- Debito por el porcentaje del cargo, cuenta suspenso
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas.1';
        r_gmovi.monto              := abs(v_imp_restante);
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(abs(v_imp_restante),2)*v_cotizacion,v_redondeo_ml);
        else
           v_cotizacion               := null;
           r_gmovi.cotizacion         := null;
           r_gmovi.mto_equ_local      := null;
        end if;
        r_gmovi.fec_valor          := v_fec_actual;
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
        r_gmovi.cod_mod_padre      := reg.cod_mod_padre;--r_pcpre.cod_modulo;
        r_gmovi.cod_mad_padre      := reg.cod_mad_padre;--r_pcpre.cod_modalidad;
        r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI:01/09/10
        r_gmovi.cod_tasa           := null;
        r_gmovi.val_tasa           := null;
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
           ----- ajuste---
        r_gmovi.nro_documento      := reg.nro_documento;
        r_gmovi.nro_documento2     := reg.nro_documento2;
        r_gmovi.nro_documento3     := reg.nro_documento3;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

        v_cod_transaccion := 1633;

        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_tra_padre;
        r_gmovi.cod_transaccion    := v_cod_transaccion;
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas';
        r_gmovi.monto              := v_importe;
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(v_importe,2)*v_cotizacion,v_redondeo_ml);
        else
           v_cotizacion               := null;
           r_gmovi.cotizacion         := null;
           r_gmovi.mto_equ_local      := null;
        end if;
        r_gmovi.fec_valor          := v_fec_actual;
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
        r_gmovi.cod_mod_padre      := reg.cod_mod_padre;
        r_gmovi.cod_mad_padre      := reg.cod_mad_padre;
        r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
        r_gmovi.cod_tasa           := null;
        r_gmovi.val_tasa           := null;
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
            ----- ajuste---
        r_gmovi.nro_documento      := reg.nro_documento;
        r_gmovi.nro_documento2     := reg.nro_documento2;
        r_gmovi.nro_documento3     := reg.nro_documento3;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

        --Genera el movimiento del IVA--
        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_tra_padre;  -- Cobro de Cargos por seguro en cuotas
        r_gmovi.cod_transaccion    := 1631;  -- Credito por el IVA del total del cargo
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas.3';
        r_gmovi.monto              := v_cargo_iva;
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(v_cargo_iva,2)*v_cotizacion,v_redondeo_ml);
        else
           v_cotizacion               := null;
           r_gmovi.cotizacion         := null;
           r_gmovi.mto_equ_local      := null;
        end if;
        r_gmovi.fec_valor          := v_fec_actual;
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
        r_gmovi.cod_mod_padre      := reg.cod_mod_padre;
        r_gmovi.cod_mad_padre      := reg.cod_mad_padre;
        r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
        r_gmovi.cod_tasa           := v_cod_tasa;
        r_gmovi.val_tasa           := v_val_tasa; --Se agrego el valor de la tasa para generar el libro de ventas JF 31/08/2011.-
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
          ----- ajuste---
        r_gmovi.nro_documento      := reg.nro_documento;
        r_gmovi.nro_documento2     := reg.nro_documento2;
        r_gmovi.nro_documento3     := reg.nro_documento3;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

        --Actualizar registro de pr_cta_gas_seguros--
        update pr_cta_gas_seguros x
            set x.fec_ult_pago = reg.fecha,
                x.hor_ult_pago = reg.hora
          where x.nro_cuenta = reg.nro_cuenta
            and exists (select 1
                          from pr_cta_gastos y
                         where y.nro_cuenta = x.nro_cuenta
                           and y.fec_ult_pago = reg.fecha
                           and y.hor_ult_pago = reg.hora
                           and y.cod_ref_gasto = x.cod_ref_gasto);
      end if;
    End loop;
Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar cargos en cuotas por seguros.  Error : '||v_cuenta||' '||sqlerrm);
END;
/

