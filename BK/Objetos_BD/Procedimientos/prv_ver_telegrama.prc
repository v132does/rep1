create or replace procedure it.prv_ver_telegrama(p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                                               p_cod_causa out number,
                                               p_observacion out varchar2,
                                               p_fecha_entrega_cli out date)
is
 v_cod_can varchar2(500);
begin
  p_cod_causa := null;
  v_cod_can := nvl(to_char(p_cod_causa),fug_obt_pardinamico('COD_CAU_PAS_VENCIDA'));
  p_observacion := 'No tiene telegrama '||v_cod_can;
  /*Verifica que el cliente haya recibido por esa cuenta un telegrama relacionado con la cancelacion
    de su cuenta corriente por pasar a vencida.
    C = Estado Entregado al Cliente
    ge_telegramas.FEC_ENTREGA = fecha de entrega al cliente */
  select a.cod_causa, a.fec_entrega, substr(substr('CC.'||p_nro_cuenta||' p/'||c.descripcion,1,35),1,50)
    into p_cod_causa, p_fecha_entrega_cli, p_observacion
    from ge_telegramas a, ge_telegramas_det b, ge_causales c
   where a.cod_telegrama = b.cod_telegrama (+)
     and a.cod_causa = c.cod_causa
     and a.ref_cuentas  like '%'||to_char(p_nro_cuenta)||'%'
     and a.estado = 'C'
     --and a.cod_causa = v_cod_can
     and instr(','||v_cod_can||',' ,  ','||a.cod_causa||',') > 0
     and a.fec_entrega is not null
     and a.fec_entrega = (select max(t.fec_entrega)
                          from   ge_telegramas t
                          where  t.ref_cuentas like '%'||to_char(p_nro_cuenta)||'%'
                          and    t.estado = 'C'
                          --and    t.cod_causa = v_cod_can
                          and    instr(','||v_cod_can||',' ,  ','||t.cod_causa||',') > 0
                          and    t.fec_entrega is not null)
     and rownum = 1;
exception
  when no_data_found then
     null;
  when others then
     raise_application_error(-20000,'Telegramas'||sqlerrm);
end;
/

