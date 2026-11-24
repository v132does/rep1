CREATE OR REPLACE TRIGGER IT.TB_CC_CTA_GARANTIAS
 BEFORE INSERT
 ON CC_CTA_GARANTIAS
 FOR EACH ROW

BEGIN
   if inserting then
      --Obtengo el codigo del cliente
      if :new.cod_persona is null then
         :new.cod_persona := fug_obt_cli_principal(:new.nro_cuenta);
      end if;
   end if;
END;
/

