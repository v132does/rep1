create or replace procedure it.pr_cta_asoc_nvo_desemb
(P_NRO_CTA_VIEJA IN GE_CUENTAS.NRO_CUENTA%TYPE,
P_NRO_CTA_NUEVA IN GE_CUENTAS.NRO_CUENTA%TYPE,
FEC_ULT_PAGO IN VARCHAR2)
is
v_FEC_ULT_PAGO DATE;
cursor cta_vieja
is
select g.nro_cuenta, g.cod_transaccion, g.cod_moneda, g.monto, g.fec_ingreso, g.fec_vencimiento, g.fec_ult_pago,
       g.cod_modalidad, g.hor_ult_pago, g.cod_modulo, g.fec_ini_vigencia, g.nro_solicitud
from pr_cta_gastos g
where g.nro_cuenta = P_NRO_CTA_VIEJA
  and g.fec_ult_pago = v_FEC_ULT_PAGO;

begin
  if (P_NRO_CTA_VIEJA = P_NRO_CTA_NUEVA) then
     raise_application_error(-20000,'Las cuentas no pueden ser iguales');
  end if;
  v_FEC_ULT_PAGO := TO_DATE(FEC_ULT_PAGO,'DD/MM/YYYY');
  for reg in cta_vieja loop
      dbms_output.put_line(P_NRO_CTA_NUEVA||','||reg.cod_transaccion||','||reg.monto);
      insert into pr_cta_gastos (nro_cuenta, cod_transaccion, cod_moneda, monto, fec_ingreso, fec_vencimiento,
      fec_ult_pago, cod_modalidad, hor_ult_pago, cod_modulo, fec_ini_vigencia, nro_solicitud)
      values (P_NRO_CTA_NUEVA, reg.cod_transaccion, reg.cod_moneda, reg.monto, reg.fec_ingreso, reg.fec_vencimiento,
      null, reg.cod_modalidad, reg.hor_ult_pago, reg.cod_modulo, reg.fec_ini_vigencia, reg.nro_solicitud);

  end loop;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20001,'Error: En el proceso de asociar los nuevos cargos... '||sqlerrm);
    End if;
end;
/

