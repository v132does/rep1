create or replace force view it.iv_ope_res_negocios as
select cod_periodo,cod_concepto, cod_sub_concepto, cod_unidad, fecha, cod_plazo, cod_moneda,
       nvl( sum_con_mto_apertura,0) sum_con_mto_apertura,
       nvl( sum_con_saldo,0) sum_con_saldo,
       nvl( sum_con_interes,0) sum_con_interes,
       nvl( sum_con_int_devengado,0) sum_con_int_devengado,
       nvl( sum_con_int_devengar,0) sum_con_int_devengar,
       nvl( sum_con_int_dev_suspenso,0) sum_con_int_dev_suspenso,
       nvl( sum_con_int_recuperado,0) sum_con_int_recuperado,
       nvl( sum_con_mto_mora,0) sum_con_mto_mora, nvl( sum_con_sal_promedio,0) sum_con_sal_promedio,

       nvl( sum_mto_apertura,0) sum_mto_apertura, nvl( sum_saldo,0)sum_saldo, nvl( sum_interes,0) sum_interes,
       nvl( sum_int_devengado,0) sum_int_devengado, nvl( sum_int_devengar,0)sum_int_devengar, nvl( sum_int_dev_suspenso,0) sum_int_dev_suspenso,
       nvl( sum_int_recuperado,0) sum_int_recuperado,
       nvl( sum_mto_mora,0) sum_mto_mora, nvl( sum_sal_promedio,0) sum_sal_promedio, por_mora,
       nvl( sum_logro,0) sum_logro, nvl( sum_con_logro,0) sum_con_logro, max_mora, pro_mora,
       nvl( can_cuentas,0) can_cuentas, nvl( can_clientes,0) can_clientes, 'REG' tipo
  from ig_ope_res_negocios
union all
select cod_periodo, cod_concepto, cod_sub_concepto, cod_unidad, fecha, cod_plazo, null,
       sum( nvl(sum_con_mto_apertura,0)), sum( nvl(sum_con_saldo,0) ), sum( nvl(sum_con_interes,0) ),
       sum( nvl(sum_con_int_devengado,0) ), sum( nvl(sum_con_int_devengar,0) ), sum( nvl(sum_con_int_dev_suspenso,0) ),
       sum( nvl(sum_con_int_recuperado,0) ), sum( nvl(sum_con_mto_mora,0) ), sum( nvl(sum_con_sal_promedio,0) ),

       null, null, null,
       null, null, null,
       null,
       null, null, null,
       null, sum ( nvl( sum_con_logro,0)), null, null,
       sum( nvl( can_cuentas,0) ), sum ( nvl( can_clientes,0) ), 'SUM'
  from ig_ope_res_negocios
 group by cod_periodo, cod_concepto, cod_sub_concepto, cod_unidad, fecha, cod_plazo
union all
select cod_periodo, cod_concepto, cod_sub_concepto, cod_unidad, fecha, null, null,
       sum( nvl(sum_con_mto_apertura,0)), sum( nvl(sum_con_saldo,0) ), sum( nvl(sum_con_interes,0) ),
       sum( nvl(sum_con_int_devengado,0) ), sum( nvl(sum_con_int_devengar,0) ), sum( nvl(sum_con_int_dev_suspenso,0) ),
       sum( nvl(sum_con_int_recuperado,0) ), sum( nvl(sum_con_mto_mora,0) ), sum( nvl(sum_con_sal_promedio,0) ),

       null, null, null,
       null, null, null,
       null,
       null, null, null,
       null, sum ( nvl( sum_con_logro,0)), null, null,
       sum( nvl( can_cuentas,0) ), sum ( nvl( can_clientes,0) ), 'SUM'
  from ig_ope_res_negocios
 group by cod_periodo, cod_concepto, cod_sub_concepto, cod_unidad, fecha
