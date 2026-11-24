CREATE OR REPLACE TYPE IT."TYP_INICIARSESION"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Nombre completo del cliente
   nombreCompleto VARCHAR2(120),
-- Email del cliente
   emailCliente VARCHAR2(80),
--  Nombre del oficial del cliente
   nombreOficial VARCHAR2(100),
-- Direccion del correo del oficial
   emailOficial VARCHAR2(100),
-- Nro de Telefono del oficial de cuentas
   telefonoOficial VARCHAR2(50),
-- Nombre de la empresa (opcional)
   nombreEmpresa VARCHAR2(120),
-- Codigo de la empresa (opcional)
   codigoEmpresa VARCHAR2(10),
-- Indica si se debe cambiar la clave
   cambiarClave VARCHAR2(1),
-- Perfil asignado al usuario
   codigoPerfil VARCHAR2(20),
-- Codigo de persona del cliente
   codigoCliente VARCHAR2(10),
-- mensaje Mensaje al usuario (opcional)
   mensaje VARCHAR2(300),
-- esVip Indica si es VIP
   esVip VARCHAR2(1),
-- sesionUsuario Codigo de sesion del usuario
   sesionUsuario VARCHAR2(32),
-- Codigo de la Sucursal a la cual pertenece el usuario
   CodOficina VARCHAR2(3),
--Estado de la clave transaccional
   estadoClaveTran NUMBER(1),
--Descripcion perfil
   descripcionPerfil VARCHAR2(35),
   veEncuesta VARCHAR2(1),
-- Nro de documento (CI,RUC)
   nroDocumento VARCHAR2(20),
-- indica si debe actualizse la clave publica
   cambiarClavePublica VARCHAR2(1),
-- indica si tiene asignado un softoken
   softoken VARCHAR2(2),

   CONSTRUCTOR FUNCTION typ_iniciarsesion RETURN SELF AS result
)
/
