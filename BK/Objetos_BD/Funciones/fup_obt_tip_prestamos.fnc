create or replace function it.
   fup_obt_tip_prestamos(p_estado in varchar2, p_tip_renovacion in varchar2, p_tipo in varchar2)
return varchar2 is
v_resultado varchar2(30);
begin
 select decode(p_estado,  'C', decode(p_tip_renovacion, 'A',fue_obt_des_refcodes('TIP_PRESTAMO',p_tipo), 'Todos'),
      'A', decode(p_tip_renovacion, 'A',fue_obt_des_refcodes('TIP_PRESTAMO',p_tipo), 'Todos'), 'Todos')
   into v_resultado from dual;
 return v_resultado;     
end;
/

