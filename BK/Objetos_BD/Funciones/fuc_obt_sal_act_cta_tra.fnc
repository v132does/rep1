create or replace function it.FUC_OBT_SAL_ACT_CTA_TRA
(P_NRO_CUENTA   ge_cuentas.nro_cuenta%TYPE,
 P_INC_SAL_TOTAL varchar2 default 'S')
  return number is
--verifica si es una cuentra transaccional
  v_exi_cta_tran varchar2(1) := 'N';
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_sal_total cc_cta_corrientes.sal_total%type;
  v_mto_debito ge_movimientos.monto%type;
  v_mto_deb_noc ge_movimientos_noc.monto%type;
  v_mto_credito ge_movimientos.monto%type;
  v_mto_cre_noc ge_movimientos_noc.monto%type;
  v_cod_moneda  cc_cta_corrientes.cod_moneda%type;
begin
  begin
    select 'S'
      into v_exi_cta_tran
      from cc_cta_transaccionales
     where nro_cuenta = p_nro_cuenta
       and (activo = 'S' or (activo = 'N' and fec_inactivacion > v_fec_actual))
       and fec_activacion <= v_fec_actual;
   exception
      when others then
        v_exi_cta_tran := 'N';
   end;
   if v_exi_cta_tran = 'S' then
     if nvl(P_INC_SAL_TOTAL, 'S') = 'S' then
       begin
         select sal_total, cod_moneda
           into v_sal_total, v_cod_moneda
           from cc_cta_corrientes
          where nro_cuenta = p_nro_cuenta;
       exception
         when others then
           v_sal_total := 0;
       end;
     else
       v_sal_total := 0;
       begin
         select cod_moneda
           into v_cod_moneda
           from cc_cta_corrientes
          where nro_cuenta = p_nro_cuenta;
       exception
         when others then
           v_cod_moneda := 'GS';
       end;
     end if;
     begin
       SELECT sum(a.monto)
         into v_mto_credito
         FROM GE_MOVIMIENTOS a, ge_transacciones d
        WHERE a.ESTADO = 'N'
          and a.nro_cuenta= p_nro_cuenta
          and a.cod_moneda= v_cod_moneda
          and a.cod_usuario like 'ATM%'
          and a.fecha= v_fec_actual
          and a.cod_modulo = d.cod_modulo
          and a.cod_modalidad = d.cod_modalidad
          and a.cod_transaccion = d.cod_transaccion
          and d.tipo='C';
     exception
       when others then
          v_mto_credito := 0;
     end;
     begin
       SELECT sum(a.monto)
         into v_mto_cre_noc
         FROM GE_MOVIMIENTOS_NOC a, ge_transacciones d
        WHERE a.ESTADO = 'N'
          and a.nro_cuenta= p_nro_cuenta
          and a.cod_moneda= v_cod_moneda
          and a.cod_usuario like 'ATM%'
          and a.fecha= v_fec_actual
          and a.cod_modulo = d.cod_modulo
          and a.cod_modalidad = d.cod_modalidad
          and a.cod_transaccion = d.cod_transaccion
          and d.tipo='C';
     exception
       when others then
          v_mto_cre_noc := 0;
     end;
     begin
        SELECT sum(a.monto)
          into v_mto_debito
         FROM GE_MOVIMIENTOS a, ge_transacciones d
          WHERE a.ESTADO = 'N'
             and a.nro_cuenta= p_nro_cuenta
             and a.cod_moneda= v_cod_moneda
             and a.cod_usuario like 'ATM%'
             and a.fecha= v_fec_actual
             and a.cod_modulo = d.cod_modulo
             and a.cod_modalidad = d.cod_modalidad
             and a.cod_transaccion = d.cod_transaccion
             and d.tipo='D';
      exception
        when others then
           v_mto_debito := 0;
      end;
      
      begin
        SELECT sum(a.monto)
          into v_mto_deb_noc
         FROM GE_MOVIMIENTOS_NOC a, ge_transacciones d
          WHERE a.ESTADO = 'N'
             and a.nro_cuenta= p_nro_cuenta
             and a.cod_moneda= v_cod_moneda
             and a.cod_usuario like 'ATM%'
             and a.fecha= v_fec_actual
             and a.cod_modulo = d.cod_modulo
             and a.cod_modalidad = d.cod_modalidad
             and a.cod_transaccion = d.cod_transaccion
             and d.tipo='D';
      exception
        when others then
           v_mto_deb_noc := 0;
      end;

      return nvl(v_sal_total, 0) + nvl(v_mto_credito, 0) + nvl(v_mto_cre_noc, 0) - nvl(v_mto_debito,0) -nvl(v_mto_deb_noc, 0);
   else
      return 0;
   end if;

exception
  when others then
    return 0;
end FUC_OBT_SAL_ACT_CTA_TRA;
/

