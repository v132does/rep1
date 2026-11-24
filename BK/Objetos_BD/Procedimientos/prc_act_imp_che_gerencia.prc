CREATE OR REPLACE PROCEDURE IT.PRC_ACT_IMP_CHE_GERENCIA
 (P_FILTRO IN VARCHAR2
 )
 IS
v_sentencia varchar2(3000);
   v_error     varchar2(1000);
BEGIN
     v_sentencia :=
     'declare  '||
     ' cursor che_ger_emitidos is '||
     ' select NRO_CUENTA, NRO_CHEQUE, rowid '||
     '  from cc_che_ger_emitidos '||
     ' where cc_che_ger_emitidos.impreso= '||''''||'N'||'''';
     v_sentencia := v_sentencia||'   and '||P_FILTRO||'; '||
     'begin '||
     ' pre_ini_aplicacion; '||
     ' pae_cnf.g_cod_modulo := 4; '||
     ' for reg in che_ger_emitidos loop '||
     '   update cc_che_ger_emitidos '||
     '      set impreso = '||''''||'S'||''''||
     '    where rowid = reg.rowid; '||
     ' end loop; '||
     'end;';
  sql_util.ejecute_dml(v_sentencia, v_error);
  if v_error is not null then
     raise_application_error(-20000,'Act Cert.'||v_error);
  end if;
END;
/

