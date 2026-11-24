CREATE OR REPLACE TYPE IT."TYP_DATBUSINESS"                                          IS OBJECT
(
   businessId              VARCHAR2(10),  -- cod persona
   businessName            VARCHAR2(120), -- razon social
   doingBusinessAs         VARCHAR2(65), -- nombre comercial/fantasia
   formationDate           varchar2(8),   -- fecha de apertura de la empresa
   businessDocumentTypeId  VARCHAR2(3),   -- codigo de tipo de documento
   businessDocumentType    VARCHAR2(4),   -- codigo de tipo de documento
   businessDocumentNumber  VARCHAR2(20),  -- nro de documento
   businessCountryId       VARCHAR2(3),   -- codigo del pais de la empresa
   membershipDate          varchar2(8),   -- fecha de membresia en la entidad
   economicActivityId      VARCHAR2(6),   -- codigo de rubro primario
   economicActivity        VARCHAR2(60),   -- codigo de rubro primario
   bankId                  VARCHAR2(3),   -- cod de banco
   bankname                VARCHAR2(40),  -- descripcion de banco
   bankbranchId            VARCHAR2(3),   -- codigo de oficina
   bankbranchname          VARCHAR2(40),  -- descripcion de oficina
   error                   VARCHAR2(1),   -- Indica si la respuesta es de error o no
   nombreRespuesta         VARCHAR2(15),  -- Codigo de respuesta
   descripcionRespuesta    VARCHAR2(200), -- Descripcion del codigo de respuesta
   
   CONSTRUCTOR FUNCTION TYP_DATBUSINESS RETURN SELF AS result
)
/

