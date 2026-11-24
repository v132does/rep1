create or replace function it.fub_obt_des_cta_contable(p_cod_rubro in varchar2) return varchar2 is
  --Creado por : rpavon en Bco Regional--
  --Finalidad  : Obetener descripcion de Rubro Contable--
  Result varchar2(500);
begin
  select a.descripcion
    into result
    from cb_rubros a
   where a.cod_rubro = p_cod_rubro;
  return(Result);
end;
/

