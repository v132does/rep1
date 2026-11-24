CREATE OR REPLACE PACKAGE BODY IT.PAG_MIG IS

  ---------------------------------------------------------------------------
  -- Paquete utilizado para migración ITGF a BANTOTAL
  -- Fecha: 15/04/2021
  -- Autor: Sergio Servín Arce (xpy0134)
  ---------------------------------------------------------------------------
  FUNCTION FU_MAX_SEQ_CR_INF_LABORALES(P_COD_PERSONA BA_PERSONAS.COD_PERSONA%type)
  ---------------------------------------------------------------------------
  -- Función OBTENER ULTIMO NRO DE SECUENCA DE CR_INF_LABORALES
  -- Fecha: 23/07/2021
  -- Autor: Egarin(xpy5126)
  ---------------------------------------------------------------------------
  RETURN BA_PERSONAS.COD_PERSONA%type IS
  L_COD_PERSONA BA_PERSONAS.COD_PERSONA%type;
  BEGIN
    SELECT MAX(NRO_SECUENCIA)
           INTO L_COD_PERSONA
    FROM CR_INF_LABORALES a
    WHERE a.COD_PERSONA = P_COD_PERSONA
    and a.actual = 'S'
    and a.nro_secuencia = (select max(b.nro_secuencia)
                           from CR_INF_LABORALES b
                           WHERE b.COD_PERSONA = P_COD_PERSONA);
    RETURN L_COD_PERSONA;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;
  -----------------------------------------------------------------------------
  FUNCTION FU_OBT_COD_BANTOTAL(P_VAL_ITGF VARCHAR2, P_NOM_TABLA VARCHAR2)
    RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       AND T.VAL_COD_ITGF = P_VAL_ITGF;

    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
  END;

   

  


  FUNCTION FU_OBT_COD_CIU_BT(P_COD_CIU_ITGF  VARCHAR2,
                             P_COD_PAIS_ITGF VARCHAR2,
                             P_NOM_TABLA     VARCHAR2) RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       and T.VAL_COD_ITGF2 = P_COD_PAIS_ITGF
       AND T.VAL_COD_ITGF = P_COD_CIU_ITGF;

    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;

  FUNCTION FU_OBT_DES_CIU_BTL_PSA(P_COD_CIU_ITGF  VARCHAR2,
                                  P_COD_PAIS_ITGF VARCHAR2,
                                  P_NOM_TABLA     VARCHAR2) RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    /*SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       and T.VAL_COD_ITGF2 = P_COD_PAIS_ITGF
       AND T.VAL_COD_ITGF = P_COD_CIU_ITGF;

    IF V_COD_BANTOTAL IN ('#N/A', 'N/A', '') THEN*/
    BEGIN
      SELECT P.DESCRIPCION
        INTO V_COD_BANTOTAL
        FROM BA_CIUDADES P
       WHERE P.COD_CIUDAD = P_COD_CIU_ITGF
         AND P.COD_PAIS = P_COD_PAIS_ITGF;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN 1;
      WHEN OTHERS THEN
        RETURN 99;
    END;

    /*END IF;*/
    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;

  FUNCTION FU_OBT_COD_ITGF(P_VAL_BT VARCHAR2, P_NOM_TABLA VARCHAR2)
    RETURN VARCHAR2 IS
    V_COD_IT mi_tab_parametricas.Val_Cod_Itgf%type;
  BEGIN
    SELECT T.VAL_COD_ITGF
      INTO V_COD_IT
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = P_NOM_TABLA
       AND T.VAL_COD_BANTOTAL = P_VAL_BT;

    RETURN V_COD_IT;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;

  FUNCTION FU_OBT_COD_REF_BT(P_DOMINIO VARCHAR2, P_VAL_ITGF VARCHAR2)
    RETURN VARCHAR2 IS
    V_COD_BANTOTAL mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    SELECT T.VAL_COD_BANTOTAL
      INTO V_COD_BANTOTAL
      FROM mi_tab_parametricas T
     WHERE T.NOM_TAB_ITGF = 'BA_COD_REFERENCIAS'
       AND T.DOM_REF_ITGF = P_DOMINIO
       AND T.VAL_COD_ITGF = P_VAL_ITGF;
    RETURN V_COD_BANTOTAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;

  FUNCTION FU_OBT_COD_EST_BT(p_estado        VARCHAR2,
                             p_cod_modalidad VARCHAR2,
                             p_cod_modulo    VARCHAR2) RETURN VARCHAR2 IS
    v_Val_Cod_Bantotal mi_tab_parametricas.Val_Cod_Bantotal%type;
  BEGIN
    select a.val_cod_bantotal
      into v_Val_Cod_Bantotal
      from mi_tab_parametricas a
     where a.nom_tab_itgf = 'GE_EST_CUENTAS'
       and a.val_cod_itgf = p_estado
       and a.val_cod_itgf2 = p_cod_modalidad
       and a.val_cod_itgf3 = p_cod_modulo;
    RETURN v_Val_Cod_Bantotal;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END;

END PAG_MIG;
/

