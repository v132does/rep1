create or replace function it.fup_obt_rel_garantia(p_cod_persona in varchar2, p_cod_garantia in number) return number is
  v_relacion pr_lin_tip_garantias.rel_garantia%type;
begin
  Select max(rel_garantia)
   into v_relacion
   from pr_lin_tip_garantias
  where cod_garantia = p_cod_garantia
    and nro_linea = (Select nro_linea
                       from pr_lineas
                      where estado = 'A'
                        and cod_persona = p_cod_persona);
  return(v_relacion);
end fup_obt_rel_garantia;
/

