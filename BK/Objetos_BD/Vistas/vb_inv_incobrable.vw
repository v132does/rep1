create or replace force view it.vb_inv_incobrable as
Select sc.FECHA, sc.COD_RUBRO, sc.COD_RUB_EXTERNO, sc.DESCRIPCION,  sc.COD_MONEDA, sc.COD_MODULO,
       sc.COD_MODALIDAD, sc.COD_OFICINA, sc.TIP_SALDO, sc.NRO_CUENTA, sc.ESTADO, sc.SAL_ACTUAL,
       sc.VAL_TASA, sc.FEC_APERTURA, sc.FEC_INI_RETEN, sc.FEC_VENCIMIENTO, sc.COD_PERSONA, sc.NOMBRE,
       sc.COD_TIP_DEUDOR,  sc.DES_DEUDOR, sc.OBSERVACION, cf.fec_fallido, cf.cod_usuario, cf.nombre nom_usuario,
       cf.cargo
  from (select i.cod_rubro,
               r.cod_rub_externo,
               r.descripcion,
               i.cod_moneda,
               i.cod_modulo,
               i.cod_modalidad,
               i.cod_oficina,
               i.tip_saldo,
               d.nro_cuenta,
               p.estado,
               d.sal_actual,
               p.val_tasa,
               p.fec_apertura,
               (Select max(a.fec_inicio)
                  from AH_RETENCIONES a
                 where a.nro_cuenta = p.nro_cuenta) as fec_ini_reten,
               p.fec_vencimiento,
               e.cod_persona,
               fue_obt_nom_persona(e.cod_persona) nombre,
               t7.cod_tip_deudor,
               t8.descripcion des_deudor,
               NULL OBSERVACION,
               i.fecha
          from cb_sal_inventarios_his i,
               cb_sal_inventarios_det_his d,
               ge_cuentas p,
               cb_rubros r,
               ge_cta_clientes e,
               ge_clientes t7,
               ge_tip_deudores t8
         where i.nro_referencia = d.nro_referencia
           and i.fecha = d.fecha
           and d.nro_cuenta = p.nro_cuenta
           and p.nro_cuenta = e.nro_cuenta
           and e.relacion = 'P'
           and t7.cod_persona = e.cod_persona
           and t7.cod_tip_deudor = t8.cod_tip_deudor
           and t7.cod_sec_contable = t8.cod_sec_contable
           and i.cod_rubro = r.cod_rubro(+)
           and not exists (select 1 from ba_cod_referencias where dominio = 'COD_RUB_CHE_VAL_CUS' and val_minimo = i.cod_rubro)
        union all
        Select i.cod_rubro,
               r.cod_rub_externo,
               r.descripcion,
               i.cod_moneda,
               i.cod_modulo,
               i.cod_modalidad,
               i.cod_oficina,
               i.tip_saldo,
               d.nro_cuenta,
               e.estado,
               d.sal_actual,
               null val_tasa,
               e.fec_apertura,
               null fec_fin_reten,
               dd.fec_vencimiento,
               e.cod_persona,
               fue_obt_nom_persona(e.cod_persona) nombre,
               t7.cod_tip_deudor,
               t8.descripcion des_deudor,
               NULL OBSERVACION,
               i.fecha
          From cb_sal_inventarios_his i,
               cb_sal_inventarios_det_his d,
               cb_rubros r,
               cc_che_custodias e,
               (Select e.cod_che_custodia, e.val_nominal, e.fec_vencimiento
                  from cc_che_custodias_det e
                 where e.cancelado != 'S'
                 Group by e.cod_che_custodia,
                          e.val_nominal,
                          e.fec_vencimiento) dd,
               ge_clientes t7,
               ge_tip_deudores t8
         where i.nro_referencia = d.nro_referencia
           and i.fecha = d.fecha
           and i.cod_rubro = r.cod_rubro
           and d.nro_cuenta = to_char(e.cod_che_custodia)
           and e.cod_che_custodia = dd.cod_che_custodia
           and decode(i.cod_rubro, '520206560101299', d.sal_actual * -1,'520206560101205', d.sal_actual * -1, d.sal_actual) = dd.val_nominal
           and e.cod_persona = t7.cod_persona
           and t7.cod_tip_deudor = t8.cod_tip_deudor
           and t7.cod_sec_contable = t8.cod_sec_contable
         Group by i.cod_rubro, r.cod_rub_externo, r.descripcion, i.cod_moneda, i.cod_modulo, i.cod_modalidad,
                  i.cod_oficina, i.tip_saldo, d.nro_cuenta,  e.estado,  e.fec_apertura, dd.fec_vencimiento,
                  d.sal_actual, e.cod_persona, fue_obt_nom_persona(e.cod_persona), t7.cod_tip_deudor,
                  t8.descripcion, i.fecha
     union all
     select i.cod_rubro,
        r.cod_rub_externo,
        r.descripcion,
        i.cod_moneda,
        i.cod_modulo,
        i.cod_modalidad,
        i.cod_oficina,
        i.tip_saldo,
        d.nro_cuenta,
        e.estado,
        d.sal_actual,
        null as val_tasa,
        null as fec_apertura,
        null as fec_fin_reten,
        null as fec_vencimiento,
        e.cod_persona,
        fue_obt_nom_persona(e.cod_persona) nombre,
        t7.cod_tip_deudor,
        t8.descripcion as des_deudor,
        null as observacion,
        i.fecha
     from  cb_sal_inventarios_his i
      inner join cb_sal_inventarios_det_his d on i.nro_referencia = d.nro_referencia and i.fecha = d.fecha
     inner join pr_movimientos_his e on /*e.nro_documento = decode(fug_val_es_numerico(d.nro_cuenta),'S',d.nro_cuenta,0) and i.fecha = e.fecha*/
                                       e.nro_documento = decode(i.cod_modulo,15,null, decode(fug_val_es_numerico(d.nro_cuenta),'S',d.nro_cuenta,0))
      inner join ge_transacciones t4 on e.cod_modulo = t4.cod_modulo and e.cod_modalidad = t4.cod_modalidad and e.cod_transaccion = t4.cod_transaccion
      inner join ge_tip_asientos t5 on e.cod_moneda = t5.cod_moneda
      inner join cb_rubros r on i.cod_rubro = r.cod_rubro
      inner join ge_clientes t7 on e.cod_persona = t7.cod_persona
      inner join ge_tip_deudores t8 on t7.cod_tip_deudor = t8.cod_tip_deudor and t7.cod_sec_contable = t8.cod_sec_contable
     where e.cod_tra_padre = 200 --- Calculo de Garantias
      and e.monto > 0
      and e.reversado = 'N'
      and ((t4.cod_tip_asiento = t5.cod_tip_asiento or t4.cod_tip_asiento2 = t5.cod_tip_asiento) and t5.tip_movimiento = 'C')) sc,
  (select a.fecha fec_fallido, a.nro_cuenta, a.cod_usuario, u.nombre, u.cargo
     from ge_cuentas_nov a, ba_usuarios u
    where a.cod_modulo in (6, 15)
      and a.est_actual = 'I'
      and a.cod_usuario = u.cod_usuario
      and a.fecha = (select max(f.fecha)
                       from ge_cuentas_nov f
                      where f.nro_cuenta = a.nro_cuenta
                        and f.cod_modulo in (6, 15)
                        and f.est_actual = 'I')   ) cf
  where sc.nro_cuenta = cf.nro_cuenta(+)
;

