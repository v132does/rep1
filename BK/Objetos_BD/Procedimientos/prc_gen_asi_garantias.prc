CREATE OR REPLACE PROCEDURE IT.PRC_GEN_ASI_GARANTIAS is
   --- Genera asientos por la constitucion de garantias y el saldo de las mismas
   --- Cursor de Lineas de Sobregiros a generar ---
   r_gmovi          ge_movimientos%rowtype;
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_hora           ge_movimientos.hora%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   v_dif_gar_compu  cc_lin_sob_garantias.mto_aplicado%type := 0;
   v_dif_gar_nocom  cc_lin_sob_garantias.mto_aplicado%type := 0;
   v_cod_mon_local  ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
   v_redondeo       number(1);
   v_tot_aplicado         number(18,2) := 0;
   ---
   cursor c_lin_sobregiros is
   select ge.cod_persona,
          p.nro_cuenta,
          g.nro_garantia, tg.cod_garantia,
          decode(p.estado,'C',0,nvl(g.mto_aplicado,0)) mto_aplicado,
          decode(p.estado,'C',0,nvl(g.mto_aplicado,0)) mto_cal_valor,
          nvl(g.mto_con_computable,0)+nvl(g.mto_con_nocomputable,0) mto_apl_valor,
          nvl(g.mto_con_computable,0) mto_con_computable,
          nvl(g.mto_con_nocomputable,0) mto_con_nocomputable,
          nvl(p.sal_total,0) mto_prestamo,
          4 cod_modulo, 41 cod_modalidad, p.cod_oficina cod_oficina, p.cod_moneda,
          gr.cod_moneda mon_garantia,
          tg.cod_transaccion1 tra_computable,
          tg.cod_transaccion2 tra_no_computable,
          nvl(tg.computable, 'N') computable,
          g.mto_apl_computable
     from pr_garantias gr, pr_gar_tipos tg, cc_cta_garantias g, cc_cta_corrientes p, ge_cta_clientes ge
      where gr.cod_garantia(+) = g.cod_garantia
        and gr.nro_garantia(+) = g.nro_garantia
        and tg.cod_garantia = g.cod_garantia
        and p.nro_cuenta = g.nro_cuenta
        and p.nro_cuenta = ge.nro_cuenta
        and ge.relacion = 'P'
        and (p.estado not in ('C','I','X')
            or  p.estado = 'C' and p.fec_cam_estado = v_fec_actual)
    order by p.fec_apertura, p.nro_cuenta, g.cod_garantia, g.nro_garantia;


-----------------------------------------
-- Obtiene el total del monto aplicado.--
-----------------------------------------
Function lf_tot_mto_aplicado (p_cod_garantia in number,
                               p_nro_garantia in number,
                               p_cod_moneda in varchar2) return number is
   v_tot_aplicado number(18,2) := 0;
Begin
    Select nvl(sum(pag_gen.fu_con_mon_a_moneda(p.cod_moneda,p_cod_moneda, nvl(cg.mto_aplicado,0))), 0)
      into v_tot_aplicado
      from pr_garantias g, cc_lin_sob_garantias cg, cc_lin_sobregiros p
     where p.nro_secuencia = cg.nro_secuencia
       and p.nro_cuenta is null
       and g.cod_garantia = cg.cod_garantia
       and g.nro_garantia = cg.nro_garantia
       and nvl(cg.mto_aplicado,0) != 0
       and g.nro_garantia = p_nro_garantia
       and g.cod_garantia = p_cod_garantia;
    Return v_tot_aplicado;
Exception
  When no_data_found then
       return 0;
