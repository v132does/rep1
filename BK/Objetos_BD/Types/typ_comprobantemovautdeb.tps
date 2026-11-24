CREATE OR REPLACE TYPE IT."TYP_COMPROBANTEMOVAUTDEB"                                          is OBJECT
(
       error                 varchar2(1),
       --  Nombre de la respuesta 
       nombreRespuesta       varchar2(15),
       -- Mensaje de la respuesta
       descripcionRespuesta  varchar2(200),
       detalleMovimiento  typ_comprobantemovimiento,
       cliente varchar2(200),
       direccion varchar2(500),
       nroCuenta varchar (20),
       oficial varchar2(200),
       telefono varchar2(20),
       moneda varchar2(35),
       oficina varchar (50),
       montoLetras  varchar2(100),
       tipoCuenta varchar2(1),

       CONSTRUCTOR FUNCTION typ_comprobanteMovAutDeb return self as result
       )
/

