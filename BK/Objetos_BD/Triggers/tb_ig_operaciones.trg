CREATE OR REPLACE TRIGGER IT.TB_IG_OPERACIONES
 BEFORE DELETE OR INSERT OR UPDATE
     ON IG_OPERACIONES
    FOR EACH ROW
DECLARE
v_mon_calculo ba_monedas.cod_moneda%type := pai_sgt.v_mon_calculo; --fug_obt_pardinamico('COD_MON_CONSOLIDAR',NULL,NULL,NULL,NULL);
v_cot_origen  ge_cotizaciones.val_conversion%type := null;
v_cot_destino ge_cotizaciones.val_conversion%type := null;
BEGIN
  if v_mon_calculo is null then
    v_mon_calculo := fug_obt_pardinamico('COD_MON_CONSOLIDAR',NULL,NULL,NULL,NULL);
  end if;
  --calcular montos en moneda de consolidación
  IF inserting THEN
     if :new.por_mora > 100 then
        :new.por_mora := 100;
     end if;   
     --si es diferente a la moneda de consolidación -> convertir
     if :new.cod_moneda <> v_mon_calculo then
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.mto_apertura,    :new.con_mto_apertura, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.saldo,           :new.con_saldo, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.interes,         :new.con_interes, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_devengado,   :new.con_int_devengado, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_devengar,    :new.con_int_devengar, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_dev_suspenso,:new.con_int_dev_suspenso, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_recuperado,  :new.con_int_recuperado, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.mto_mora,        :new.con_mto_mora, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sal_promedio,    :new.con_sal_promedio, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.logro,           :new.con_logro, v_cot_origen, v_cot_destino);
     else
        :new.con_mto_apertura     := :new.mto_apertura;
        :new.con_saldo            := :new.saldo;
        :new.con_interes          := :new.interes;
        :new.con_int_devengado    := :new.int_devengado;
        :new.con_int_devengar     := :new.int_devengar;
        :new.con_int_dev_suspenso := :new.int_dev_suspenso;
        :new.con_int_recuperado   := :new.int_recuperado;
        :new.con_mto_mora         := :new.mto_mora;
        :new.con_sal_promedio     := :new.sal_promedio;
        :new.con_logro            := :new.logro;
     end if;
  ELSIF updating THEN
     --si modifica la moneda o los montos 
     if :new.cod_moneda <> :old.cod_moneda or nvl(:new.mto_apertura,-1) <> nvl(:old.mto_apertura,-1) or
        nvl(:new.saldo,-1) <> nvl(:old.saldo,-1) or nvl(:new.interes,-1) <> nvl(:old.interes,-1) or
        nvl(:new.int_devengado,-1) <> nvl(:old.int_devengado,-1) or nvl(:new.int_devengar,-1) <> nvl(:old.int_devengar,-1) or
        nvl(:new.int_dev_suspenso,-1) <> nvl(:old.int_dev_suspenso,-1) or nvl(:new.int_recuperado,-1) <> nvl(:old.int_recuperado,-1) or
        nvl(:new.mto_mora,-1) <> nvl(:old.mto_mora,-1) or nvl(:new.sal_promedio,-1) <> nvl(:old.sal_promedio,-1) or nvl(:new.logro,-1) <> nvl(:old.logro,-1) then 
        --si es diferente a la moneda de consolidación -> convertir
        if :new.cod_moneda <> v_mon_calculo then
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.mto_apertura,    :new.con_mto_apertura, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.saldo,           :new.con_saldo, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.interes,         :new.con_interes, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_devengado,   :new.con_int_devengado, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_devengar,    :new.con_int_devengar, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_dev_suspenso,:new.con_int_dev_suspenso, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.int_recuperado,  :new.con_int_recuperado, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.mto_mora,        :new.con_mto_mora, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.sal_promedio,    :new.con_sal_promedio, v_cot_origen, v_cot_destino);
           pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.logro,           :new.con_logro, v_cot_origen, v_cot_destino);
        else
          :new.con_mto_apertura     := :new.mto_apertura;
          :new.con_saldo            := :new.saldo;
          :new.con_interes          := :new.interes;
          :new.con_int_devengado    := :new.int_devengado;
          :new.con_int_devengar     := :new.int_devengar;
          :new.con_int_dev_suspenso := :new.int_dev_suspenso;
          :new.con_int_recuperado   := :new.int_recuperado;
          :new.con_mto_mora         := :new.mto_mora;
          :new.con_sal_promedio     := :new.sal_promedio;
          :new.con_logro            := :new.logro;
        end if;
     end if;
  END IF;
END;
/

