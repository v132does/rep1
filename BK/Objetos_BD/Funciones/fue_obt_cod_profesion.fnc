CREATE OR REPLACE FUNCTION IT.fue_obt_cod_profesion(P_DES_PROFESION IN BA_PROFESIONES.DESCRIPCION%TYPE)
  RETURN NUMBER IS
  v_cod_profesion BA_PROFESIONES.COD_PROFESION%TYPE;
BEGIN
  begin
    --Obtiene el código de País
    select p.cod_profesion
      into v_cod_profesion
      from ba_profesiones p
     where upper(paw_bem.depurarTextos_dev(p.descripcion, 35)) = upper(p_des_profesion);
  exception
    when others then
      v_cod_profesion := null;
  end;

  return v_cod_profesion;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
/

