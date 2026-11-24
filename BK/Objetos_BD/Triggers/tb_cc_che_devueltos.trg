CREATE OR REPLACE TRIGGER IT.TB_CC_CHE_DEVUELTOS
  BEFORE DELETE OR UPDATE
     ON CC_CHE_DEVUELTOS
    FOR EACH ROW
      /*
      ** Este trigger sirve para buscar los cheques que se Devolvieron desde cámara
      ** y son cargo nuestro banco
      ** CRO-JM-08/2014
      */
DECLARE
  v_existe           varchar2(1);
  v_cod_che_custodia number;
  v_cod_emisor       number;
BEGIN
  begin
    select 'S', a.cod_che_custodia, b.cod_emisor
      into v_existe, v_cod_che_custodia, v_cod_emisor
      from cc_che_custodias a, cc_che_custodias_det b
     where a.cod_che_custodia = b.cod_che_custodia
       and b.nro_documento = :new.nro_cheque
       and b.nro_cta_debito = :new.nro_cuenta;
  exception
    when others then
      v_existe := 'N';
  end;
  if v_existe = 'S' and nvl(:new.regularizado, 'N') = 'N' and
     (v_cod_emisor = 7) then
    update cc_che_custodias_det a
       set a.estado = 'B' -- seteamos como devuelto en cámara
     where a.cod_che_custodia = v_cod_che_custodia
       and a.nro_documento = :new.nro_cheque
       and a.nro_cta_debito = :new.nro_cuenta;
  end if;
EXCEPTION
  when others then
    raise_application_error(-20000,
                            'Existe un error en el trigger AA_CC_CHE_DEVUELTOS ' ||
                            sqlerrm);
END;
/

