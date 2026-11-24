CREATE OR REPLACE TRIGGER IT.TB_IG_BIE_ADJUDICADOS
 BEFORE DELETE OR INSERT OR UPDATE
     ON IG_BIE_ADJUDICADOS
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
     --si es diferente a la moneda de consolidación -> convertir
     if :new.cod_moneda <> v_mon_calculo then
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.VAL_CONTABLE,    :new.CON_VAL_CONTABLE, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.MTO_PREVISION,   :new.CON_MTO_PREVISION, v_cot_origen, v_cot_destino);
        pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.logro,           :new.con_logro, v_cot_origen, v_cot_destino);
     else
        :new.CON_VAL_CONTABLE     := :new.VAL_CONTABLE;
        :new.CON_MTO_PREVISION    := :new.MTO_PREVISION;
        :new.CON_LOGRO            := :new.LOGRO;
     end if;
  ELSIF updating THEN
     --si modifica la moneda o los montos 
     if :new.cod_moneda    <> :old.cod_moneda or
        :new.VAL_CONTABLE  <> :old.VAL_CONTABLE or
        :new.MTO_PREVISION <> :old.MTO_PREVISION or
        :new.LOGRO         <> :old.LOGRO
      then 
        --si es diferente a la moneda de consolidación -> convertir
        if :new.cod_moneda <> v_mon_calculo then
            pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.VAL_CONTABLE,    :new.CON_VAL_CONTABLE, v_cot_origen, v_cot_destino);
            pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.MTO_PREVISION,   :new.CON_MTO_PREVISION, v_cot_origen, v_cot_destino);
            pag_gen.PR_CON_MON_A_MONEDA(:new.cod_moneda, v_mon_calculo, :new.logro,           :new.con_logro, v_cot_origen, v_cot_destino);
        else
            :new.CON_VAL_CONTABLE     := :new.VAL_CONTABLE;
            :new.CON_MTO_PREVISION    := :new.MTO_PREVISION;
            :new.CON_LOGRO            := :new.LOGRO;
        end if;        
     end if;
  END IF;
END;
/

