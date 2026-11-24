CREATE OR REPLACE TYPE IT."TYP_CLIENTEFIELCO"                                          as object
(
  -- Author  : $OSUSER
  -- Created : $DATE $TIME
  -- Purpose : Retorna informacion del cliente fielco

  -- Attributes
  cod_persona VARCHAR2(10),
   nombre VARCHAR2(100),
   apellido VARCHAR2(100),
   correoElectronico VARCHAR2(250),
   numeroDocumento VARCHAR2(40),
   numeroCelular VARCHAR2(100),
   titulo NUMBER,
   segundoApellido VARCHAR2(100),
   tipoDocumento VARCHAR2(100),
   direccion VARCHAR2(100),
   nroTelefono VARCHAR2(100),
   fechaNacimineto VARCHAR2(100),
   tipoPersona VARCHAR2(1),
   razonSocial VARCHAR2(100),
   nacionalidad VARCHAR2(100),
   genero VARCHAR2(100),
   ruc VARCHAR2(100),
   digitoVerificadorRuc NUMBER(1),
   fechaEmision VARCHAR2(100),
   fechaVencimiento VARCHAR2(100),
    CONSTRUCTOR FUNCTION typ_clientefielco RETURN SELF AS RESULT
)
/

