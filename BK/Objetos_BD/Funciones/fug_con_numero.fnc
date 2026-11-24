CREATE OR REPLACE FUNCTION IT.fug_con_numero( p_numero varchar2 ) RETURN NUMBER IS
  v_nro NUMBER;
  v_val_convertido VARCHAR2(25);
BEGIN
  begin
    select to_number(p_numero)
      into v_nro
      from dual;

    return v_nro;
  EXCEPTION
    WHEN OTHERS THEN
      begin
         v_val_convertido := replace(p_numero, ',','.');
         v_nro := to_number(v_val_convertido);
         return v_nro;
      exception
        when others then
         v_val_convertido := replace(p_numero, '.',',');
         v_nro := to_number(v_val_convertido);
         return v_nro;
     end;
  END;
END;
/

