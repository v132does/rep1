CREATE OR REPLACE FORCE VIEW IT.GV_RIE_EVA_PERSONAS AS
SELECT p.cod_persona,
       lpad(ltrim(to_char(nvl(pf.cod_actividad, 0), '9999999999999')), 3, '0') actividadcli,
       substr(rpad(nvl(plab.actual, ' '), 1, ' '), 1, 1) actual,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,19), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 19, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 19), 0), '999999999999990D99')), 20, ' ')*/ alquilercob,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,19), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 19, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 19), 0), '999999999999990D99')), 20, ' ')*/ alquilercobcon,
       lpad(ltrim(to_char(nvl(pf.cod_titulo, 0), '9999999999999')), 3, '0') carrerauniver,
       rpad(decode(ge.cat_sistema, NULL, decode(cant.cat_sistema, NULL, ' ',cant.cat_sistema), ge.cat_sistema), 1,
            ' ') categoriaclibcp,
       substr(rpad(nvl(p.cod_persona, ' '), 10, ' '), 1, 10) codcliente,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 13, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 13), 0), '999999999999990D99')), 20, ' ') cuotaconsumo,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 13, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 13), 0), '999999999999990D99')), 20, ' ') cuotaconsumocon,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 18, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 18), 0), '999999999999990D99')), 20, ' ') cuotahip,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 18, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 18), 0), '999999999999990D99')), 20, ' ') cuotahipcon,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 16, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 16), 0), '999999999999990D99')), 20, ' ') cuotaotras,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 16, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 16), 0), '999999999999990D99')), 20, ' ') cuotaotrascon,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 15, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 15), 0), '999999999999990D99')), 20, ' ') cuotatarj,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 15, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 15), 0), '999999999999990D99')), 20, ' ') cuotatarjcon,
       lpad(ltrim(to_char(nvl(fug_obt_max_dia_mto_mora(p.cod_persona, 'D'), 0), '9999999999999')), 5,
            '0') diasatro,
       lpad(ltrim(to_char(nvl(cant.dispuesto, 0), '999999999999990D99')), 20, ' ') dispuestoclisf,
       --substr(rpad(nvl(ge.cli_especial, ' '), 1, ' '), 1, 1) esclipreferente, --04/2016 ajuste DYDMR-3377
       substr(rpad(decode(ge.cod_seg_preferente,1,'V',2,'P','O'), 1, ' '), 1, 1) esclipreferente,
       substr(rpad(nvl(plab.mto_fijo, ' '), 1, ' '), 1, 1) esfijo,
       substr(rpad(nvl(pf.est_civil, ' '), 1, ' '), 1, 1) estadocivil,
       substr(rpad(nvl(cant.faj_buro, ' '), 1, ' '), 1, 1) fajaburo,
       substr(rpad(nvl(to_char(ge.fec_ingreso, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fecaltacliente,
       substr(rpad(nvl(to_char(fie.fechaingresoemp, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fechaingresoemp,
       substr(rpad(nvl(to_char(pf.fec_nacimiento, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fecnacimiento,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 24, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 24), 0), '999999999999990D99')), 20, ' ') gastoalquiler,
       lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 12, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 12), 0), '999999999999990D99')), 20, ' ') gastofamiliar,
       substr(rpad(nvl(fue_obt_nom_usuario(ge.cod_usu_oficial), ' '), 60, ' '), 1, 60) gestor,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ult_mto_nomina(p.cod_persona), 0),
                          '999999999999990D99')), 20, ' ') mtonomina,
       /*decode(par_per.fu_obt_ult_mto_nomina(p.cod_persona),null,lpad(' ', 20, ' '),
              lpad(ltrim(to_char(par_per.fu_obt_ult_mto_nomina(p.cod_persona),'999999999999990D99')), 20, ' ')) mtonomina,*/
       substr(rpad(nvl(cant.sit_infocheck, ' '), 1, ' '), 1, 1) infocheck,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,26), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 26, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 26), 0), '999999999999990D99')), 20, ' ')*/ ingesosventacon,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,26), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 26, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 26), 0), '999999999999990D99')), 20, ' ') */ingesosventas,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,14), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 14, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 14), 0), '999999999999990D99')), 20, ' ') */ingresosind,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,14), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 14, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 14), 0), '999999999999990D99')), 20, ' ') */ingresosindcon,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,11), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 11, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 11), 0), '999999999999990D99')), 20, ' ') */interesesaho,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,11), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 11, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 11), 0), '999999999999990D99')), 20, ' ') */interesesahocon,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,5), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 5, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 5), 0), '999999999999990D99')), 20, ' ') */jubypension,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,5), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 5, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 5), 0), '999999999999990D99')), 20, ' ') */jubypensioncon,
       lpad(ltrim(to_char(nvl(ge.tot_deu_con_sistema, 0), '999999999999990D99')), 20, ' ') limcontingente,
       substr(rpad(nvl((SELECT nvl('S', 'N')
                         FROM ge_per_inhibidas i
                        WHERE i.cod_persona = p.cod_persona
                          AND i.situacion = 'I'), ' '), 1, ' '), 1, 1) marcaclicastigo,

       lpad(ltrim(to_char(nvl(fug_obt_max_dia_mto_mora(p.cod_persona, 'D', 12), 0), '9999999999999')),
            5, '0') maxdiasincum12,
       lpad(ltrim(to_char(nvl(fug_obt_max_dia_mto_mora(p.cod_persona, 'D', 6), 0), '9999999999999')),
            5, '0') maxdiasincum6,
       lpad(ltrim(to_char(nvl(cant.med_dispuesto, 0), '9999999999999')), 18, '0') mddispclibcp6,
       lpad(ltrim(to_char(nvl(fug_obt_max_dia_mto_mora(p.cod_persona, 'M'), 0), '999999999999990D99')),
            20, ' ') montoatrfecsol,
       lpad(ltrim(to_char(nvl(fug_obt_max_dia_mto_mora(p.cod_persona, 'M', 12), 0),
                          '999999999999990D99')), 20, ' ') montomaxincum12,
       lpad(ltrim(to_char(nvl(fug_obt_max_dia_mto_mora(p.cod_persona, 'M', 6), 0),
                          '999999999999990D99')), 20, ' ') montomaxincum6,
       lpad(ltrim(to_char(nvl(pf.cod_niv_estudio, 0), '9999999999999')), 3, '0') nivelestudios,
       substr(rpad(nvl(pvin.cod_per_vinculo, ' '), 10, ' '), 1, 10) numconyuge,
       lpad(ltrim(to_char(nvl(pf.can_personas, 0), '9999999999999')), 4, '0') numpersonacargo,
       lpad(ltrim(to_char(nvl(cant.mto_pag_minimo, 0), '999999999999990D99')), 20, ' ') pagominimo,
       lpad(ltrim(to_char(nvl(p.cod_pais, 0), '9999999999999')), 3, '0') paisorigen,
       lpad(ltrim(to_char(nvl(pf.patrimonio, 0), '999999999999990D99')), 20, ' ') patrimonio,
       lpad(ltrim(to_char(nvl(cant.pro_categoria, 0), '9999999999999')), 1, '0') peorcatclibcp6,
       lpad(ltrim(to_char(nvl(pf.cod_profesion, 0), '9999999999999')), 3, '0') profesion,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,7), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 7, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 7), 0), '999999999999990D99')), 20, ' ') */rentasaccion,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,7), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 7, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 7), 0), '999999999999990D99')), 20, ' ') */rentasaccioncon,
       lpad(ltrim(to_char(nvl(fug_obt_sal_med_pas_vista(p.cod_persona), 0), '999999999999990D99')),
            20, ' ') saldomediopv,
       substr(rpad(nvl(pf.cod_sexo, ' '), 1, ' '), 1, 1) sexo,
       substr(rpad(nvl(plab.tip_empleo, ' '), 1, ' '), 1, 1) situacionlab,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,23), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 23, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 23), 0), '999999999999990D99')), 20, ' ') */sueldofijo,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,23), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 23, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 23), 0), '999999999999990D99')), 20, ' ') */sueldofijocon, ---DE-2588
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(p.cod_persona,9), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 9, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = p.cod_persona
                                 AND cing.cod_concepto = 9), 0), '999999999999990D99')), 20, ' ') */sueldovar,
       lpad(ltrim(to_char(nvl(par_per.fu_obt_ingresos(pcon.cod_persona,9), 0), '999999999999990D99')), 20, ' ')
       /*lpad(ltrim(to_char(nvl((SELECT decode(cing.cod_concepto, 9, cing.importe)
                                FROM cr_per_ing_egresos cing
                               WHERE cing.cod_persona = pcon.cod_persona
                                 AND cing.cod_concepto = 9), 0), '999999999999990D99')), 20, ' ') */sueldovarcon,
       fug_obt_blo_tarjetas(p.cod_persona) tarjetabloq,
       substr(rpad(nvl(pprop.tip_propiedad, ' '), 1, ' '), 1, 1) tipopropiedad,
       lpad(ltrim(to_char(nvl(pf.cod_tip_vivienda, 0), '9999999999999')), 3, '0') tipovivienda,
       lpad(ltrim(to_char(nvl((SELECT SUM(x.val_comercial)
                                FROM cr_per_propiedades x
                               WHERE x.cod_persona = p.cod_persona
                                 AND nvl(x.hipotecado, 'N') = 'N'), 0), '999999999999990D99')), 20,
            ' ') valcompropiedad,
        lpad(ltrim(to_char(par_per.fu_obt_pro_mto_nomina (p.cod_persona), '999999999999990D99')), 20,
            ' ') cre_pro_nomina,
       substr(rpad(nvl(to_char(fie.fechaingresoemp1, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fechaingresoemp1,
       substr(rpad(nvl(to_char(fie.fechaingresoemp2, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fechaingresoemp2,
       substr(rpad(nvl(to_char(fie.fechaingresoemp3, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fechaingresoemp3
  FROM ba_personas         p,
       ba_per_fisicas      pf,
       ba_vinculos         pvin,
       ba_personas         pcon,
       cr_inf_laborales    plab,
       cr_per_propiedades  pprop,
       ge_clientes         ge,
       ge_cli_antecedentes cant,
       (select *
          from (select c.cod_persona,
                       'fechaingresoemp' || c.nro_reg fecha,
                       max(c.fec_ingreso) max_fec
                  from (select b.nro_reg, b.cod_persona, b.fec_ingreso, b.mto_ingreso
                          from (select row_number() over(partition by a.cod_persona order by a.mto_ingreso desc, a.fec_ingreso desc) as nro_reg,
                                       a.cod_persona,
                                       a.fec_ingreso,
                                       a.mto_ingreso
                                  from cr_inf_laborales a
                                 where a.actual = 'S'
                                   and a.fec_ingreso is not null
                                   and par_per.fu_obt_ingresos(a.cod_persona, a.tip_ingreso, a.nro_secuencia) > 0
                                 order by to_number(a.cod_persona), a.mto_ingreso desc) b
                         where b.nro_reg <= 4
                         order by to_number(b.cod_persona), b.nro_reg) c
                 group by c.cod_persona, 'fechaingresoemp' || c.nro_reg) x
        pivot(max(max_fec)
           for fecha in('fechaingresoemp1' as fechaingresoemp,
                        'fechaingresoemp2' as fechaingresoemp1,
                        'fechaingresoemp3' as fechaingresoemp2,
                        'fechaingresoemp4' as fechaingresoemp3))) fie
 WHERE p.cod_persona = pf.cod_persona
   AND p.cod_persona = pvin.cod_persona(+)
   AND p.cod_persona = fie.cod_persona(+)
   AND pvin.tipo(+) in ('E', 'C') --DE-2588
   AND pvin.cod_per_vinculo = pcon.cod_persona(+)
   AND p.cod_persona = plab.cod_persona(+)
   AND plab.actual(+) = 'S'
   AND nvl(plab.nro_secuencia, 0) =
       (select nvl(MAX(cl.nro_secuencia), nvl(plab.nro_secuencia,0))
          from cr_inf_laborales cl
         WHERE cl.cod_persona(+) = p.cod_persona
           AND cl.actual(+) = 'S'
           and nvl(cl.mto_ingreso, -1) =
               (SELECT nvl(MAX(l.mto_ingreso), -1)
                  FROM cr_inf_laborales l
                 WHERE l.cod_persona(+) = p.cod_persona
                   and par_per.fu_obt_ingresos(l.cod_persona, l.tip_ingreso, l.nro_secuencia) > 0
                   AND l.actual(+) = 'S'))

      --Propiedad con el mayor valor comercial
   AND p.cod_persona = pprop.cod_persona(+)
   AND nvl(pprop.nro_finca, 0) =
       (SELECT nvl(MAX(cpp.nro_finca), 0)
          FROM cr_per_propiedades cpp
         WHERE cpp.cod_persona(+) = p.cod_persona
           and nvl(cpp.val_comercial, -1) =
               (SELECT nvl(MAX(t.val_comercial), -1)
                  FROM cr_per_propiedades t
                 WHERE t.cod_persona(+) = p.cod_persona))
   AND p.cod_persona = ge.cod_persona(+)
   AND p.cod_persona = cant.cod_persona(+)
;

