CREATE OR REPLACE TRIGGER IT.TA_CC_CHE_DEVUELTOS
  AFTER INSERT OR UPDATE
     ON CC_CHE_DEVUELTOS
    FOR EACH ROW
      /*
      */
DECLARE
  v_existe           varchar2(1);
BEGIN
  begin
    select 'S'
      into v_existe
      from cc_che_hibridos a
     where a.fecha = :new.fecha
       and a.hora = :new.hora
       and a.nro_cuenta = :new.nro_cuenta
       and a.nro_cheque = :new.nro_cheque;
  exception
    when others then
      v_existe := 'N';
  end;
  if v_existe = 'S' then

     pag_btw.pr_upd_che_hibridos(:new.fecha, 
                         :new.hora,
                         :new.cod_usuario, 
                         :new.nro_cuenta,
                         :new.nro_cheque,
                         :new.monto,
                         'D',  --situacion = 'D', -- seteamos como devuelto
                          :new.cod_causa);

  end if;
EXCEPTION
  when others then
    raise_application_error(-20000,
                            'Existe un error en el trigger AA_CC_CHE_DEVUELTOS ' ||
                            sqlerrm);
END;
/

