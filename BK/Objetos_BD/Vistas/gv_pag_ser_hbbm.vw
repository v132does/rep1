CREATE OR REPLACE FORCE VIEW IT.GV_PAG_SER_HBBM AS
select 'CAJERO HOME BANKING' caja,
 999 nro_caja,
 c.cod_persona,
 p.nom_completo,
 p.nro_documento,
 u.nombre nom_gestor,
 FUE_OBT_SIG_REFCODES('TIP_PERSONA', p.tipo) tipo_persona,
 s.fecha
 from bw_pag_servicios s, ge_cta_clientes cc, ge_clientes c, ba_personas p, ba_usuarios u
 where s.nro_cuenta = cc.nro_cuenta
 and cc.relacion = 'P'
 and cc.cod_persona = c.cod_persona
 and p.cod_persona = c.cod_persona
 and u.cod_usuario = c.cod_usu_oficial
 and s.cod_ws_servicios is null
 and s.reversado = 'N' --Operaciones exitosas
UNION ALL
select decode(bw.nro_caja, 999,'CAJERO HOME BANKING','CAJERO BANCA MOVIL') caja, bw.nro_caja nro_caja,
 c.cod_persona,
 p.nom_completo,
 p.nro_documento,
 u.nombre nom_gestor,
 FUE_OBT_SIG_REFCODES('TIP_PERSONA', p.tipo) tipo_persona,
 s.fecha
 from bw_pag_servicios s, ge_cta_clientes cc,  ge_clientes c,  ba_personas p,  /*ba_cod_referencias cr,*/ ba_usuarios u, bw_movimientos bw
 where s.nro_cuenta = cc.nro_cuenta
 and cc.relacion = 'P'
 and cc.cod_persona = c.cod_persona
 and p.cod_persona = c.cod_persona
 and u.cod_usuario = c.cod_usu_oficial
 and trunc(bw.fec_hora) = s.fecha
 and bw.cod_tip_mensaje = '088'
 and bw.nro_documento = s.nro_documento
 and s.cod_ws_servicios is not null --Operaciones exitosas
 and s.reversado = 'N'
 union all
 --Transferencias Interbancarias
 select  decode(bw.nro_caja,'999','CAJERO HOME BANKING', '994','CAJERO BANCA MOVIL','CAJERO HOME BANKING') "Canal",
 bw.nro_caja,
 t.cod_per_solicitante cod_persona,
 t.nom_solicitante nom_completo,
 t.nro_doc_solicitante nro_documento,
 u.nombre nom_gestor,
 decode(p.tipo, 'F', 'Persona Física', 'J', 'Persona Jurídica', p.tipo) tip_persona,
 t.fecha
 from (select t.*
  from cc_movimientos_his cc, ge_snp_transferencias t
 where cc.fecha = t.fecha
   and cc.hora = t.hora
   and cc.cod_usuario = t.cod_usuario
   and t.nro_referencia = cc.nro_documento
   and cc.reversado = 'N'
   and cc.cod_modalidad = 41
   and t.nro_ref_externa is null
   and t.fec_recepcion is null
   and (t.cod_usuario='HBANK' or t.usu_insercion = 'HBANK')
union all
select t.*
  from ah_movimientos_his ah, ge_snp_transferencias t
 where ah.fecha = t.fecha
   and ah.hora = t.hora
   and ah.cod_usuario = t.cod_usuario
   and ah.nro_documento = t.nro_referencia
   and ah.reversado = 'N'
   and ah.cod_modalidad = 31
   and t.nro_ref_externa is null
   and t.fec_recepcion is null
   and (t.cod_usuario='HBANK' or t.usu_insercion = 'HBANK')) t, bw_movimientos bw,
 gv_snp_participantes w,
 ba_personas p,
 ge_clientes c ,
 ba_usuarios u
 where t.cod_swi_pte_beneficiario = w.cod_swift
 and t.cod_per_solicitante = p.cod_persona
 and p.cod_persona = c.cod_persona
 and c.cod_usu_oficial = u.cod_usuario
 and (t.cod_usuario = 'HBANK' or t.usu_insercion ='HBANK')
 and t.nro_ref_externa is null
 and t.fec_recepcion is null
 and t.nro_referencia = bw.dato3(+)
 and trunc(bw.fec_hora) = trunc(t.fec_insercion)
 and bw.cod_tip_mensaje = '036'
 UNION ALL
 --Solicitud de chequeras
 select 'CAJERO HOME BANKING' caja,
       999 nro_caja,
       cod_persona,
       nom_completo,
       nro_documento,
       fug_obt_gestor(COD_persona) "NOM_GESTOR",
       FUE_OBT_SIG_REFCODES('TIP_PERSONA', tipo) tipo_persona,
       fecha
from (select   b.cod_persona,
               fue_obt_nom_persona(b.cod_persona)"NOM_COMPLETO",
               ba.nro_documento,
               a.fecha,
               ba.tipo
          from cc_sol_chequeras   a,
               ge_cta_clientes    b,
               cc_chequeras       c,
               cc_tip_chequeras   d,
               ba_personas        ba,
               --ba_cod_referencias bc,
               ba_tip_documentos  bt
         where a.nro_cuenta = b.nro_cuenta
           and b.relacion = 'P'
           and c.nro_cuenta(+) = a.nro_cuenta
           and ba.cod_tip_documento = bt.cod_tip_documento
           and c.cod_ofi_retiro(+) = a.cod_ofi_retiro
           and c.tipo(+) = a.cod_tip_chequera
           and c.fec_solicitud(+) = a.fecha
           and c.hor_solicitud(+) = a.hora
           and d.cod_tip_chequera = a.cod_tip_chequera
           and ba.cod_persona = b.cod_persona
          -- and bc.dominio = 'TIP_PERSONA'
           and b.cod_modulo in ('3','4')
          --and bc.val_minimo = ba.tipo
           and (a.cod_usuario = 'HBANK' OR a.usu_insercion = 'HBANK'))
