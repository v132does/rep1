create or replace force view it.bv_lin_pr_aprobadas as
select linpre.fec_aprobacion as fec_aprobacion,
       linpre.fecha_hora as fecha_hora,
       linpre.identificador as identificador,
       to_number(linpre.monto) as monto,
       linpre.cod_moneda as cod_moneda,
       linpre.tipo as tipo,
       upper(linpre.estado) as estado,
       linpre.destino as destino,
       linpre.cod_persona as cod_persona,
       linpre.nombre as nombre,
       linpre.usuario as cod_usuario,
       linpre.usu_aprobacion as usu_aprobacion,
       linpre.mto_maximo as mto_maximo,
       linpre.cod_moneda_lim as cod_moneda_limite,
       linpre.cod_usu_oficial as cod_usu_oficial,
       linpre.usu_oficial as usu_oficial,
       linpre.ofi_gestor as ofi_gestor,
       ba.descripcion as desc_oficina,
       linpre.fec as fec_vencimiento,
       linpre.credito_utilizado as credito_utilizado,
       linpre.credito_disponible as credito_disponible,
       linpre.usu_insercion,
       linpre.mto_capital mto_capital
  from (select trunc(xx.fec_otorgamiento) as fec_aprobacion,
               xx.fec_otorgamiento as fecha_hora,
               to_char(xx.nro_linea) as identificador,
               xx.monto,
               xx.cod_moneda,
               'LINEA DE CREDITO' as TIPO,
               xx.abreviatura as ESTADO,
               '' as DESTINO,
               xx.cod_persona,
               fue_obt_nom_persona(xx.cod_persona) as nombre,
               usuario,
               fue_obt_nom_usuario(xx.usuario) as usu_aprobacion,
               xx.mto_maximo,
               xx.cod_moneda_lim,
               xx.cod_usu_oficial as cod_usu_oficial,
               fue_obt_nom_usuario(xx.cod_usu_oficial) as usu_oficial,
               fug_obt_ofi_usuario(xx.cod_usu_oficial) as ofi_gestor,
               xx.fec,
               xx.credito_utilizado as credito_utilizado,
               xx.credito_disponible as credito_disponible,
               xx.usu_insercion,
               null mto_capital
        --29/07/2013 SF: se modifico para que traigan tambien las lineas historicas aprobadas. DC-2557
          from (select trim(substr(a.observacion, 2, 8)) usuario,
                       b.cod_usuario,
                       a.*,
                       b.mto_maximo,
                       b.cod_moneda as cod_moneda_lim,
                       g.cod_usu_oficial,
                       a.fec_vencimiento as fec,
                       a.mto_aplicado as credito_utilizado,
                       (a.monto - a.mto_aplicado) as credito_disponible,
                       br.abreviatura
                  from pr_lineas_his a,
                       (select * from ge_usu_limites where cod_modulo = 6) b,
                       ge_clientes g,
                       ba_cod_referencias br
                 where trim(a.observacion) is not null
                   and trim(substr(a.observacion, 2, 8)) = b.cod_usuario(+)
                   and g.cod_persona = a.cod_persona
                   and a.estado = 'A'
                   and a.estado = br.val_minimo
                   and br.dominio = 'EST_LIN_SOBREGIRO') xx

        union

        select trunc(x.fecha) as fec_aprobacion,
               x.fecha as fecha_hora,
               to_char(b.nro_cuenta) as identificador,
               a.monto,
               a.cod_moneda,
               'PRESTAMOS' as TIPO,
               fug_obt_des_est_cta(b.cod_modulo, b.cod_modalidad, b.estado) as ESTADO,
               a.descripcion as DESTINO,
               a.cod_persona,
               fue_obt_nom_persona(a.cod_persona) as nombre,
               x.cod_usuario usuario,
               fue_obt_nom_usuario(x.cod_usuario) as usu_aprobacion,
               z.mto_maximo,
               z.cod_moneda as cod_moneda_lim,
               g.cod_usu_oficial as cod_usu_oficial,
               fue_obt_nom_usuario(g.cod_usu_oficial) as usu_oficial,
               fug_obt_ofi_usuario(g.cod_usu_oficial) as ofi_gestor,
               NULL as fec,
               NULL as credito_utilizado,
               NULL as credito_disponible,
               b.usu_insercion,
               b.mto_capital
          from pr_solicitudes a,
               pr_cta_prestamos b,
               (select * from ge_usu_limites where cod_modulo = 6) z,
               ge_clientes g,
               (select * from pr_sol_gestiones d where d.estado = 'L') x
         where a.nro_solicitud = b.nro_solicitud
           and x.cod_usuario = z.cod_usuario(+)
           and x.nro_solicitud = a.nro_solicitud
           and g.cod_persona = a.cod_persona
           and x.fecha = (select max(q.fecha)
                            from pr_sol_gestiones q
                           where q.nro_solicitud = a.nro_solicitud
                             and q.estado = 'L')
         order by 1 desc) linpre,
       ba_oficinas ba
 where ba.cod_oficina = linpre.ofi_gestor
;

