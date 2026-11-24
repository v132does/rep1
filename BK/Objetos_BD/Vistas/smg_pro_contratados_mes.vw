create or replace force view it.smg_pro_contratados_mes as
select dat.fec_apertura, dat.grupo, dat.cod_oficina, ofi.descripcion ofi_desc, dat.cod_modulo, dat.cod_modalidad, mo.descripcion, dat.estado,
       dat.est_desc, dat.cod_usu_oficial, dat.nombre_gestor, dat.cant
from (
     select c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion est_desc, cli.cod_usu_oficial,
     fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_gestor, count(1)cant, '01. Tarjetas de Crédito' grupo
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and c.cod_modulo = 5 -- tarjeta de credito
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
     fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '02. Préstamos de Consumo'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (65, 68)) -- prestamos de consumo
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
             fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '03. H20/H30'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (612, 673)) -- H20/H30
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura, c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '04. Otros préstamos particulares'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (676, 672, 610, 60)) -- otros préstamos particulares
       group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
                cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '05. Operaciones de Comercio Exterior '
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (63, 64, 606, 602, 603, 627, 631)) -- operaciones de comercio exterior
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '06. Préstamos Hipotecarios Empresas'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (61, 67, 613, 622, 608, 613)) -- prestamos hipotecarios empresas
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '07. Préstamos a la Vista'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
        and (c.cod_modulo = 6 and c.cod_modalidad in (677, 675)) -- prestamos a la vista
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura, c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '08. Otros préstamos de la empresa'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (61, 67, 613, 622, 608, 613)) -- otros prestamos de la empresa
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura, c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '09. Ahorro a la vista'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 3 and c.cod_modalidad = 31) -- ahorro a la vista
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
     union all
     select c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            fue_obt_nom_usuario(cli.cod_usu_oficial), count(1), '10. CDA'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 3 and c.cod_modalidad in (33, 36)) -- cda
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
) dat, ba_oficinas ofi, ge_modalidades mo
where dat.cod_oficina = ofi.cod_oficina
  and dat.cod_modulo = mo.cod_modulo
  and dat.cod_modalidad = mo.cod_modalidad
order by dat.fec_apertura,dat.grupo, dat.cod_oficina, ofi.descripcion, dat.cod_modulo, dat.cod_modalidad, mo.descripcion, dat.estado, dat.est_desc, dat.cant
;

