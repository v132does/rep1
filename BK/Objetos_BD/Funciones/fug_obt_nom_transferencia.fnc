create or replace function it.fug_obt_nom_transferencia(p_cod_transaccion in varchar2,
                                                        p_transactionId   in varchar2,
                                                        p_fecha           date,
                                                        p_hora            in varchar2,
                                                        p_cod_usuario     in varchar2)
  return varchar2 is
  result       varchar2(300);
  v_nro_cuenta ah_movimientos_his.nro_cuenta%type;
begin
  begin
    select decode(p_cod_transaccion, 602,t.nom_solicitante, 503, t.nom_beneficiario, t.nom_solicitante)
      into result
      from ge_snp_transferencias t
     where t.nro_referencia = p_transactionId;
  exception
    when no_data_found then
      if p_cod_transaccion = 602 then
        begin
          select t.nro_cuenta
            into v_nro_cuenta
            from ah_movimientos_his t
           where t.fecha = p_fecha
             and t.hora = p_hora
             and t.cod_usuario = p_cod_usuario
             and t.cod_transaccion = 503
             and t.nro_documento = p_transactionId

          union all

          select t.nro_cuenta
            from ge_movimientos t
           where t.fecha = p_fecha
             and t.hora = p_hora
             and t.cod_usuario = p_cod_usuario
             and t.cod_transaccion = 503
             and t.nro_documento = p_transactionId;
        exception
          when others then
            result := null;
        end;

      else
        begin
          select t.nro_cuenta
            into v_nro_cuenta
            from ah_movimientos_his t
           where t.fecha = p_fecha
             and t.hora = p_hora
             and t.cod_usuario = p_cod_usuario
             and t.cod_transaccion = 602
             and t.nro_documento = p_transactionId

          union all

          select t.nro_cuenta
            from ge_movimientos t
           where t.fecha = p_fecha
             and t.hora = p_hora
             and t.cod_usuario = p_cod_usuario
             and t.cod_transaccion = 602
             and t.nro_documento = p_transactionId;
        exception
          when others then
            result := null;
        end;

      end if;

      begin
        select p.nom_completo
          into result
          from ge_cta_clientes t, ba_personas p
         where t.cod_persona = p.cod_persona
           and t.relacion = 'P'
           and t.nro_cuenta = v_nro_cuenta;
      exception
        when others then
         result := null;
      end;
    when others then
      result := null;
  end;

  return(result);
exception
  when others then
    return(result);
end fug_obt_nom_transferencia;
/

