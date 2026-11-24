CREATE OR REPLACE FORCE VIEW IT.VG_CRC_BCP AS
SELECT y.tipo_ident tipo_ident,
       y.nro_documento nro_documento,
       y.tipo_per tipo_per,
       y.apellido apellido,
       y.nombre nombre,
       y.fecha_nac fec_nacimiento,
       y.cod_persona cod_persona,
       lpad(rownum, 6, 0) nro_orden,
       decode(y.relacion, 'P', 'PRINCIPAL', 'CODEUDOR') AS tipo_persona,
       decode(fug_es_cliente(y.cod_persona),
              'S',
              fue_obt_nom_usuario(fug_obt_cod_usu_oficial(y.cod_persona)),
              '') gestor,
       decode(fug_es_cliente(y.cod_persona),
              'S',
              fue_obt_des_oficina(fug_obt_ofi_cliente(y.cod_persona)),
              '') AS oficina,
       y.linea || lpad(rownum, 6, 0) bcp
  FROM (SELECT DISTINCT a.relacion,
                        doc.abreviatura tipo_ident,
                        per.nro_documento,
                        per.tipo tipo_per,
                        decode(per.tipo,
                               'F',
                               TRIM(bf.pri_apellido) || chr(32) ||
                               TRIM(bf.seg_apellido),
                               NULL) apellido,
                        decode(per.tipo,
                               'F',
                               TRIM(bf.pri_nombre) || chr(32) ||
                               TRIM(bf.seg_nombre),
                               TRIM(per.nom_completo)) nombre,
                        decode(per.tipo, 'F', bf.fec_nacimiento, NULL) fecha_nac,
                        a.cod_persona,
                        14 ||
                        rpad(substr(doc.abreviatura, 1, 3), 3, chr(32)) || CASE
                          WHEN length(TRIM(translate(per.nro_documento,
                                                     '0123456789',
                                                     ''))) IS NULL THEN
                           lpad(TRIM(substr(per.nro_documento, 1, 15)), 15, 0)
                          ELSE
                           rpad(TRIM(substr(per.nro_documento, 1, 15)),
                                15,
                                chr(32))
                        END || CASE
                          WHEN per.tipo = 'F' AND
                               bf.est_civil = 'C' THEN
                           '003'
                          WHEN per.tipo = 'F' THEN
                           '002'
                          ELSE
                           '001'
                        END ||
                        rpad(substr(decode(per.tipo,
                                           'F',
                                           TRIM(bf.pri_apellido) || chr(32) ||
                                           TRIM(bf.seg_apellido),
                                           chr(32)),
                                    1,
                                    30),
                             30,
                             chr(32)) ||
                        rpad((substr(decode(per.tipo,
                                            'F',
                                            TRIM(bf.pri_nombre) || chr(32) ||
                                            TRIM(bf.seg_nombre),
                                            TRIM(per.nom_completo)),
                                     1,
                                     60)),
                             60,
                             chr(32)) ||
                        rpad(decode(per.tipo,
                                    'F',
                                    nvl(to_char(bf.fec_nacimiento, 'YYYYMMDD'),
                                        chr(32)),
                                    chr(32)),
                             8,
                             chr(32)) linea
          FROM (SELECT cli.cod_persona,
                       cta.nro_cuenta,
                       cta.cod_modulo,
                       cta.cod_modalidad,
                       gcc.relacion,
                       (nvl(ope.tot_deu_real, 0) +
                       nvl(ope.tot_deu_contingente, 0)) deuda
                  FROM ge_clientes            cli,
                       ge_cta_clientes        gcc,
                       ge_cuentas             cta,
                       ge_cla_operaciones_his ope,
                       ge_calendarios         cal
                 WHERE cli.cod_persona = gcc.cod_persona
                   AND relacion IN ('P', 'C') -- Solo principal y codeudores
                   AND cta.nro_cuenta = gcc.nro_cuenta
                   AND ope.nro_cuenta = cta.nro_cuenta
                   AND ope.fecha = cal.fec_anterior
                   AND cal.cod_modulo = 1) a,
               ba_personas per,
               ba_tip_documentos doc,
               ge_modalidades m,
               ba_per_fisicas bf
         WHERE a.cod_persona = per.cod_persona
           AND per.cod_tip_documento = doc.cod_tip_documento
           AND a.cod_modulo = m.cod_modulo
           AND a.cod_modalidad = m.cod_modalidad
           AND a.deuda <> 0
           AND per.cod_persona = bf.cod_persona(+)
           /*AND NOT EXISTS
         (SELECT 1
                  FROM personas_ref r
                 WHERE r.rf_tipo_ident = doc.abreviatura
                   AND r.rf_numero = per.nro_documento)*/) y
