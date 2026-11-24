CREATE OR REPLACE TRIGGER IT.TB_LC_POSICIONES
 BEFORE INSERT OR UPDATE
 ON LC_POSICIONES
 FOR EACH ROW
DECLARE
  v_existe varchar2(1);
BEGIN
  begin
    select distinct 'S'
      into v_existe
      from lc_sal_posiciones
     where cod_moneda = :new.cod_moneda
       and cod_ofi_cambio = :new.cod_ofi_cambio;
  exception
    when no_data_found then
      v_existe := 'N';
  end;
  --
  if nvl(v_existe,'N') = 'N' then
    insert into lc_sal_posiciones
      (cod_ofi_cambio, cod_moneda, tip_posicion, mto_efe_compra,
       mto_efe_venta, mto_nef_compra, mto_nef_venta, cot_efectivo, cot_no_efectivo)
    values
      (:new.cod_ofi_cambio, :new.cod_moneda, 'E', 0,
       0, 0, 0, 0, 0);
    --
    insert into lc_sal_posiciones
      (cod_ofi_cambio, cod_moneda, tip_posicion, mto_efe_compra,
       mto_efe_venta, mto_nef_compra, mto_nef_venta, cot_efectivo, cot_no_efectivo)
    values
      (1/*:new.cod_ofi_cambio*/, :new.cod_moneda, 'O', 0,
       0, 0, 0, 0, 0);
  end if;
END;
/

