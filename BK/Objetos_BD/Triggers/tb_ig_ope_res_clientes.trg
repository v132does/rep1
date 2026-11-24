CREATE OR REPLACE TRIGGER IT.TB_IG_OPE_RES_CLIENTES
 BEFORE DELETE OR INSERT OR UPDATE
     ON IG_OPE_RES_CLIENTES
    FOR EACH ROW
DECLARE
v_mon_calculo ba_monedas.cod_moneda%type := pai_sgt.v_mon_calculo;
v_cot_origen  ge_cotizaciones.val_conversion%type := null;
v_cot_destino ge_cotizaciones.val_conversion%type := null;
BEGIN
  if v_mon_calculo is null then
    v_mon_calculo := fug_obt_pardinamico('COD_MON_CONSOLIDAR',NULL,NULL,NULL,NULL);
  end if;
  --calcular montos en moneda de consolidación
  IF inserting THEN
     --si es diferente a la moneda de consolidación -> convertir
     if :new.cod_moneda <> v_mon_calculo then
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_mto_apertura,    :new.sum_con_mto_apertura, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_saldo,           :new.sum_con_saldo, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_interes,         :new.sum_con_interes, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_devengado,   :new.sum_con_int_devengado, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_devengar,    :new.sum_con_int_devengar, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_dev_suspenso,:new.sum_con_int_dev_suspenso, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_recuperado,  :new.sum_con_int_recuperado, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_mto_mora,        :new.sum_con_mto_mora, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_sal_promedio,    :new.sum_con_sal_promedio, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_logro,           :new.sum_con_logro, v_cot_origen, v_cot_destino);
     else
        :new.sum_con_mto_apertura     := :new.sum_mto_apertura;
        :new.sum_con_saldo            := :new.sum_saldo;
        :new.sum_con_interes          := :new.sum_interes;
        :new.sum_con_int_devengado    := :new.sum_int_devengado;
        :new.sum_con_int_devengar     := :new.sum_int_devengar;
        :new.sum_con_int_dev_suspenso := :new.sum_int_dev_suspenso;
        :new.sum_con_int_recuperado   := :new.sum_int_recuperado;
        :new.sum_con_mto_mora         := :new.sum_mto_mora;
        :new.sum_con_sal_promedio     := :new.sum_sal_promedio;
        :new.sum_con_logro            := :new.sum_logro;
     end if;
  ELSIF updating THEN
     --si modifica la moneda o los montos
     if :new.cod_moneda <> :old.cod_moneda or :new.sum_mto_apertura <> :old.sum_mto_apertura or
        :new.sum_saldo <> :old.sum_saldo or :new.sum_interes <> :old.sum_interes or
        :new.sum_int_devengado <> :old.sum_int_devengado or :new.sum_int_devengar <> :old.sum_int_devengar or
        :new.sum_int_dev_suspenso <> :old.sum_int_dev_suspenso or :new.sum_int_recuperado <> :old.sum_int_recuperado or
        :new.sum_mto_mora <> :old.sum_mto_mora or :new.sum_sal_promedio <> :old.sum_sal_promedio then
        --si es diferente a la moneda de consolidación -> convertir
        if :new.cod_moneda <> v_mon_calculo then
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_mto_apertura,    :new.sum_con_mto_apertura, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_saldo,           :new.sum_con_saldo, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_interes,         :new.sum_con_interes, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_devengado,   :new.sum_con_int_devengado, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_devengar,    :new.sum_con_int_devengar, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_dev_suspenso,:new.sum_con_int_dev_suspenso, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_int_recuperado,  :new.sum_con_int_recuperado, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_mto_mora,        :new.sum_con_mto_mora, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_sal_promedio,    :new.sum_con_sal_promedio, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sum_logro,           :new.sum_con_logro, v_cot_origen, v_cot_destino);
        else
          :new.sum_con_mto_apertura     := :new.sum_mto_apertura;
          :new.sum_con_saldo            := :new.sum_saldo;
          :new.sum_con_interes          := :new.sum_interes;
          :new.sum_con_int_devengado    := :new.sum_int_devengado;
          :new.sum_con_int_devengar     := :new.sum_int_devengar;
          :new.sum_con_int_dev_suspenso := :new.sum_int_dev_suspenso;
          :new.sum_con_int_recuperado   := :new.sum_int_recuperado;
          :new.sum_con_mto_mora         := :new.sum_mto_mora;
          :new.sum_con_sal_promedio     := :new.sum_sal_promedio;
          :new.sum_con_logro            := :new.sum_logro;
        end if;
     end if;
  END IF;
END;
/

