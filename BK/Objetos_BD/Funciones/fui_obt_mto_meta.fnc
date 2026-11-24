CREATE OR REPLACE FUNCTION IT.FUI_OBT_MTO_META
(p_COD_PERIODO IN NUMBER,
p_COD_CONCEPTO IN NUMBER,
p_COD_SUB_CONCEPTO IN NUMBER)
RETURN VARCHAR2 IS
v_monto ig_ent_metas.meta%type;
BEGIN
   SELECT meta
     into v_monto
     from ig_ent_metas
    where cod_periodo = p_cod_periodo
      and cod_concepto = p_cod_concepto
      and nvl(cod_sub_concepto,-1) = nvl(p_COD_SUB_CONCEPTO,-1);
   return v_monto;
exception
   when no_data_found then
      raise_application_error(-20000,'No existe Meta '||p_cod_periodo||'-'||p_cod_concepto||'-'||p_cod_sub_concepto);
   when others then
      raise_application_error(-20000,'Obt.Meta. '||p_cod_periodo||'-'||p_cod_concepto||'-'||p_cod_sub_concepto||sqlerrm);
END;
/

