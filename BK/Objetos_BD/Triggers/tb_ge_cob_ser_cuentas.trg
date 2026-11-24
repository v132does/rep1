CREATE OR REPLACE TRIGGER IT.TB_GE_COB_SER_CUENTAS
 BEFORE INSERT OR UPDATE
 ON GE_COB_SER_CUENTAS
 FOR EACH ROW

DECLARE
  vcod_mon_ser GE_CUENTAS.COD_MONEDA%TYPE;
  vcod_moneda  GE_CUENTAS.COD_MONEDA%TYPE;
  vcod_modulo  GE_CUENTAS.COD_MODULO%TYPE;
  vestado      GE_CUENTAS.ESTADO%TYPE;
  vmensaje     VARCHAR2(2000);
  verror       EXCEPTION;
BEGIN
  IF inserting OR updating THEN
    BEGIN
      select cod_moneda
        into vcod_mon_ser
        from ge_cob_ser_parametros s, ge_cuentas c
       where s.cod_servicio = :new.cod_servicio
         and s.nro_cuenta = c.nro_cuenta;
    EXCEPTION
      when others then
        vmensaje := 'Se produjo un error al buscar los datos de la cuenta del servicio ' || sqlerrm;
        raise verror;
    END;
    BEGIN
      select cod_moneda, cod_modulo, estado
        into vcod_moneda, vcod_modulo, vestado
        from ge_cuentas
       where nro_cuenta = :new.nro_cuenta;
    EXCEPTION
      when verror then
        raise verror;
      when others then
        vmensaje := 'Se produjo un error al buscar los datos de la cuenta ' || sqlerrm;
        raise verror;
    END;
    IF vcod_modulo NOT IN( 3, 4 ) THEN
      vmensaje := 'La cuenta debeser de Ahorro o Cuenta Corriente.';
      raise verror;
    END IF;
    IF vestado IN( 'A', 'X', 'C' ) THEN
      vmensaje := 'No puede cargar una cuenta con estado "' || vestado || '".';
      raise verror;
    END IF;
    IF nvl( vcod_mon_ser, 'x' ) <> nvl( vcod_moneda, 'x' ) THEN
      vmensaje := 'La moneda de la cuenta (' || vcod_moneda ||
                  ') no coincide con la moneda del servicio (' || vcod_mon_ser ||
                  ').';
      raise verror;
    END IF;
  END IF;
EXCEPTION
  when verror then
    RAISE_APPLICATION_ERROR( -20151, vmensaje );
  when others then
    RAISE_APPLICATION_ERROR( -20152, 'ERROR. Al validar los datos de la cuenta (TB_GE_COB_SERVICIOS) ' || sqlerrm );
END;
/

