create or replace force view it.pv_seguros as
select dat.cod_ente,
       dat.desc_ente,
       dat.cod_persona,
       dat.nro_solicitud,
       fue_obt_tip_doc_abreviatura(per.cod_tip_documento)tip_documento, --tip documento,
       per.nro_documento,
       fis.pri_nombre,
       fis.seg_nombre,
       fis.pri_apellido,
       fis.seg_apellido,
       fis.fec_nacimiento,
       dat.fec_inicio,
       dat.fec_vencimiento,
       dat.cod_moneda,
       dat.monto_sol,
       dat.monto_carg, --movi de cuentas prestamo, hoja con lupita
       (select m.monto
         from pr_movimientos_his m
        where m.nro_cuenta = dat.nro_cuenta
          and m.cod_transaccion = 736
          and rownum=1) prima_cliente, --prima cliente,
        (select m.monto
         from pr_movimientos_his m
        where m.nro_cuenta = dat.nro_cuenta
          and m.cod_transaccion = 517
          and rownum = 1) iva_cliente, --iva cliente,
       (select nvl(m.monto/2,0)
         from pr_movimientos_his m
        where m.nro_cuenta = dat.nro_cuenta
          and m.cod_transaccion = 736
          and rownum = 1) prima_mapfre, --prima aseguradora,
        (select nvl(m.monto/2,0)
         from pr_movimientos_his m
        where m.nro_cuenta = dat.nro_cuenta
          and m.cod_transaccion = 517
          and rownum=1) iva_mapfre, --iva aseguradora
       mo.cod_modalidad, --nro modalidad
       mo.descripcion,
       dat.cod_transaccion,
       dat.tip_amortizacion,
       dat.tasa_interes,
       dat.sal_capital,
       dat.fec_ult_pago,
       dat.sal_int_cuota,
       dat.sal_cap_cuota,
       dat.nro_cuenta,--Nro de prestamo,
       dat.nro_cta_debito,--Nro cuenta desembolso,
       fue_obt_dir_principa(dat.cod_persona) direccion,--Direccion,
       fue_obt_nom_usuario(FUG_OBT_COD_USU_OFICIAL(dat.cod_persona)) gestor, --Gestor,
       dat.jgo, --JGO, --358  cod de usuario
       fue_obt_des_oficina(fug_obt_ofi_cliente(dat.cod_persona)) oficina--Oficina
  from (select e.cod_ente,e.descripcion desc_ente,s.cod_persona,s.nro_solicitud,
               s.fec_inicio,s.fec_vencimiento,s.cod_moneda,s.tot_prestamo monto_sol,c.monto monto_carg,
               c.mto_mon_prestamo,t.cod_transaccion,t.descripcion,t.cod_modulo,t.cod_modalidad,t.tipo,
               pc.sal_capital sal_cap_cuota,pc.sal_interes sal_int_cuota,pcp.val_tasa tasa_interes,
               pcp.sal_capital,pc.fec_ult_pago,pcp.nro_cuenta,s.tip_amortizacion,
               pcp.nro_cta_debito, fue_obt_nom_usuario(pcp.usu_insercion) jgo
          from pr_sol_cargos    c,
               pr_solicitudes   s,
               ge_transacciones t,
               ge_entes         e,
               pr_cta_prestamos pcp,
               pr_cuotas        pc
         where pcp.nro_solicitud = s.nro_solicitud
           and pc.nro_cuenta = pcp.nro_cuenta
           and c.nro_solicitud = s.nro_solicitud
           and c.cod_transaccion = t.cod_transaccion
           and s.cod_modulo = t.cod_modulo
           and s.cod_modalidad = t.cod_modalidad
           and c.cod_ent_seguro = e.cod_ente
           and e.tipo = 'SE') dat,
       ba_personas per,
       ba_per_fisicas fis,
       ge_modalidades mo
 where dat.cod_modulo = mo.cod_modulo
   and dat.cod_modalidad = mo.cod_modalidad
   and dat.cod_persona = per.cod_persona
   and dat.cod_persona = fis.cod_persona(+)
 order by dat.cod_ente,
          dat.cod_persona,
          dat.cod_transaccion,
          dat.cod_modulo,
          dat.cod_modalidad
;

