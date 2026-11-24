CREATE OR REPLACE FUNCTION IT.fuk_cal_impuesto (p_monto in number,
                           p_tas_impuesto in number, p_incluido in varchar2 default 'S',
                           p_redondeo in number)
return number is
v_val_impuesto number := 0;
begin
   if p_redondeo is not null then
      if nvl(p_incluido,'N') = 'S' then
         v_val_impuesto     := p_monto - round((p_monto * 100) / (p_tas_impuesto + 100),p_redondeo);
      else
         v_val_impuesto     := round((p_monto * p_tas_impuesto) / 100,p_redondeo);
      end if;
   else
      if nvl(p_incluido,'N') = 'S' then
         v_val_impuesto     := p_monto - ((p_monto * 100) / (p_tas_impuesto + 100));
      else
         v_val_impuesto     := ((p_monto * p_tas_impuesto) / 100);
      end if;
    end if;
   return v_val_impuesto;
end;
/

