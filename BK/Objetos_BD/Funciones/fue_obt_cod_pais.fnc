CREATE OR REPLACE FUNCTION IT.FUE_OBT_COD_PAIS(P_DES_PAIS IN BA_PAISES.DESCRIPCION%TYPE)
  RETURN NUMBER IS

  V_COD_PAIS BA_PAISES.COD_PAIS%TYPE;
Begin

  begin
    --Obtiene el código de País
    select p.cod_pais
      into v_cod_pais
      from ba_paises p
     where upper(p.descripcion) = upper(p_des_pais);
  exception
    when too_many_rows then
      v_cod_pais := null;
      return v_cod_pais;
    when no_data_found then
      v_cod_pais := null;
      return v_cod_pais;
    when others then
      v_cod_pais := null;
      return v_cod_pais;      
  end;

  return v_cod_pais;

exception
  when others then
    v_cod_pais := null;
    return v_cod_pais;
End;
/

