create or replace package it.pag_btw is

/*
Funcion que recibe datos de Cuenta/Cheque de IT desde Bantotal
Retornamos el estado / situacion del cheque / Cuenta
*/
function fu_val_che_recibidos(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                              p_nro_cheque in varchar2  default null, -- Nro de cheque
                              p_cod_moneda in varchar2  default null, -- cod_moneda
                              p_mto_cheque in varchar2 default null,     -- Monto del cheque
                              p_modo in varchar2 default 'V') return typ_mapa;


/*
Funcion que recibe datos de Cuenta/Cheque de IT desde Bantotal y confirma la operativa
Retornamos el resultado de procesamiento
*/
function fu_pro_che_recibidos(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                              p_nro_cheque in varchar2  default null, -- Nro de cheque
                              p_cod_moneda in varchar2  default null, -- cod_moneda
                              p_mto_cheque in varchar2 default null,     -- Monto del cheque
                              p_modo in varchar2 default 'C') return typ_mapa;


/*
Procedimiento invocado desde la funcion val_355 de ItCaja que ejecuta el servicio en Runes y
obtiene el estado / situacion de una cuenta / cheque de Bantotal
*/
procedure pr_val_che_btw(p_nro_cuenta in varchar2,
                        p_nro_cheque in number,
                        p_cod_moneda in varchar2,
                        p_monto      in number,
                        p_tipo       in varchar2 default 'V',
                        p_nro_caja   in number,
                        p_cod_respuesta out varchar2,
                        p_msg_respuesta out varchar2,
                        p_procesa       out varchar2);


/*
Procedimiento invocado desde la funcion pro_355 de ItCaja que ejecuta el servicio en Runes y
confirma la operacion en Bantotal
*/
procedure pr_pro_che_btw(p_nro_cuenta in varchar2,
                        p_nro_cheque in number,
                        p_cod_moneda in varchar2,
                        p_monto      in number,
                        p_tipo       in varchar2 default 'C',
                        p_nro_caja   in number,
                        p_cod_respuesta out varchar2,
                        p_msg_respuesta out varchar2,
                        p_procesa    out varchar2,
                        p_cod_causa  in number default null);


/*
FUNCION que procesa los cheques devueltos en caja de BanTotal
*/
function fu_pro_che_devueltos(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                              p_nro_cheque in varchar2  default null, -- Nro de cheque
                              p_cod_moneda in varchar2  default null, -- cod_moneda
                              p_mto_cheque in varchar2 default null,     -- Monto del cheque
                              p_cod_causa in number,
                              p_hora in varchar2 default null) return typ_mapa;

/*Procedimiento que rechaza un cheque BT pendiente de autorizacion 
actualiza boleta de deposito y saldo retenido */
procedure pr_rch_pen_che_btw(p_nro_cuenta in varchar2  default null, -- Nro de cuenta del cli
                              p_nro_cheque in number  default null, -- Nro de cheque
                              p_cod_moneda in varchar2  default null, -- cod_moneda
                              p_mto_cheque in number default null,     -- Monto del cheque
                              p_cod_causa in number,
                              p_msj_respuesta out varchar2) ;

/*
PROCEDIMIENTO que loguea los datos enviados y recibidos a/desde Runes
*/
PROCEDURE pr_ins_log_btw(p_nro_cuenta in varchar2,
                        p_nro_cheque in varchar2,
                        p_monto in number,
                        p_tipo       in varchar2,
                        p_nro_caja   in number,
                        p_procesa in varchar2,
                        p_mensaje    in varchar2,
                        p_cod_respuesta in varchar2,
                        p_msg_respuesta in varchar2,
                        p_error         in varchar2);
                        
                        
/*
PROCEDIMIENTO que inserta en la tabla para seguimiento o conciliacion de datos
*/                        
PROCEDURE pr_ins_che_hibridos(p_fecha in date, 
                              p_hora in varchar2,
                              p_cod_usuario in varchar2, 
                              p_nro_cuenta in varchar2,
                              p_nro_cheque in number,
                              p_cod_moneda in varchar2,
                              p_monto      in number,
                              p_nro_caja   in number,
                              p_situacion  in varchar2);
                              
                              
PROCEDURE pr_upd_che_hibridos(p_fecha in date, 
                              p_hora in varchar2,
                              p_cod_usuario in varchar2, 
                              p_nro_cuenta in varchar2,
                              p_nro_cheque in number,
                              p_monto in number,
                              p_situacion  in varchar2,
                              p_cod_causa  in number);

/*
Funcion para convertir UTF-8 al chartset de la BD
*/                        
function fu_val_charset(p_cadena in varchar2, p_origen in varchar2) return varchar2;                                               


/*
Funcion para obtener la oficina de BanTotal
*/
function fu_obt_ofi_btw(p_cod_oficina in number) return number;
end;
/

