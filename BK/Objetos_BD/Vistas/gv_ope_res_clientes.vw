create or replace force view it.gv_ope_res_clientes as
select g.fecha,
         g.hora,
         g.cod_usuario,
         g.cod_persona, fue_obt_nro_doc_persona(g.cod_persona) nro_doc_cliente,
         fue_obt_nom_persona(g.cod_persona) nom_persona,
         g.fec_valor,
         (select c.cod_usu_oficial from ge_clientes c where c.cod_persona = g.cod_persona) cod_usu_oficial,
         fue_obt_nom_usuario((select c.cod_usu_oficial from ge_clientes c where c.cod_persona = g.cod_persona)) nom_oficial,
         g.cod_moneda,
         g.nro_cuenta,
         g.cod_ofi_origen,
         g.cod_tra_padre,
         fue_obt_titulo(
         fug_obt_des_transaccion(g.cod_mod_padre,g.cod_mad_padre,g.cod_tra_padre)) des_transaccion,
         g.cod_modulo,
         (select m.descripcion from ba_modulos m where g.cod_modulo = m.cod_modulo) modulo,
         g.cod_modalidad,
         decode(tip_mov_rubro,'D',g.monto,0) mto_debito,
         decode(tip_mov_rubro,'D',g.mto_equ_mon_fuerte,0) mto_fue_debito,
         decode(tip_mov_rubro,'C',g.monto,0) mto_credito,
         decode(tip_mov_rubro,'C',g.mto_equ_mon_fuerte,0) mto_fue_credito,
         g.mto_equ_local,
         g.mto_equ_mon_fuerte,
         g.cotizacion,
         g.nro_documento,
         g.tip_mov_rubro,
         g.informado,
         nvl((select nvl(r.cli_frecuente,'N')
                from cr_inf_fondos r
               where r.cod_persona = g.cod_persona
             ),'N') cli_frecuente,
         case
            when (select count(distinct m.cod_modalidad)
                  from ge_mov_res_clientes m
                  where  m.cod_persona = g.cod_persona and m.fecha = g.fecha) = 1 then 'FRA'
            when (select count(distinct m.cod_modalidad)
                  from ge_mov_res_clientes m
                  where  m.cod_persona = g.cod_persona and m.fecha = g.fecha) > 1 then 'MUL'
         end ope_fra_mu,
         decode(g.cod_modulo,5,
         (select nvl(p.sal_facturar,0)+nvl(p.sal_facturado,0)+nvl(p.sal_financiado,0)+nvl(p.sal_cuo_pendientes,0) mto_prestamo
                          from ta_cta_tarjetas p
                         where p.nro_cuenta = g.nro_cuenta),
         6, g.monto) tot_deuda
    from ge_mov_res_clientes g
   where g.cod_persona is not null
   and ((g.cod_modulo = 5 and g.cod_tra_padre in (250,450))
     or (g.cod_modulo = 6 and g.cod_tra_padre = 359));