End lf_tot_mto_aplicado;
----
begin
   v_fec_actual    := pag_cal.FU_OBT_FEC_ACTUAL(4);
   v_hora          := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_nro_secuencia := 0;
   ---
   select nvl(max(nro_secuencia),0)
   into   v_nro_secuencia
   from   ge_movimientos
   where  fecha = v_fec_actual
   and    hora = v_hora
   and    cod_usuario = user;
   ---

   --Actualizacion a 0 mde montos computables--
   update cc_lin_sob_garantias
      set mto_con_computable = 0,
          mto_con_nocomputable = 0;

   --Inserta Transacciones por Lineas Actuales--
   for pre in c_lin_sobregiros loop
      v_redondeo := 0;
      If pre.cod_moneda != v_cod_mon_local then
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', pre.cod_modulo, pre.cod_modalidad, pre.cod_moneda, pre.cod_oficina);
      End if;
      -- Cera las variables de valor computable y no computable.
      v_dif_gar_compu := 0;
      v_dif_gar_nocom := 0;
      If pre.computable = 'S' then
         if nvl(pre.mto_con_computable,0) != nvl(pre.mto_apl_computable,0) then
            --- Calcula la diferencia tanto del computable como del no computable.
            v_dif_gar_compu := nvl(pre.mto_apl_computable,0) - nvl(pre.mto_con_computable,0);
         end if;
      End If;
      ---
      if v_nro_secuencia + 1 > 997 then
         v_nro_secuencia := 0;
         v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      end if;
      --- Cabecera del movimiento ---
      r_gmovi.fecha          := v_fec_actual;
      r_gmovi.hora           := v_hora;
      r_gmovi.cod_usuario    := USER;
      r_gmovi.fec_valor      := v_fec_actual;
      --r_gmovi.nro_cuenta     := pre.nro_cuenta;
      r_gmovi.cod_moneda     := pre.mon_garantia;
      r_gmovi.cod_oficina    := pre.cod_oficina;
      r_gmovi.cod_ofi_origen := pre.cod_oficina;
      r_gmovi.nro_cuenta     := pre.nro_cuenta;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.cod_mod_padre  := pre.cod_modulo;
      r_gmovi.cod_mad_padre  := pre.cod_modalidad;
      r_gmovi.cod_tra_padre  := 200; --- Calculo de Garantias
      r_gmovi.cod_modulo     := pre.cod_modulo;
      r_gmovi.cod_modalidad  := pre.cod_modalidad;
      r_gmovi.protegido      := 'N';
      r_gmovi.nro_documento  := pre.cod_persona;
      r_gmovi.nro_documento2 := pre.nro_cuenta;
      --- Verifica primero si existe diferencia en el computable para generar la transaccion.
      if v_dif_gar_compu != 0 then
         r_gmovi.cod_transaccion := pre.tra_computable;
         if v_dif_gar_compu < 0 then
            r_gmovi.concepto := 'DESAFECTACION GARANTIA(comp)';
         else
            r_gmovi.concepto := 'CONSTITUCION GARANTIA(comp)';
         end if;
         if r_gmovi.cod_transaccion is not null then
            --- Generar asiento contable por constitucion o desafectacion
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.monto         := v_dif_gar_compu;
            r_gmovi.monto         := pag_gen.fu_con_mon_a_moneda(pre.cod_moneda,pre.mon_garantia, nvl(r_gmovi.monto,0));
            -- solamente inserta movimiento si es la primera garantia de la cuenta
            pag_gen.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
         end if;
         --
         r_gmovi.cod_transaccion := pre.tra_no_computable;
         if r_gmovi.cod_transaccion is not null then
            --- Generar asiento contable por constitucion o desafectacion
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.monto         := (v_dif_gar_compu * (-1));
            r_gmovi.monto         := pag_gen.fu_con_mon_a_moneda(pre.cod_moneda,pre.mon_garantia, nvl(r_gmovi.monto,0));
            if r_gmovi.monto < 0 then
               r_gmovi.concepto := 'DESAFECTACION GARANTIA(nocomp)';
            else
               r_gmovi.concepto := 'CONSTITUCION GARANTIA(nocomp)';
            end if;
            -- solamente inserta movimiento si es la primera garantia de la cuenta
            pag_gen.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
         end if;
         --- Afectar garantia de la cuenta
         update cc_lin_sob_garantias
            set mto_con_computable = nvl(mto_con_computable,0) + v_dif_gar_compu
          where nro_secuencia        = pre.nro_cuenta
            and cod_garantia         = pre.cod_garantia
            and nvl(nro_garantia,-1) = nvl(pre.nro_garantia,nvl(nro_garantia,-1));
         --
         update cc_cta_garantias
            set mto_con_computable = nvl(mto_con_computable,0) + v_dif_gar_compu
          where nro_cuenta           = pre.nro_cuenta
            and cod_garantia         = pre.cod_garantia
            and nvl(nro_garantia,-1) = nvl(pre.nro_garantia,nvl(nro_garantia,-1));
         --- Afectar garantia
         if pre.nro_garantia is not null and pre.cod_garantia not in (1,2) then
            update pr_garantias p
               set p.mto_apl_valor = nvl(p.mto_apl_valor,0) +
               pag_gen.fu_con_mon_a_moneda(pre.cod_moneda,p.cod_moneda, nvl(v_dif_gar_compu,0))
             where p.nro_garantia = pre.nro_garantia;
         end if;
      end if;
   end loop;
end prc_gen_asi_garantias;
/

