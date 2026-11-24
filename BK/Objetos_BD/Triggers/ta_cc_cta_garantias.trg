CREATE OR REPLACE TRIGGER IT.TA_CC_CTA_GARANTIAS
 AFTER DELETE OR INSERT OR UPDATE
 ON CC_CTA_GARANTIAS
 FOR EACH ROW
DECLARE
 v_cod_mon_pres cc_cta_corrientes.cod_moneda%type;
BEGIN
  if inserting then
    begin
      select cod_moneda
        into v_cod_mon_pres
        from cc_cta_corrientes
       where nro_cuenta = :new.nro_cuenta;
    exception
       when no_data_found then
         v_cod_mon_pres := null;
    End;
    --actualizar la garantia con el nuevo monto aplicado computable
    If :new.cod_garantia > 2 then
      if nvl(:new.mto_apl_computable,0) <> 0 then
        pap_gar.pr_act_gar_aplicado(:new.nro_garantia, v_cod_mon_pres, nvl(:new.mto_apl_computable,0));
      end if;
    end if;
  end if;
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
  
END;
/

