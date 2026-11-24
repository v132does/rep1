CREATE OR REPLACE TRIGGER IT.TB_TA_SOL_LINEAS
BEFORE INSERT OR DELETE ON TA_SOL_LINEAS
 FOR EACH ROW
DECLARE
v_cod_modalidad ta_cta_tarjetas.cod_modalidad%type;
v_afinidad      ta_cta_tarjetas.afinidad%type;
v_sub_afinidad  ta_cta_tarjetas.sub_afinidad%type;
BEGIN
  IF inserting THEN
    IF :new.nro_cuenta IS NOT NULL THEN
       BEGIN
         SELECT cod_modalidad, afinidad, sub_afinidad
           INTO v_cod_modalidad, v_afinidad, v_sub_afinidad
           FROM ta_cta_tarjetas
          WHERE nro_cuenta = :new.nro_cuenta;
       EXCEPTION
         WHEN OTHERS THEN
           raise_application_error(-20000,'No encuentra la Cuenta del Titular. Nro.de Cuenta : '||:new.nro_cuenta);
       END;
    ELSE
       raise_application_error(-20001, 'La solicitud no está asociada a ninguna cuenta de tarjeta.');
    END IF;
  END IF;
  IF deleting THEN -- SDHSCORM-1
    delete ba_tab_dat_adicionales
     where tab_relacion = 'TA_SOL_LINEAS'
       and referencia = :old.nro_solicitud;
  END IF;
END;
/

