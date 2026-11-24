CREATE OR REPLACE TYPE IT."TYP_CONTRATARSERVICIOUSUARIO"                                          FORCE AS OBJECT
(
      Nombre1                  VARCHAR2(120),
      Nrodocumento1        VARCHAR2(20),
      CorreoElectronico1   VARCHAR2(80),
      telefono1            VARCHAR2(20),
      Nombre2                  VARCHAR2(120),
      Nrodocumento2        VARCHAR2(20),
      CorreoElectronico2   VARCHAR2(80),
      telefono2            VARCHAR2(20),
      Nombre3                 VARCHAR2(120),
      Nrodocumento3        VARCHAR2(20),
      CorreoElectronico3   VARCHAR2(80),
      telefono3            VARCHAR2(20),
      Nombre4                 VARCHAR2(120),
      Nrodocumento4        VARCHAR2(20),
      CorreoElectronico4   VARCHAR2(80),
      telefono4            VARCHAR2(20),
      Nombre5                 VARCHAR2(120),
      Nrodocumento5        VARCHAR2(20),
      CorreoElectronico5   VARCHAR2(80),
      telefono5            VARCHAR2(20),
      CONSTRUCTOR FUNCTION typ_contratarserviciousuario RETURN SELF AS RESULT
)
--https://itti-digital.atlassian.net/browse/NVB-3811
/

