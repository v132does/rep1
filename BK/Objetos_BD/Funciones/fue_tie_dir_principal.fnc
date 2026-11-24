CREATE OR REPLACE FUNCTION IT.FUE_TIE_DIR_PRINCIPAL
 (P_COD_PERSONA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
PRAGMA AUTONOMOUS_TRANSACTION; --Para que el control sea independiente--
v_tie_dir_principal varchar2(1) := 'N';
Begin
    select decode(nvl(count(*),0),0,'N','S')
      into v_tie_dir_principal
      from ba_direcciones
     where cod_persona = p_cod_persona
       and principal = 'S';
    return v_tie_dir_principal;
exception
   when others then
   raise_application_error(-20000,'Error en FUE_TIE_DIR_PRINCIPAL: '||sqlerrm);
End;
/

