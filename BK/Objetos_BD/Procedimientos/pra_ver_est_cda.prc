CREATE OR REPLACE PROCEDURE IT.PRA_VER_EST_CDA
 (P_TABLA IN VARCHAR2
 ,P_FILTRO IN VARCHAR2
 )
 IS
   v_sentencia varchar2(3000);
   v_error     varchar2(1000);
BEGIN
   if p_tabla = 'AH_CTA_CERTIFICADOS' then
     v_sentencia :=
     ' Declare V_ESTADO VARCHAR2(1); ' ||
     ' Begin ' ||
     ' select ESTADO '||
     '   INTO V_ESTADO'||
     '   from AH_CTA_CERTIFICADOS '||
     '  where '||P_FILTRO || ';' ;
     v_sentencia := v_sentencia ||
     ' if V_ESTADO NOT IN ('||''''||'N'||''''||','||''''||'V'||''''||') THEN'|| 
     '  raise_application_error(-20000,'||''''||'Cuenta no está totalmente fondeada '||''''||' ); '||
     ' end if;' ||
     ' End; ';
  end if;
  sql_util.ejecute_dml(v_sentencia, v_error);
  if v_error is not null then
     raise_application_error(-20000,'Act Cert.'||v_error);
  end if;
END;
/
