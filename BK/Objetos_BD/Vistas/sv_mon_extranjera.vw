CREATE OR REPLACE FORCE VIEW IT.SV_MON_EXTRANJERA AS
select pag_mig.fu_obt_cod_bantotal(p.cod_pais,'BA_PAISES') JGBN038PAI,
       pag_mig.fu_obt_cod_bantotal(p.cod_tip_documento,'BA_TIP_DOCUMENTOS') JGBN038TDO,
       decode(fue_obt_tip_doc_abreviatura(p.cod_tip_documento), 'CRP',
              (SELECT TRIM(leading '0' FROM p.nro_documento) FROM dual), p.nro_documento) JGBN038NDO,
       'S' JGBN038GIE,
       decode(x.tip_documento, null,
              decode(fue_obt_tip_doc_abreviatura(p.cod_tip_documento), 'DNI', 'CRC',
                                                                       'PAS', 'CRC',
                                                                       'SW' , 'CRC',
                                                                       'OTR', 'CRC',
                                                                       'PJ' , 'CRC',
                     fue_obt_tip_doc_abreviatura(p.cod_tip_documento)),
              x.tip_documento) TipoDocBCP,
       decode(x.nro_documento, null,
              decode(fue_obt_tip_doc_abreviatura(p.cod_tip_documento), 'CRP',
                     (SELECT TRIM(leading '0' FROM p.nro_documento) FROM dual), p.nro_documento),
              x.nro_documento) NdocBcp,
       p.cod_persona cuenta
  from ba_personas p, ba_per_dat_adicionales a,
      (select d.tip_documento, d.nro_documento, d.cod_persona
         from sb_crc_clasificaciones_det d
        where d.fecha = (select max(b.fecha)
                           from sb_crc_clasificaciones_det b
                          where b.cod_persona = d.cod_persona)) x
 where p.cod_persona = a.cod_persona
   and a.parametro = 'MON_PREDOMINANTE'
   and a.val_parametro <> 'L'
   and p.cod_persona = x.cod_persona (+);

