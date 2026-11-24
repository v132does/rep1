create or replace force view it.tv_solicitudes_his as
select sol.tipo, sol.des_tipo, sol.nro_solicitud,
      sol.cod_persona, sol.cod_oficina, sol.cod_modulo,
      sol.cod_modalidad, sol.cod_usu_promotor, sol.fec_solicitud,
      sol.cod_usu_oficial, sol.fec_aprobacion, sol.cod_causa,
      sol.deb_automatico, sol.nro_cta_debito, sol.tip_cobro,
      sol.nom_embozado, sol.monto, sol.cod_estado,
      sol.cod_est_sugerido, sol.lin_sugerida, sol.puntaje,
      sol.observacion, sol.cod_moneda, sol.cod_campana,
      sol.cod_canal, sol.mto_aprobado, sol.est_titular,
      sol.nro_acta, sol.niv_aprobacion, 'N' reenviar,
      ti.cod_ent_procesadora, null fecha,
      cta.nro_cuenta, sol.cod_per_titular,'Solicitud' descripcion,
      sol.nro_linea, 'Alta' motivo
  from tv_solicitudes sol,
       ta_cta_tarjetas cta,
       (select distinct t.cod_modalidad, t.cod_modulo, t.Afinidad, t.sub_afinidad, t.cod_campana, t.cod_ent_procesadora, t.cod_oficina
          from ta_tipos t ) ti--ta_tipos ti
 where (sol.cod_modulo = 5 and sol.cod_estado = 'APR' and sol.nro_cuenta is null)
   and ti.cod_modalidad = sol.cod_modalidad
   and ti.cod_modulo    = sol.cod_modulo
   and ti.afinidad      = sol.afinidad
   and nvl(ti.sub_afinidad,'ZZ') = nvl(sol.sub_afinidad,'ZZ')
   and (ti.cod_oficina = sol.cod_oficina or ti.cod_oficina is null)
   and nvl(ti.cod_campana,-1) = nvl(sol.cod_campana,-1)
   and ti.cod_campana is null
   and sol.nro_solicitud = cta.nro_solicitud(+)
   and exists (select 1
                 from ge_sol_estados l_gsoes
                where (sol.cod_estado = l_gsoes.cod_estado )
                  and l_gsoes.cod_estado in ('APR','TIA')
                  and sol.cod_modalidad in (select cod_modalidad
                                              from ta_tipos
                                             where cod_ent_procesadora = ti.cod_ent_procesadora))
union all
select distinct sol.tipo, sol.des_tipo, sol.nro_solicitud,
      sol.cod_persona, sol.cod_oficina, sol.cod_modulo,
      sol.cod_modalidad, sol.cod_usu_promotor, sol.fec_solicitud,
      sol.cod_usu_oficial, sol.fec_aprobacion, sol.cod_causa,
      sol.deb_automatico, sol.nro_cta_debito, sol.tip_cobro,
      sol.nom_embozado, sol.monto, sol.cod_estado,
      sol.cod_est_sugerido, sol.lin_sugerida, sol.puntaje,
      sol.observacion, sol.cod_moneda, sol.cod_campana,
      sol.cod_canal, sol.mto_aprobado, sol.est_titular,
      sol.nro_acta, sol.niv_aprobacion, 'N' reenviar,
      ti.cod_ent_procesadora, null fecha,
      sol.nro_cuenta, sol.cod_per_titular,'Solicitud' descripcion,
      sol.nro_linea, 'Alta' motivo
  from tv_solicitudes sol,
       ta_cta_tarjetas cta,
       (select distinct t.cod_modalidad, t.cod_modulo, t.Afinidad, t.sub_afinidad, t.cod_campana, t.cod_ent_procesadora, t.cod_oficina
          from ta_tipos t ) ti--ta_tipos ti
 where (sol.cod_modulo = 5 and sol.cod_estado = 'APR')
   and ti.cod_modalidad = sol.cod_modalidad
   and ti.cod_modulo    = sol.cod_modulo
   and ti.afinidad      = sol.afinidad
   and nvl(ti.sub_afinidad,'ZZ') = nvl(sol.sub_afinidad,'ZZ')
   and (ti.cod_oficina = sol.cod_oficina or ti.cod_oficina is null)
   and nvl(ti.cod_campana,-1) = nvl(sol.cod_campana,-1)
   and ti.cod_campana is null
   and sol.nro_cuenta      = cta.nro_cuenta
   and sol.nro_solicitud   is null
   and exists (select 1
                 from ge_sol_estados l_gsoes
                where (sol.cod_estado = l_gsoes.cod_estado )
                  and l_gsoes.cod_estado in ('APR','TIA')
                  and sol.cod_modalidad in (select cod_modalidad
                                              from ta_tipos
                                             where cod_ent_procesadora = ti.cod_ent_procesadora))
