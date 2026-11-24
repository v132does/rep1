create or replace function it.fug_obt_fec_incobrable(p_cuenta in varchar2, p_modulo in number)
  return date is
  v_retorno ge_cuentas_nov.fecha%type;
begin
  if p_modulo = 6 then
         Select max(a.fecha)
           into v_retorno
           from ge_cuentas_nov a
          where a.nro_cuenta = p_cuenta
            and a.cod_modulo = 6
            and a.est_actual = 'I';
 else 
        Select max(o.fec_cam_estado)
          into v_retorno
          from ov_cta_vencidas o
         where o.nro_cuenta = p_cuenta
           and o.estado = 'I';
  end if;        
  return v_retorno;
exception
  when others then
    return null ;
end fug_obt_fec_incobrable;
/

