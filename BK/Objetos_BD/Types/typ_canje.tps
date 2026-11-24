CREATE OR REPLACE TYPE IT."TYP_CANJE"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Número de identificación del canje de puntos
   nro_canje NUMBER(12),
-- Categoría del producto canjeado (1=Tangibles, 2=Servicios, 3=Viajes)
   cat_producto NUMBER(2),
-- Nombre del producto canjeado
   nom_producto VARCHAR2(255),
-- Descripción del producto canjeado
   des_producto VARCHAR2(1000),
-- Teléfono de contacto del cliente
   tel_contacto VARCHAR2(10),
-- Dirección de correo de contacto del cliente
   ema_contacto VARCHAR2(319),
-- Fecha y hora del sistema en que se insertó el registro
   fec_insercion DATE,
-- Cantidad de productos o servicios canjeados
   cantidad NUMBER,
-- Total de puntos canjeados
   puntos NUMBER,
-- Teléfono de del proveedor que ofrece el producto o servicio canjeado
   tel_proveedor VARCHAR2(10),
-- Retiro del producto canjeado del showroom del comercio (S=SI / N=NO)
   showroom VARCHAR2(1),
-- Dirección a enviar del producto canjeado o dirección del proveedor del producto/servicio canjeado
   direccion VARCHAR2(80),
-- Recepción o retiro del producto canjeado por una persona autorizada (S=SI / N=NO)
   rec_autorizada VARCHAR2(1),
-- Nombre y apellido de la persona autorizada para recepción o retiro del producto canjeado
   per_autorizada VARCHAR2(120),
-- Tipo de documento de la persona autorizada para la recepción o retiro del producto canjeado
   cod_tip_autorizado NUMBER(3),
-- Número de documento de la persona autorizada para la recepción o retiro del producto canjeado
   nro_doc_autorizado VARCHAR2(20),
-- Horario a partir de cuando se puede entregar el producto canjeado
   hor_inicio VARCHAR2(5),
-- Horario hasta cuando se puede entregar el producto canjeado
   hor_fin VARCHAR2(5),
-- Beneficiario del servicio canjeado es el titular de la tarjeta usada en el canje de puntos (S=SI / N=NO)
   ben_titular VARCHAR2(1),
-- Nombre y apellido del beneficiario del servicio canjeado a el cual se emite el voucher
   beneficiario VARCHAR2(120),
-- Contactar para reservar turno (S=SI / N=NO)
   turno VARCHAR2(1),
-- Pasaje es solo de ida (S=Pasaje de solo ida / N=Pasaje de ida y vuelta)
   sol_ida VARCHAR2(1),
-- Fecha de salida del viaje canjeado
   fec_salida DATE,
-- Fecha de retorno del viaje canjeado
   fec_retorno DATE,
-- Fechas de salida y retorno son flexibles (S=SI / N=NO)
   fec_flexible VARCHAR2(1),
-- Clase de servicio (1=Turista, 2=Ejecutivo)
   cla_servicio NUMBER(2),
-- Cantidad de niños para el viaje canjeado
   can_ninos NUMBER,
-- Cantidad de adultos para el viaje canjeado
   can_adultos NUMBER,
-- Línea aérea de preferencia del usuario
   lin_aerea VARCHAR2(100),
-- Numero de documento de beneficiario
   nro_doc_beneficiario VARCHAR2(20),
-- Fecha de entrada en hospedajes
   fec_entrada DATE,
-- Codigo verificador del canje
   cod_verificador VARCHAR2(10),
-- Estado de verificacion del canje
   verificado VARCHAR2(1),
-- Fecha de verificacion del canje
   fec_verificacion DATE,
-- Nombre del proveedor que ofrece el producto o servicio canjeado
   comercio VARCHAR2(255),
       CONSTRUCTOR FUNCTION typ_canje RETURN SELF AS RESULT
  )
/

