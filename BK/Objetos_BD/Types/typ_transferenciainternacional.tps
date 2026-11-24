CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIAINTERNACIONAL"                                          IS OBJECT
(
/* tipoTransferencia <ul><li> <b>ENV:</b> Envio </li>
                            <li> <b>REC: </b> Recibido </li></ul>*/
   tipoTransferencia VARCHAR2(3),
-- nroReferenciaExterna Numero de referencia externa que indentifica a la transferencia en el swift
   nroReferenciaExterna VARCHAR2(20),
-- Fecha de la operacion
   fechaOperacion DATE,
-- Cuenta de referencia de la transferencia
   nroCuentaReferencia VARCHAR2(20),
-- Estado de la transferencia
   estado VARCHAR2(16),
-- Codigo Moneda de la transferencia
   codigoMoneda VARCHAR2(3),
-- Monto de la transferencia
   monto NUMBER(18, 2),
-- Nombre y Apellido del Beneficiario
   beneficiario VARCHAR2(100),
-- Nombre y Apellido del Solicitante
   solicitante VARCHAR2(100),
-- Numero de Operacion
   numeroOperacion VARCHAR2(15),
-- Nombre del Banco emisor/pagador
   nombreBanco VARCHAR2(100),
-- Descripcion del Banco Corresponsal    
   nombreBancocorresponsal VARCHAR2(100),
-- Fecha estimada de pago
   fechaValor DATE,
-- Mensaje original recibido/enviado del/al swift
   mensajeswift VARCHAR2(4000),
   CONSTRUCTOR FUNCTION typ_transferenciaInternacional RETURN SELF AS result
)
/