union all
  select tv.tipo, tv.des_tipo, tv.nro_solicitud, tv.cod_persona,
         tv.cod_oficina, tv.cod_modulo, tv.cod_modalidad,
         tv.cod_usu_promotor, tv.fec_solicitud, tv.cod_usu_oficial,
         tv.fec_aprobacion, tv.cod_causa, tv.deb_automatico,
         tv.nro_cta_debito, tv.tip_cobro, tv.nom_embozado, tv.monto,
         tv.cod_estado, tv.cod_est_sugerido, tv.lin_sugerida, tv.puntaje,
         tv.observacion, tv.cod_moneda, tv.cod_campana, tv.cod_canal,
         tv.mto_aprobado, tv.est_titular, tv.nro_acta, tv.niv_aprobacion,
         'S', to_number(substr(h.cod_procesadora,1,5)), to_char(h.fec_envio,'dd/mm/rrrr')||' '||h.hor_envio,
         h.nro_cuenta, tv.cod_per_titular,'Ya enviada' descripcion,
         tv.nro_linea, 'Alta' motivo
    from tv_solicitudes tv,
         ta_env_tarjetas_his h --tarjetas
   where tv.nro_solicitud = h.nro_solicitud
     and tv.cod_persona = h.cod_persona
     and not exists (select 0
                       from ta_env_cuentas_his z
                      where tv.nro_cuenta = z.nro_cuenta
                        and tv.tipo = 'T')
union all
  select tv.tipo, tv.des_tipo, tv.nro_solicitud, tv.cod_persona,
         tv.cod_oficina, tv.cod_modulo, tv.cod_modalidad,
         tv.cod_usu_promotor, tv.fec_solicitud, tv.cod_usu_oficial,
         tv.fec_aprobacion, tv.cod_causa, tv.deb_automatico,
         tv.nro_cta_debito, tv.tip_cobro, tv.nom_embozado, tv.monto,
         tv.cod_estado, tv.cod_est_sugerido, tv.lin_sugerida, tv.puntaje,
         tv.observacion, tv.cod_moneda, tv.cod_campana, tv.cod_canal,
         tv.mto_aprobado, tv.est_titular, tv.nro_acta, tv.niv_aprobacion,
         'S', to_number(substr(h.cod_procesadora,1,5)), to_char(h.fec_envio,'dd/mm/rrrr')||' '||h.hor_envio,
         h.nro_cuenta, tv.cod_per_titular,'Ya enviada' descripcion,
         tv.nro_linea, 'Altas' motivo
    from tv_solicitudes tv,
         ta_env_cuentas_his h --cuentas
   where tv.nro_cuenta = h.nro_cuenta
     and tv.tipo = 'T'
