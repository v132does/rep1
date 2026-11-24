create or replace package it.PAO_PMT is

  -- Author  : DLANGER
  -- Created : 31/01/2014 11:44:00 a.m.
  -- Purpose : Validaciones y procesamiento de MTs enviados y recibidos.
  -- Módulo Utilitarios

function fu_obt_msj_error return varchar2;

/*Obtiene el Código de Mensaje del texto*/
function fu_obt_cod_msj_swift( p_texto in clob )
  return varchar2;

/*Obtiene el valor del Campo especificado del texto*/
function fu_obt_val_campo( p_texto in clob,
                           p_campo in sb_snp_campos.campo%type )
  return varchar2;

/*Obtiene el Campo (tag) del texto*/
function fu_obt_campo( p_texto in clob )
  return varchar2;

/*Obtiene la linea (cadena) a partir del texto y nro. de linea*/
function fu_obt_linea( p_texto       in clob,
                       p_nro_linea   in number,
                       p_delimitador in varchar2 default chr(10) )
  return clob;

/*Obtiene el Código y tipo de Mensaje del texto*/
function fu_obt_cod_mensaje ( p_texto in clob )
  return sb_snp_tip_mensajes.cod_mensaje%type;

/*Función que valida el formato Regex del Dato*/
function fu_val_formato( p_formato in sb_snp_formatos.formato%type,
                         p_valor   in sb_snp_mensajes_tmp.valor%type,
                         p_campo   in sb_snp_mensajes_tmp.campo%type )
  return varchar2 ;

/*Valida el Valor de Dato del campo*/
function fu_val_dato( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                      p_det_sql     in sb_snp_campos.det_sql_recibido%type,
                      p_valor       in sb_snp_mensajes_tmp.valor%type,
                      p_nro_detalle in sb_snp_mensajes_tmp.nro_detalle%type )
  return varchar2;

/*Obtiene el Valor por Defecto del Campo*/
function fu_obt_val_defecto( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                             p_det_sql     in sb_snp_campos.det_sql_recibido%type,
                             p_nro_detalle in sb_snp_mensajes_tmp.nro_detalle%type default 0 )
  return varchar2;

/*Obtiene el Campo XXa*/
function fu_obt_tag_campo( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                           p_det_sql     in sb_snp_campos.det_sql_recibido%type,
                           p_valor       in sb_snp_mensajes_tmp.valor%type )
  return varchar2;

/*Procesa el MT de Recepción*/
function fu_pro_mt_recibido( p_texto in clob )
  return varchar2 ;

/*Obtiene la Prioridad a partir de la Cabecera*/
function fu_obt_prioridad( p_cadena in varchar2 ) return number;

/*Obtiene Monto, Fecha o Moneda de la Cadena*/
function fu_obt_tip_valor( p_cadena in varchar2,
                           p_tipo   in varchar2 ) return varchar2;

/*Obtiene valor de instacia por delimitador de una cadena*/
function fu_obt_val_delimitador(p_cadena    in varchar2,
                                p_posicion  in number) return varchar2;

/*Inserta los datos de salida en la tabla SB_SNP_MENSAJE_TMP*/
procedure pr_ins_sb_snp_mensajes_tmp( p_cod_mensaje    in sb_snp_mensajes_tmp.cod_mensaje%type,
                                      p_campo          in sb_snp_mensajes_tmp.campo%type,
                                      p_valor          in sb_snp_mensajes_tmp.valor%type,
                                      p_nro_detalle    in sb_snp_mensajes_tmp.nro_detalle%type default 0);

/*Inserta los datos de salida en la tabla SB_SNP_MENSAJE_TMP y valida el Dato ingresado*/
procedure pr_ins_sb_snp_mensajes_tmp( p_cod_mensaje    in sb_snp_mensajes_tmp.cod_mensaje%type,
                                      p_campo          in sb_snp_mensajes_tmp.campo%type,
                                      p_valor          in sb_snp_mensajes_tmp.valor%type,
                                      p_nro_detalle    in sb_snp_mensajes_tmp.nro_detalle%type default 0,
                                      p_err_validacion in out varchar2);

/*Procesa el MT de Envío*/
procedure pr_pro_mt_enviado( p_cod_mensaje in  sb_snp_tip_mensajes.cod_mensaje%type,
                             p_texto       out clob,
                             p_nro_detalle in  sb_snp_mensajes_tmp.nro_detalle%type default null );

/*Obtiene el valor de la tabla temporal*/
function fu_obt_val_mt_proceso( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                                p_campo       in sb_snp_mensajes_tmp.campo%type,
                                p_nro_linea   in sb_snp_mensajes_tmp.nro_linea%type default null,
                                p_nro_detalle in varchar2 default 0 )
   return varchar2;

/*Obtiene los valores del MT en proceso, y Valida los datos con el DET_SQL cargado*/
function fu_obt_val_mt_proceso( p_cod_mensaje    in sb_snp_mensajes_tmp.cod_mensaje%type,
                                p_campo          in sb_snp_mensajes_tmp.campo%type,
                                p_nro_linea      in sb_snp_mensajes_tmp.nro_linea%type default null,
                                p_nro_detalle    in varchar2 default 0,
                                p_err_validacion in out varchar2 )
   return varchar2;

/*Forma la cadena del Swift en proceso*/
function fu_obt_msj_swift( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                           p_nro_detalle in sb_snp_mensajes_tmp.nro_detalle%type default null )
   return clob;

/*Inicializa la Tabla Temporal con el MT esquematizado para generar un MT*/
procedure pr_ini_sb_snp_mensajes_tmp( p_cod_mensaje   in sb_snp_tip_mensajes.cod_mensaje%type,
                                      p_cod_msj_swift in number,
                                      p_prioridad     in number,
                                      p_can_detalle   in number );

/*Función que verifica los Datos cargados en la tabla temporal contra el esquema*/
function fu_ver_esquema( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                         p_ind_envio   in varchar2 )
 return varchar2;

end PAO_PMT;
/

