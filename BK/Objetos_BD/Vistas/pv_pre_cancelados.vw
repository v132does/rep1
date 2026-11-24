CREATE OR REPLACE FORCE VIEW IT.PV_PRE_CANCELADOS AS
SELECT distinct pre.nro_cuenta nro_cuenta,
                pre.cod_modalidad,
                decode(pre.cod_modalidad,
                       608,
                       'DCTO. CH. T.',
                       610,
                       'DCTO. CH. P.',
                       mod.descripcion) DESCRIPCION,
                pre.nro_solicitud Nro_Solicidud,
                pre.cod_moneda Moneda,
                sol.fec_aprobacion Fecha_Desembolso,
                pre.fec_cancelacion Fec_Cancelacion,
                (select sum(mto_capital)
                   from pr_cobros
                  where nro_cuenta = pre.nro_cuenta
                    and fecha = pre.fec_cancelacion
                    and dia_mora > 0) Capital_Vencido,
                (select sum(nvl(mto_interes,0))+sum(nvl(mto_int_documentado,0))
                   from pr_cobros
                  where nro_cuenta = pre.nro_cuenta
                    and fecha = pre.fec_cancelacion
                    and dia_mora > 0) Interes_Vencido,
                (select sum(mto_capital)
                   from pr_cobros
                  where nro_cuenta = pre.nro_cuenta
                    and fecha = pre.fec_cancelacion
                    and dia_mora = 0) Capital_No_Vencido,
                (select sum(nvl(mto_int_moratorio, 0)) +
                        sum(nvl(mto_int_mor_interes, 0)) +
                        sum(nvl(mto_int_mor_adelantado, 0)) +
                        sum(nvl(mto_int_punitorio, 0)) +
                        sum(nvl(mto_impuesto, 0)) + sum(nvl(mto_cargo, 0))
                   from pr_cobros
                  where nro_cuenta = pre.nro_cuenta
                    and fecha = pre.fec_cancelacion) Otros_Cargos,
                (select max(dia_mora)
                   from pr_cobros
                  where nro_cuenta = pre.nro_cuenta
                    and fecha = pre.fec_cancelacion) Dias_Mora,
                (select sum(nvl(mto_capital,0))+
                        sum(nvl(mto_interes,0))+
                        sum(nvl(mto_int_documentado,0))+
                        sum(nvl(mto_int_moratorio, 0)) +
                        sum(nvl(mto_int_mor_interes, 0)) +
                        sum(nvl(mto_int_mor_adelantado, 0)) +
                        sum(nvl(mto_int_punitorio, 0)) +
                        sum(nvl(mto_impuesto, 0)) + sum(nvl(mto_cargo, 0))
                   from pr_cobros
                  where nro_cuenta = pre.nro_cuenta
                    and fecha = pre.fec_cancelacion) Monto_Abonado,
                (select cat_automatica
                   from ge_cla_operaciones_his
                   where nro_cuenta = pre.nro_cuenta
                   and fecha = (select max(fecha)from ge_cla_operaciones_his where nro_cuenta = pre.nro_cuenta)) Categoria_Operacion,
                pre.val_tasa Tasa_Operacion
  FROM pr_cta_prestamos pre,
       pr_solicitudes   sol,
       ge_cta_clientes  cli,
       pr_cuotas        x,
       ge_modalidades   MOD
 WHERE pre.nro_cuenta = cli.nro_cuenta
   AND pre.estado = 'N'
   AND cli.relacion = 'P'
   AND pre.nro_solicitud = sol.nro_solicitud
   AND pre.nro_cuenta = x.nro_cuenta
   and pre.cod_modulo = mod.cod_modulo
   AND pre.cod_modalidad = mod.cod_modalidad
   AND NOT EXISTS (select '1'
          from pr_cta_prestamos b
         where cod_modalidad = 660
           and instr(descripcion, to_char(pre.nro_cuenta)) > 0)
 ORDER BY 7, 3;