union all
   -- Novedades de Cuentas
  select distinct decode(P.relacion,'P','T',p.relacion),decode(P.relacion,'P','Titular','A','Adicional'),j.nro_solicitud,
        tar.cod_persona, j. cod_oficina,j.cod_modulo,
        j.cod_modalidad, j.cod_usu_promotor,nvl(tar.fec_solicitud,t.fec_insercion),
        null,t.fec_aprobacion,null,
        j.deb_automatico,j.nro_cta_debito,j.tip_cobro,
        tar.nom_embozar, j.lin_credito, decode(t.aprobado,'S','APR','TIA'),
        '',0,0,
        t.observacion,j.cod_moneda, j.cod_campana,
        j.cod_canal, j.lin_credito, 'TIA',
        null,null,'N',
        a.cod_ent_procesadora,null, tar.nro_cuenta,
        p.cod_persona /*persona titular*/, 'Modificación Cuenta' descripcion,
        j.nro_linea, 'Novedades' motivo
   from ta_cta_tarjetas_nov t,
        ta_cta_tarjetas j,
        ta_tipos a,
        ta_tarjetas tar,
        ge_cta_clientes p -- cliente principal
  where nvl( t.enviado, 'N' ) <> 'S'
    and nvl(aprobado,'N')   = 'S'
    and t.nro_cuenta        = j.nro_cuenta
    and a.cod_modulo        = j.cod_modulo
    and a.cod_modalidad     = j.cod_modalidad
    and a.afinidad          = j.afinidad
    and nvl(a.sub_afinidad,'XX') = nvl(j.sub_afinidad,'XX')
    and (a.cod_oficina       = j.cod_oficina or a.cod_oficina is null)
    and nvl(a.cod_campana,-1) = nvl(j.cod_campana,-1)
    and a.cod_campana is null
    and j.nro_cuenta        = tar.nro_cuenta
    and tar.cod_persona     = P.cod_persona
    and tar.nro_cuenta      = P.nro_cuenta
    and nvl(p.relacion,'P') = 'P'
    --DE-2103 - Enviar modificaciones de estado (Baja) de las tarjetas en estado NO VIGENTES - DYD-SDSL-3233
    --LCabrera - Agosto/2016
    and j.estado <> 'C'
    --and tar.vigente = 'S'
