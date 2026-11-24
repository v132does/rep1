CREATE OR REPLACE FORCE VIEW IT.GV_CON_SEG_PRODUCTIVIDAD AS
SELECT linpre.cod_persona as Cod_Persona, --1
         linpre.nombre as Nombre,--2
         linpre.cod_usu_oficial ,--3
         linpre.usu_oficial as Gestor, --4
         to_number(linpre.ofi_gestor) as Ofi_Gestor,--5
         linpre.tipo descrip_prod_modalidad, --6
         'LINEAS DE CREDITOS' reporte,--6.1
         null nro_cuenta,--7
         linpre.cod_moneda as Cod_Moneda,--8
         linpre.monto as Monto,--9
         linpre.fec_aprobacion as Fec_Apertura, --10
         null estado,--1G
         null nro_Desembols,--12
         null cod_ente,--13
         null des_ente,--14
         null detalle_canal,--15
         null cod_campana,--16
         null nom_campana,--17
         null promotor,
         null cod_usu_promotor,
         null tipo_paquete,
         linpre.usu_insercion,
         linpre.mto_capital,
         decode(linpre.cod_moneda,'GS',linpre.monto, nvl(fug_obt_cotizacion(linpre.cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * linpre.monto) monto_guaranizado,
         decode(linpre.cod_moneda,'GS',linpre.mto_capital, nvl(fug_obt_cotizacion(linpre.cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * linpre.mto_capital) cap_guaranizado,
         null tot_desembolso
    FROM bv_lin_pr_aprobadas linpre
   WHERE fug_es_empleado(linpre.cod_persona) = 'N'
     AND linpre.tipo = 'LINEA DE CREDITO'
UNION ALL
--COMEX (SEG_COMEX)
select cc.cod_persona cod_persona,--1
       p.nom_completo nom_completo,--2
       u.cod_usuario cod_gestor,--3
       u.nombre nom_gestor,--4
       to_number(u.cod_oficina) ofi_gestor,--5
       fug_obt_des_modalidad(x.cod_modalidad) descrip_prod_modalidad,--6
       'COMEX' reporte,--6.1
       x.nro_cuenta nro_cuenta,--7
       cod_moneda moneda,--8
       mto_original monto,--9
       ---este
       fec_aprobacion ,--10
       fug_obt_des_est_cta(x.cod_modulo, x.cod_modalidad, x.estado) estado,--11
       null nro_Desembols,--12
       null cod_ente,--13
       null des_ente,--14
       null detalle_canal,--15
       null cod_campana,--16
       null nom_campana,--17
       null promotor,
       null cod_usu_promotor,
       null tipo_paquete,
       x.usu_insercion,
       null mto_capital,
       decode(cod_moneda,'GS',mto_original, nvl(fug_obt_cotizacion(cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * mto_original) monto_guaranizado,
       null cap_guaranizado,
       null tot_desembolso
  from cx_cta_importaciones x,
       ge_cta_clientes cc,
       ba_personas p,
       ge_clientes c,
       ba_usuarios u,
       ge_bancas   b
 where x.nro_cuenta      = cc.nro_cuenta
   and 'P'               = cc.relacion
   and cc.cod_persona    = p.cod_persona
   and p.cod_persona     = c.cod_persona
   and c.cod_usu_oficial = u.cod_usuario
   and u.cod_banca       = b.cod_banca (+)
   and mto_original      is not null
union all
select cod_per_beneficiario,--1
       p.nom_completo,--2
       u.cod_usuario cod_gestor,--3
       u.nombre,--4
       to_number(u.cod_oficina),--5
       fug_obt_des_modalidad(x.cod_modalidad) descrip_prod_modalidad,--6
       'COMEX' reporte,--6.1
       nro_cuenta,--7
       cod_moneda,--8
       mto_original,--9
       fec_aprobacion,--10
       fug_obt_des_est_cta(x.cod_modulo, x.cod_modalidad, x.estado) estado, --11
       null nro_Desembols,--12
       null cod_ente,--13
       null des_ente,--14
       null detalle_canal,--15
       null cod_campana,--16
       null nom_campana,--17
       null promotor,
       null cod_usu_promotor,
       null tipo_paquete,
       x.usu_insercion,
       null mto_capital,
       decode(cod_moneda,'GS',mto_original, nvl(fug_obt_cotizacion(cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * mto_original) monto_guaranizado,
       null cap_guaranizado,
       null tot_desembolso
  from cx_cta_exportaciones x,
       ba_personas p,
       ge_clientes c,
       ba_usuarios u,
       ge_bancas   b
 where x.cod_per_beneficiario = p.cod_persona
   and p.cod_persona           = c.cod_persona
   and c.cod_usu_oficial       = u.cod_usuario
   and u.cod_banca             = b.cod_banca (+)
   and mto_original            is not null
union all
select cod_per_solicitante,--1
       p.nom_completo,--2
       u.cod_usuario cod_gestor,--3
       u.nombre,--4
       to_number(u.cod_oficina),--5
       fug_obt_des_modalidad(x.cod_modalidad) descrip_prod_modalidad,--6
       'COMEX' reporte,
       nro_cuenta, --7
       cod_moneda,--8
       monto,--9
       fec_concesion,--10
       fug_obt_des_est_cta(x.cod_modulo, x.cod_modalidad, x.estado) estado, --11
       null nro_Desembols,--12
       null cod_ente,--13
       null des_ente,--14
       null detalle_canal,--15
       null cod_campana,--16
       null nom_campana,--17
       null promotor,
       null cod_usu_promotor,
       null tipo_paquete,
       x.usu_insercion,
       null mto_capital,
       decode(cod_moneda,'GS',monto, nvl(fug_obt_cotizacion(cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * monto) monto_guaranizado,
       null cap_guaranizado,
       null tot_desembolso
  from cx_fianzas x,
       ba_personas p,
       ge_clientes c,
       ba_usuarios u,
       ge_bancas   b
 where x.cod_per_solicitante = p.cod_persona
   and p.cod_persona         = c.cod_persona
   and c.cod_usu_oficial     = u.cod_usuario
   and u.cod_banca           = b.cod_banca (+)
   and monto                 is not null
union all
select p.cod_persona,--1
       p.nom_completo,--2
       u.cod_usuario cod_gestor,--3
       u.nombre,--4
       to_number(u.cod_oficina),--5
       fug_obt_des_modalidad(x.cod_modalidad) descrip_prod_modalidad,--6
       'COMEX' reporte,
       nro_cuenta,--7
       cod_moneda,--8
       monto,--9
       fec_aprobacion,--10
       fug_obt_des_est_cta(x.cod_modulo, x.cod_modalidad, x.estado) estado, --11
       null nro_Desembols,--12
       null cod_ente,--13
       null des_ente,--14
       null detalle_canal,--15
       null cod_campana,--16
       null nom_campana,--17
       null promotor,
       null cod_usu_promotor,
       null tipo_paquete,
       x.usu_insercion,
       null mto_capital,
       decode(cod_moneda,'GS',monto, nvl(fug_obt_cotizacion(cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * monto) monto_guaranizado,
       null cap_guaranizado,
       null tot_desembolso
  from cx_cta_cobranzas x,
       ba_personas p,
       ge_clientes c,
       ba_usuarios u,
       ge_bancas   b
 where p.cod_persona     = decode(x.cod_modalidad, '83', x.cod_per_pagador, '84', x.cod_per_beneficiario)
   and p.cod_persona     = c.cod_persona
   and c.cod_usu_oficial = u.cod_usuario
   and u.cod_banca       = b.cod_banca (+)
   and monto             is not null

UNION ALL

--SEGUIMIENTO DE CAJAS DE AHORRO Y CUENTAS CORRIENTES(SEG_CC_AH)
select x.cod_persona,--1
       x.denominacion,--2/*ok*/
       x.gestor,--3/*OK*/
       x.nom_gestor,--4/*OK*/
       to_number(x.ofi_gestor),--5/*OK*/
       x.des_modalidad,--6/*OK*/
       'PASIVOS' reporte,--6.1
       x.nro_cuenta,--7/*OK*/
       x.cod_moneda,--8/*OK*/
       x.saldo,--9/*OK*/
       x.fec_apertura,--10/*OK*/
       x.des_estado,--11/*OK*/
       null nro_Desembols,--12
       x.cod_ente,--13/*OK*/
       x.des_ente,--14/*OK*/
       x.detalle_canal,--15
       x.cod_campana,--16
       x.nom_campana,--17
       x.promotor,
       x.cod_usu_promotor,
       null tipo_paquete,
       x.usu_insercion,
       null mto_capital,
       decode(x.cod_moneda,'GS',saldo, nvl(fug_obt_cotizacion(x.cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * saldo) monto_guaranizado,
       null cap_guaranizado,
       null tot_desembolso
 from
(
select b.cod_persona,
       a.nro_cuenta,
       a.denominacion,
       a.cod_moneda,
       a.sal_total - a.sal_bloqueado - a.sal_retenido as saldo,
       fug_obt_des_modalidad(a.cod_modalidad) as des_modalidad,
       a.fec_apertura,
       fug_obt_des_est_cta(a.cod_modulo, a.cod_modalidad, a.estado) as des_estado,
       fug_obt_cod_usu_oficial(b.cod_persona) as gestor,
       fue_obt_nom_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) as nom_gestor,
       fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) as ofi_gestor,
       to_char(a.cod_ente) as cod_ente,
       fue_obt_nom_ente(a.cod_ente) des_ente,
       fug_obt_des_canal(a.cod_canal) detalle_canal,
       a.cod_campana,
       cr.descripcion nom_campana,
       decode(a.cod_usu_promotor,null,null,fue_obt_nom_usuario(a.cod_usu_promotor)) promotor,
       a.cod_usu_promotor,
       a.usu_insercion,null mto_capital
  from ah_cta_vistas a, ge_cta_clientes b, ba_personas c, cr_campanas cr
 where a.nro_cuenta = b.nro_cuenta
   and b.cod_persona = c.cod_persona
   and b.relacion = 'P'
   and a.cod_campana = cr.cod_campana (+)
   union all
   select b.cod_persona,
       aa.nro_cuenta,
       aa.denominacion,
       aa.cod_moneda,
       aa.sal_total - aa.sal_bloqueado - aa.sal_retenido as saldo,
       fug_obt_des_modalidad(aa.cod_modalidad) as des_modalidad,
       aa.fec_apertura,
       fug_obt_des_est_cta(aa.cod_modulo, aa.cod_modalidad, aa.estado) as des_estado,
       fug_obt_cod_usu_oficial(b.cod_persona) as gestor,
       fue_obt_nom_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) as nom_gestor,
       fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) as ofi_gestor,
       to_char(aa.cod_ente) as cod_ente,
       fue_obt_nom_ente(aa.cod_ente) des_ente,
       fug_obt_des_canal(aa.cod_canal) detalle_canal,
       aa.cod_campana,
       cr.descripcion nom_campana,
       decode(aa.cod_usu_promotor,null,null,fue_obt_nom_usuario(aa.cod_usu_promotor)) promotor,
       aa.cod_usu_promotor,
       aa.usu_insercion,null mto_capital
  from cc_cta_corrientes aa, ge_cta_clientes b, ba_personas c, cr_campanas cr
 where aa.nro_cuenta = b.nro_cuenta
   and b.cod_persona = c.cod_persona
   and b.relacion = 'P'
   and aa.cod_campana = cr.cod_campana (+)
  union all
  select b.cod_persona,
       a.nro_cuenta,
       a.denominacion,
       a.cod_moneda,
       a.sal_total - a.sal_bloqueado - a.sal_retenido as saldo,
       fug_obt_des_modalidad(a.cod_modalidad) as des_modalidad,
       a.fec_apertura,
       fug_obt_des_est_cta(a.cod_modulo, a.cod_modalidad, a.estado) as des_estado,
       fug_obt_cod_usu_oficial(b.cod_persona) as gestor,
       fue_obt_nom_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) as nom_gestor,
       fug_obt_ofi_usuario(fug_obt_cod_usu_oficial(b.cod_persona)) as ofi_gestor,
       to_char('') as cod_ente,
       to_char('') des_ente,
       fug_obt_des_canal(a.cod_canal) detalle_canal,
       a.cod_campana,
       cr.descripcion nom_campana,
       decode(a.cod_usu_promotor,null,null,fue_obt_nom_usuario(a.cod_usu_promotor)) promotor,
       a.cod_usu_promotor,
       a.usu_insercion,null mto_capital
  from ah_cta_certificados a, ge_cta_clientes b, ba_personas c, cr_campanas cr
 where a.nro_cuenta = b.nro_cuenta
   and b.cod_persona = c.cod_persona
    and b.relacion = 'P'
    and a.cod_campana = cr.cod_campana (+)
   ) x

UNION ALL
--ACTIVOS (SEG_PRES)
Select o.descripcion_cliente,--1
       o.nom_cliente,--2
        o.Cod_gestor,--3
       o.Gestor,--4
       o.cod_oficina_gestor,--Oficina_Gestor,--5
       fug_obt_des_modalidad(o.cod_modalidad) descrip_prod_modalidad,--6
       'ACTIVOS' reporte,--6.1
       o.nro_cuenta,--7
       o.cod_moneda,--8
       o.monto,--9
       To_date(to_char(o.fec_inicio,'dd/mm/yyyy'),'dd/mm/yyyy'), --10
       o.estado_cuenta,--11
       o.Nro_Desembolso,--12
       null cod_ente,--13
       null des_ente,--14
       o.canal_Cuenta detalle_canal,--15
       o.cod_campana,--16
       o.nom_campana,--17
       decode(o.cod_usu_promotor,null,null,fue_obt_nom_usuario(o.cod_usu_promotor)) promotor,
       o.cod_usu_promotor,
       null tipo_paquete,
       o.usu_insercion,
       o.mto_capital,
       decode(o.cod_moneda,'GS',monto, nvl(fug_obt_cotizacion(o.cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * monto) monto_guaranizado,
       decode(o.cod_moneda,'GS',mto_capital, nvl(fug_obt_cotizacion(o.cod_moneda, pag_cal.fu_obt_fec_actual(1)),0) * mto_capital) cap_guaranizado,
       o.tot_prestamo
  from (select c.cod_persona as Descripcion_Cliente,
               fue_obt_nom_persona(c.cod_persona) nom_cliente,
               a.nro_cuenta, a.cod_modalidad,
               fup_obt_nro_desembolso(C.cod_persona, A.nro_cuenta) As Nro_Desembolso,
               a.cod_moneda,
               c.monto, c.fec_inicio,
               case when a.estado = 'N' then 'Cancelada'
                 when a.estado = 'C' then 'Vigente'
                 when a.estado = 'G' then 'En gestion'
                 when A.estado = 'I' then 'Incobrable'
                 when a.estado = 'M' then 'Morosa'
                 when a.estado = 'V' then 'Vencida'
               end as estado_cuenta,
               e.cod_usu_oficial as Cod_gestor,
               p.nombre as Gestor,
               p.cod_oficina as cod_oficina_gestor,
               fue_obt_des_oficina(p.cod_oficina) as Oficina_Gestor,
               a.cod_canal,
               fug_obt_des_canal(c.cod_canal)  as canal_Cuenta,
               a.cod_campana,
               nvl(fug_obt_nom_campana(a.cod_campana), fug_obt_des_campana(a.cod_campana)) as Nom_campana,
               a.usu_insercion,
               a.mto_capital,
               (select x.tot_prestamo from pr_solicitudes x where x.nro_solicitud = c.nro_sol_original and nvl(x.en_etapas,'')='S') tot_prestamo,
               c.cod_usu_promotor
          from pr_cta_prestamos a,
               pr_solicitudes   c,
               ge_clientes      e,
               ge_cuentas  t,
               ba_usuarios p,
               Ba_Personas x
         where a.nro_solicitud (+) = c.nro_solicitud
         and a.nro_cuenta = t.nro_cuenta
           and e.cod_persona  = fug_obt_cli_principal(a.nro_cuenta)
           and e.cod_usu_oficial = p.cod_usuario
           And E.cod_Persona = X.cod_persona
          And E.cod_Usu_Oficial <> 'RRHH') o

UNION ALL
--PAQUETES (SEG_PAQ)
select a.cod_persona as cod_persona,--1
       fue_obt_nom_persona(a.cod_persona) as nombre,--2
       c.cod_usu_oficial as cod_gestor, --3
       fue_obt_nom_usuario(c.cod_usu_oficial) as nombre_gestor,--4
       fug_obt_ofi_oficial(a.cod_persona) as ofi_gestor,--5
       'PAQUETES' descrip_prod_modalidad,--6
       'PAQUETES' reporte,--6
       null nro_cuenta, --7
       b.cod_moneda, --8
       null monto,--9
       a.fec_inicio as fec_inicio,--10
       a.estado as estado,--11
       null nro_Desembolso,--12
       null cod_ente,--13
       null des_ente,--14
       null detalle_canal,--15
       null cod_campana,--16
       null nom_campana,--17
       null promotor,
       null cod_usu_promotor,
       b.descripcion tipo_paquete,
       a.usu_insercion,
       null mto_capital,
       null mto_guaranizado,
       null cap_guaranizado,
       null tot_desembolso
  from ge_paq_clientes a, ge_paquetes b, ge_clientes c
 where a.cod_paquete = b.cod_paquete
   and a.cod_persona = c.cod_persona
;

