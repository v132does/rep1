CREATE OR REPLACE TRIGGER IT.TA_CC_CHE_CUSTODIAS_DET
  after update or delete on cc_che_custodias_det  
  for each row
declare
  -- CRO-JM-09/2014
  -- Solamente actualizamos el campo saldo de la cabecera de la custodia de cheques
begin
  if updating then
    if (nvl(:new.estado, 'C') in ('E', 'B', 'D', 'A')) and -- si es "devuelto de camara", "Entregado al cliente" o "confirmado en cuenta", "en compensacion"
       (nvl(:old.estado, 'C') in ('C')) then
      begin
        update cc_che_custodias a
           set a.saldo = nvl(a.saldo, 0) - nvl(:new.val_nominal, 0)
         where a.cod_che_custodia = :new.cod_che_custodia;
      exception
        when others then
          Raise_application_error(-20000,
                                  'Error al tratar de actualizar(-) saldo TA_CC_CHE_CUSTODIAS_DET');
      end;
    end if;
    -- CRO-JM-2014: Para el caso de las reversiones:
    if (nvl(:new.estado, 'C') = 'C') and (:old.estado in ('E', 'D', 'A')) then
      begin
        update cc_che_custodias a
           set a.saldo = nvl(a.saldo, 0) + nvl(:new.val_nominal, 0)
         where a.cod_che_custodia = :new.cod_che_custodia;
      exception
        when others then
          Raise_application_error(-20000,
                                  'Error al tratar de actualizar(+) saldo TA_CC_CHE_CUSTODIAS_DET');
      end;
    end if;
    -- CRO-JM-2014: Para el caso de las cancelaciones desde CMDOCCUS, debe dejar la cabecera como Cancelado:
    if (nvl(:new.estado, 'C') = 'E') and (:old.estado in ('C')) then
      declare
        v_saldo number;
      begin
        begin
          select a.saldo
            into v_saldo
            from cc_che_custodias a
           where a.cod_che_custodia = :new.cod_che_custodia;
        exception
          when others then
            v_saldo := -1;
        end;
        if v_saldo = 0 then
          begin
            update cc_che_custodias a
               set a.estado = 'C'
             where a.cod_che_custodia = :new.cod_che_custodia;
          exception
            when others then
              Raise_application_error(-20000,
                                      'Error al tratar de actualizar el estado de la custodia TA_CC_CHE_CUSTODIAS_DET');
          end;
        end if;
      end;
    end if;
  elsif deleting then
    begin
      update cc_che_custodias a
         set a.saldo = nvl(a.saldo, 0) - nvl(:old.val_nominal, 0)
       where a.cod_che_custodia = :old.cod_che_custodia;
    exception
      when others then
        Raise_application_error(-20000,
                                'Error al tratar de borrar saldo TA_CC_CHE_CUSTODIAS_DET');
    end;
  end if;
end TA_CC_CHE_CUSTODIAS_DET;
/

