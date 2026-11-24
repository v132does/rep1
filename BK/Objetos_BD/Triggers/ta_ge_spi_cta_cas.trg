CREATE OR REPLACE TRIGGER IT.TA_GE_SPI_CTA_CAS
 AFTER UPDATE
 ON "IT"."GE_SPI_CTA_CAS"
 FOR EACH ROW	
declare
v_nro_cuenta varchar2(35); 
begin
  IF UPDATING THEN  
     if (:old.est_solicitud = 'B' and :new.est_solicitud = 'A') and 
        (:old.cta_recordid is null and :new.cta_recordid is not null )  then


          update ge_spi_ali_cas c
          set c.est_solicitud='U',
              c.cli_recordid = :old.cli_recordid
          where c.cod_persona= :old.cod_persona
          and c.nro_cta_solicitante = :old.nro_cta_solicitante; 


     end if;
  end if; 
end;
/

