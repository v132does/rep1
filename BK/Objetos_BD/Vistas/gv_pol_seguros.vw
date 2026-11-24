CREATE OR REPLACE FORCE VIEW IT.GV_POL_SEGUROS AS
select codigo, cod_persona, cod_ente, cod_oficina, 'CALL CENTER' registro, seccion, sub_seccion, nro_poliza, producto,
       mto_capital, mto_premio, mto_prima, mto_cuota, can_cuota, for_pago, fec_inicial, fec_final, fec_entrega, fec_envio,
       fec_propuesta, observaciones, cuo_inicial,
       estado, e.significado des_estado, referencia, cod_usu_ges_interno, cod_ges_externo, cod_irene, cod_moneda, situacion, tip_movimiento,
       tip_anulacion, cod_sub_seccion, canal, fec_emision
   from ge_pol_seguros s, ba_cod_referencias e
  where e.dominio = 'EST_POLIZA'
    and s.estado = e.val_minimo
union all
select c.nro_seguro, c.cod_persona, c.cod_ente, u.cod_oficina cod_oficina, 'ATM/WEB' registro, null, t.descripcion sub_seccion,
       decode(c.cod_tip_seguro, 2,trim(a.val_parametro),3, trim(v.val_parametro)) || '/' || to_char(c.nro_seguro) as nro_poliza,
       null, c.mto_capital, 0,0, cu.monto, 1, 'D', c.fec_inicio, c.fec_vencimiento, null fec_entrega, null fec_envio,
       null fec_propuesta, motivo observaciones, null,
       c.estado, e.significado, null referencia, null ges_interno, null ges_externo, null cod_irene, 'GS' cod_moneda, null situacion, null tip_movimiento,
       null tip_anulacion, to_char(c.cod_tip_seguro), to_char(c.cod_canal) canal, null
   from ge_cli_seguros c, ge_tip_seguros t, ge_par_dinamicos a, ge_par_dinamicos v, ba_cod_referencias e,
        (SELECT nro_seguro, max(nro_cuota) nro_cuota, monto  FROM ge_cuo_seguros
          group by nro_seguro, monto) cu, ba_usuarios u, ge_clientes cl, ge_canales ca
where c.cod_tip_seguro = t.cod_tipo
  and a.parametro = 'SEG_WEB_POL_ACCIDENTES'
  and v.parametro = 'SEG_WEB_POL_VIDA'
  and c.nro_seguro = cu.nro_seguro
  and e.dominio = 'EST_SEGURO'
  and c.estado = e.val_minimo
  and c.cod_persona = cl.cod_persona
  and cl.cod_usu_oficial = u.cod_usuario
  and c.cod_canal = ca.cod_canal;

