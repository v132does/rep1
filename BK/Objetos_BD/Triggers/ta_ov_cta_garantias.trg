CREATE OR REPLACE TRIGGER IT.TA_OV_CTA_GARANTIAS
 AFTER DELETE OR INSERT OR UPDATE
 ON OV_CTA_GARANTIAS
 FOR EACH ROW

DECLARE
-- Para recuperar datos de la garantía y la propuesta.
/*cursor garantia is
   select pr.cod_modulo cod_mod_prestamo, pr.cod_modalidad cod_mad_prestamo,
          pr.cod_moneda cod_mon_prestamo, pr.cod_oficina cod_ofi_prestamo,
          ct.cod_modulo cod_mod_cuenta, ct.cod_modalidad cod_mad_cuenta, ct.cod_oficina cod_ofi_cuenta,
          ct.cod_moneda cod_mon_cuenta,ca.monto monto, ca.nro_cta_referencia nro_cta_referencia
     from pr_gar_cash ca,
          ov_cta_garantias pr,
          ge_cuentas ct
    where ca.nro_garantia  = :new.nro_garantia
      and pr.nro_cuenta = :new.nro_cuenta
      and ca.nro_cta_referencia = ct.nro_cuenta(+);
*/
/*
cursor garan is
   select pr.cod_modulo cod_mod_prestamo, pr.cod_modalidad cod_mad_prestamo,
          pr.cod_moneda cod_mon_prestamo, pr.cod_oficina cod_ofi_prestamo,
          ct.cod_modulo cod_mod_cuenta, ct.cod_modalidad cod_mad_cuenta, ct.cod_oficina cod_ofi_cuenta,
          ct.cod_moneda cod_mon_cuenta,ca.monto monto, ca.nro_cta_referencia nro_cta_referencia
     from pr_gar_cash ca,
          ov_cta_garantias pr,
          ge_cuentas ct
    where ca.nro_garantia  = :old.nro_garantia
      and pr.nro_cuenta = :old.nro_cuenta
      and ca.nro_cta_referencia = ct.nro_cuenta(+);
*/
  v_cod_mod_pres   ta_cta_tarjetas.cod_modalidad%type;
  v_cod_mon_pres   ta_cta_tarjetas.cod_moneda%type;
  v_cod_mon_gar    pr_garantias.cod_moneda%type;
  v_mto_a_aplicar  pr_lineas.mto_aplicado%type;
  v_mto_aplicado pr_lineas.mto_aplicado%type;
  v_mto_a_apli_gar pr_garantias.mto_aplicado%type;
  v_cot_mon_ori    ge_cotizaciones.val_conversion%type;
  v_cot_mon_des    ge_cotizaciones.val_conversion%type;

  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_procesa        varchar2(01);
  v_nro_cuenta     ta_cta_tarjetas.nro_cuenta%type;
  v_aplicado       pr_garantias.mto_aplicado%type;
  v_tipo           pr_garantias.tipo%type;
  v_estado         pr_garantias.estado%type;

---------------------------------------------------------------------------------------
/*principal*/
BEGIN
   if inserting or updating then
      v_nro_cuenta := :new.nro_cuenta;
   else
      v_nro_cuenta := :old.nro_cuenta;
   end if;

   begin
      select cod_moneda,cod_modalidad
        into v_cod_mon_pres,v_cod_mod_pres
        from ov_cta_vencidas
       where nro_cuenta = v_nro_cuenta;
      exception
       when no_data_found then
         null;
   End;
   --- POR ELIMINACION O MODIFICACION DEL MONTO APLICADO
   If deleting OR updating  then
     IF nvl(:new.mto_apl_computable,0) <> nvl(:old.mto_apl_computable,0) then
       begin
          If :old.cod_garantia > 2 and :old.nro_garantia is not null then
            -- Actualizar monto aplicado de garantia
            pap_gar.pr_act_gar_aplicado(:old.nro_garantia, v_cod_mon_pres, (nvl(:old.mto_apl_computable,0)*-1));
            pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_pres, nvl(:new.mto_apl_computable,0));
          End if;
        exception
          when others then
            If sqlcode <= -20000 then
              raise;
            else
              raise_application_error(-20001,'Al Actualizar Garantía'||sqlerrm);
            End if;
        end;
      end if;
   End if;

  --- POR INSERT
  if inserting then
    --actualizar la garantia con el nuevo monto aplicado computable
    If :new.cod_garantia > 2 then
         if nvl(:new.mto_apl_computable,0) <> 0 then
            pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_pres, nvl(:new.mto_apl_computable,0));
         end if;
    end if;
  end if;
END;
/

