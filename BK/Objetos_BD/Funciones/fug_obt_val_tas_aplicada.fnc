CREATE OR REPLACE FUNCTION IT.fug_obt_val_tas_aplicada
--Función Obtiene Tasa Aplicada al CDA.
(P_NRO_CUENTA in ge_cuentas.nro_cuenta%type)
RETURN number IS
  v_capital          number;
  v_interes          number;
  v_plazo            number;
  v_tiempo           number;
  v_val_tas_aplicada number;
begin
  select g.capital, g.fec_vencimiento - g.fec_apertura,  sum(mto_interes)
    into v_capital, v_plazo, v_interes
    from ah_cta_certificados g, ah_cupones c
   where g.nro_cuenta = c.nro_cuenta
     and c.nro_cuenta = P_NRO_CUENTA
   group by g.capital, g.fec_vencimiento - g.fec_apertura;

  v_tiempo := v_plazo / 365;

  v_val_tas_aplicada := round((( v_interes / (v_capital * v_tiempo)) * 100),2);

  RETURN v_val_tas_aplicada;

exception
  when others then
    null;
end;
/

