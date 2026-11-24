create or replace procedure it.prg_act_cuentas(p_nro_cuenta varchar2,
                                            p_estado     varchar2,
                                            p_error  out varchar2) is
  v_fecha         ge_movimientos.fecha%type;
  v_hora          ge_movimientos.hora%type;
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  v_nro_documento ge_movimientos.nro_documento%type;
  -- Procedimiento que modifica el estado de la Cuenta a estado (N)Normal. BSEVOCORE-200
begin
  p_error         := null;
  v_fecha         := pag_cal.fu_obt_fec_actual(1);
  v_hora          := to_char(sysdate, 'HH24:MI:SS');
  v_nro_documento := s_nro_documento.nextval;
  v_nro_secuencia := 0;
  pag_cta.pr_obt_cuenta(p_nro_cuenta);
  pag_cta.pr_set_variables(user, v_fecha, 425, p_estado, 'N', v_nro_secuencia, p_estado, 
                           pag_cta.g_ctas.cod_oficina, pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad);
  pag_cta.pr_act_estado(p_nro_cuenta, p_estado, v_fecha, v_hora, v_nro_documento);
  commit;
exception
  when others then
    p_error := 'Error en PRG_ACT_CUENTAS '||sqlerrm;
end;
/