UNION ALL
--Pago a proveedvores
SELECT 'CAJERO HOME BANKING' caja,
       999 nro_caja,
       cod_persona,
       nom_completo,
       nro_documento,
       fug_obt_gestor(COD_persona) "NOM_GESTOR",
       tipo_persona,
       fecha
  FROM (SELECT B.COD_PERSONA,
               fue_obt_nom_persona(b.cod_persona) nom_completo,
               fue_obt_nro_doc_persona(b.cod_persona) nro_documento,
               'Persona Jurídica' tipo_persona,
               TRUNC(A.FEC_PAGO) FECHA
          FROM GE_PAG_PROVEEDORES A, GE_ENTES B
         WHERE A.COD_ENTE = B.COD_ENTE
           AND A.ESTADO = 'N'
           AND a.usu_insercion = 'HBANK'
         ORDER BY 1, 3)
UNION ALL
--Compra y venta de divisas
select 'CAJERO HOME BANKING' caja,
       999 nro_caja,
       bp2.cod_persona cod_persona,
       bp2.nom_completo nom_completo,
       bp2.nro_documento nro_documento,
       fug_obt_gestor(bp2.cod_persona) "NOM_GESTOR",
       decode(bp2.tipo,
              'F',
              'Persona Física',
              'J',
              'Persona Jurídica',
              bp2.tipo) tip_persona,
       lm2.fecha fecha
  from cc_movimientos_his lm2, ba_personas bp2
 where fug_obt_cli_principal(lm2.nro_cuenta) = bp2.cod_persona
   and lm2.cod_mad_padre = 91
   and lm2.COD_MOD_PADRE = 9
   and lm2.cod_tra_padre = 388
   and lm2.reversado = 'N'
   and lm2.estado = 'N'
   and lm2.cod_moneda != 'GS'
   and (((SELECT COUNT(*)
            FROM AH_MOVIMIENTOS_HIS AM
           WHERE lm2.FECHA = AM.FECHA
             AND lm2.HORA = AM.HORA
             AND lm2.COD_USUARIO = AM.COD_USUARIO
             AND lm2.NRO_DOCUMENTO = AM.NRO_DOCUMENTO
             AND lm2.COD_MONEDA != AM.COD_MONEDA) > 0) OR
        ((SELECT COUNT(*)
            FROM CC_MOVIMIENTOS_HIS CM
           WHERE lm2.FECHA = CM.FECHA
             AND lm2.HORA = CM.HORA
             AND lm2.COD_USUARIO = CM.COD_USUARIO
             AND lm2.NRO_DOCUMENTO = CM.NRO_DOCUMENTO
             AND lm2.COD_MONEDA != CM.COD_MONEDA) > 0))
 group by bp2.cod_persona,
          bp2.nom_completo,
          bp2.nro_documento,
          bp2.tipo,
          lm2.fecha
union all
select 'CAJERO HOME BANKING' caja,
       999 nro_caja,
       bp2.cod_persona cod_persona,
       bp2.nom_completo nom_completo,
       bp2.nro_documento nro_documento,
       fug_obt_gestor(bp2.cod_persona) "NOM_GESTOR",
       decode(bp2.tipo,
              'F',
              'Persona Física',
              'J',
              'Persona Jurídica',
              bp2.tipo) tip_persona,
       lm2.fecha fecha
  from ah_movimientos_his lm2, ba_personas bp2
 where fug_obt_cli_principal(lm2.nro_cuenta) = bp2.cod_persona
   and lm2.cod_mad_padre = 91
   and lm2.COD_MOD_PADRE = 9
   and lm2.cod_tra_padre = 388
   and lm2.reversado = 'N'
   and lm2.estado = 'N'
   and lm2.cod_moneda != 'GS'
   and (((SELECT COUNT(*)
            FROM AH_MOVIMIENTOS_HIS AM
           WHERE lm2.FECHA = AM.FECHA
             AND lm2.HORA = AM.HORA
             AND lm2.COD_USUARIO = AM.COD_USUARIO
             AND lm2.NRO_DOCUMENTO = AM.NRO_DOCUMENTO
             AND lm2.COD_MONEDA != AM.COD_MONEDA) > 0) OR
        ((SELECT COUNT(*)
            FROM CC_MOVIMIENTOS_HIS CM
           WHERE lm2.FECHA = CM.FECHA
             AND lm2.HORA = CM.HORA
             AND lm2.COD_USUARIO = CM.COD_USUARIO
             AND lm2.NRO_DOCUMENTO = CM.NRO_DOCUMENTO
             AND lm2.COD_MONEDA != CM.COD_MONEDA) > 0))
 group by bp2.cod_persona,
          bp2.nom_completo,
          bp2.nro_documento,
          bp2.tipo,
          lm2.fecha
;

