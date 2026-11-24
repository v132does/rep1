CREATE OR REPLACE FUNCTION IT.fuc_val_cta_cheque(p_nro_cheque IN NUMBER, p_nro_cuenta varchar2) RETURN VARCHAR2 IS
   v_valida VARCHAR2(1);
BEGIN
   SELECT 'S'
     INTO v_valida
     FROM cc_chequeras ch
    WHERE p_nro_cheque BETWEEN ch.nro_che_inicial AND ch.nro_che_final
      AND ch.nro_cuenta= p_nro_cuenta;
   RETURN(v_valida);
EXCEPTION
   WHEN no_data_found THEN
      v_valida:='N';
      RETURN(v_valida);
   WHEN too_many_rows THEN
      v_valida:='N';
      RETURN(v_valida);
   WHEN OTHERS THEN
      raise_application_error(-20001, 'ERROR en fuc_val_cta_cheque ' || SQLERRM);
END;
/

