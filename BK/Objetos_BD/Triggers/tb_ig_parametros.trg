CREATE OR REPLACE TRIGGER IT.TB_IG_PARAMETROS
 BEFORE DELETE OR INSERT OR UPDATE
     ON IG_PARAMETROS
    FOR EACH ROW
DECLARE
  v_nractiv ig_parametros.cod_periodo%type;
BEGIN
  if inserting then
    IF :new.cod_periodo IS NULL THEN
      BEGIN
        select s_cod_periodo.nextval
          into v_nractiv
          from dual;
      EXCEPTION
        when others then
          v_nractiv := 0;
      END;
      :new.cod_periodo := v_nractiv;
    END IF;
  end if;
  if deleting or updating then
    if :old.liquidado = 'S' then
      raise_application_error(-20000,'No puede actualizar o eliminar registros liquidados');
    end if;
  end if;
END;
/

