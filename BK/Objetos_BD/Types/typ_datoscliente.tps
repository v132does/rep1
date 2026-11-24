CREATE OR REPLACE TYPE IT."TYP_DATOSCLIENTE"                                          IS OBJECT(
   error                VARCHAR2(1),  -- Indica si la respuesta es de error o no
   nombreRespuesta      VARCHAR2(15), -- Codigo de respuesta
   descripcionRespuesta VARCHAR2(200),-- Descripcion del codigo de respuesta
   nombreCompleto       VARCHAR2(120),-- Nombre completo del cliente
   direccion            VARCHAR2(200),-- Direccion del cliente
   numeroCasa           VARCHAR2(15), -- Numero de casa del cliente
   telefonoFijo         VARCHAR2(21), -- Numero de Telefono fijo del cliente
   celular              VARCHAR2(21), -- Numero de Celular del cliente
   tipoLineaPrincipal   VARCHAR2(1),  -- Permite indicar si el telefono fijo o el celular, está marcado como telefono principal
   email                VARCHAR2(80), -- Correo electronico del cliente
   codigoPais           VARCHAR2(80), -- Codigo de pais (direccion del cliente)
   descripcionPais      VARCHAR2(80), -- Descripcion de pais (direccion del cliente)
   codigoDepartamento   VARCHAR2(80), -- Codigo de departamento (direccion del cliente)
   descripcionDepartamento VARCHAR2(80), -- Descripcion del departamento (direccion del cliente)
   codigoCiudad         NUMBER(3),       -- Codigo de ciudad (direccion del cliente)
   descripcionCiudad    VARCHAR2(35),    -- Descripcion de ciudad
   codigoBarrio         NUMBER(5) ,      -- Codigo de barrio
   descripcionBarrio    VARCHAR2(40),    -- Descripcion de barrio
   poseeClaveDinamica   VARCHAR2(1),     --Indica si el cliente tiene OTP configurado
   esClienteNomina      VARCHAR2(1),     --Indica si el cliente es un cliente de nomina
   respuestaLimite      VARCHAR2(2),     --Se utiliza solo si se modificara los datos del cliente. Indica si se necesita clave de token o transaccional
   listaCuentas         typ_listaresumencuenta, --Lista de cuentas del cliente
   genero                VARCHAR2(1),  -- Indica si es Femenino/Masculino
   fechaNacimiento       DATE,
   descripcionPaisNacionalidad VARCHAR2(60), --Pais correspondiente a la nacionalidad
   tipoDocumento        NUMBER(3),    -- tipo de documento,
   codigoPaisIso        VARCHAR2(2), -- codigo iso del pais
   nroDocumento         VARCHAR2(20), -- Nro documento Cliente
   CONSTRUCTOR FUNCTION typ_datosCliente RETURN SELF AS result
)
/

