CREATE OR REPLACE TRIGGER IT.TB_TA_TAR_GLOBAL_TMP
  BEFORE INSERT ON TA_TAR_GLOBAL_TMP
  FOR EACH ROW
DECLARE
  v_existe   number;
  v_existe_2 number;
BEGIN
  --Persona
  begin
    select count(*)
      into v_existe
      from TA_TAR_GLOBAL_TMP s
     where s.cod_persona = :new.cod_persona;
      if v_existe <> 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
                                'No se puede insertar mas de un registro para un mismo COD_PERSONA:'||:new.cod_persona||'. Favor Verifique!!');
      end if;
  end;
  --Cuenta
  begin
    select count(*)
      into v_existe_2
      from TA_TAR_GLOBAL_TMP s
     where s.nro_cuenta = :new.nro_cuenta;
      if v_existe_2 <> 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
                                'No se puede insertar mas de un registro para un NRO_CUENTA:'||:new.nro_cuenta||'. Favor Verifique!!');
      end if;
  end;
END;
/
