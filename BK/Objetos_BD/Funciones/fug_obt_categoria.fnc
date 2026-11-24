create or replace function it.fug_obt_categoria(p_tra_padre in number,
                                                p_mad_padre in number,
                                                p_mod_padre in number)
  return varchar2 is
  v_categoria varchar2(50);
begin
  if p_tra_padre in (309, 388, 303, 385) then
    v_categoria := 'Transferencia';
  elsif p_tra_padre in (353, 382) then
    v_categoria := 'Extraccion de efectivo';
  elsif p_tra_padre = '9731' then
    v_categoria := 'Transferencia por contacto';
  elsif p_tra_padre = '8592' then
    v_categoria := 'Pago de servicios';
  else
    v_categoria := 'Servicios financieros';
  end if;

  return(v_categoria);
end fug_obt_categoria;
/

