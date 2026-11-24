CREATE OR REPLACE FUNCTION IT."FUP_OBT_TRA_ORI_FONDO" (p_cod_ori_fondo pr_fondos.cod_ori_fondo%type,
p_cod_moneda pr_fondos.cod_moneda%type,
p_tipo in varchar2 default 'A') -- valores posibles A - Alta (desembolso) / B - Baja (cobro)
-- recupera la transacción de Alta o Desembolso, o la de Baja o Cobro del origen de fondo del préstamo
return Number is
v_transaccion ge_transacciones.cod_transaccion%type;
begin
   Select decode(p_tipo,'A', cod_tra_desembolso, cod_tra_cobro)
     into v_transaccion
     from pr_fondos
    where cod_ori_fondo = p_cod_ori_fondo 
      and cod_moneda = nvl(p_cod_moneda,cod_moneda);

   if v_transaccion is not null then
      return v_transaccion;
   else
      raise_application_error(-20000,'Transacción no definida para el origen de fondos.');
   end if;
   
exception
   when no_data_found then
      raise_application_error(-20000,'No existe transacción para el origen de fondos.');
   when too_many_rows then
      raise_application_error(-20000,'Varios registros para el origen de fondos.');
   when others then
      if sqlcode <= -20000 then
         raise;
      end if;
      raise_application_error(-20000,'Recup.Trans.Origen Fondo -'||sqlerrm);
end;
/

