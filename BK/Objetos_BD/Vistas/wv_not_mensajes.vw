CREATE OR REPLACE FORCE VIEW IT.WV_NOT_MENSAJES AS
SELECT cod_evento, cod_cli_destino, mensaje, fec_envio, seguro, cod_persona, cod_origen,
       usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, enviar, fec_ult_error,
       cod_ult_error, cod_mensaje, nro_cuenta, fec_programado,FEC_LEIDO
  FROM bw_not_mensajes_his
UNION
SELECT cod_evento, cod_cli_destino, mensaje, fec_envio, seguro, cod_persona, cod_origen,
       usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, enviar, fec_ult_error,
       cod_ult_error, cod_mensaje, nro_cuenta, fec_programado,FEC_LEIDO
FROM bw_not_mensajes;

