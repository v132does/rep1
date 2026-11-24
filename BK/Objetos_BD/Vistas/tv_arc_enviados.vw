CREATE OR REPLACE FORCE VIEW IT.TV_ARC_ENVIADOS AS
SELECT 'CUENTAS' archivo, fec_envio, sec_env_datos nro_secuencia,
       fue_obt_titulo(fue_obt_nom_persona(cod_persona)) nom_persona, cod_persona, nro_documento,
       decode(nro_cuenta,null,fut_obt_sol_nro_cuenta(nro_solicitud),nro_cuenta) nro_cuenta,
       fut_obt_nro_tar_cliente(nro_solicitud,cod_persona) nro_tarjeta,
       cod_afinidad afinidad, lin_cre_normal, lin_cre_cuota,
       nvl(est_procesadora, 'A') est_procesadora, substr(txt_rechazo,1,300) txt_rechazo
  FROM ta_env_cuentas_his a
UNION
SELECT 'TARJETAS', fec_envio, sec_env_datos,
       fue_obt_titulo(fue_obt_nom_persona(cod_persona)),
       cod_persona, nro_documento,
       decode(nro_cuenta,null,fut_obt_sol_nro_cuenta(nro_solicitud),nro_cuenta),
       decode(nro_tarjeta,null,fut_obt_nro_tar_cliente(nro_solicitud,cod_persona),nro_tarjeta)
       nro_tarjeta, cod_afinidad afinidad, NULL, NULL,
       nvl(est_procesadora, 'A'), substr(txt_rechazo,1,300) txt_rechazo
  FROM ta_env_tarjetas_his t;

