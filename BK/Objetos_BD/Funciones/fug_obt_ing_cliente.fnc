create or replace function it.fug_obt_ing_cliente(p_cod_persona varchar2, p_tipo varchar2)
return number is
v_mto cr_inf_laborales.mto_ingreso%type:=0;

begin
begin
IF p_tipo = 'F' THEN
   begin
      Select sum(FUB_CON_MON_A_MONEDA(cod_moneda,
         pag_gen.fu_obt_mon_local(),
         mto_ingreso))
         into v_mto
      from cr_inf_laborales
      where cod_persona = p_cod_persona
      and actual = 'S';
   exception
   when no_data_found then
      return (0);
      when others then
      return(0);
   end;
ELSE
   begin
      select sum(importe)
         into v_mto
      from cr_per_ing_egresos
      where cod_persona = p_cod_persona
         and ing_egreso = 'I';
   exception
   when no_data_found then
      return (0);
      when others then
      return(0);
   end;
END IF;
return(nvl(v_mto,0));
end;
end;
/

