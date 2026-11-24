CREATE OR REPLACE TRIGGER IT.tb_bw_cla_lim_montos
   BEFORE DELETE OR INSERT OR UPDATE ON "IT"."BW_CLA_LIM_MONTOS"
   FOR EACH ROW
BEGIN
  IF updating THEN
    :new.fec_modificacion := sysdate; -- DYDMR-987 CRO-JM-12/2014:
    :new.usu_modificacion := substr(user, 1, 10);
    --NVB-3262 Se comenta para dejar la funcionalidad como esta en prod
    --proyecto bankiti
    /*IF (:old.mto_minimo <> :new.mto_minimo) OR
       (:old.mto_maximo <> :new.mto_maximo) OR
       (:old.mto_max_personalizacion <> :new.mto_max_personalizacion) THEN
      :new.activo               := 'P';
      :new.cod_usu_autorizacion := null;
      :new.fec_usu_autorizacion := null;
    END IF;*/
  
    -- DYDMR-987 CRO-JM-12/2014:
    if :old.cod_tip_mensaje <> :new.cod_tip_mensaje or
       :old.cod_tip_clave <> :new.cod_tip_clave or
       :old.tip_persona <> :new.tip_persona or
       :old.cod_moneda <> :new.cod_moneda or
       :old.mto_minimo <> :new.mto_minimo or
       :old.mto_maximo <> :new.mto_maximo or
       :old.cod_persona <> :new.cod_persona or
       :old.nro_cuenta <> :new.nro_cuenta or
       :old.mto_max_personalizacion <> :new.mto_max_personalizacion then
      :new.cod_usu_modificacion := :new.usu_modificacion;
      :new.fec_usu_modificacion := :new.fec_modificacion;
    end if;
  
    --DYDMR-987 CRO-JM-12/2014
    if :new.activo = 'A' then
      :new.fec_usu_autorizacion := :new.fec_modificacion;
    end if;
  END IF;
END;
/

