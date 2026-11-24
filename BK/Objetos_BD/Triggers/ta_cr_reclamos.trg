CREATE OR REPLACE TRIGGER IT.TA_CR_RECLAMOS
 BEFORE INSERT OR UPDATE
 ON CR_RECLAMOS
 FOR EACH ROW
DECLARE
 v_cod_error number;
BEGIN
   -- solo para pruebas de circuitos
   if inserting then

      v_cod_error := paw_cir.FU_INI_CIRCUITO(81, :new.nro_reclamo, :new.cod_persona); -- 81 es el tipo de circuito
      if v_cod_error <> 0 then
         raise_application_error(-20067,'Error al generar Circuito '||paw_cir.G_MSJ_ERROR);
      end if;

   end if;
END;
/

