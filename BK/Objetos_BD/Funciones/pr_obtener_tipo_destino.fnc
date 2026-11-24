CREATE OR REPLACE FUNCTION IT."PR_OBTENER_TIPO_DESTINO" (p_propdestin number, p_riesgo number)
return number
as
  v_salario_min number(18,2) := 1408863;
  v_saldo_total number(18,2);
begin

       if(p_propdestin = 2)then
         return 4;
       end if;

       if(p_propdestin = 3)then
         return 3;
       end if;

       /*select sum(ln.total_principal)+sum(ln.total_interes)
       into v_saldo_total from loans_numero_cuenta ln
       where ln.nuries = p_riesgo;*/

       --Si la deuda total del cliente es menor o igual a 25 salarios mínimos
       --Es un microcrédito
       if(v_saldo_total <= 25*v_salario_min) then
          return 5;
       end if;

       --Grandes deudores
       if(v_saldo_total >= 836000000)then
         return 1;
       end if;

       return 2; --Pequeños deudores

end;
/

