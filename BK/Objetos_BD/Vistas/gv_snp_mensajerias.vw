CREATE OR REPLACE FORCE VIEW IT.GV_SNP_MENSAJERIAS AS
SELECT CASE WHEN a.fec_recepcion IS NULL THEN 'Enviado' ELSE 'Recibido' END tipo,
          a.cod_msj_swift,
          a.fec_valor,
          a.fec_ingreso,
          fue_obt_des_refcodes('EST_MSJ_SNP', a.estado) estado,
          fue_obt_des_refcodes('SITUACION', a.situacion) situacion,
          to_char(a.nro_referencia) nro_referencia,
          a.nro_ref_externa,
          a.monto,
          a.cod_moneda,
          a.msj_swift,
          a.origen,
          a.plataforma,
          a.error,
          a.fec_insercion,
          a.nro_lote,
          CASE WHEN a.fec_recepcion IS NULL THEN a.cod_per_solicitante ELSE a.cod_per_beneficiario END cod_persona

     FROM GE_SNP_TRANSFERENCIAS a

   UNION ALL

   SELECT CASE WHEN a.fec_recepcion IS NULL THEN 'Enviado' ELSE 'Recibido' END tipo,
          a.cod_msj_swift,
          a.fec_valor,
          a.fec_valor fec_ingreso,
          null,
          fue_obt_des_refcodes('SITUACION', a.situacion) situacion,
          a.nro_referencia,
          a.nro_ref_externa,
          a.monto,
          a.cod_moneda,
          a.msj_swift,
          null,
          null,
          a.error,
          a.fec_insercion,
          null,
          null
     FROM GE_SNP_MENSAJES a
     UNION ALL

   SELECT CASE WHEN i.fec_recepcion IS NULL THEN 'Enviado' ELSE 'Recibido' END tipo,
          to_number(b.val_minimo),
          i.fecha,
          i.fecha fec_ingreso,
          fue_obt_des_refcodes('EST_MSJ_SNP', i.estado) estado,
          fue_obt_des_refcodes('SITUACION', i.situacion) situacion,
          i.nro_referencia,
          i.nro_ref_externa,
          i.monto,
          i.cod_moneda,
          i.msj_mx,
          null,
          null,
          i.error,
          i.fec_insercion,
          null,
          null
     FROM GE_SPI_INFORMES i,BA_COD_REFERENCIAS b
     where b.DOMINIO = 'COD_MSJ_SWIFT'
     and i.cod_msj_mx=b.abreviatura

     UNION ALL

     SELECT CASE WHEN s.fec_recepcion IS NULL THEN 'Enviado' ELSE 'Recibido' END tipo,
     to_number(s.cod_msj_swift),
     trunc(s.fec_insercion),
     trunc(s.fec_insercion),
     fue_obt_des_refcodes('EST_MSJ_SNP', s.est_solicitud) ,
     fue_obt_des_refcodes('SITUACION', s.sit_solicitud),
     to_char(s.nro_referencia),
     s.nro_ref_externa,
     s.monto,
     s.cod_moneda,
     s.msj_mx,
     null,
     null,
     s.respuesta,
     s.fec_insercion,
     to_char(s.cod_sol_spi),
     CASE WHEN s.fec_recepcion IS NULL THEN FUE_OBT_COD_PERSONA_DOC(tip_doc_solicitante,doc_solicitante)
     ELSE FUE_OBT_COD_PERSONA_DOC(tip_doc_beneficiario,doc_beneficiario) END cod_persona
     FROM GE_SPI_SOLICITUDES s
     WHERE s.nro_ref_externa NOT IN (Select T.NRO_REF_EXTERNA --Evita duplicados en GCSNPMEN
                                     from GE_SNP_TRANSFERENCIAS t
                                     where T.NRO_REF_EXTERNA = s.nro_ref_externa)
;

