create or replace force view it.ov_car_cli_morosos as
select pe.cod_persona, pe.nom_completo, di.direccion||decode(di.numero,null,'',' '||di.numero) dir_particular, ci.descripcion ciu_particular,
      dl.direccion||decode(di.numero,null,'',' '||di.numero) dir_laboral, initcap( co.descripcion ) ofi_ciudad,
      decode( nvl( pe.cod_tip_documento, -1 ), 1, pe.nro_documento, NULL ) nro_cedula,
      to_char( pag_cal.fu_obt_fec_actual(21), 'dd' ) || ' de ' ||
      rtrim( to_char( pag_cal.fu_obt_fec_actual(21), 'Month' ) ) || ' de ' ||
      to_char( pag_cal.fu_obt_fec_actual(21), 'YYYY' ) des_fecha, cp.cod_campana
 from ba_personas pe, ba_direcciones di, ba_ciudades ci, ba_direcciones dl, ge_clientes cl, ba_oficinas oi,
      ba_ciudades co, cr_cam_personas cp
where pe.cod_persona = di.cod_persona (+)
  and nvl( di.tipo(+), 'P' ) = 'P'
/*  and nvl( di.cod_direccion(+), 0 ) = ( select nvl( min( dr.cod_direccion ), 0 )
                                          from ba_direcciones dr
                                         where dr.cod_persona = pe.cod_persona
                                           and nvl( dr.tipo, 'P' ) = 'P' )*/
  and di.cod_pais = ci.cod_pais (+)
  and di.cod_ciudad = ci.cod_ciudad (+)
  and pe.cod_persona = dl.cod_persona (+)
  and nvl( dl.tipo(+), 'L' ) = 'L'
/*  and nvl( dl.cod_direccion(+), 0 ) = ( select nvl( min( da.cod_direccion ), 0 )
                                          from ba_direcciones da
                                         where da.cod_persona = pe.cod_persona
                                           and nvl( da.tipo, 'P' ) = 'L' )*/
  and pe.cod_persona = cl.cod_persona
  and oi.cod_oficina = cl.cod_oficina
  and oi.cod_ciudad = co.cod_ciudad (+)
  and oi.cod_pais = co.cod_pais (+)
  and pe.cod_persona = cp.cod_persona;

