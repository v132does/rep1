create or replace procedure it.prg_obt_dat_cuentas(p_nro_cuenta        ge_cuentas.nro_cuenta%type,
                                                   p_producto          out ge_modalidades.descripcion%type,
                                                   p_denominacion      out ah_cta_vistas.denominacion%type,
                                                   p_moneda            out ba_monedas.descripcion%type,
                                                   p_sal_disponible    out ah_cta_vistas.sal_total%type,
                                                   p_sal_retenido      out ah_cta_vistas.sal_total%type,
                                                   p_val_tas_tae       out ge_tas_fechas.val_tasa%type,
                                                   p_val_tas_nom       out ge_tas_fechas.val_tasa%type,
                                                   p_fec_apertura      out ah_cta_vistas.fec_apertura%type,
                                                   p_sal_sobregiro     out cc_cta_corrientes.sal_total%type,
                                                   p_can_dia_sob       out cc_sobregiros_res.can_dias%type,
                                                   p_nro_tarjeta       out varchar2,
                                                   p_vto_tarjeta       out ah_tar_debitos.fec_vencimiento%type,
                                                   p_alias             out ge_cta_dat_adicionales.val_parametro%type,
                                                   p_dep_pendientes    out ah_retenciones.monto%type,
                                                   p_ext_pendientes    out ah_retenciones.monto%type,
                                                   p_sal_bloqueado     out ah_cta_vistas.sal_bloqueado%type,
                                                   p_lin_tot_sobregiro out cc_cta_corrientes.sal_total%type,
                                                   p_tas_int_sobregiro out cc_lin_sobregiros.val_tas_interes%type,
                                                   p_cod_moneda        out ba_monedas.cod_moneda%type,
                                                   p_sal_minimo        out ah_cta_vistas.sal_minimo%type,
                                                   p_tra_atm_sin_costo out number,
                                                   p_cos_atm_prop      out ah_cta_vistas.sal_minimo%type,
                                                   p_cos_atm_otro      out ah_cta_vistas.sal_minimo%type,
                                                   p_cod_error         out number,
                                                   p_men_error         out varchar2) is
  v_cod_modulo        ba_modulos.cod_modulo%type;
  v_cod_modalidad     ge_modalidades.cod_modalidad%type;
  v_cod_oficina       ba_oficinas.cod_oficina%type;
  v_cta_oficina       ah_cta_vistas.cod_oficina%type;
  v_cod_moneda        ba_monedas.cod_moneda%type;
  v_sal_promedio      ah_sal_mensuales.sal_fin_mes%type;
  v_fec_anterior      ge_calendarios.fec_anterior%type;
  v_tas_personalizada ah_cta_vistas.tas_personalizada%type;
  v_cod_tasa          ah_cta_vistas.cod_tasa%type;
  v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
  v_sal_acumulado     cc_sal_mensuales.sal_fin_mes%type;
  v_can_dia_acumulado cc_sal_mensuales.can_dia_acumulado%type;
  v_nro_emision       ah_tar_debitos.nro_emision%type;
  v_nro_cuenta        ah_tar_debitos.nro_cuenta%type;
  v_pro_correcto      number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                    0);
  v_cod_persona       ah_tar_debitos.cod_persona%type;
  v_persona           ge_cta_clientes.cod_persona%type;
  v_dep_pendientes    ah_cta_vistas.sal_total%type := 0;
  v_est_proceso       ba_modulos.estado%TYPE;
