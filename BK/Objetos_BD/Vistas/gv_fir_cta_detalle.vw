create or replace view it.gv_fir_cta_detalle as
select a.nro_cuenta || ' ' || denominacion nombre,
       descripcion || ' EN ' || cod_moneda tipo,
       u.nombre oficial,
       nvl(reg_firma, 'SIN REGIMEN') observacion, -- a partir de aquí falta
       c.usu_insercion as usuario,
       c.fec_insercion as fec_insercion,
       a.can_fir_registradas as can_fir_registradas,
       a.can_fir_requeridas as can_fir_requeridas,
       null fec_vigencia,
       a.nro_cuenta
  from ba_usuarios     u,
       ge_clientes     d,
       ge_cta_clientes c,
       ge_modalidades  b,
       ah_cta_vistas   a
 where b.cod_modulo = a.cod_modulo
   and b.cod_modalidad = a.cod_modalidad
   and c.nro_cuenta = a.nro_cuenta
   and c.relacion = 'P'
   and c.cod_persona = d.cod_persona
   and d.cod_usu_oficial = u.cod_usuario
union
select a.nro_cuenta || ' ' || denominacion nombre,
       descripcion || ' EN ' || cod_moneda tipo,
       u.nombre oficial,
       NVL(reg_firma, 'SIN REGIMEN') observacion, -- a partir de aquí falta
       c.usu_insercion as usuario,
       c.fec_insercion as fec_insercion,
       a.can_fir_registradas as can_fir_registradas,
       a.can_fir_requeridas as can_fir_requeridas,
       null fec_vigencia,
       a.nro_cuenta
  from ba_usuarios       u,
       ge_clientes       d,
       ge_cta_clientes   c,
       ge_modalidades    b,
       cc_cta_corrientes a
 where b.cod_modulo = a.cod_modulo
   and b.cod_modalidad = a.cod_modalidad
   and c.nro_cuenta = a.nro_cuenta
   and c.relacion = 'P'
   and c.cod_persona = d.cod_persona
   and d.cod_usu_oficial = u.cod_usuario
;