union all
select cod_periodo,cod_concepto, null, cod_unidad, fecha, cod_plazo, cod_moneda,
       sum(nvl( sum_con_mto_apertura,0)) sum_con_mto_apertura,
       sum(nvl( sum_con_saldo,0)) sum_con_saldo,
       sum(nvl( sum_con_interes,0)) sum_con_interes,
       sum(nvl( sum_con_int_devengado,0)) sum_con_int_devengado,
       sum(nvl( sum_con_int_devengar,0)) sum_con_int_devengar,
       sum(nvl( sum_con_int_dev_suspenso,0)) sum_con_int_dev_suspenso,
       sum(nvl( sum_con_int_recuperado,0)) sum_con_int_recuperado,
       sum(nvl( sum_con_mto_mora,0)) sum_con_mto_mora, sum(nvl( sum_con_sal_promedio,0)) sum_con_sal_promedio,

       sum(nvl( sum_mto_apertura,0)) sum_mto_apertura, sum(nvl( sum_saldo,0)) sum_saldo, sum(nvl( sum_interes,0)) sum_interes,
       sum(nvl( sum_int_devengado,0)) sum_int_devengado, sum(nvl( sum_int_devengar,0)) sum_int_devengar,
       sum(nvl( sum_int_dev_suspenso,0)) sum_int_dev_suspenso,
       sum(nvl( sum_int_recuperado,0)) sum_int_recuperado,
       sum(nvl( sum_mto_mora,0)) sum_mto_mora, sum(nvl( sum_sal_promedio,0)) sum_sal_promedio, null por_mora,
       sum(nvl( sum_logro,0)) sum_logro, sum(nvl( sum_con_logro,0)) sum_con_logro, max(max_mora), null pro_mora,
       sum(nvl( can_cuentas,0)) can_cuentas, sum(nvl( can_clientes,0)) can_clientes, 'REG' tipo
  from ig_ope_res_negocios
  group by cod_periodo,cod_concepto, cod_unidad, fecha, cod_plazo, cod_moneda
union all
-- sumatoria por conceptos por plazos
select cod_periodo, cod_concepto, null, cod_unidad, fecha, cod_plazo, null,
       sum( nvl(sum_con_mto_apertura,0)), sum( nvl(sum_con_saldo,0) ), sum( nvl(sum_con_interes,0) ),
       sum( nvl(sum_con_int_devengado,0) ), sum( nvl(sum_con_int_devengar,0) ), sum( nvl(sum_con_int_dev_suspenso,0) ),
       sum( nvl(sum_con_int_recuperado,0) ), sum( nvl(sum_con_mto_mora,0) ), sum( nvl(sum_con_sal_promedio,0) ),

       null, null, null,
       null, null, null,
       null,
       null, null, null,
       null, sum ( nvl( sum_con_logro,0)), null, null,
       sum( nvl( can_cuentas,0) ), sum ( nvl( can_clientes,0) ), 'CON_PLAZO'
  from ig_ope_res_negocios
 group by cod_periodo, cod_concepto, cod_unidad, fecha, cod_plazo
union all
-- sumatoria por conceptos por fecha
select cod_periodo, cod_concepto, null, cod_unidad, fecha, null, null,
       sum( nvl(sum_con_mto_apertura,0)), sum( nvl(sum_con_saldo,0) ), sum( nvl(sum_con_interes,0) ),
       sum( nvl(sum_con_int_devengado,0) ), sum( nvl(sum_con_int_devengar,0) ), sum( nvl(sum_con_int_dev_suspenso,0) ),
       sum( nvl(sum_con_int_recuperado,0) ), sum( nvl(sum_con_mto_mora,0) ), sum( nvl(sum_con_sal_promedio,0) ),

       null, null, null,
       null, null, null,
       null,
       null, null, null,
       null, sum ( nvl( sum_con_logro,0)), null, null,
       sum( nvl( can_cuentas,0) ), sum ( nvl( can_clientes,0) ), 'CON_FECHA'
  from ig_ope_res_negocios
 group by cod_periodo, cod_concepto, cod_unidad, fecha
order by 1,2,4,5,3,6,7
;

