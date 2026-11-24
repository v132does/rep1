CREATE OR REPLACE TRIGGER IT.TB_CC_CHE_RECIBIDOS_TMP
 BEFORE INSERT OR UPDATE
 ON CC_CHE_RECIBIDOS_TMP
 FOR EACH ROW
DECLARE
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
BEGIN
  --Si viene Bco. 11 (ABN) cambiar a 28 (Regional)
  if inserting then
    if :new.cod_bco_receptor = 11 then
      :new.cod_bco_receptor := 28;
    end if;

    --Cuentas Bancarias (Si se proceso el archivo de CIDESA, empiezan con "3151")
    if substr(:new.nro_cuenta,1,4) = '3151' then
      begin
        select b.nro_cuenta
          into v_nro_cuenta
          from cc_cta_bancarias b
         where b.cod_modalidad = 42
           and b.cod_banco = :new.cod_bco_receptor
           and b.cod_moneda = pag_gen.fu_obt_mon_local;

        :new.nro_cuenta := v_nro_cuenta;

      exception
        when others then
           null;
      end;
    end if;

    --Evaluar Equivalencias que Ctas. que cambiaron de Nro.
    if :new.nro_cuenta = '0701009720' then
       :new.nro_cuenta := '1101009723';
    elsif :new.nro_cuenta = '0101149537' then
       :new.nro_cuenta := '2101149532';
    end if;
  end if;
END;
/

