create or replace function it.fug_obt_val_parcausal(p_parametro   varchar2,
                                                 p_cod_persona varchar2 default null,
                                                 p_nro_cuenta  varchar2 default null)
  return varchar2 is
  v_val_parametro ge_par_causales.val_parametro%type := 'N';
  v_inh_firmante varchar2(1) := 'N';
begin
  begin
    select distinct b.val_parametro
      into v_val_parametro
      from ge_per_inhibidas a, ge_par_causales b
     where a.cod_persona = p_cod_persona
       and b.parametro = p_parametro
       and b.cod_causa = a.cod_causa
       and a.estado = 'I'
       and b.val_parametro = 'S'
       and rownum = 1;
  exception
    when no_data_found then
      v_val_parametro := 'N';
    when others then
      v_val_parametro := 'N';
  end;
  if p_nro_cuenta is not null and v_val_parametro = 'N' then
    begin
      select 'S'
        into v_inh_firmante
        from ge_cuentas a, ge_cta_clientes b
       where a.nro_cuenta = b.nro_cuenta
         and a.nro_cuenta = p_nro_cuenta
         and b.relacion in ('P', 'Y')
         and exists (select 1
                from ge_per_inhibidas c, ge_par_causales d
               where c.cod_persona = b.cod_persona
                 and c.estado = 'I'
                 and d.cod_causa = c.cod_causa
                 and d.parametro = p_parametro
                 and d.val_parametro = 'S')
         and rownum = 1;
    exception
      when no_data_found then
        v_inh_firmante := 'N';
    END;
  END IF;
  if nvl(v_val_parametro, 'N') = 'S' or nvl(v_inh_firmante, 'N') = 'S' then
    return 'S';
  else
    return 'N';
  end if;
end;
/

