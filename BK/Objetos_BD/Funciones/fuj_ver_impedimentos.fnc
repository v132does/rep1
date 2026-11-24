create or replace function it.FUJ_VER_IMPEDIMENTOS
   (p_nro_cuenta in varchar2,
    p_cod_modalidad   in number,
    p_cod_transaccion in number,
    p_est_cuenta in varchar2,
    p_tip_operacion in varchar2) return varchar2 is
  v_salida varchar2(200)  := '';
begin
  if p_est_cuenta in ('T') then
     -- cuenta con estado bloqueado o cancelado
     v_salida := 'Cuenta totalmente bloqueada';
  elsif p_est_cuenta in ('C') then
     -- cuenta con estado Cancelado
     v_salida := 'Cuenta Cancelada';   
  elsif p_est_cuenta in ('P')  and p_tip_operacion = 'C' then
     -- Cuenta esta pendiente de cancelar, no puede recibir creditos
     v_salida := 'Cuenta esta pendiente de Cancelacion';  
  elsif p_est_cuenta in ('D')  and p_tip_operacion = 'D' then
     -- Cuenta tiene bloqueo de debito, no puede ser debitado
     v_salida := 'Cuenta tiene bloqueo de Debito';  
  elsif p_cod_modalidad in (32,33,34) and p_est_cuenta <> 'A' and p_tip_operacion = 'C' then
     -- cda, o plazo fijo ya esta activa, no puede recibir creditos 
     v_salida := 'Cuenta no puede recibir creditos';
  else
    -- verifico si la cuenta no tiene transaccion prohibida
    begin
      select 'Cuenta no habilitada para esta Transaccion'
        into v_salida
        from ge_tra_prohibidas
       where nro_cuenta = p_nro_cuenta
         and cod_transaccion = p_cod_transaccion
         and cod_modalidad = p_cod_modalidad;
    exception
      when no_data_found then 
         v_salida := null;
      when others then  
         v_salida := 'GE_TRANSACCIONES '||sqlerrm;
    end;
  end if;      
  return(v_salida);
exception
   when others then
        return ('ERROR ' ||sqlerrm);
end FUJ_VER_IMPEDIMENTOS;
/

