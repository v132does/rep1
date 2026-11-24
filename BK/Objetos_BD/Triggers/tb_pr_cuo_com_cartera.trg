create or replace trigger it.tb_pr_cuo_com_cartera
  before insert
  on it.pr_cuo_com_cartera
  for each row
declare
  v_existe varchar2(1) default 'N';
  v_moneda pr_com_cartera.cod_moneda%type;
begin
     begin
       select 'S', a.cod_moneda
        into v_existe,v_moneda
        from  pr_com_cartera a
       where a.nro_operacion = :new.nro_operacion;
      exception
        when others then
          v_existe := 'N';
      end;

      if v_existe = 'N' then
         raise_application_error(-20000,
                                 'ERROR. No existe la cabecera del número de operación: '||:new.nro_operacion);
      end if;

      if v_moneda = 'GS' then
        if (trunc(:new.mto_cuota) <> :new.mto_cuota) or
          (trunc(:new.sal_capital) <> :new.sal_capital) or
          (trunc(:new.sal_interes) <> :new.sal_interes) then
            raise_application_error(-20000,
                                    'ERROR. El monto en guaranies no puede tener decimales: '||:new.nro_operacion);
        end if;
       end if;    
         
end;
/
