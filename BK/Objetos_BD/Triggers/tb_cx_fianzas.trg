CREATE OR REPLACE TRIGGER IT.TB_CX_FIANZAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CX_FIANZAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

   v_cot_mon_ori   ge_cotizaciones.val_conversion%type;
   v_cot_mon_des   ge_cotizaciones.val_conversion%type;
   v_cod_mon_linea pr_lineas.cod_moneda%type;
   v_diferencia    CX_FIANZAS.monto%type;
   v_mto_aplicado  CX_FIANZAS.monto%type;

cursor garantias is
    select cod_garantia, sum( mto_aplicado ) mto_aplicado
           from CX_cta_garantias
          where nro_cuenta = :new.nro_cuenta
          group by cod_garantia
          order by cod_garantia;

  v_mto_apli_gar  pr_lineas.mto_aplicado%type;
BEGIN
   if inserting or updating then
      if :new.estado <> nvl(:old.estado,'X') then
         :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(8);
      end if;
   end if;

   ---- Control de Utilización de Línea
   if updating then
      if  :new.nro_linea is not null
      and nvl(:new.monto,0) <> nvl(:old.monto,0) then
         --- Hallar monto de linea (positivo) o reversado (negativo)
         v_diferencia := (nvl(:old.monto,0) - nvl(:new.monto,0));
         --- Actualizar mto aplicado de linea utilizado
         -- Recuperar moneda de la linea
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
         -- Convertir el monto a moneda de la linea en la cotizacion actual
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
            v_diferencia, v_mto_aplicado,
            v_cot_mon_ori, v_cot_mon_des);
         -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
         -- obs: se cambia de signo porque los pagos deben descontar el aplicado
         pap_gar.pr_act_lin_aplicado(:new.nro_linea, (v_mto_aplicado*-1));

      end if;
      --- Si no estaba asociado a una linea y se asocia debe tener mismo trato que insert
      if :new.nro_linea is not null and :old.nro_linea is null then
         v_diferencia := (nvl(:old.monto,0) - nvl(:new.monto,0));
         -- Recuperar moneda de la linea
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:new.nro_linea);
         -- Convertir el monto a moneda de la linea en la cotizacion actual
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
            v_diferencia, v_mto_aplicado,
            v_cot_mon_ori, v_cot_mon_des);
         -- Actualizar linea de crédito y mto aplicado del crédito en moneda de la linea
         -- obs: se cambia de signo porque los pagos deben descontar el aplicado
         pap_gar.pr_act_lin_aplicado(:new.nro_linea, (v_mto_aplicado*-1));
      End if;
      --- Si se desasocia la linea
      if :new.nro_linea is null and :old.nro_linea is not null then
        -- Recuperar moneda de la linea
         v_cod_mon_linea := pap_gar.fu_obt_mon_linea(:old.nro_linea);
         -- Convertir el monto a moneda de la linea en la cotizacion actual
         pag_gen.pr_con_mon_a_moneda(:new.cod_moneda, v_cod_mon_linea,
            nvl(:old.monto,0), v_mto_aplicado,
            v_cot_mon_ori, v_cot_mon_des);
         pap_gar.pr_act_lin_aplicado(:old.nro_linea, (nvl(v_mto_aplicado,0)*-1));
         for gar in garantias loop
           pag_gen.pr_con_mon_a_moneda(:new.cod_moneda,v_cod_mon_linea,
                                       nvl(gar.mto_aplicado,0), v_mto_apli_gar,
                                       v_cot_mon_ori, v_cot_mon_des);
           --Actualizar el mto aplicado de tipos de garantia por limite
           pap_gar.pr_act_tip_limite(:old.nro_linea,gar.cod_garantia,nvl(v_mto_apli_gar,0)*-1);
           --Actualizar el mto aplicado de garantias por Modalidad
           pap_gar.pr_act_mad_limite(:old.nro_linea,gar.cod_garantia,nvl(v_mto_apli_gar,0)*-1,8,:new.cod_modalidad);
         end loop;
      end if;
   end if;
END;
/

