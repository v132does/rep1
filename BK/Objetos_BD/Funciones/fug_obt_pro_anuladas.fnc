create or replace function it.fug_obt_pro_anuladas(p_nro_referencia in bw_ope_programadas.nro_referencia%type,
                                                p_cod_tip_operacion in bw_tip_mensajes.cod_tip_mensaje%type) return number is
  v_retorno number := 0;
begin
  select count(0)
    into v_retorno
    from bw_ope_programadas_det t
   where t.nro_referencia = p_nro_referencia
     and t.estado = 'A';
     
  if p_cod_tip_operacion = '036' then
    select v_retorno + count(0)
      into v_retorno
      from bw_ope_programadas_det det, ge_snp_transferencias snp
     where det.nro_referencia = p_nro_referencia
       and det.estado = 'C'
       and det.nro_documento = snp.nro_referencia
       and (snp.estado IN ('C','E','R') OR snp.situacion IN ('C','E','T'));     
  end if;  
  return (v_retorno);
exception
  when others then
     return -1;
end fug_obt_pro_anuladas;
/

