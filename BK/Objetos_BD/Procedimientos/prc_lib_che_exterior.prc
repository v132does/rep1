CREATE OR REPLACE PROCEDURE IT.PRC_LIB_CHE_EXTERIOR
 (P_NRO_CUENTA IN GE_CHE_EXTERIOR.NRO_CUENTA%TYPE
 ,P_NRO_CHEQUE IN GE_CHE_EXTERIOR.NRO_CHEQUE%TYPE
 ,P_NRO_SECUENCIA IN ge_movimientos.nro_secuencia%type DEFAULT NULL
 )
 IS
v_hora          ge_movimientos.hora%type;
v_fec_actual    date;
v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
cursor cheques is
  select ext.nro_cuenta,ext.nro_cheque,ext.cod_banco,ext.monto,
         cta.cod_moneda,cta.cod_oficina
    from ge_che_exterior ext,
         ge_cuentas cta
   where ext.estado = 'C' --confirmados
     and ext.nro_cuenta = nvl(p_nro_cuenta,ext.nro_cuenta)
     and ext.nro_cheque = nvl(p_nro_cheque,ext.nro_cheque)
     and ext.fec_final <= v_fec_actual
     and ext.nro_cuenta = cta.nro_cuenta;
begin
    v_fec_actual := pag_cal.fu_obt_fec_actual(4);
    v_hora := to_char(sysdate,'HH24:mi:ss');
    If p_nro_secuencia is not null then
      v_nro_secuencia := p_nro_secuencia;
    end if;
    for che_ext in cheques loop
      v_nro_secuencia := v_nro_secuencia + 1;
      pag_cta.pr_act_operacion(che_ext.nro_cuenta,
                               v_hora,
                               'C',
                               che_ext.cod_moneda,
                               che_ext.monto,
                               184,
                               184,
                               che_ext.nro_cheque,
                               null,
                               che_ext.cod_oficina,
                               4,
                               41,
                               null, -- tasa
                               null, -- valor de tasa
                               'Cheque del exterior',
                               'S',
                               v_nro_secuencia,
                               v_fec_actual/*,
                               che_ext.cod_banco*/
                               );
      if pag_cta.fu_obt_cod_error() <> 0 then
         raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error());
      end if;
    end loop;
    if v_nro_secuencia = 0 then
      raise_application_error(-20000,'No existe(n) cheque(s) a liberar');
    end if;
end;
/

