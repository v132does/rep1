CREATE OR REPLACE TRIGGER IT."TB_CC_LIN_SOBREGIROS"
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_LIN_SOBREGIROS
 FOR EACH ROW

declare
  cursor garantias is
  select cod_garantia,mto_aplicado
   from cc_lin_sob_garantias
   where nro_secuencia = :new.nro_secuencia;

  cursor garan is
  select cod_garantia,mto_aplicado
   from cc_lin_sob_garantias
   where nro_secuencia = :old.nro_secuencia;

   v_mto_a_aplicar pr_lineas.mto_aplicado%type;
   v_mto_aplicado  pr_lineas.mto_aplicado%type;
   v_cod_mon_linea pr_lineas.cod_moneda%type;
   v_cot_mon_ori   ge_cotizaciones.val_conversion%type;
   v_cot_mon_des   ge_cotizaciones.val_conversion%type;

BEGIN
   --- Actualizar linea de crédito
   if inserting and :new.nro_linea is not null and :new.nro_sec_padre is null then
      -- Recuperar moneda de la linea
      v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
      -- Convertir el monto a moneda de la linea en la cotizacion actual
      pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
            :new.monto, v_mto_a_aplicar,
            v_cot_mon_ori, v_cot_mon_des);
      --- Actualizar monto aplicado de la linea
      pap_gar.pr_act_lin_aplicado(:new.nro_linea, v_mto_a_aplicar);
   elsif updating and :new.nro_sec_padre is null then
      --- Si no estaba asociado a una linea y se asocia debe tener mismo trato que insert
      if :new.nro_linea is not null and :old.nro_linea is null then
         -- Recuperar moneda de la linea
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
         -- Convertir el monto a moneda de la linea en la cotizacion actual
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
            :new.monto, v_mto_a_aplicar,
            v_cot_mon_ori, v_cot_mon_des);
         -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
         pap_gar.pr_act_lin_aplicado(:new.nro_linea, v_mto_a_aplicar);
      end if;
      --- Si se desasocia la linea
      if :new.nro_linea is null and :old.nro_linea is not null then
         -- Recuperar moneda de la linea
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
         -- Convertir el monto a moneda de la linea en la cotizacion actual
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
            :old.monto, v_mto_aplicado,
            v_cot_mon_ori, v_cot_mon_des);
         pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado,0)*-1));
      end if;
      If (NVL(:new.nro_linea,-1) <> NVL(:old.nro_linea,-1) and :old.nro_linea is not null) or
         (NVL(:new.monto,0) <> NVL(:old.monto,0) and :new.nro_linea is not null) then
        --desasocia la linea        
        -- Recuperar moneda de la linea
        v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
        -- Convertir el monto a moneda de la linea en la cotizacion actual
        pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
            :old.monto, v_mto_aplicado,
            v_cot_mon_ori, v_cot_mon_des);
        pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado,0)*-1));
        if :new.nro_linea is not null  then
            -- Recuperar moneda de la linea
            v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
            -- Convertir el monto a moneda de la linea en la cotizacion actual
            pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
                :new.monto, v_mto_a_aplicar,
                v_cot_mon_ori, v_cot_mon_des);
            -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
            pap_gar.pr_act_lin_aplicado(:new.nro_linea, v_mto_a_aplicar);
        end if;    
      End if;
   elsif deleting then
      ---- Actualizar linea de crédito
      If :old.nro_linea is not null and :old.nro_sec_padre is not null then
        -- Recuperar moneda de la linea
        v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
        -- Convertir el monto a moneda de la linea en la cotizacion actual
        pag_gen.pr_con_mon_a_moneda(:old.cod_moneda, v_cod_mon_linea,
            :old.monto, v_mto_aplicado,
            v_cot_mon_ori, v_cot_mon_des);
        pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado,0)*-1));
      End if;
   end if;
END;
/

