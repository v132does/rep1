create or replace function it.fug_obt_max_atraso_ult_cuotas
 (p_nro_cuenta in varchar2, 
  p_can_cuotas in number,
  p_fec_control in date default sysdate) return number is
  Result number := 0;
cursor cuotas is
   select nvl(a.fec_ult_pago,sysdate) - a.fec_vencimiento dia_atraso
    from pr_cuotas a
   where a.nro_cuenta = p_nro_cuenta
     and a.fec_vencimiento < nvl(p_fec_control,sysdate)
   order by a.fec_vencimiento desc;
v_can_cuotas number(6) := 0;  
begin
  for ct in cuotas loop
      v_can_cuotas := v_can_cuotas + 1;
      if nvl(ct.dia_atraso,0) > Result then
         Result := nvl(ct.dia_atraso,0);
      end if;
      exit when v_can_cuotas >= p_can_cuotas;
  end loop;
  return(Result);
end fug_obt_max_atraso_ult_cuotas;
/

