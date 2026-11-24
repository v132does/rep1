CREATE OR REPLACE FUNCTION IT.fup_obt_tip_gar_equ(p_cod_garantia pr_garantias.cod_garantia%TYPE) RETURN NUMBER IS
v_cod_tip_garantia pr_garantias.cod_garantia%TYPE;
BEGIN
   BEGIN
       SELECT a.cod_gar_bankitti
         INTO v_cod_tip_garantia
         FROM pr_tip_gar_equi a
        WHERE a.cod_gar_ueno = p_cod_garantia;
    EXCEPTION
      WHEN no_data_found THEN
        return(p_cod_garantia);
      WHEN OTHERS THEN
        raise_application_error(-20000, 'Error al buscar equivalencia de garantias. '||SQLERRM);
    END;
    return(v_cod_tip_garantia);
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000, 'Error en la obtención de equivalencia de garantias. '||SQLERRM);
END;
/

