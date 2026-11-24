CREATE OR REPLACE FUNCTION IT.FUB_EXISTE_RUB_GRUPO (p_cod_rubro varchar2) return varchar2 is
  result VARCHAR2(10);
begin
  select d.cod_gru_rubro
  into result
  from cb_gru_rubros_det d
  where d.cod_gru_rubro in (1,2,3,4)
  and d.cod_rubro=p_cod_rubro;

  return(Result);

  exception
     when others then
        return 0;
end fub_existe_rub_grupo;
/

