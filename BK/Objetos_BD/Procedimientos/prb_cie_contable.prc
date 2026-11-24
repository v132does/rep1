create or replace procedure it.prb_cie_contable is
-- cierre contable
v_lugar varchar2(300);
begin
   -- copia de seguridad
   v_lugar := 'prb_cop_respaldo';
   prb_cop_respaldo;
   -- union de asientos automaticos
   v_lugar := 'PRB_UN_ASIENTOS';
   --Modificado por : rpavon en Banco Regional--
   --Finalidad : La unificacion de los asientos en CB_ASIENTOS--
   prb_uni_asientos;
   prb_uni_asi_futuros;
   -- validacion de asientos
   v_lugar := 'prb_val_asientos';
   prb_val_asientos;   --pone a confirmados los asientos
   -- inicializo el estado del modulo a procesando...
   v_lugar := 'PRB_INI_EST_MODULO';
   PRB_INI_EST_MODULO;
   -- sumriza los saldos consolidados
   v_lugar := 'prb_sum_sal_consolidados';
   prb_sum_sal_consolidados;   --x las dudas, para asegurar que estén bien los saldos
   -- cancela las ctas especiales
   v_lugar := 'prb_can_cta_especiales';
   prb_can_cta_especiales;  --genera asientos
   -- actualiza los saldos por oficina
   v_lugar := 'prb_act_saldos';
   prb_act_saldos;   --actualiza cb_sal_oficinas y cb_sal_consolidados, pone a actualizados los asientos 
   -- ajuste cambiario
   v_lugar := 'prb_aju_dif_cambios';
   prb_aju_dif_cambios;  --genera asientos
   -- actualiza de vueltas los saldos por los asientos generados
   v_lugar := 'prb_act_saldos';
   prb_act_saldos; 
   -- genera las cuentas especiales
   v_lugar := 'prb_gen_cta_especiales';
   prb_gen_cta_especiales;  --genera asientos
   -- provision de impuesto a la renta
   v_lugar := 'prb_pro_imp_renta';
   --prb_pro_imp_renta;
   -- actualiza de vueltas los saldos por los asientos generados
   v_lugar := 'prb_act_saldos';
   prb_act_saldos;
   -- calculo de la utilidad
   v_lugar := 'prb_cal_utilidad';
   prb_cal_utilidad;
   -- sumarizacion de saldos por oficina
   v_lugar := 'prb_sum_oficinas';
   prb_sum_sal_oficinas;
   -- recalculo del consolidado
   v_lugar := 'prb_sum_sal_consolidados';
   prb_sum_sal_consolidados;
   -- cierre del modulo
   v_lugar := 'prb_fin_est_modulo';
   prb_fin_est_modulo;
exception
   when others then
      raise_application_error(-20000,v_lugar||' - '||sqlerrm);
end;
/

