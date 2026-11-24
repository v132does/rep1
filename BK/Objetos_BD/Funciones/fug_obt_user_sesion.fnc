create or replace function it.fug_obt_user_sesion(p_sesion IN VARCHAR2)
  return varchar2 is
  v_cod_empresa BW_AUT_SESIONES.Cod_Per_Vinculada%type;
/*
  Funcion que busca segun la sesion si es una persona Fisica o Juridica
  Dejamos preparado para que mas adelante se cambie desde aqui el usuario con el cual se guardaran
  los registros de movimientos.
  glopez
*/
BEGIN

  BEGIN
    --Buscamos si la sesion tiene el campo cod_per_viculada (Empresa)
    SELECT cod_per_vinculada
      INTO v_cod_empresa
      FROM BW_AUT_SESIONES TK
     WHERE TK.cod_sesion = p_sesion;
  EXCEPTION
    WHEN others THEN
      return user;
  END;
  --Si es campo esta vacio, entonces se trata de una persona fisica.
  if v_cod_empresa is null then
    return 'HBANKF';
  end if;
  --En el caso de no estar vacio, entonces es una persona Juridica.
  return 'HBANKJ';
END;
/

