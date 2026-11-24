create or replace force view it.gv_prod_act_nomina as
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       ta.fec_apertura, ta.nro_cuenta, ta.cod_moneda, ta.cod_modulo, ta.cod_modalidad, ta.estado, ta.cod_oficina,
       fue_obt_des_oficina(ta.cod_oficina) des_oficina, count(1)cant, '01. Tarjetas de Crédito' grupo
  from ge_clientes cli, ge_cta_clientes cta, ta_cta_tarjetas ta
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = ta.nro_cuenta
   and cta.relacion = 'P'
   and ta.estado not in ('C','P')
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       ta.fec_apertura, ta.nro_cuenta, ta.cod_moneda, ta.cod_modulo, ta.cod_modalidad, ta.estado, ta.cod_oficina,
       fue_obt_des_oficina(ta.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina) des_oficina, count(1)cant, '02. Préstamos de Consumo' grupo
  from ge_clientes cli, ge_cta_clientes cta, pr_cta_prestamos pr
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = pr.nro_cuenta
   and cta.relacion = 'P'
   and pr.estado not in ('I','N','V')
   and pr.cod_modalidad in (65, 68) -- prestamos de consumo
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina) des_oficina, count(1)cant, '03. H20/H30' grupo
  from ge_clientes cli, ge_cta_clientes cta, pr_cta_prestamos pr
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = pr.nro_cuenta
   and cta.relacion = 'P'
   and pr.estado not in ('I','N','V')
   and pr.cod_modalidad in (612, 673) -- H20/H30
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina) des_oficina, count(1)cant, '04. Otros préstamos particulares' grupo
  from ge_clientes cli, ge_cta_clientes cta, pr_cta_prestamos pr
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = pr.nro_cuenta
   and cta.relacion = 'P'
   and pr.estado not in ('I','N','V')
   and pr.cod_modalidad in (676, 672, 610, 60) -- otros préstamos particulares
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina) des_oficina, count(1)cant, '05. Operaciones de Comercio Exterior' grupo
  from ge_clientes cli, ge_cta_clientes cta, pr_cta_prestamos pr
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = pr.nro_cuenta
   and cta.relacion = 'P'
   and pr.estado not in ('I','N','V')
   and pr.cod_modalidad in (63, 64, 606, 602, 603, 627, 631) -- operaciones de comercio exterior
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina) des_oficina, count(1)cant, '06. Préstamos Hipotecarios Empresas' grupo
  from ge_clientes cli, ge_cta_clientes cta, pr_cta_prestamos pr
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = pr.nro_cuenta
   and cta.relacion = 'P'
   and pr.estado not in ('I','N','V')
   and pr.cod_modalidad in (61, 67, 613, 622, 608) -- prestamos hipotecarios empresas
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina) des_oficina, count(1)cant, '07. Préstamos a la Vista' grupo
  from ge_clientes cli, ge_cta_clientes cta, pr_cta_prestamos pr
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = pr.nro_cuenta
   and cta.relacion = 'P'
   and pr.estado not in ('I','N','V')
   and pr.cod_modalidad in (677, 675) -- prestamos a la vista
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina) des_oficina, count(1)cant, '08. Otros préstamos de la empresa' grupo
  from ge_clientes cli, ge_cta_clientes cta, pr_cta_prestamos pr
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = pr.nro_cuenta
   and cta.relacion = 'P'
   and pr.estado not in ('I','N','V')
   and pr.cod_modalidad in (61, 67, 613, 622, 608, 613) -- otros prestamos de la empresa
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       pr.fec_inicio, pr.nro_cuenta, pr.cod_moneda, pr.cod_modulo, pr.cod_modalidad, pr.estado, pr.cod_oficina,
       fue_obt_des_oficina(pr.cod_oficina)
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       qc.fec_inicio, q.nro_cuenta, null, q.cod_modulo, q.cod_modalidad, qc.estado, null, null,
       count(1)cant, '09. Paquetes' grupo
  from ge_clientes cli, ge_cta_clientes cta, ge_paq_cuentas q, ge_paq_clientes qc
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = q.nro_cuenta
   and q.cod_persona = qc.cod_persona
   and q.cod_paquete = qc.cod_paquete
   and cta.relacion = 'P'
   and qc.estado <> 'C'
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       qc.fec_inicio, q.nro_cuenta, q.cod_modulo, q.cod_modalidad, qc.estado
union
Select fue_obt_cod_ent_per(cli.cod_persona) cod_ente, cli.cod_persona, fue_obt_nom_persona(cli.cod_persona) nombre,
       cc.fec_apertura, cc.nro_cuenta, cc.cod_moneda, cc.cod_modulo, cc.cod_modalidad, cc.estado, cc.cod_oficina,
       fue_obt_des_oficina(cc.cod_oficina) des_oficina, count(1)cant, '10. Chequeras' grupo
  from ge_clientes cli, ge_cta_clientes cta, cc_chequeras ch, cc_cta_corrientes cc
 where cli.cod_persona = cta.cod_persona
   and cta.nro_cuenta = cc.nro_cuenta
   and cc.nro_cuenta = ch.nro_cuenta
   and cta.relacion = 'P'
   and cc.estado not in ('C','P')
   and (exists (Select 1
                  from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
                 where cl.nro_cuenta = ah.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and ah.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and ah.estado not in ('C','P')
                   and ah.cod_ente is not null) or exists
               (Select 1
                  from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
                 where cc.nro_cuenta = cl.nro_cuenta
                   and cl.cod_persona = cli.cod_persona
                   and cl.cod_modulo = g.cod_modulo
                   and cl.cod_modalidad = g.cod_modalidad
                   and cc.estado = g.estado
                   and g.activo = 'S'
                   and cl.relacion = 'P'
                   and cc.estado not in ('C','P')
                   and cc.cod_ente is not null))
group by fue_obt_cod_ent_per(cli.cod_persona), cli.cod_persona, fue_obt_nom_persona(cli.cod_persona),
       cc.fec_apertura, cc.nro_cuenta, cc.cod_moneda, cc.cod_modulo, cc.cod_modalidad, cc.estado, cc.cod_oficina,
       fue_obt_des_oficina(cc.cod_oficina)
order by 1
;

