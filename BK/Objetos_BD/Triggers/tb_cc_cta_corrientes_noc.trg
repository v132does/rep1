CREATE OR REPLACE TRIGGER IT.TB_CC_CTA_CORRIENTES_NOC
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_CTA_CORRIENTES_NOC
 FOR EACH ROW
DECLARE
  v_cod_persona      ba_personas.cod_persona%type;
  v_afe_debito       varchar2(1) default 'N';
BEGIN
  if inserting or updating then
    -- Verifica si el Cliente o la Cta. tiene Inhibición que no permita realizar débito BSEVOCORE-147
    if :new.mto_deb_pendientes > 0 then
      v_cod_persona :=fug_obt_cli_principal(:new.nro_cuenta);
      v_afe_debito  := fug_obt_val_parcausal('AFE_DEB_CUENTA',v_cod_persona, :new.nro_cuenta);
      if nvl(v_afe_debito,'N') = 'S' then
        raise_application_error(-20000,'Inhibición del Cliente Principal o Vinculados a la Cuenta no permite realizar Débito');
      end if;
    end if;
  end if;
END;
/

