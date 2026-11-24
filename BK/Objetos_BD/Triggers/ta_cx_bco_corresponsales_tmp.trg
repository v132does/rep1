CREATE OR REPLACE TRIGGER IT.TA_CX_BCO_CORRESPONSALES_TMP
  after insert on CX_BCO_CORRESPONSALES_TMP  
  for each row
declare
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
begin
   select cod_modalidad
     into v_cod_modalidad
     from ge_cuentas
    where nro_cuenta = :new.nro_cuenta;
   if    v_cod_modalidad = 81 then -- CCI
      update cx_cta_importaciones i
         set i.cod_bco_corresponsal = :new.cod_bco_corresponsal,
             i.nro_cta_credito = :new.nro_cta_debito
       where nro_cuenta = :new.nro_cuenta;
   elsif v_cod_modalidad = 82 then -- CCE
      update cx_cta_exportaciones e
         set e.cod_bco_corresponsal = :new.cod_bco_corresponsal,
             e.nro_cta_debito = :new.nro_cta_debito
       where nro_cuenta = :new.nro_cuenta;
   elsif v_cod_modalidad in (83,84) then -- COB
      update cx_cta_cobranzas o
         set o.cod_bco_corresponsal = :new.cod_bco_corresponsal,
             o.nro_cta_debcre = :new.nro_cta_debito
       where nro_cuenta = :new.nro_cuenta;
   else
      raise_application_error(-20000,'Modalidad de la cuenta '||v_cod_modalidad||' no corresponde para el proceso');
   end if;         
exception
   when no_data_found then
      raise_application_error(-20000, 'Cuenta '||:new.nro_cuenta||' no registrada');    
end TA_CX_BCO_CORRESPONSAL_TMP;
/

