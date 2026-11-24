CREATE OR REPLACE PROCEDURE IT.PRA_ACT_EST_CUS_LOGISTICA (P_FILTRO IN VARCHAR2)
 IS
   v_sentencia varchar2(3000);
   v_error     varchar2(1000);
BEGIN
     v_sentencia := v_sentencia||
     'begin '||
     'begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;'||
     '   update ge_nom_logistica_tmp n'||
     '      set n.cod_estado = '||''''||'I'||''''||
     '    where n.cod_estado = '||''''||'N'||''''||
     '      and '||P_FILTRO||'; '||
     'end;';
  sql_util.ejecute_dml(v_sentencia, v_error);
  if v_error is not null then
     raise_application_error(-20000,'Act Cert.'||v_error);
  end if;
END;
/

