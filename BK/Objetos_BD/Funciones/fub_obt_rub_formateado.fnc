create or replace function it.FUB_OBT_RUB_FORMATEADO
            (P_COD_RUBRO     CB_RUBROS.COD_RUBRO%TYPE )
  return varchar2 is
-- Se foramtea el rubro de tal manera que el plazo se repite en la 9 posición del rubro

begin
 if p_cod_rubro is not null then
       Return '0.'||
               substr(p_cod_rubro,1,2)||'.'||
               substr(p_cod_rubro,3,1)||'.'||
               substr(p_cod_rubro,4,2)||'.'||
               substr(p_cod_rubro,6,3)||'.'||
               substr(p_cod_rubro,3,1)||'.'||
               substr(p_cod_rubro,9,2)||'.'||
               substr(p_cod_rubro,11,3)||'.'||
               substr(p_cod_rubro,14,2);
 else
      return null;
 end if;

end FUB_OBT_RUB_FORMATEADO;
/

