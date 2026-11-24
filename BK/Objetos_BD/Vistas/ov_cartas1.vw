create or replace force view it.ov_cartas1 as
select cp.cod_campana, pe.cod_persona, pe.nom_completo, di.direccion||decode(numero,null,'',' '||numero) direccion, ci.descripcion ciudad,
       decode( nvl( pf.cod_sexo, 'A' ), 'M', 'Señor', 'F', 'Señora', 'Señores' ) tratamiento,
       max( cu.dia_atraso ) dia_atraso
from pr_cta_prestamos p, ge_cta_clientes c, ge_est_cuentas e, ba_personas pe,
     ba_direcciones di, ba_ciudades ci, cr_cam_personas cp, ba_per_fisicas pf,
     ba_per_juridicas pj, ge_cuentas cu
where p.nro_cuenta = c.nro_cuenta
-- and p.cod_banca = 2   -- No corporativos      ge_est_cuentas ec
 and p.cod_modulo = e.cod_modulo
 and p.cod_modalidad = e.cod_modalidad  -- Solo Prestamos Activos
 and p.estado = e.estado
 and nvl(e.activo, 'N') = 'S'
 /*and nvl(p.dia_atraso, 0) between 30 and         -- A los 30 dias de mora
                                 (30 +((select (l.fec_actual - l.fec_anterior)
                                        from ge_calendarios l
                                        where l.cod_modulo = e.cod_modulo)- 1))
 and p.mto_mora >= 100000               -- Montos mayores o iguales a 100.000*/
 and not exists (select 1
                    from ba_usuarios z
                    where z.cod_usuario = c.cod_persona
                      and z.estado = 'A'
                      and z.categoria is not null) -- No funcionarios
 and not exists (select 1
                 from ah_cta_certificados a, ge_cta_clientes cc, ge_est_cuentas b
                 where a.nro_cuenta = cc.nro_cuenta
                   and a.cod_modulo = cc.cod_modulo
                   and a.cod_modalidad = cc.cod_modalidad
                   and a.cod_modulo = b.cod_modulo
                   and a.cod_modalidad = b.cod_modalidad
                   and a.estado = b.estado
                   and nvl(b.activo, 'N') = 'S'
                   and cc.cod_persona = c.cod_persona)  -- No en Grupo de CDA's ACTIVOS
 and pe.cod_persona = di.cod_persona (+)
 and nvl( di.principal, 'N' ) = 'S'
 and di.cod_pais = ci.cod_pais (+)
 and di.cod_ciudad = ci.cod_ciudad (+)
 and pe.cod_persona = cp.cod_persona
 and pe.cod_persona = pf.cod_persona (+)
 and pe.cod_persona = pj.cod_persona (+)
 and pe.cod_persona = c.cod_persona
 and cu.nro_cuenta = c.nro_cuenta
 and c.relacion = 'P'
 and cu.cod_modulo = e.cod_modulo
 and cu.cod_modalidad = e.cod_modalidad
 and cu.estado = e.estado
 and nvl( e.activo, 'N' ) = 'S'
group by cp.cod_campana, pe.cod_persona, pe.nom_completo, di.direccion||decode(numero,null,'',' '||numero), ci.descripcion,
      decode( nvl( pf.cod_sexo, 'A' ), 'M', 'Señor', 'F', 'Señora', 'Señores' )
UNION
select cp.cod_campana, pe.cod_persona, pe.nom_completo, di.direccion||decode(numero,null,'',' '||numero), ci.descripcion ciudad,
       decode( nvl( pf.cod_sexo, 'A' ), 'M', 'Señor', 'F', 'Señora', 'Señores' ) tratamiento,
       max( cu.dia_atraso ) dia_atraso
from ta_cta_tarjetas p, ge_cta_clientes c, ge_est_cuentas e, ba_personas pe,
     ba_direcciones di, ba_ciudades ci, cr_cam_personas cp, ba_per_fisicas pf,
     ba_per_juridicas pj, ge_cuentas cu
where p.nro_cuenta = c.nro_cuenta
  and p.cod_modulo = e.cod_modulo
  and p.cod_modalidad = e.cod_modalidad
  and p.estado = e.estado
  and nvl(e.activo, 'N') = 'S'         --Solo Tarjetas Activas
  and nvl(p.dia_mora, 0) between 30  and          -- A los 30 dias de mora
                                (30 +((select (l.fec_actual - l.fec_anterior)
                                       from ge_calendarios l
                                       where l.cod_modulo = e.cod_modulo)- 1))
  and p.mto_mora >= 100000
  and not exists (select 1
                   from ba_usuarios z
                   where z.cod_usuario = c.cod_persona
                     and z.estado = 'A'
                     and z.categoria is not null) -- No funcionarios
  and not exists (select *
                  from ah_cta_certificados a, ge_cta_clientes cc, ge_est_cuentas b
                  where a.nro_cuenta = cc.nro_cuenta
                    and a.cod_modulo = cc.cod_modulo
                    and a.cod_modalidad = cc.cod_modulo
                    and a.cod_modulo = b.cod_modulo
                    and a.cod_modalidad = b.cod_modalidad
                    and a.estado = b.estado
                    and nvl(b.activo, 'N') = 'S'
                    and cc.cod_persona = c.cod_persona)  -- No en Grupo de CDA's ACTIVOS
  and pe.cod_persona = di.cod_persona (+)
  and nvl( di.principal, 'N' ) = 'S'
  and di.cod_pais = ci.cod_pais (+)
  and di.cod_ciudad = ci.cod_ciudad (+)
  and pe.cod_persona = cp.cod_persona
  and pe.cod_persona = pf.cod_persona (+)
  and pe.cod_persona = pj.cod_persona (+)
  and pe.cod_persona = c.cod_persona
  and cu.nro_cuenta = c.nro_cuenta
  and c.relacion = 'P'
  and cu.cod_modulo = e.cod_modulo
  and cu.cod_modalidad = e.cod_modalidad
  and cu.estado = e.estado
  and nvl( e.activo, 'N' ) = 'S'
group by cp.cod_campana, pe.cod_persona, pe.nom_completo, di.direccion||decode(numero,null,'',' '||numero), ci.descripcion,
      decode( nvl( pf.cod_sexo, 'A' ), 'M', 'Señor', 'F', 'Señora', 'Señores' )
;

