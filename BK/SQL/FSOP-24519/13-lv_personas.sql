CREATE OR REPLACE VIEW IT.LV_PERSONAS AS
SELECT
        ba.cod_persona,
        lug.lug_trabajo,
        lug.fec_ingreso,
        ba.tipo,
        ba.cod_tip_documento,
        ba.nro_documento,
        ba.fec_vto_documento,
        trunc(ba.fec_insercion) fec_alta,
        ba.cod_rub_primario,
        ba.cod_rub_secundario,
        ba.cod_rub_terciario,
        cc.pri_nombre,
        cc.seg_nombre,
        cc.pri_apellido,
        cc.seg_apellido,
        nvl(cc.est_civil,'O') est_civil,
        cc.cod_sexo cod_sexo,
        cc.fec_nacimiento,
        ju.fec_apertura,
        ba.tip_iva,
        dir.dir_particular direccion,
        dir.numero,
        NVL(dir.tipo,'O') tip_direccion,
        NVL(dir.cod_pais, 1) cod_pai_direccion,
        NVL(dir.cod_ciudad, 1) cod_ciu_direccion,

        --ba.cod_pais cod_pai_origen,
        CASE WHEN ba.cod_pais in (select b.cod_pais from ba_paises b
                                                    where b.cod_pais not in (select c.cod_pais from ba_ciudades c)) THEN 1
             WHEN ba.cod_pais IS NULL THEN 1
             ELSE ba.cod_pais END cod_pai_origen,

        nvl(ba.cod_ciu_origen, 1) cod_ciu_origen,
        --fue_obt_dir_envio(e.cod_persona) dir_env_extracto,
        telp.telefono,
        telp.area,
        ju.raz_social,
        cli.cod_seg_cliente,
        NVL(cli.cod_oficina, fug_obt_ofi_matriz) cod_oficina,
        cli.cod_gru_economico,
        cli.cod_usu_oficial,
        cli.residente,

        (SELECT SUM(nvl(can_tra_debito, 0))
                  FROM cr_act_esperadas
                  WHERE cod_persona = ba.cod_persona) can_tra_debito,

         (SELECT SUM(nvl(can_tra_credito, 0))
                  FROM cr_act_esperadas
                  WHERE cod_persona = ba.cod_persona) can_tra_credito,

        nvl(SUM(decode(eg.ing_egreso, 'I',
                       pag_gen.fu_con_mon_a_moneda('GS', 'USD',
                                                    eg.importe), 0)), 0) tot_ingreso,

        nvl(SUM(pag_gen.fu_con_mon_a_moneda(es.cod_moneda, 'USD', es.mto_pro_credito) *
                (to_number(fug_obt_pardinamico('POR_LIM_OPE_AUTORIZADO')) / 100)), 0) tot_ing_limite,

        nvl(SUM(decode(eg.ing_egreso, 'E',
                       pag_gen.fu_con_mon_a_moneda('GS', 'USD',
                                                    eg.importe), 0)), 0) tot_egreso,

        nvl(SUM(pag_gen.fu_con_mon_a_moneda(es.cod_moneda, 'USD', es.mto_pro_debito) *
                (to_number(fug_obt_pardinamico('POR_LIM_OPE_AUTORIZADO')) / 100)), 0) tot_egr_limite,

        case when ju.naturaleza in (1, 9, 11, 20) then 'S'
          else 'N'
            end ONG,

        nvl(cf.pep, 'N') PEP,
        ba.cod_actividad,
        cc.cod_pai_nacionalidad,

        nvl((SELECT SUM(pag_gen.fu_con_mon_a_moneda(nvl(co.cod_moneda,
                                                       'GS'),
                                                   'USD', co.mto_limite))
              FROM cr_per_tip_operaciones co
             WHERE cod_persona = ba.cod_persona), 0) mto_lim_operacional



           FROM ba_personas        ba,
                ba_per_fisicas     cc,
                ba_per_juridicas   ju,
                ge_dir_envios      e,
                ge_clientes        cli,
                cr_per_ing_egresos eg,
                cr_act_esperadas   es,
                cr_inf_fondos      cf,

      (select distinct m.cod_persona, m.lug_trabajo, m.fec_ingreso
           from it.cr_inf_laborales m,
           ba_personas ba
           where m.cod_persona = ba.cod_persona
           and m.actual = 'S'
           and m.nro_secuencia = (select max(n.nro_secuencia) from it.cr_inf_laborales n
                                                              where n.actual = 'S'
                                                              and  n.cod_persona = m.cod_persona)) lug,

    (select distinct ba.cod_persona ,h.area || h.telefono telefono, h.area
                                  from it.ba_telefonos h, ba_personas ba
                                   where h.cod_persona = ba.cod_persona
                                   and h.tipo = 'P'
                                   and h.tip_linea = 'C'
                                     and h.telefono     <> '999'
                                     and h.principal     = 'S') telp,

    (SELECT DISTINCT ba.cod_persona, ci.cod_ciudad, ci.cod_pais,di.tipo,di.numero, TRIM(substr(di.direccion,1,300)) dir_particular
            FROM ba_direcciones di, ba_ciudades ci, ba_personas ba, BA_DEPARTAMENTOS DE, ba_barrios bar
            WHERE di.cod_pais = ci.cod_pais(+)
            AND di.cod_ciudad = ci.cod_ciudad(+)
            AND di.cod_persona = ba.cod_persona(+)
            AND di.principal = 'S'
            AND di.tipo = 'P'
            AND ci.COD_DEPARTAMENTO = de.COD_DEPARTAMENTO(+)
            and di.cod_pais = bar.cod_pais(+)
            and di.cod_ciudad = bar.cod_ciudad(+)
            and di.cod_barrio = bar.cod_barrio(+)) dir


          WHERE  ba.cod_persona = ju.cod_persona(+)
            AND ba.cod_persona = cc.cod_persona(+)
            AND ba.cod_persona = e.cod_persona(+)
            AND ba.cod_persona = cli.cod_persona(+) -- SE verifica que esté en GE_CLIENTES
            AND ba.cod_persona = eg.cod_persona(+)
            AND ba.cod_persona = es.cod_persona(+)
            AND ba.cod_persona = cf.cod_persona(+)
            AND BA.COD_PERSONA = telp.COD_PERSONA(+)
            AND BA.COD_PERSONA = lug.COD_PERSONA(+)
            AND BA.COD_PERSONA = dir.COD_PERSONA(+)
            and ((to_char(cc.fec_nacimiento,'yyyy') > 1900)
                or cc.fec_nacimiento is null)

          GROUP BY lug.lug_trabajo,
                   lug.fec_ingreso,
                   ba.tipo,
                   ba.cod_tip_documento,
                   ba.nro_documento,
                   ba.fec_vto_documento,
                   cc.pri_nombre,
                   cc.seg_nombre,
                   cc.pri_apellido,
                   cc.seg_apellido,
                   ba.tip_iva,
                   ba.cod_pais,
                   ba.cod_ciu_origen,
                   trunc(ba.fec_insercion),
                   ba.cod_rub_primario,
                   ba.cod_rub_secundario,
                   ba.cod_rub_terciario,
                   cc.est_civil,
                   cc.cod_sexo,
                   cc.fec_nacimiento,
                   ju.fec_apertura,
                   dir.dir_particular,
                   dir.numero,
                   dir.tipo ,
                   dir.cod_pais ,
                   dir.cod_ciudad,
                   telp.telefono,
                   telp.area,
                   --fue_obt_dir_envio(e.cod_persona),
                   cli.cod_seg_cliente,
                   cli.cod_gru_economico,
                   cli.cod_usu_oficial,
                   cli.residente,
                   cli.cod_oficina,
                   ju.raz_social,
                   ba.cod_persona,
                   ju.naturaleza,
                   cf.pep,
                   ba.cod_actividad,
                   cc.cod_pai_nacionalidad
;
-- Create the synonym
create or replace public synonym LV_PERSONAS
  for IT.LV_PERSONAS;