begin
  p_cod_error := v_pro_correcto;
  p_men_error := 'Operacion Exitosa';

  begin
    select c.cod_modulo, c.cod_modalidad,cc.cod_persona
      into v_cod_modulo, v_cod_modalidad,v_persona
      from ge_cuentas c,ge_cta_clientes cc, ba_personas pe
     where c.nro_cuenta = p_nro_cuenta
     and cc.nro_cuenta=c.nro_cuenta
     and cc.relacion = 'P'
     and pe.cod_persona = cc.cod_persona
     and pe.tipo = 'F';
  exception
    when no_data_Found then
      p_cod_error := 1016;
      p_men_error := 'Numero de cuenta invalido.';
    when others then
      p_cod_error := 1016;
      p_men_error := 'Error al buscar la cuenta. ' || sqlerrm;
  end;
  v_est_proceso := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
  if p_cod_error = v_pro_correcto then
    if v_cod_modalidad in (31, 38, 39, 331, 332, 334) then
      begin
        select v.denominacion,
               v.fec_apertura,
               mo.descripcion tip_cuenta,
               m.cod_moneda,
               m.descripcion moneda,
               nvl(sal_total, 0) - nvl(sal_retenido, 0) -
               nvl(sal_bloqueado, 0) - nvl(mto_deb_pendientes, 0) +
               nvl(mto_cre_pendientes, 0) sal_disponible,
               nvl(sal_retenido, 0),
               v.cod_moneda,
               tas_personalizada,
               cod_tasa,
               fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA'),
               nvl(sal_bloqueado, 0),
               nvl(v.mto_cre_pendientes, 0),
               nvl(v.mto_deb_pendientes, 0),
               nvl(fug_obt_parentes(v.cod_ente, 'CAN_MAX_EXT_PRO_ATM'), 0),
               nvl(fug_obt_parentes(v.cod_ente, 'COS_ATM_PROPIO'), 0),
               nvl(fug_obt_parentes(v.cod_ente, 'COS_ATM_OTRO'), 0),
               v.cod_oficina
          into p_denominacion,
               p_fec_apertura,
               p_producto,
               p_cod_moneda,
               p_moneda,
               p_sal_disponible,
               p_sal_retenido,
               v_cod_moneda,
               v_tas_personalizada,
               v_cod_tasa,
               p_alias,
               p_sal_bloqueado,
               p_dep_pendientes,
               p_ext_pendientes,
               p_tra_atm_sin_costo,
               p_cos_atm_prop,
               p_cos_atm_otro,
               v_cta_oficina
          from ah_cta_vistas v, ba_monedas m, ge_modalidades mo
         where v.nro_cuenta = p_nro_cuenta
           and v.estado in ('A', 'I', 'N', 'S', 'B', 'D', 'T')
           and v.cod_moneda = m.cod_moneda
           and v.cod_modulo = mo.cod_modulo
           and v.cod_modalidad = mo.cod_modalidad;

           p_sal_minimo:=FUG_OBT_SAL_MIN_PACTADO(v_cod_moneda,v_persona,v_cod_modulo,v_cod_modalidad,v_cta_oficina);

      exception
        when others then
          p_cod_error := 1016;
          p_men_error := 'Error al buscar la cuenta. ' || sqlerrm;
      end;
      IF v_est_proceso not in (2,6) THEN
        begin
          SELECT nvl(sal_retenido, 0) sal_retenido,
                 nvl(sal_bloqueado, 0) sal_bloqueado,
                 nvl(sal_total, 0) - nvl(mto_deb_pendientes, 0) + nvl(mto_cre_pendientes, 0) +
                 nvl(mto_cre_a_confirmar, 0) total
            INTO p_sal_retenido,
                 p_sal_bloqueado,
                 p_sal_disponible
            FROM ah_cta_vistas_noc
           WHERE nro_cuenta = p_nro_cuenta;
        exception
          when no_data_found then
            null;
          when others then
            p_cod_error := 1018;
            p_men_error := 'Error al buscar la Cuenta en noc. ' || sqlerrm;
        end;
      END IF;
      ---------movimientos de depositos pendientes---------------
      select nvl(sum(amount),0)
        into v_dep_pendientes
        from (select nvl(c.monto, 0) amount
                from ge_movimientos c
               where c.cod_tra_padre in (352, 393)
                 and c.nro_cuenta is not null
                 and c.nro_cuenta = p_nro_cuenta
                 and c.estado = 'P'
              union all
              /*Historico*/
              select nvl(c.monto, 0) amount
                from ah_movimientos_his c
               where c.cod_tra_padre in (352, 393)
                 and c.nro_cuenta is not null
                 and c.nro_cuenta = p_nro_cuenta
                 and c.estado = 'P');

      p_dep_pendientes := p_dep_pendientes + v_dep_pendientes;
      ---------
      v_fec_anterior := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,
                                                   v_cod_oficina,
                                                   1);

      begin
        SELECT nvl(sal_acu_diario, 0) /
               decode(nvl(can_dia_acumulado, 0), 0, 1, can_dia_acumulado) promedio
          into v_sal_promedio
          FROM ah_sal_mensuales
         WHERE ano = to_number(to_char(v_fec_anterior, 'YYYY'))
           AND mes = to_number(to_char(v_fec_anterior, 'MM'))
           AND nro_cuenta = p_nro_cuenta;
      exception
        when others then
          v_sal_promedio := 0;
      end;

      begin
        p_val_tas_nom := FUG_OBT_VAL_TASA(v_cod_modulo,
                                          v_cod_modalidad,
                                          v_cod_oficina,
                                          p_nro_cuenta,
                                          v_cod_moneda,
                                          v_sal_promedio,
                                          v_tas_personalizada,
                                          v_cod_tasa,
                                          NULL,
                                          v_fec_actual);
      exception
        when others then
          p_cod_error := 1041;
          p_men_error := 'No se encuentra la tasa TAN. ' || 'Modulo:' ||
                         v_cod_modulo || ' Modalidad:' || v_cod_modalidad ||
                         ' Oficina:' || v_cod_oficina || ' Moneda:' ||
                         v_cod_moneda || ' Promedio:' || v_sal_promedio ||
                         ' Tasa Personalizada:' || v_tas_personalizada ||
                         ' Tasa:' || v_cod_tasa || ' Fecha:' ||
                         v_fec_actual;
      end;

      -- Buscamos tarjeta si tiene
      BEGIN
        SELECT MAX(t.nro_emision),
               t.fec_vencimiento,
               t.nro_cuenta,
               t.cod_persona
          INTO v_nro_emision, p_vto_tarjeta, v_nro_cuenta, v_cod_persona
          FROM ah_tar_debitos t, ba_cod_referencias b
         WHERE t.nro_cuenta = p_nro_cuenta
           AND t.cod_est_solicitud = b.val_minimo
           AND b.dominio = 'EST_TAR_DEB_EXT'
         GROUP BY t.fec_vencimiento, t.nro_cuenta, t.cod_persona;
      exception
        when others then
          v_nro_emision := null;
          p_vto_tarjeta := null;
          v_nro_cuenta  := p_nro_cuenta;
          v_cod_persona := null;
      END;

      if p_cod_error = v_pro_correcto then
        p_val_tas_tae := p_val_tas_nom;
      end if;
      p_sal_sobregiro := 0;
      p_can_dia_sob   := 0;
    elsif v_cod_modalidad = 41 then
      begin
        select v.denominacion,
               v.fec_apertura,
               mo.descripcion tip_cuenta,
               m.cod_moneda,
               m.descripcion moneda,
               nvl(sal_total, 0) - nvl(sal_retenido, 0) -
               nvl(sal_bloqueado, 0) - nvl(mto_deb_pendientes, 0) +
               nvl(mto_cre_pendientes, 0) sal_disponible,
               nvl(sal_retenido, 0),
               v.cod_moneda,
               tas_personalizada,
               nvl(v.sal_minimo, 0),
               nvl(v.mto_cre_pendientes, 0),
               nvl(v.mto_deb_pendientes, 0),
               nvl(fug_obt_parentes(v.cod_ente, 'CAN_MAX_EXT_PRO_ATM'), 0),
               v.sal_bloqueado,
               nvl(fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA'),
                   p_nro_cuenta),
               nvl(fug_obt_parentes(v.cod_ente, 'COS_ATM_PROPIO'), 0),
               nvl(fug_obt_parentes(v.cod_ente, 'COS_ATM_OTRO'), 0),
               v.cod_oficina
          into p_denominacion,
               p_fec_apertura,
               p_producto,
               p_cod_moneda,
               p_moneda,
               p_sal_disponible,
               p_sal_retenido,
               v_cod_moneda,
               v_tas_personalizada,
               p_sal_minimo,
               p_dep_pendientes,
               p_ext_pendientes,
               p_tra_atm_sin_costo,
               p_sal_bloqueado,
               p_alias,
               p_cos_atm_prop,
               p_cos_atm_otro,
               v_cta_oficina
          from cc_cta_corrientes v, ba_monedas m, ge_modalidades mo
         where v.nro_cuenta = p_nro_cuenta
           and v.estado in ('A', 'I', 'N')
           and v.cod_moneda = m.cod_moneda
           and v.cod_modulo = mo.cod_modulo
           and v.cod_modalidad = mo.cod_modalidad;

           p_sal_minimo:=FUG_OBT_SAL_MIN_PACTADO(v_cod_moneda,v_persona,v_cod_modulo,v_cod_modalidad,v_cta_oficina);

      exception
        when others then
          p_cod_error := 1016;
          p_men_error := 'Error al buscar la cuenta. ' || sqlerrm;
      end;
      IF v_est_proceso not in (2,6) THEN
          begin
            SELECT nvl(sal_retenido, 0) sal_retenido,
                   nvl(sal_bloqueado, 0) sal_bloqueado,
                   nvl(sal_total, 0) - nvl(mto_deb_pendientes, 0) + nvl(mto_cre_pendientes, 0) +
                   nvl(mto_cre_a_confirmar, 0) total
              INTO p_sal_retenido,
                   p_sal_bloqueado,
                   p_sal_disponible
              FROM cc_cta_corrientes_noc
             WHERE nro_cuenta = p_nro_cuenta;
          exception
            when no_data_found then
              p_cod_error := 1019;
              p_men_error := 'No se encontro la cuenta.';
            when others then
              p_cod_error := 1020;
              p_men_error := 'Error al buscar la Cuenta Corriente en noc. ' || sqlerrm;
          end;
        END IF;
      ---------movimientos de depositos pendientes---------------
      select nvl(sum(amount),0)
        into v_dep_pendientes
        from (select nvl(c.monto, 0) amount
                from ge_movimientos c
               where c.cod_tra_padre in (352, 393)
                 and c.nro_cuenta is not null
                 and c.nro_cuenta = p_nro_cuenta
                 and c.estado = 'P'
              union all
              /*Historico*/
              select nvl(c.monto, 0) amount
                from cc_movimientos_his c
               where c.cod_tra_padre in (352, 393)
                 and c.nro_cuenta is not null
                 and c.nro_cuenta = p_nro_cuenta
                 and c.estado = 'P');

      p_dep_pendientes := p_dep_pendientes + v_dep_pendientes;
      ---------

      --obtiene saldo promedio
      begin
        pag_cta.pr_obt_sal_promedio(v_cod_modulo,
                                    v_cod_modalidad,
                                    v_cod_oficina,
                                    p_nro_cuenta,
                                    v_fec_actual,
                                    v_fec_actual,
                                    v_sal_acumulado,
                                    v_sal_promedio,
                                    v_can_dia_acumulado);

        p_val_tas_nom := fug_obt_val_tasa(v_cod_modulo,
                                          v_cod_modalidad,
                                          v_cod_oficina,
                                          p_nro_cuenta,
                                          v_cod_moneda,
                                          v_sal_promedio,
                                          v_tas_personalizada,
                                          NULL,
                                          550,
                                          v_fec_actual);
      exception
        when others then
          p_cod_error := 1041;
          p_men_error := 'No se encuentra la tasa TAN. ' || v_cod_modulo || ' ' ||
                         sqlerrm;
      end;
      -- Buscamos tarjeta si tiene
      BEGIN
        SELECT MAX(t.nro_emision),
               t.fec_vencimiento,
               t.nro_cuenta,
               t.cod_persona
          INTO v_nro_emision, p_vto_tarjeta, v_nro_cuenta, v_cod_persona
          FROM ah_tar_debitos t, ba_cod_referencias b
         WHERE t.nro_cuenta = p_nro_cuenta
           AND t.cod_est_solicitud = b.val_minimo
           AND b.dominio = 'EST_TAR_DEB_EXT'
         GROUP BY t.fec_vencimiento, t.nro_cuenta, t.cod_persona;
      exception
        when others then
          v_nro_emision := null;
          p_vto_tarjeta := null;
          v_nro_cuenta  := p_nro_cuenta;
          v_cod_persona := null;
      END;

      if p_cod_error = v_pro_correcto then
        begin
          p_val_tas_tae := pas_bcp.FU_OBT_TAE(p_val_tas_nom, 30);
        exception
          when others then
            p_cod_error := 1042;
            p_men_error := 'No se encuentra la tasa TAE. ' || sqlerrm;
        end;
      end if;

      begin
        Select nvl(sum(pag_gen.FU_CON_MON_A_MONEDA(s.cod_moneda,
                                                   c.cod_moneda,
                                                   s.monto)) +
                   decode(abs(p_sal_disponible),
                          p_sal_disponible,
                          0,
                          p_sal_disponible),
                   0),
               nvl(sum(pag_gen.FU_CON_MON_A_MONEDA(s.cod_moneda,
                                                   c.cod_moneda,
                                                   s.monto)),
                   0),
               s.val_tas_interes
          into p_sal_sobregiro, p_lin_tot_sobregiro, p_tas_int_sobregiro
          from cc_lin_sobregiros s, cc_cta_corrientes c
         where s.nro_cuenta = p_nro_cuenta
           and c.nro_cuenta = s.nro_cuenta
           and s.estado = 'A'
         group by s.val_tas_interes;
      exception
        when others then
          p_sal_sobregiro     := 0;
          p_lin_tot_sobregiro := 0;
          p_tas_int_sobregiro := 0;
      end;

      BEGIN
        SELECT can_dias
          INTO p_can_dia_sob
          FROM cc_sobregiros_res
         WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          p_can_dia_sob := 0;
      END;
    end if;
  end if;
  if p_cod_error <> v_pro_correcto then
    p_denominacion   := null;
    p_moneda         := null;
    p_sal_disponible := null;
    p_sal_retenido   := null;
    p_val_tas_tae    := null;
    p_val_tas_nom    := null;
    p_fec_apertura   := null;
    p_sal_sobregiro  := null;
    p_can_dia_sob    := null;

  end if;
exception
  when others then
    null;
end prg_obt_dat_cuentas;
/
