create or replace force view it.pv_cta_canceladas as
select x.fec_cancelacion,
         x.nro_cuenta,
         x.cod_persona,
         x.nom_cliente,
         x.denominacion ,
         x.cod_moneda,
         x.mto_capital,
         x.cod_oficina,
         x.desc_oficina,
         x.fec_inicio,
         x.fec_vencimiento,
         x.estado,
         x.des_estado,
         x.des_garantia,
         x.cod_garantia,
         x.mto_apl_garantia

    from
       (select a.fec_cancelacion,
               a.nro_cuenta nro_cuenta,
               b.cod_persona cod_persona,
               fue_obt_nom_persona(b.cod_persona) nom_cliente,
               cc.denominacion ,
               a.cod_moneda cod_moneda,
               FUP_OBT_ULT_CAPITAL(a.nro_cuenta) mto_capital,
               a.cod_oficina cod_oficina,
               o.descripcion  desc_oficina,
               a.fec_inicio fec_inicio,
               a.fec_vencimiento ,
               a.estado ,
               c.descripcion des_estado,
               gt.descripcion des_garantia,
               g.cod_garantia ,
               g.mto_aplicado mto_apl_garantia
    from pr_cta_prestamos a, ge_cta_clientes b, ge_est_cuentas c , ge_cuentas cc ,
         ba_oficinas o , pr_cta_garantias g , pr_garantias gg , pr_gar_tipos gt
   where a.nro_cuenta = b.nro_cuenta
   and a.cod_modulo = c.cod_modulo
   and a.cod_modalidad = c.cod_modalidad
   and a.estado = c.estado
   and c.estado = 'N'
   and b.relacion = 'P'
   and b.nro_cuenta = cc.nro_cuenta
   and o.cod_oficina = a.cod_oficina
   and a.nro_cuenta = g.nro_cuenta(+)
   and g.cod_garantia = gg.cod_garantia(+)
   and g.nro_garantia = gg.nro_garantia(+)
   and gg.cod_garantia = gt.cod_garantia(+)
   and a.fec_cancelacion = pag_cal.FU_OBT_FEC_ACTUAL(1))x;

