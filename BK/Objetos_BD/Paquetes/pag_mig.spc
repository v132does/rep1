CREATE OR REPLACE PACKAGE IT.PAG_MIG IS

  ---------------------------------------------------------------------------
  -- Paquete utilizado para migración ITGF a BANTOTAL
  -- Fecha: 15/04/2021
  -- Autor: Sergio Servín Arce (xpy0134)
  ---------------------------------------------------------------------------
  
  FUNCTION FU_MAX_SEQ_CR_INF_LABORALES(P_COD_PERSONA BA_PERSONAS.COD_PERSONA%type)
    RETURN BA_PERSONAS.COD_PERSONA%type;

  FUNCTION FU_OBT_COD_BANTOTAL(P_VAL_ITGF VARCHAR2, P_NOM_TABLA VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION FU_OBT_COD_CIU_BT(P_COD_CIU_ITGF  VARCHAR2,
                             P_COD_PAIS_ITGF VARCHAR2,
                             P_NOM_TABLA     VARCHAR2) RETURN VARCHAR2;

  FUNCTION FU_OBT_DES_CIU_BTL_PSA(P_COD_CIU_ITGF  VARCHAR2,
                                  P_COD_PAIS_ITGF VARCHAR2,
                                  P_NOM_TABLA     VARCHAR2) RETURN VARCHAR2;
  FUNCTION FU_OBT_COD_REF_BT(P_DOMINIO VARCHAR2, P_VAL_ITGF VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION FU_OBT_COD_ITGF(P_VAL_BT VARCHAR2, P_NOM_TABLA VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION FU_OBT_COD_EST_BT(p_estado        VARCHAR2,
                             p_cod_modalidad VARCHAR2,
                             p_cod_modulo    VARCHAR2) RETURN VARCHAR2;

END PAG_MIG;
/

