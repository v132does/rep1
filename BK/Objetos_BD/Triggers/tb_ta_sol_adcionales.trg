CREATE OR REPLACE TRIGGER IT.TB_TA_SOL_ADCIONALES
BEFORE INSERT 
 ON TA_SOL_ADICIONALES
 FOR EACH ROW
DECLARE
v_existe number;
BEGIN
 --*
 --* Controlar que no se grabe solicitud adcional a una solicitud que ya tiene tarjeta
 --*
 Select count(*) into v_existe
    from  ta_cta_tarjetas t
   where t.nro_solicitud = :NEW.nro_solicitud;
   
 if  v_existe <> 0 then     
    raise_application_error(-20000,'No se puede cargar adicional a una solicitud que tiene un tarjeta activa.');
 end if;  


END;
/