UNION
SELECT y.tipo_ident tipo_ident,
       y.nro_documento nro_documento,
       y.tipo_per tipo_per,
       y.apellido apellido,
       y.nombre nombre,
       y.fecha_nac fec_nacimiento,
       y.cod_persona cod_persona,
       lpad(rownum, 6, 0) nro_orden,
       'CONYUGE' AS tipo_persona,
       decode(fug_es_cliente(y.cod_persona),
              'S',
              fue_obt_nom_usuario(fug_obt_cod_usu_oficial(y.cod_persona)),
              '') gestor,
       decode(fug_es_cliente(y.cod_persona),
              'S',
              fue_obt_des_oficina(fug_obt_ofi_cliente(y.cod_persona)),
              '') AS oficina,
       y.linea || lpad(rownum, 6, 0) bcp
  FROM (SELECT DISTINCT doc.abreviatura tipo_ident,
                        per.nro_documento,
                        per.tipo tipo_per,
                        decode(per.tipo,
                               'F',
                               TRIM(bf.pri_apellido) || chr(32) ||
                               TRIM(bf.seg_apellido),
                               NULL) apellido,
                        decode(per.tipo,
                               'F',
                               TRIM(bf.pri_nombre) || chr(32) ||
                               TRIM(bf.seg_nombre),
                               TRIM(per.nom_completo)) nombre,
                        decode(per.tipo, 'F', bf.fec_nacimiento, NULL) fecha_nac,
                        a.cod_persona,
                        14 ||
                        rpad(substr(doc.abreviatura, 1, 3), 3, chr(32)) || CASE
                          WHEN length(TRIM(translate(per.nro_documento,
                                                     '0123456789',
                                                     ''))) IS NULL THEN
                           lpad(TRIM(substr(per.nro_documento, 1, 15)), 15, 0)
                          ELSE
                           rpad(TRIM(substr(per.nro_documento, 1, 15)),
                                15,
                                chr(32))
                        END || CASE
                          WHEN per.tipo = 'F' AND
                               bf.est_civil = 'C' THEN
                           '003'
                          WHEN per.tipo = 'F' THEN
                           '002'
                          ELSE
                           '001'
                        END ||
                        rpad(substr(decode(per.tipo,
                                           'F',
                                           TRIM(bf.pri_apellido) || chr(32) ||
                                           TRIM(bf.seg_apellido),
                                           chr(32)),
                                    1,
                                    30),
                             30,
                             chr(32)) ||
                        rpad((substr(decode(per.tipo,
                                            'F',
                                            TRIM(bf.pri_nombre) || chr(32) ||
                                            TRIM(bf.seg_nombre),
                                            TRIM(per.nom_completo)),
                                     1,
                                     60)),
                             60,
                             chr(32)) ||
                        rpad(decode(per.tipo,
                                    'F',
                                    nvl(to_char(bf.fec_nacimiento, 'YYYYMMDD'),
                                        chr(32)),
                                    chr(32)),
                             8,
                             chr(32)) linea
          FROM (SELECT cod_persona
                  FROM (SELECT (SELECT MAX(cod_per_vinculo)
                                  FROM ba_vinculos
                                 WHERE tipo = 'E'
                                   AND cod_persona = cli.cod_persona) cod_persona
                          FROM ge_clientes            cli,
                               ge_cta_clientes        gcc,
                               ge_cuentas             cta,
                               ge_cla_operaciones_his ope,
                               ge_calendarios         cal
                         WHERE cli.cod_persona = gcc.cod_persona
                           AND relacion IN ('P') -- Solo principal y codeudores
                           AND cta.nro_cuenta = gcc.nro_cuenta
                           AND ope.nro_cuenta = cta.nro_cuenta
                           AND ope.fecha = cal.fec_anterior
                           AND cal.cod_modulo = 1)
                 WHERE cod_persona IS NOT NULL) a,
               ba_personas per,
               ba_tip_documentos doc,
               ba_per_fisicas bf
         WHERE a.cod_persona = per.cod_persona
           AND per.cod_tip_documento = doc.cod_tip_documento
           AND bf.est_civil = 'C' -- Casado sin Separación de Bienes
           AND per.cod_persona = bf.cod_persona(+)
           /*AND NOT EXISTS
         (SELECT 1
                  FROM personas_ref r
                 WHERE r.rf_tipo_ident = doc.abreviatura
                   AND r.rf_numero = per.nro_documento)*/
         ORDER BY 5) y
 ORDER BY 5, 8
;

