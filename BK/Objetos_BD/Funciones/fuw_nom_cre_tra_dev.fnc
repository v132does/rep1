CREATE OR REPLACE FUNCTION IT.fuw_nom_cre_tra_dev(p_nro_documento IN bw_movimientos.nro_documento%TYPE,
                                               p_cod_empresa   IN bw_movimientos.cod_per_principal%TYPE) RETURN VARCHAR2 IS
  v_nom_beneficiario VARCHAR2(100);
begin
   SELECT substr(trim(m.parametros), 1, 100)
     INTO v_nom_beneficiario
     FROM bw_movimientos m
    WHERE m.nro_documento = p_nro_documento
      AND m.cod_tip_mensaje = '055'
      AND m.cod_per_principal = p_cod_empresa
      AND m.fec_insercion > trunc(sysdate);
   RETURN v_nom_beneficiario;
EXCEPTION
   WHEN OTHERS THEN
     RETURN NULL;
END;
/

