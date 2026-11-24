create or replace procedure it.PRB_ACT_EXTRACTO(P_FILTROS IN VARCHAR2)
  is
  v_sentencia varchar2(3000);
  v_error varchar2(1000);
BEGIN
  v_sentencia := 'declare cursor cuentas is '||
    'SELECT DISTINCT CB_RUBROS.COD_RUBRO,'||
    '        NVL(ULT_NRO_MAYOR,0) + 1 ULT_NRO_MAYOR '||
    '  FROM CB_SAL_CONSOLIDADOS,'||
    '       CB_RUBROS,          '||
    '       CB_ASIENTOS_DET,    '||
    '       CB_ASIENTOS'||
    ' WHERE CB_SAL_CONSOLIDADOS.COD_RUBRO = CB_RUBROS.COD_RUBRO'||
    '   AND CB_SAL_CONSOLIDADOS.COD_RUBRO = CB_ASIENTOS_DET.COD_RUBRO'||
    '   AND CB_ASIENTOS.NRO_ASIENTO       = CB_ASIENTOS_DET.NRO_ASIENTO'||
    '   AND CB_ASIENTOS.ACTUALIZADO       = '||''''||'S'||''''||
    '   AND CB_ASIENTOS_DET.ACTUALIZADO   = '||''''||'S'||'''';

  v_sentencia := v_sentencia||' and '||nvl(P_FILTROS,'1=1')||';'||
  'begin '||
  'PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 2; '||
  'for i in cuentas loop '||
    'UPDATE CB_RUBROS '||
    '   SET ULT_NRO_MAYOR = i.ult_nro_mayor '||
     'WHERE COD_RUBRO = i.cod_rubro; '||
   'end loop; '||
  'end;';

  sql_util.ejecute_dml(v_sentencia, v_error);
  if v_error is not null then
     raise_application_error(-20000,'Error al actualizar nro. de extracto '||v_error);
  end if;
end PRB_ACT_EXTRACTO;
/

