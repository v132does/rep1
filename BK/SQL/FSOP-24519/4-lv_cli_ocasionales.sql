CREATE OR REPLACE VIEW IT.LV_CLI_OCASIONALES AS
SELECT
    --'CO_1' Item,
    ba.cod_tip_documento,
    ba.nro_documento,
    ba.pri_nombre,
    ba.seg_nombre,
    ba.pri_apellido,
    ba.seg_apellido,
    ba.cod_pai_nacionalidad,
    ba.cop_documento,
    ba.fec_nacimiento,
    ba.ocupacion,
    ba.domicilio,
    ba.cod_oficina,
    null COD_ACTIVIDAD

  FROM  ba_cli_ocasionales ba

  where not exists (select * from ge_snp_transferencias ex
                              where (ex.nro_doc_solicitante = ba.nro_documento
                                     or ex.nro_doc_beneficiario = ba.nro_documento)) -- Controlamos que ya no exista como Solicitante
  and ba.fec_insercion in (select max(ge.fec_insercion) from ba_cli_ocasionales ge
                                                         where ge.nro_documento = ba.nro_documento)

  union all

  -- Agregamos a los Beneficarios

   select distinct
    --'CO_2',
    nvl(ex.cod_tip_doc_beneficiario, b.cod_tip_documento) cod_tip_doc_beneficiario,
    TRIM(nvl(ex.nro_doc_beneficiario, cod_per_beneficiario)) nro_doc_beneficiario,
    null, --nvl(b.nom_completo, ex.nom_beneficiario) nom_beneficiario,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null

  FROM ge_snp_transferencias ex,
       ba_personas b
  where ex.cod_per_beneficiario = b.cod_persona(+)
  and EX.ESTADO = 'A'
  and (ex.nro_doc_beneficiario is not null or
          cod_per_beneficiario is not null)
  and ex.fec_insercion in (select max(ge.fec_insercion) from ge_snp_transferencias ge
                                                        where ge.nro_doc_beneficiario = ex.nro_doc_beneficiario
                                                        )

  union
  -- Agregamos a los Solicitantes
   select distinct
    --'CO_3',
    nvl(ex.cod_tip_doc_solicitante, b.cod_tip_documento) cod_tip_doc_solicitante,
    TRIM(nvl(ex.nro_doc_solicitante, cod_per_solicitante)) nro_doc_solicitante,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null

  FROM ge_snp_transferencias ex,
       ba_personas b
  where ex.cod_per_solicitante = b.cod_persona(+)
  and EX.ESTADO = 'A' --Estado = Aprobado
  and (ex.nro_doc_solicitante is not null or cod_per_solicitante is not null)
  /*and not exists (select * from ge_snp_transferencias s
                           where s.nro_doc_beneficiario = ex.nro_doc_solicitante)*/
  and not exists (select * from ba_cli_ocasionales b
                           where b.nro_documento = ex.nro_doc_beneficiario)
  and not exists (select * from ge_snp_transferencias s
                           where s.nro_doc_beneficiario = trim(b.cod_tip_documento))
  and ex.fec_insercion in (select max(ge.fec_insercion) from ge_snp_transferencias ge
                                                        where ge.nro_doc_solicitante = ex.nro_doc_solicitante)

 UNION
 -- Agregamos solicitante de la tabla LC_TRANSFERENCIA
 select DISTINCT
        NULL,--cx.cod_tip_doc_solicitante,
        NULL,-- cx.nro_doc_solicitante,
        NULL nom_solicitante,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null

  FROM GV_MOVIMIENTOS C
    JOIN LC_TRANSFERENCIAS CX ON C.COD_MOD_PADRE  = CX.COD_MODULO
                              AND C.FECHA         = CX.FEC_OPERACION
                              AND C.NRO_DOCUMENTO = CX.NRO_OPERACION

    JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                 AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                 AND C.COD_TRANSACCION = GE.COD_TRANSACCION

  WHERE C.COD_MOD_PADRE  = 7
    AND C.COD_TRA_PADRE  <> 297
    AND C.COD_TRANSACCION NOT IN (661, 941, 962, 663, 503)
    AND C.ESTADO         = 'N'
    AND C.REVERSADO      <> 'S'
    AND TO_CHAR(C.FECHA, 'YYYY') = (SELECT TO_CHAR(SYSDATE, 'YYYY') FROM DUAL)
;
-- Create the synonym
create or replace public synonym LV_CLI_OCASIONALES 
  for IT.LV_CLI_OCASIONALES ;
