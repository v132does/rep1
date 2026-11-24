CREATE OR REPLACE TRIGGER IT.TB_TA_TIPOS
 BEFORE INSERT OR UPDATE OR DELETE
 ON "IT"."TA_TIPOS"
 FOR EACH ROW
DECLARE
 v_existe number;
BEGIN
  IF INSERTING OR UPDATING THEN
    --*
    --* Controlar que la afinidad corresponda al tipo de Tarjeta
    --*
   If  substr(:new.afinidad,1,2) <> :new.cod_tip_tarjeta then
      raise_application_error(-20000,'La afinidad no corresponde al tipo de tarjeta.');
   End if;
   If  length(ltrim(rtrim(:NEW.nro_bin))) <> fug_obt_pardinamico('NRO_BIN_LONGITUD',5,:NEW.Cod_Modalidad,null,null) then
    raise_application_error(-20000,'El nro. de bin debe tener '||fug_obt_pardinamico('NRO_BIN_LONGITUD',5,:NEW.Cod_Modalidad,null,null)||' caracteres.');
   End if;
   --*
   --* Controlar que los parametros requeridos por la procesadora no sean nulos
   --*
   If  :new.tip_Cierre is null then
       raise_application_error(-20000,'Debe ingresar un valor para el tipo de cierre.');
   end if;
   If  :new.tip_cobro is null then
       raise_application_error(-20000,'Debe ingresar un valor para el tipo de cobro.');
   end if;
   If  :new.tip_tas_financiacion is null then
       raise_application_error(-20000,'Debe ingresar un valor para el tipo de tasa de financiación.');
   end if;
   If  :new.tip_com_emision is null then
       raise_application_error(-20000,'Debe ingresar un valor para el tipo de comisión de emisión.');
   end if;
   If  :new.tip_generacion is null then
       raise_application_error(-20000,'Debe ingresar un valor para el tipo de generación.');
   end if;
   If  :new.tip_cuenta is null then
       raise_application_error(-20000,'Debe ingresar un valor para el tipo de cuenta.');
   end if;
   If  :new.tip_gas_financiero is null then
       raise_application_error(-20000,'Debe ingresar un valor para el tipo de gasto financiero.');
   end if;
   If  :new.plz_dur_tarjeta is null then
       raise_application_error(-20000,'Debe ingresar un valor para el plazo de duración de la tarjeta.');
   end if;
   If  :new.ref_Externa is null then
       raise_application_error(-20000,'Debe ingresar un valor para la referencia externa.');
   end if;
 END IF;
 --
 IF  (UPDATING  and NVL(:old.sub_afinidad,'ZZ') <> NVL(:new.sub_afinidad,'ZZ'))
 OR DELETING THEN
    Select count(*) into v_existe
      from ta_cta_tarjetas
     where cod_modulo = :old.cod_modulo
       and cod_modalidad = :old.cod_modalidad
       and afinidad      = :old.afinidad
       and nvl(sub_afinidad,'ZZ') = nvl(:old.sub_afinidad,'ZZ')
       and rownum = 1;
    If  v_existe <> 0 then
       raise_application_error(-20000,'Existen cuentas de tarjetas con este Modulo,Modalidad,Afinidad y Sub Afinidad que quedaran inconsistentes. Verifique.');
    end if;
 END IF;

END;
/

