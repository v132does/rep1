create or replace function it.fub_obt_rubro_cuota(p_nro_cuenta varchar2, p_tip_saldo varchar2) return varchar2 is
  v_rubro varchar2(15);
begin

  if(p_tip_saldo='C') then --capital  
    select i.cod_rubro
    into v_rubro
    from cb_sal_inventarios_det d 
    left outer join cb_sal_inventarios i on (i.nro_referencia=d.nro_referencia)
    where d.nro_cuenta=p_nro_cuenta
    and (i.tip_saldo='C' or i.tip_saldo='F')
    and rownum=1; --prestamos financiados por afd se contabilizan en varios rubros
  elsif(p_tip_saldo='I') then --interes
    select i.cod_rubro
    into v_rubro
    from cb_sal_inventarios_det d 
    left outer join cb_sal_inventarios i on (i.nro_referencia=d.nro_referencia)
    where d.nro_cuenta=p_nro_cuenta
    and i.tip_saldo =p_tip_saldo;  
  end if;
  
  return(v_rubro);
  
  exception
     when others then
          return null;
end fub_obt_rubro_cuota;
/

