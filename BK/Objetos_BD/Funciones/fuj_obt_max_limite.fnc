create or replace function it.FUJ_OBT_MAX_LIMITE(
      p_cod_usuario   in varchar2,       -- Usuario cajero
      p_cod_moneda    in varchar2,       -- Codigo de moneda
      p_cod_tra_padre in number default null) -- trans. padre de caja
return NUMBER is
  v_mto_max_permitido number(18,2) := -1;
begin
  -- busco el monto maximo permitido para el usuario en la moneda dada
  begin
    SELECT MTO_MAX_PERMITIDO 
      INTO v_mto_max_permitido
      FROM CJ_LIMITES
     WHERE COD_USUARIO = p_cod_usuario 
       AND COD_MONEDA = p_cod_moneda
       AND COD_TRA_PADRE = p_cod_tra_padre;
  exception
     when no_data_found then
        -- no existe especifico, puede que exista sin cod tra padre
        BEGIN
          SELECT MTO_MAX_PERMITIDO 
            INTO v_mto_max_permitido
            FROM CJ_LIMITES
           WHERE COD_USUARIO = p_cod_usuario 
             AND COD_MONEDA = p_cod_moneda
             AND COD_TRA_PADRE is null;
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
             SELECT 0 -- no tiene limite en general para la moneda, pero tiene alguna particular
               INTO v_mto_max_permitido
               FROM CJ_LIMITES
              WHERE COD_USUARIO = p_cod_usuario 
                AND COD_MONEDA = p_cod_moneda
                AND ROWNUM = 1;
                 
        END;     
  end;   
  return v_mto_max_permitido;   
exception
   WHEN NO_DATA_FOUND THEN
      return -1;  -- para indicar que no existe
   WHEN OTHERS THEN
      return -1;     
end FUJ_OBT_MAX_LIMITE;
/

