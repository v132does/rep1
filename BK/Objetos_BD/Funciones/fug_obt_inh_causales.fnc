create or replace function it.fug_obt_inh_causales(p_cod_persona in ba_personas.cod_persona%type)
  return varchar2 is
  v_inh_descri  ge_causales.descripcion%type;
  v_inh_tdescri varchar2(500);
begin
  for cinh in (select b.cod_causa
                 from ge_per_inhibidas b
                where cod_persona = p_cod_persona
                  and estado = 'I') loop
    select c.descripcion
      into v_inh_descri
      from ge_causales c
     where c.cod_causa = cinh.cod_causa;
    if trim(v_inh_tdescri) is null then
      v_inh_tdescri := v_inh_descri;
    else
      v_inh_tdescri := v_inh_descri || ' ,';
    end if;
  end loop;
  return v_inh_tdescri;
exception
  when others then
    return '';
end;
/

