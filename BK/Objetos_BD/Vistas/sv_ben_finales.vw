create or replace force view it.sv_ben_finales as
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre gestor,
       bab.descripcion oficina,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza)tipo_sociedad,
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona)tipo_accion_accionista,
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo)tipo_doc,
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo)nro_documento_vinculo,
        e.descripcion TIPO_DE_VINCULO,
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo)nombre_persona_vinculada,
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%
           and rownum = 1')"PORCENTAJE_PARTICIPACION",
        (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais)nacionalidad,
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') domicilio_legal,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo) correo
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
 where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and d.tipo = e.cod_tip_vinculo
   and e.cod_tip_vinculo in ('G', 'AD', 'TE', 'OT')
   and b.naturaleza = 'OTRAS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        'FIRMANTE',
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S'),
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and d.tipo = e.cod_tip_vinculo
   and e.cod_tip_vinculo not in ('G', 'AD', 'TE','OT')
   and b.naturaleza = 'OTRAS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union -- S.A
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona)tipo_accion_accionista,
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
      (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        (select bv.descripcion
           from ba_tip_vinculos bv
          where bv.cod_tip_vinculo = e.cod_tip_vinculo),
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%
           and rownum = 1'),
      (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and d.tipo = e.cod_tip_vinculo
   and e.cod_tip_vinculo in ('AC', 'AA', 'RE', 'P', 'DI', 'TE', 'A', 'R', 'V', 'PS', 'BF', 'G', 'GF', 'DT')
   and b.naturaleza = 'SA'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select bv.descripcion
           from ba_tip_vinculos bv
          where bv.cod_tip_vinculo = e.cod_tip_vinculo),
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and d.tipo = e.cod_tip_vinculo
   and e.cod_tip_vinculo not in ('OH', 'AC', 'AA', 'RE', 'P', 'DI', 'TE', 'A', 'R', 'V', 'PS', 'BF', 'G', 'GF', 'DT')
   and b.naturaleza = 'SA'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union --SOCIEDADES SIMPLES en las sa t_accion empressa cargado
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
        (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        'ACCIONISTA' ,
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and d.tipo = e.cod_tip_vinculo
   and e.cod_tip_vinculo = 'S'
   and b.naturaleza = 'SS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
        (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S','AL_PORTADOR','N','NOMINATIVA',null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       'FIRMANTE',
        (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais)nacionalidad,
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') domicilio_legal,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and d.tipo = e.cod_tip_vinculo
   and e.cod_tip_vinculo != 'S'
   and b.naturaleza = 'SS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union -- Sociedades Colectivas en las sa t_accion empressa cargado
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        'ACCIONISTA',
        (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
         (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo = 'S'
   and b.naturaleza = 'SC'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       'FIRMANTE',
        (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
         (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo != 'S'
   and b.naturaleza = 'SC'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union --Sociedades en Comanditas Simples en las sa t_accion empressa cargado
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion ,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        'ACCIONISTA' ,
        (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo = 'S'
   and b.naturaleza = 'SCS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre ,
       bab.descripcion ,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        'FIRMANTE',
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais)nacionalidad,
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') domicilio_legal,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo != 'S'
   and b.naturaleza = 'SCS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union -- Sociedad de Responsabilidad Limitada SRL en las sa t_accion empressa vacio
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        e.descripcion,
        (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
          and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
         where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo = 'S'
   and b.naturaleza = 'SRL'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
        (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        e.descripcion,
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo != 'S'
   and b.naturaleza = 'SRL'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union -- Sociedad en Comandita por Acciones  en las sa t_accion empressa cargado
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
        (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        'ACCIONISTA',
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo = 'S'
   and b.naturaleza = 'SEPA'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
        (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
         'FIRMANTE',
      (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo != 'S'
   and b.naturaleza = 'SEPA'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union -- SOCIEDAD ANONIMA EMISORA DE CAPITAL ABIERTO
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo)cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
      (select bv.descripcion
           from ba_tip_vinculos bv
          where bv.cod_tip_vinculo = e.cod_tip_vinculo),
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
      (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
  -- and e.cod_tip_vinculo in ('AC', 'AA', 'RE', 'P', 'DI', 'TE', 'A', 'R', 'V', 'PS', 'BF', 'G', 'GF', 'DT')
   and b.naturaleza = 'SAECA'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select bv.descripcion
           from ba_tip_vinculos bv
          where bv.cod_tip_vinculo = e.cod_tip_vinculo),
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   --and e.cod_tip_vinculo not in ('OH', 'AC', 'AA', 'RE', 'P', 'DI', 'TE', 'A', 'R', 'V', 'PS', 'BF', 'G', 'GF', 'DT')
   and b.naturaleza = 'SAECA'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union -- sin naturaleza
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select bv.descripcion
           from ba_tip_vinculos bv
          where bv.cod_tip_vinculo = e.cod_tip_vinculo),
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
      (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
  -- and e.cod_tip_vinculo in ('AC', 'AA', 'RE', 'P', 'DI', 'TE', 'A', 'R', 'V', 'PS', 'BF', 'G', 'GF', 'DT')
   and b.naturaleza is null -- = 'SAECA'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union -- Sociedad Empresas por Acciones Simplificadas EAS--VAE BSEVOCORE-901-902
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
       (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        e.descripcion,
        (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
          and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
         where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo = 'S'
   and b.naturaleza = 'EAS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
union
select a.cod_persona,
       a.nom_completo,
       a.nro_documento,
       bau.nombre,
       bab.descripcion,
       ge.cod_oficina,
       b.naturaleza,
        (select bc.significado
          from ba_cod_referencias bc
         where bc.dominio = 'TIP_NATURALEZA'
           and bc.val_minimo = b.naturaleza),
       (select decode(ba.ind_acc_portador, 'S', 'AL_PORTADOR', 'N', 'NOMINATIVA', null)
         from ba_acc_portador ba
        where ba.cod_persona = a.cod_persona),
       (select aa.cod_pais
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo
          )cod_pais,
       (select aa.cod_tip_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select aa.nro_documento
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
        e.descripcion,
       (select aa.nom_completo
         from ba_personas aa
        where aa.cod_persona = d.cod_per_vinculo),
       (select ca.val_parametro
          from ba_per_dat_adicionales ca
         where ca.cod_persona = d.cod_per_vinculo
           and parametro like '%POR_PARTICIPACION%'
           and rownum = 1),
       (select bp.nacionalidad
          from ba_paises bp, ba_personas be
         where be.cod_persona = d.cod_per_vinculo
           and be.cod_pais = bp.cod_pais),
        (select dd.direccion
           from ba_direcciones dd
          where dd.cod_persona = d.cod_per_vinculo
            and dd.principal = 'S') ,
        (select ab.dir_correo
           from ba_personas ab
          where ab.cod_persona = d.cod_per_vinculo)
  from ba_personas a,
       ba_per_juridicas b,
       ba_acc_portador c,
       ba_vinculos d,
       ba_tip_vinculos e,
       ge_clientes ge,
       ba_oficinas bab,
       ba_usuarios bau
where a.cod_persona = b.cod_persona
   and b.cod_persona = c.cod_persona(+)
   and b.cod_persona = d.cod_persona
   and d.tipo = e.cod_tip_vinculo
   and d.cod_persona = ge.cod_persona(+)
   and ge.cod_oficina = bab.cod_oficina
   and ge.cod_usu_oficial = bau.cod_usuario
   and e.cod_tip_vinculo != 'S'
   and b.naturaleza = 'EAS'
   and exists (select 1
                 from ba_personas pp,
                      ba_per_juridicas jj,
                      ge_cta_clientes ccc,
                      ge_cuentas ce,
                      ge_est_cuentas eee
                where pp.cod_persona = ccc.cod_persona
                  and pp.cod_persona = jj.cod_persona
                  and ccc.relacion = 'P'
                  and ccc.nro_cuenta = ce.nro_cuenta
                  and ce.cod_modulo = eee.cod_modulo
                  and ce.cod_modalidad = eee.cod_modalidad
                  and ce.estado = eee.estado
                  and eee.activo = 'S'
                  and pp.tipo = 'J'
                  and pp.cod_persona = d.cod_persona)
order by 4 desc
;

