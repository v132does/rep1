create or replace function it.FUG_OBT_CAU_DEVOLUCION(P_TIPO VARCHAR2, P_VALOR VARCHAR2) return number is
  v_cod_causa NUMBER;
begin
  select GEC.COD_CAUSA
 	  INTO v_cod_causa
     from GE_PAR_CAUSALES GEP,
          GE_CAUSALES GEC
    where GEP.COD_CAUSA = GEC.COD_CAUSA
      AND GEP.PARAMETRO = 'TIP_DEVOLUCION'
      AND GEC.TIPO = p_tipo
      AND GEP.VAL_PARAMETRO = p_valor
      and rownum = 1;
  return(v_cod_causa);
end FUG_OBT_CAU_DEVOLUCION;
/

