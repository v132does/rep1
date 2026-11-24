CREATE OR REPLACE FUNCTION IT."OBTENER_TIPO_PRESTAMO" (p_congru varchar2, p_can_cuotas number,
                                                 p_monto number, p_prop_monto  number)
return varchar2
is
begin

       if(substr(trim(p_congru),1,3) = '173') then
          return 'A';
       end if;

       if(substr(trim(p_congru),1,3) = '169') then
          return 'P';
       end if;

       if(substr(trim(p_congru),1,3) in ('141','351','405')) then
          return 'D';
       end if;

       if(p_can_cuotas = 1 --Si la propuesta indica que tiene una sola cuota
            and p_monto = p_prop_monto ) then--El total de capital q falta pagar
                                             --es igual al monto de la propuesta
          return 'P';--El préstamo es a plazo fijo
       end if;

       return 'A';
end;
/

