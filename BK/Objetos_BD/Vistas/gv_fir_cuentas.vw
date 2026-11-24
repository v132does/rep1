create or replace view it.gv_fir_cuentas as
select a.nro_cuenta nro_cuenta,
       denominacion nombre,
       descripcion||' EN '||cod_moneda tipo,
       u.nombre oficial, nvl(a.reg_firma,'SIN REGIMEN') observacion
   from ba_usuarios u, ge_clientes d, ge_cta_clientes c, ge_modalidades b,  ah_cta_vistas a
  where b.cod_modulo = a.cod_modulo
    and b.cod_modalidad = a.cod_modalidad
    and c.nro_cuenta = a.nro_cuenta
    and c.relacion = 'P'
    and c.cod_persona = d.cod_persona
    and d.cod_usu_oficial = u.cod_usuario
union all
select a.nro_cuenta nro_cuenta,
       denominacion nombre,
       descripcion||' EN '||cod_moneda tipo,
       u.nombre oficial, nvl(a.reg_firma,'SIN REGIMEN') observacion
   from ba_usuarios u, ge_clientes d, ge_cta_clientes c, ge_modalidades b,  cc_cta_corrientes a
  where b.cod_modulo = a.cod_modulo
    and b.cod_modalidad = a.cod_modalidad
    and c.nro_cuenta = a.nro_cuenta
    and c.relacion = 'P'
    and c.cod_persona = d.cod_persona
    and d.cod_usu_oficial = u.cod_usuario
union all
select a.nro_cuenta nro_cuenta,
       denominacion nombre,
       descripcion||' EN '||cod_moneda tipo,
       u.nombre oficial, nvl(a.reg_firma,'SIN REGIMEN') observacion
   from ba_usuarios u, ge_clientes d, ge_cta_clientes c, ge_modalidades b,  ah_cta_certificados a
  where b.cod_modulo = a.cod_modulo
    and b.cod_modalidad = a.cod_modalidad
    and c.nro_cuenta = a.nro_cuenta
    and c.relacion = 'P'
    and c.cod_persona = d.cod_persona
    and d.cod_usu_oficial = u.cod_usuario;
