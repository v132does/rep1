CREATE OR REPLACE PROCEDURE IT.PRS_GEN_ANA_LIQ_CUO (p_fec_proceso in date default pag_cal.FU_OBT_FEC_ACTUAL(2)) is
--- Genera tabla auxiliar para el informe de fin de mes de Analisis de Liquidez
   --- Variables auxiliares
   v_nro_cuenta    pr_cta_prestamos.nro_cuenta%type;
   v_mto_prevision pr_previsiones.monto%type;
   v_mto_act_prev  pr_previsiones.monto%type;
   v_mto_valuacion pr_valuaciones.tot_val_capital%type;
   v_mto_act_valu  pr_valuaciones.tot_val_capital%type;
   v_mto_devengado ah_devengados.mto_dev_acumulado%type;
   v_mto_act_deven ah_devengados.mto_dev_acumulado%type;
   --- Cursor de previsiones de prestamos
   cursor c_previsiones is
   select pv.nro_cuenta, pv.monto
     from pr_cta_prestamos pr, pr_previsiones pv
    where pv.nro_cuenta = pr.nro_cuenta
      and pv.fecha = (select max(pv1.fecha)
                        from pr_previsiones pv1
                       where pv1.nro_cuenta = pv.nro_cuenta)
      and pr.est_batch <> 'N';
   --- Cursor de valuaciones del prestamo
   cursor c_valuaciones is
   select nvl(pr.tot_val_capital,0)+nvl(pr.tot_val_interes,0)+
          nvl(pr.tot_val_int_ade,0)+nvl(pr.tot_val_int_devengar,0)+
          nvl(pr.tot_val_prevision,0)+nvl(pr.tot_val_suspenso,0) tot_valuacion,
          pr.nro_cuenta
    from pr_valuaciones pr, pr_cta_prestamos ct
   where pr.estado not in('N','C')
     and ct.nro_cuenta=pr.nro_cuenta
     and ct.est_batch <> 'N'
     and ( nvl(pr.tot_val_capital,0) <>0
          or nvl(pr.tot_val_interes,0) <>0
          or nvl(pr.tot_val_int_ade,0) <>0
          or nvl(pr.tot_val_int_devengar,0) <>0
          or nvl(pr.tot_val_prevision,0) <>0
          or nvl(pr.tot_val_suspenso,0) <>0);

   -- Cursor de cdas
   cursor c_cda is
   select nro_cuenta, capital, fec_apertura, fec_vencimiento
     from ah_cta_certificados
    where est_batch not in ('C','T','P')
      and fec_vencimiento >= p_fec_proceso;

   --- Cursor de cuotas de la cuenta
   cursor c_liq_cuotas is
   select sb.nro_cuenta, sb.nro_cuota, rowid registro,
          sb.sal_capital + sb.dev_no_cobrado deuda,
          sb.sal_capital + sb.sal_interes + sb.val_int_devengar + sb.mto_prevision deu_valu,
          sb.sal_interes
     from sb_liq_cuotas sb
    where sb.fecha = p_fec_proceso
      and sb.nro_cuenta = v_nro_cuenta;
begin
   --- Elimino tabla auxiliar para la fecha
   delete sb_liq_cuotas where fecha = p_fec_proceso;
   --- Genero nuevamente la informacion a partir de las cuotas no canceladas
   insert into sb_liq_cuotas
     (fecha, nro_cuenta, nro_cuota, cod_moneda, fec_vencimiento,
      sal_capital, dev_no_cobrado, mto_prevision, sal_interes, val_int_devengar)
   select p_fec_proceso, cu.nro_cuenta, cu.nro_cuota, pr.cod_moneda, cu.fec_vencimiento,
      nvl(cu.sal_capital,0), nvl(cu.dev_no_cobrado,0), 0, nvl(cu.sal_interes,0)+nvl(cu.sal_int_documentado,0), (nvl(cu.mto_interes,0)+nvl(cu.mto_int_documentado,0))-nvl(cu.dev_acumulado,0)
    from pr_cuotas cu, pr_cta_prestamos pr
   where pr.nro_cuenta = cu.nro_cuenta
     and pr.est_batch <> 'N'
     and cu.estado <> 'N';
   --- Recorro previsiones del prestamo y lo distribuyo por cuotas
   for prv in c_previsiones loop
      v_nro_cuenta    := prv.nro_cuenta;
      v_mto_prevision := prv.monto;
      for cuo in c_liq_cuotas loop
         v_mto_act_prev  := 0;
         if cuo.deuda <= v_mto_prevision then
            v_mto_act_prev := cuo.deuda;
         else
            v_mto_act_prev := v_mto_prevision;
         end if;
         v_mto_prevision := v_mto_prevision - v_mto_act_prev;
         update sb_liq_cuotas
            set mto_prevision = v_mto_act_prev
          where rowid = cuo.registro;
         exit when v_mto_prevision <= 0;
      end loop;
   end loop;
   --- Recorro valuaciones del prestamo y lo distribuyo por cuotas
   for val in c_valuaciones loop
      v_nro_cuenta    := val.nro_cuenta;
      v_mto_valuacion := val.tot_valuacion;
      for cuo in c_liq_cuotas loop
         v_mto_act_valu  := 0;
         if cuo.deu_valu <= v_mto_valuacion then
            v_mto_act_valu := cuo.deu_valu;
         else
            v_mto_act_valu := v_mto_valuacion;
         end if;
         v_mto_valuacion := v_mto_valuacion - v_mto_act_valu;
         update sb_liq_cuotas
            set mto_valuacion = v_mto_act_valu
          where rowid = cuo.registro;
         exit when v_mto_valuacion <= 0;
      end loop;
   end loop;
   --- Insertar cuotas de CDA
   insert into sb_liq_cuotas
     (fecha, nro_cuenta, nro_cuota, cod_moneda, fec_vencimiento,
      sal_capital, dev_no_cobrado, mto_prevision, sal_interes, val_int_devengar)
   select p_fec_proceso, cu.nro_cuenta, substr(cu.nro_cupon,1,3), ce.cod_moneda, cu.fec_vencimiento,
      0, 0, 0, nvl(cu.mto_interes,0),0
    from ah_cupones cu, ah_cta_certificados ce
   where ce.nro_cuenta = cu.nro_cuenta
     and ce.est_batch not in ('C','P','T')
     and cu.est_batch not in ('C','P','T');
   --- Desglosar el a devengar por cuotas
   for reg in c_cda loop
      v_mto_devengado := pas_bcp.FU_OBT_DEV_CDA(reg.nro_cuenta,reg.capital,reg.fec_apertura, p_fec_proceso);
      v_nro_cuenta    := reg.nro_cuenta;
      for cuo in c_liq_cuotas loop
         v_mto_act_deven  := 0;
         if cuo.sal_interes <= v_mto_devengado then
            v_mto_act_deven := cuo.sal_interes;
         else
            v_mto_act_deven := v_mto_devengado;
         end if;
         v_mto_devengado := v_mto_devengado - v_mto_act_deven;
         update sb_liq_cuotas
            set val_int_devengar = v_mto_act_deven
          where rowid = cuo.registro;
         exit when v_mto_devengado <= 0;
      end loop;
   end loop;



end PRS_GEN_ANA_LIQ_CUO;

 
/
