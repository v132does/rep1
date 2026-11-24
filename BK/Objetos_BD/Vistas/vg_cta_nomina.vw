create or replace force view it.vg_cta_nomina as
select pp.cod_ente,
       pp.empresa,
       pp.cod_modulo,
       pp.cod_modalidad,
       pp.tipo_cta,
       pp.cod_sub_modalidad sub_mod,
       pp.tipo_cuenta sub_mod_cta,
       ba.nombre gestor,
       pp.nro_cuenta,
       pp.cod_moneda,
       pp.fec_apertura,
       pp.estado_cta,
       pp.cod_persona,
       pp.cliente,
       pp.nro_documento,
       pp.debito_tarjeta,
       pp.debito_prestamo,
       pp.fec_ult_crd fec_ult_acrd,
       pp.sal_disponible,
       cc.monto mon_sobregiro,
       pp.dir_correo,
       pp.dir_kit
  from vg_cta_ent_pag_salario pp,
       cc_lin_sobregiros      cc,
       ge_clientes            ss,
       ba_usuarios            ba
 where pp.nro_cuenta = cc.nro_cuenta(+)
   and pp.cod_persona = ss.cod_persona
   and ss.cod_usu_oficial = ba.cod_usuario;