Union All
   -- Novedades de Tarjetas
   Select  distinct decode(P.relacion,'P','T',p.relacion)    Tipo   ,  -- Tipo
        decode(P.relacion,'P','Titular','A','Adicional') Des_tipo,  -- Descripcion Tipo
        j.nro_solicitud                                  Nro_Soli,  -- Nro. solicitud
        tar.cod_persona                                  Cod_Pers,  -- Cod. Persona
        j.cod_oficina                                    Cod_Ofic,  -- Cod. Oficina
        j.cod_modulo                                     Cod_Modu,  -- Cod. Modulo
        j.cod_modalidad                                  Cod_Moda,  -- Cod. Modalidad
        j.cod_usu_promotor                               Promotor,  -- Promotor
        tar.fec_solicitud                                Fec_Soli,  -- Fecha de Solicitud
        null                                             Oficial ,  -- Oficial
        null                                             Fec_Apro,  -- Fec. Aprobación
        null                                             Cod_Caus,  -- Cod. Causa
        j.deb_automatico                                 Deb_Auto,  -- Debito Automático
        j.nro_cta_debito                                 Cta_Debi,  -- Nro. Cta. Débito
        j.tip_cobro                                      Tip_Cobr,  -- Tipo de Cobro
        tar.nom_embozar                                  Nom_Embo,  -- Nombre a Embozar
        j.lin_credito                                    Lin_Cred,  -- Linea de Crédito
        decode(t.aprobado,'S','APR','TIA')               Estado  ,  -- Estado
        ''                                               Est_Suge,  -- Estado Sugerido
        0                                                Lin_Suge,  -- Linea Sugerida
        0                                                Puntaje ,  -- Puntaje
        NULL                                             Obervaci,  -- Obervacion
        j.cod_moneda                                     Moneda  ,  -- Moneda
        j.cod_campana                                    Campaña ,  -- Campaña
        j.cod_canal                                      Canal   ,  -- Canal
        j.lin_credito                                    Mto_Apli,  -- Mto. Aprobado
        'TIA'                                            Est_Titu,  -- Estado del Titular
        null                                             Nro_Acta,  -- Nro. Acta
        null                                             Niv_Apro,  -- Nivel de Aprobacion
        'N'                                              Reenviar,  -- Reenviar
        a.cod_ent_procesadora                            Procesad,  -- Codigo de Procesadora
        null                                             Fecha   ,  -- Fecha
        tar.nro_cuenta                                   Cuenta  ,  -- Cuenta
        fug_obt_cli_principal(T.NRO_CUENTA,'P')          Titular ,  -- Codigo del Titular
        'Modificación Cuenta'                            Descripc,  -- Descripción
        j.nro_linea                                      Nro_Line,  -- Numero de Línea
        'Novedades'                                      Motivo     -- Motivo

   From ta_tarjetas_nov  t  ,
        ta_cta_tarjetas  j  ,
        ta_tipos         a  ,
        ta_tarjetas      tar,
        ge_cta_clientes  p

  Where nvl( t.enviado, 'N' )    <> 'S'
    and nvl(aprobado,'N')        = 'S'
    and t.nro_cuenta             = j.nro_cuenta
    and a.cod_modulo             = j.cod_modulo
    and a.cod_modalidad          = j.cod_modalidad
    and a.afinidad               = j.afinidad
    and nvl(a.sub_afinidad,'XX') = nvl(j.sub_afinidad,'XX')
    and (a.cod_oficina           = j.cod_oficina or a.cod_oficina is null)
    and nvl(a.cod_campana,-1)    = nvl(j.cod_campana,-1)
    and a.cod_campana            is null
    and j.nro_cuenta             = tar.nro_cuenta
    and tar.cod_persona          = P.cod_persona
    and tar.nro_cuenta           = P.nro_cuenta
    and t.nro_tarjeta            = tar.nro_tarjeta
    and nvl(p.relacion,'P')      = 'A'
    and tar.vigente              = 'S'
union all
   -- Modificaciones de tarjetas --    Esto se comenta porque ya trae en novedades
