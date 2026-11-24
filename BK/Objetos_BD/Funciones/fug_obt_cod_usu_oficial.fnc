CREATE OR REPLACE FUNCTION IT.FUG_OBT_COD_USU_OFICIAL
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
  IS
  v_usu_oficial varchar2(10);

Begin
    select cod_usu_oficial
    into v_usu_oficial
    from ge_clientes
    where cod_persona = p_cod_persona;
    return v_usu_oficial;
    exception
    when no_data_found then
      v_usu_oficial := null;
      return v_usu_oficial;
End;
/

