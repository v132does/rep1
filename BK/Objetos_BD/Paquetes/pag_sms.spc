CREATE OR REPLACE PACKAGE IT.PAG_SMS IS

/**
* FUNCION QUE OBTIENE EL VALOR DENTRO DE UNA CADENA SEPARADO POR UN VALOR
* p_valor     : cadena que contien el valor a buscar
* p_separador : separador de los campos
* p_orden     : posicion del campo buscado
* return      : valor del campo en la posicion
*/
FUNCTION fu_obt_val_separado(p_valor     IN VARCHAR2,
                             p_separador IN VARCHAR2,
                             p_posicion  IN NUMBER)
RETURN VARCHAR2;

FUNCTION fu_ver_val_num_entero(p_valor IN VARCHAR2)
RETURN VARCHAR2;

FUNCTION fu_ver_val_numerico(p_valor IN VARCHAR2)
RETURN VARCHAR2;

FUNCTION fu_ver_val_logico(p_valor IN VARCHAR2)
RETURN VARCHAR2;

FUNCTION fu_val_nro_telefono(p_area         IN VARCHAR2,
                             P_nro_telefono IN VARCHAR2)
RETURN VARCHAR2;

/**
* PROCEDIMIENTO QUE GENERA EL LOG DE ENVIO
* p_cod_persona      : codigo de persona
* p_area             : area del telefono
* p_nro_telefono     : nro. de telefono
* p_mensaje          : contenido del mensaje
* p_ref_tra_servidor : referencia al nro. de transaccion del servidor
* p_cod_ser_sms      : codigo de servicio sms
* p_en_linea         : si es en linea fecha en envio es al instante, si no la fecha de envio es el dia siguiente
* p_nro_tra_banco    : nro. de transaccion unica del banco
*/
PROCEDURE pr_gen_log_envio(p_cod_persona      IN VARCHAR2,
                           p_area             IN VARCHAR2,
                           p_nro_telefono     IN VARCHAR2,
                           p_mensaje          IN VARCHAR2,
                           p_ref_tra_servidor IN NUMBER DEFAULT NULL,
                           p_cod_ser_sms      IN NUMBER DEFAULT NULL,
                           p_en_linea         IN VARCHAR2,
                           p_nro_tra_banco    OUT NUMBER);

/**
* PROCEDIMIENTO QUE ENVIA EL MENSAJE
* p_nro_tra_banco : nro. de transaccion unica del banco
* p_cod_error     : codigo de error
* p_msj_error     : mensaje de error
*/
PROCEDURE pr_env_mensaje(p_nro_tra_banco IN VARCHAR2,
                         p_cod_error     OUT NUMBER,
                         p_msj_error     OUT VARCHAR2);

/**
* PROCESO DE ENVIO DE MENSAJE MASIVO
* p_fecha : fecha de mensajes a enviar
*/
PROCEDURE pr_env_men_masivo(p_fecha IN DATE DEFAULT NULL);

/* AVISO DE SALDOS */
PROCEDURE pr_pro_servicio_001(p_en_linea IN VARCHAR2 DEFAULT 'N');

/* AVISO DE SALDOS INFERIORES A */
PROCEDURE pr_pro_servicio_002(p_en_linea IN VARCHAR2 DEFAULT 'N');

/* AVISO DE SALDOS SUPERIORES A */
PROCEDURE pr_pro_servicio_003(p_en_linea IN VARCHAR2 DEFAULT 'N');

/* AVISO DE VENCIMIENTOS DE PRESTAMOS*/
PROCEDURE pr_pro_servicio_004(p_en_linea IN VARCHAR2 DEFAULT 'N');

/* AVISO DE VENCIMIENTOS DE CDA*/
PROCEDURE pr_pro_servicio_005(p_en_linea IN VARCHAR2 DEFAULT 'N');

/* AVISO DE VENCIMIENTOS DE TARJETAS */
PROCEDURE pr_pro_servicio_006(p_en_linea IN VARCHAR2 DEFAULT 'N');

/* AVISO DE CHEQUES DEBITADOS */
PROCEDURE pr_pro_servicio_007(p_en_linea IN VARCHAR2 DEFAULT 'N');

/**
* PROCESO DE GENERACION DE MENSAJES DE ALERTAS
* p_cod_ser_sms : codigo de servicio, si es nulo para todos los servicios
*/
PROCEDURE pr_gen_msj_alertas(p_cod_ser_sms IN NUMBER DEFAULT NULL);

END PAG_SMS;
/

