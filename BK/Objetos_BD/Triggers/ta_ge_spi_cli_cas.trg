CREATE OR REPLACE TRIGGER IT.TA_GE_SPI_CLI_CAS
 AFTER DELETE OR INSERT OR UPDATE
 ON "IT"."GE_SPI_CLI_CAS"
 FOR EACH ROW
declare
v_nro_cuenta varchar2(35); 
begin
  IF UPDATING THEN  
     if (:old.est_cliente = 'inactive' and :new.est_cliente = 'active') /*and 
        (:old.cli_recordid is null and :new.cli_recordid is not null )*/  then
          
          update ge_spi_cta_cas c
          set c.est_solicitud='U',
              c.cli_recordid = :new.cli_recordid
          where c.tip_identificador = :old.tip_identificador
          and c.identificador=:old.val_identificador
          and c.cod_persona=:old.cod_persona;
          
         /* TRFS-1099
          begin
            select c.nro_cta_solicitante
            into v_nro_cuenta 
            from ge_spi_cta_cas c
            where c.tip_identificador = :old.tip_identificador
            and c.identificador =:old.val_identificador
            and c.cod_persona =:old.cod_persona; 
           exception
             when no_data_found then
               v_nro_cuenta := null ; 
             when others then
              v_nro_cuenta := null ;   
          end;  

          update ge_spi_ali_cas c
          set c.est_solicitud='U',
              c.cli_recordid = :new.cli_recordid
          where c.cod_persona= :old.cod_persona
          and c.nro_cta_solicitante = v_nro_cuenta; */

     end if;
    end if; 
end;
/

