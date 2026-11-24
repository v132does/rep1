CREATE OR REPLACE TYPE IT."TYP_SOLMULTIPLE"                                          FORCE AS OBJECT
   (
    error                VARCHAR2(1),
    nombreRespuesta      VARCHAR2(15),
    descripcionRespuesta VARCHAR2(200),
    pestana              VARCHAR2(10),
    fecha                DATE,
    nom_contacto         VARCHAR2(60),
    cta_contacto         VARCHAR2(20),
    estado               VARCHAR2(15),
    monto                NUMBER(18,2),
    concepto             VARCHAR2(100),
    moneda               VARCHAR2(3),
    nom_beneficiario     VARCHAR2(60),
    nro_doc_beneficiario VARCHAR2(20),
    tip_doc_beneficiario VARCHAR2(3),
    nro_cta_credito      VARCHAR2(20),
    tipo                 VARCHAR2(1),
    tipo_cta             NUMBER(3),
    uuid                 VARCHAR(50),
    
    CONSTRUCTOR FUNCTION TYP_SOLMULTIPLE RETURN SELF AS RESULT
  )
/

