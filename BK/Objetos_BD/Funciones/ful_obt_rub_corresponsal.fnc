create or replace function it.ful_obt_rub_corresponsal (p_cod_banco in number, p_cod_moneda in varchar2)
return varchar2 is

v_cod_rubro cb_rubros.cod_rubro%type;
begin
  select cod_rubro
    into v_cod_rubro
    from cc_cta_bancarias
   where cod_banco = p_cod_banco
     and cod_moneda = p_cod_moneda
     and cod_modalidad = 45;
   return v_cod_rubro;
exception
   when no_data_found then
      raise_Application_error(-20000,'Corresponsal inexistente');
   when too_many_rows then
      raise_Application_error(-20000,'Más de un Corresponsal definido para el Banco y Moneda');
   when others then
      raise_Application_error(-20000,'Obt.Corresponsal. '||sqlerrm);
end;
/

