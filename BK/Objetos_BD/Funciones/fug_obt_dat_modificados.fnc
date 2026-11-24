CREATE OR REPLACE FUNCTION IT.FUG_OBT_DAT_MODIFICADOS(P_CADENA IN VARCHAR2,
                                                   P_CAMPO IN VARCHAR2,
                                                   P_TIPO IN VARCHAR2) RETURN varchar2 IS
  /*Objetivo: Decodificar campos de Auditoria segun parametros recibidos*/
  /*Por: rpavon*/
  V_CADENA VARCHAR2(4000) := P_CADENA;
  V_POS_INI NUMBER;
  V_POS_FIN NUMBER;
  V_VAL_ANT VARCHAR2(4000) := NULL;
  V_VAL_DES VARCHAR2(4000) := NULL;
BEGIN
  SELECT INSTR(p_cadena,p_campo)
    INTO V_POS_INI
    from dual;
  
  IF V_POS_INI > 0 THEN
  
    V_POS_INI := V_POS_INI + LENGTH(P_CAMPO)+LENGTH(':<i:');
    
    SELECT INSTR(p_cadena,':f>',V_POS_INI)
      INTO V_POS_FIN
      from dual;
    
    v_val_ant := substr(p_cadena,V_POS_INI,V_POS_FIN-V_POS_INI);
    V_POS_INI := V_POS_INI + (V_POS_FIN-V_POS_INI);
    V_CADENA := SUBSTR(P_CADENA,V_POS_INI+6);
      
    SELECT INSTR(V_cadena,':f>')
      INTO V_POS_FIN
      from dual;
    
    v_val_des := substr(v_cadena,1,V_POS_FIN-1);
    
    if P_TIPO = 'A' then --antes
       return V_val_ant;
    else
       return v_val_des;
    end if;
  ELSE
    RETURN NULL;
  END IF;

exception
  when others then null;
END;
/

