CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_PROFESION(P_COD_PROFESION IN BA_PROFESIONES.COD_PROFESION%TYPE)
  RETURN VARCHAR2 IS
  v_descripcion BA_PROFESIONES.DESCRIPCION%TYPE;
BEGIN
  begin
    --Obtiene el código de País
    select p.descripcion
      into v_descripcion
      from ba_profesiones p
     where p.cod_profesion = P_COD_PROFESION;
  exception
    when others then
      v_descripcion := null;
  end;

  return v_descripcion;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
/

