CREATE OR REPLACE TRIGGER IT.TA_CR_SOLICITUDES
 BEFORE INSERT OR UPDATE
 ON "IT"."CR_SOLICITUDES"
 FOR EACH ROW
DECLARE
 v_cod_error number;
BEGIN
   -- solo para pruebas de circuitos
   if inserting then

      v_cod_error := paw_cir.FU_INI_CIRCUITO(62, :new.nro_solicitud, :new.cod_persona); -- 62 es el tipo de circuito
      if v_cod_error <> 0 then
         raise_application_error(-20067,'Error al generar Circuito '||paw_cir.G_MSJ_ERROR);
      end if;

   end if;
END;
/