/*  select decode(P.relacion,'P','T',p.relacion),decode(P.relacion,'P','Titular','A','Adicional'),j.nro_solicitud,
        tar.cod_persona, j. cod_oficina, j.cod_modulo,
        j.cod_modalidad, j.cod_usu_promotor,tar.fec_solicitud,
        null,null,null,
        j.deb_automatico,j.nro_cta_debito,j.tip_cobro,
        tar.nom_embozar, j.lin_credito,'TIA',
        '',0,0,
        NULL,j.cod_moneda, j.cod_campana,
        j.cod_canal, j.lin_credito, 'TIA',
        null,null,'N',
        t.cod_ent_procesadora,null, tar.nro_cuenta,
        p.cod_persona, --persona titular,
        'Modificación Tarjeta' descripcion,
        j.nro_linea
   from tv_tar_modificadas t,
        ta_cta_tarjetas j,
        ta_tarjetas tar,
        ge_cta_clientes p -- cliente principal
  where t.nro_cuenta        = j.nro_cuenta
    and j.nro_cuenta        = tar.nro_cuenta
    and t.nro_tarjeta     = tar.nro_tarjeta
    and t.nro_cuenta      = tar.nro_cuenta
    and t.cod_persona     = tar.cod_persona
    and t.cod_persona     = P.cod_persona
    and t.nro_cuenta      = P.nro_cuenta
union all*/
  -- No renovacion de tarjetas --
  select decode(cli.relacion, 'P', 'T',p.relacion), decode(cli.relacion,'P','Titular','A','Adicional'), c.nro_solicitud,
         t.cod_persona, c.cod_oficina, c.cod_modulo,
         c.cod_modalidad, c.cod_usu_promotor, c.fec_solicitud,
         null,null,null,
         c.deb_automatico, c.nro_cta_debito, c.tip_cobro,
         t.nom_embozar, c.lin_credito, 'TIA',
         null,null,null,
         null, c.cod_moneda, c.cod_campana,
         c.cod_canal, c.lin_credito, 'TIA',
         null, null, 'N',
         ti.cod_ent_procesadora, null, c.nro_cuenta,
         nvl(p.cod_persona,cli.cod_persona) /*persona titular*/, 'No Renovación' descripcion,
         c.nro_linea, 'No Renovacion' motivo
    from ta_tarjetas t    ,
         ta_cta_tarjetas c,
         ge_cta_clientes cli,
         ge_cta_clientes p,
         (select distinct tt.cod_modalidad, tt.cod_modulo, tt.afinidad, tt.sub_afinidad, tt.cod_campana, tt.cod_ent_procesadora, tt.cod_oficina
            from ta_tipos tt ) ti,
         ba_personas z    ,
         ba_per_fisicas y
   where t.cod_estado    = 15
     and c.nro_cuenta    = t.nro_cuenta
     and c.cod_modulo    = ti.cod_modulo
     and c.cod_modalidad = ti.cod_modalidad
     and c.afinidad      = ti.afinidad
     and nvl(c.sub_afinidad,'XX') = nvl(ti.sub_afinidad,'XX')
     and (c.cod_oficina   = ti.cod_oficina or ti.cod_oficina is null)
     and nvl(c.cod_campana,-1) = nvl(ti.cod_campana,-1)
     and ti.cod_campana is null
     and t.cod_persona   = z.cod_persona
     and z.cod_persona   = y.cod_persona
     and t.cod_persona   = cli.cod_persona
     and t.nro_cuenta    = cli.nro_cuenta
     and cli.cod_persona   <> p.cod_persona(+)
     and cli.nro_cuenta    = p.nro_cuenta(+)
     and nvl(p.relacion,'P') = 'P'
     and not exists(select 1
                      from ta_env_tarjetas_his h
                     where h.cod_procesadora = ti.cod_ent_procesadora
                       and h.nro_tarjeta     = t.nro_tarjeta
                       and h.estado          = 'E')
union all
   -- Activacion de tarjetas --
    select decode(P.relacion,'P','T',p.relacion),decode(P.relacion,'P','Titular','A','Adicional'),
           (select s.nro_solicitud from ta_solicitudes s
                          where s.nro_solicitud=j.nro_solicitud
                            and s.cod_persona = t.cod_persona) nro_solicitud,
          t.cod_persona, j.cod_oficina, j.cod_modulo,
          j.cod_modalidad, j.cod_usu_promotor,t.fec_solicitud,
          null,null,null,
          j.deb_automatico,j.nro_cta_debito,j.tip_cobro,
          t.nom_embozar, j.lin_credito,'TIA',
          '',0,0,
          NULL,j.cod_moneda, j.cod_campana,
          j.cod_canal, j.lin_credito, 'TIA',
          null,null,'N',
          ti.cod_ent_procesadora,null, t.nro_cuenta,
          p.cod_persona , 'Activación Tarjeta' descripcion,
          j.nro_linea, 'Activacion' motivo
     from ta_cta_tarjetas j,
          ta_tarjetas t,
          ge_cta_clientes p,  -- cliente principal
          ta_tipos ti
     where t.cod_estado in('3','4' )  -- Tarjetas ya entregadas
      and j.nro_cuenta        = t.nro_cuenta
      and t.cod_persona     = P.cod_persona
      and t.nro_cuenta      = P.nro_cuenta
      and j.cod_modulo      = ti.cod_modulo
      and j.cod_modalidad   = ti.cod_modalidad
       and j.afinidad        = ti.afinidad
      and nvl(j.sub_afinidad,'ZZ') = nvl(ti.sub_afinidad,'ZZ')
      and (j.cod_oficina = ti.cod_oficina or ti.cod_oficina is null)
;

