CREATE OR REPLACE FORCE VIEW IT.GV_OPE_DIVISAS AS
SELECT GV_MOVIMIENTOS.FECHA as FECHA,
       substr(GV_MOVIMIENTOS.HORA, 1, 5) AS HORA,
       case
         when cliente.tipo = 'F' then
           (select trim(pf.pri_nombre || ' ' || pf.seg_nombre)
              from ba_per_fisicas pf
             where pf.cod_persona = cliente.cod_persona)
         when cliente.tipo = 'J' then
           cliente.nombre
         when (select 1
                 from ge_clientes gc
                where gc.cod_persona = cliente.COD_PERSONA) is null then
           gv_movimientos.CONCEPTO
       end as nombre_cliente,
       case
         when cliente.tipo = 'F' then
           (select trim(pf.pri_apellido || ' ' || pf.seg_apellido)
              from ba_per_fisicas pf
             where pf.cod_persona = cliente.cod_persona)
         when cliente.tipo = 'J' then
           null
       end as apellido_cliente,
       case when cliente.DOC_PERSONA is not null then
         cliente.DOC_PERSONA
       else
         (select distinct gvmov.REFERENCIA
          from gv_movimientos gvmov
         where gvmov.FECHA = gv_movimientos.fecha
           and gvmov.HORA = gv_movimientos.hora
           and gvmov.COD_USUARIO = gv_movimientos.cod_usuario
           and gvmov.NRO_SECUENCIA = 2
           and gvmov.REFERENCIA is not null
           and rownum <= 1)
        end AS NRO_DOCUMENTO,
       fue_obt_tip_doc_abreviatura(cliente.cod_tip_documento) AS TIPO_DOCUMENTO,
       decode(cliente.tipo,'F','Física','J','Jurídica') AS PERSONA,
       case
         when (select 1
                 from ge_clientes gc
                where gc.cod_persona = cliente.COD_PERSONA) is not null then
          'Establecido'
         when (select 1
                 from ge_clientes gc
                where gc.cod_persona = cliente.COD_PERSONA) is null then
          'Ocasional'
         else
          null
       end as TIPO_DE_CLIENTE,
       pai.cod_pai_iso AS NACIONALIDAD,
       fue_obt_des_oficina(gv_movimientos.cod_ofi_origen) SUCURSAL,
       depa.descripcion ZONA_GEOGRAFICA,
       moda.descripcion TIP_OPERACION,
       LC_TIP_OPERACIONES.DESCRIPCION MODALIDAD,
       ---
       CASE
         WHEN (GV_MOVIMIENTOS.COD_MAD_PADRE = 71) OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 71) THEN
          GV_MOVIMIENTOS.MONTO
         WHEN GV_MOVIMIENTOS.COD_MAD_PADRE = 72 OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 72) THEN
          (select sum(monto)
             from gv_movimientos m
            where m.FECHA = gv_movimientos.FECHA
              and m.hora = gv_movimientos.hora
              and m.COD_USUARIO = gv_movimientos.cod_usuario
              and m.NRO_SECUENCIA <> gv_movimientos.nro_secuencia
              and m.cod_tip_ope_cambio is not null
              and m.MONTO is not null)

       END MONTO_RECIBIDO,
       --
       CASE
         WHEN GV_MOVIMIENTOS.COD_MAD_PADRE = 71 OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 71) THEN
          GV_MOVIMIENTOS.COD_MONEDA
         WHEN GV_MOVIMIENTOS.COD_MAD_PADRE = 72 OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 72) THEN
          (select distinct cod_moneda
             from gv_movimientos m
            where m.FECHA = gv_movimientos.FECHA
              and m.hora = gv_movimientos.hora
              and m.COD_USUARIO = gv_movimientos.cod_usuario
              and m.NRO_SECUENCIA <> gv_movimientos.nro_secuencia
              and m.cod_tip_ope_cambio is not null
              and m.MONTO is not null)
       END MONEDA_RECIBIDA,
       ---

       CASE
         WHEN GV_MOVIMIENTOS.COD_MAD_PADRE = 71 OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 71) THEN

          (select nvl(sum(monto),
                      sum(gv_movimientos.monto * gv_movimientos.cotizacion))
             from gv_movimientos m
            where m.FECHA = gv_movimientos.FECHA
              and m.hora = gv_movimientos.hora
              and m.COD_USUARIO = gv_movimientos.cod_usuario
              and m.NRO_SECUENCIA <> gv_movimientos.nro_secuencia
              and m.cod_tra_padre = gv_movimientos.cod_tra_padre
              and m.cod_transaccion <> 760
              and m.MONTO is not null)
         WHEN GV_MOVIMIENTOS.COD_MAD_PADRE = 72 OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 72) THEN
          GV_MOVIMIENTOS.MONTO
       END MONTO_ENTREGADO,
       ---
       CASE
         WHEN GV_MOVIMIENTOS.COD_MAD_PADRE = 71 OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 71) THEN
          (select distinct cod_moneda
             from gv_movimientos m
            where m.FECHA = gv_movimientos.FECHA
              and m.hora = gv_movimientos.hora
              and m.COD_USUARIO = gv_movimientos.cod_usuario
              and m.NRO_SECUENCIA <> gv_movimientos.nro_secuencia
              and m.cod_tra_padre = gv_movimientos.cod_tra_padre
              and m.cod_transaccion <> 760
              and m.MONTO is not null)
         WHEN GV_MOVIMIENTOS.COD_MAD_PADRE = 72 OR
              (GV_MOVIMIENTOS.COD_MAD_PADRE = 73 AND
              GV_MOVIMIENTOS.COD_MODALIDAD = 72) THEN
          GV_MOVIMIENTOS.COD_MONEDA
       END MONEDA_ENTREGADA
-----
  FROM BA_MONEDAS,
       Gv_MOVIMIENTOS GV_MOVIMIENTOS,
       LC_TIP_OPERACIONES,
       (select GV_MOVIMIENTOS.nro_documento,
               GV_MOVIMIENTOS.nro_documento2 nro_doc,
               GV_MOVIMIENTOS.fecha,
               GV_MOVIMIENTOS.hora,
               GV_MOVIMIENTOS.cod_usuario,
               ba_personas.cod_persona,
               nvl(ba_personas.nom_completo, gv_movimientos.concepto) nombre,
               nvl(ba_personas.nro_documento, gv_movimientos.referencia) DOC_PERSONA,
               ba_personas.cod_tip_documento,
               ba_personas.tipo,
               ba_personas.cod_pais
          from ba_personas, Gv_MOVIMIENTOS GV_MOVIMIENTOS
         where ba_personas.cod_persona != '11198'
		   and decode(gv_movimientos.cod_mad_padre,
                      76,
                      gv_movimientos.cod_persona,
                      nvl(to_char(GV_MOVIMIENTOS.nro_documento2),
                          gv_movimientos.cod_persona)) =
               ba_personas.cod_persona(+)
           and GV_MOVIMIENTOS.cod_transaccion = 760
           and GV_MOVIMIENTOS.COD_MOD_PADRE = 7
           and GV_MOVIMIENTOS.reversado = 'N') cliente,
       ba_oficinas ofi,
       ba_ciudades ciu,
       ge_modalidades moda,
       ba_departamentos depa,
       ba_paises pai

 WHERE BA_MONEDAS.COD_MONEDA = GV_MOVIMIENTOS.COD_MONEDA
   AND ((GV_MOVIMIENTOS.COD_MAD_PADRE IN (71, 72) AND
       GV_MOVIMIENTOS.NRO_SECUENCIA = 1 AND
       gv_movimientos.cod_ref_cambio <> 76) OR --forward
       (gv_movimientos.cod_mad_padre = 76 AND
       gv_movimientos.nro_secuencia = 1) OR --arbitraje
       (GV_MOVIMIENTOS.COD_MAD_PADRE IN (73) AND
       GV_MOVIMIENTOS.NRO_SECUENCIA = 1 /*IN (1,2)*/
       ))
   AND GV_MOVIMIENTOS.MONTO > 0
   AND GV_MOVIMIENTOS.COTIZACION IS NOT NULL
   AND GV_MOVIMIENTOS.MTO_EQU_LOCAL IS NOT NULL
   and cliente.fecha(+) = GV_MOVIMIENTOS.fecha
   and cliente.cod_usuario(+) = GV_MOVIMIENTOS.cod_usuario
   and cliente.hora(+) = GV_MOVIMIENTOS.hora
   AND GV_MOVIMIENTOS.REVERSADO = 'N'
   AND GV_MOVIMIENTOS.COD_TIP_OPE_CAMBIO =
       LC_TIP_OPERACIONES.COD_TIP_OPERACION
   AND ((afe_posicion IN ('E', 'O') AND gv_movimientos.cod_mad_padre <> 76) OR
       (gv_movimientos.cod_mad_padre = 76))
   AND gv_movimientos.COD_MAD_PADRE <> 74
   AND (gv_movimientos.COD_PERSONA is null or gv_movimientos.COD_PERSONA != 11198)
   and (gv_movimientos.CONCEPTO not like '%AJUSTE%CAJA%')
   and pal_cam.FU_CON_MON_A_MONEDA(GV_MOVIMIENTOS.COD_MONEDA,
                                   'USD',
                                   GV_MOVIMIENTOS.MONTO) < fug_obt_pardinamico('BCP_MTO_INF_CAMBIOS')
      --
   and ofi.cod_oficina = gv_Movimientos.Cod_Ofi_Origen
   and ofi.cod_ciudad = ciu.cod_ciudad
   and ofi.cod_pais = ciu.cod_pais
   and moda.cod_modulo = gv_movimientos.cod_mod_padre
   and moda.Cod_Modalidad = gv_movimientos.cod_mad_padre
   and depa.cod_departamento = ciu.cod_departamento
   and pai.cod_pais(+) = cliente.cod_pais
union
Select a.fecha as fecha,
       substr(a.hora, 1, 5) as hora,
       case
         when b.TIPO = 'F' then
          (select aa.pri_nombre || ' ' || aa.seg_nombre
             from ba_per_fisicas aa
            where aa.cod_persona = b.COD_PERSONA)
         when b.tipo = 'J' then
          (select bb.raz_social
             from ba_per_juridicas bb
            where bb.cod_persona = b.COD_PERSONA)
         else
          null
       end nombre_cliente,
       case
         when b.TIPO = 'F' then
          (select aa.pri_apellido || ' ' || aa.seg_apellido
             from ba_per_fisicas aa
            where aa.cod_persona = b.COD_PERSONA)
         when b.tipo = 'J' then
          (select bb.nom_comercial
             from ba_per_juridicas bb
            where bb.cod_persona = b.COD_PERSONA)
         else
          null
       end apellido_cliente,

       b.nro_documento as documento,
       c.abreviatura as tip_documento,
       decode(b.TIPO, 'F', 'Fisica', 'J', 'Jurídica') as persona,
       case
         when (select 1
                 from ge_clientes gc
                where gc.cod_persona = b.COD_PERSONA) is not null then
          'Establecido'
         when (select 1
                 from ge_clientes gc
                where gc.cod_persona = b.COD_PERSONA) is null then
          'Ocacional'
         else
          null
       end as tipo_de_cliente,
       (select bp.cod_pai_iso
          from ba_paises bp
         where bp.cod_pais = b.cod_pais) Nacionalidad,
       u.descripcion as sucursal,
       e.descripcion as zona_geografica,
       decode(cod_tip_movimiento, 'D', 'Compra', 'C', 'Venta', 0) tipo_de_operacion,
       a.des_tra_padre as operacion,
       decode(cod_tip_movimiento, 'D', a.monto, mov.monto) monto_recibido,
       decode(cod_tip_movimiento, 'D', a.cod_moneda, mov.cod_moneda) moneda_recibida,
       decode(cod_tip_movimiento, 'C', a.monto, mov.monto) monto_entregado,
       decode(cod_tip_movimiento, 'C', a.cod_moneda, mov.cod_moneda) moneda_entregada
  from gv_movimientos a,
       ba_personas b,
       ba_tip_documentos c,
       lc_ope_pendientes l,
       ge_clientes i,
       ba_oficinas o,
       ba_ciudades u,
       ba_departamentos e,
       (select ah.fecha,
               ah.hora,
               ah.cod_usuario,
               ah.nro_secuencia,
               ah.monto,
               ah.cod_moneda
          from ah_movimientos_his ah
         where ah.monto is not null
           and ah.cod_mod_padre in (7, 9)
           and ah.cod_tra_padre = 388
           and ah.REVERSADO = 'N'
        union
        select cc.fecha,
               cc.hora,
               cc.cod_usuario,
               cc.nro_secuencia,
               cc.monto,
               cc.cod_moneda
          from cc_movimientos_his cc
         where cc.monto is not null
           and cc.cod_mod_padre in (7, 9)
           and cc.cod_tra_padre = 388
           and cc.REVERSADO = 'N') mov
 where a.cod_usuario in ('HOMEBANK', 'HBANK')
   and b.cod_tip_documento = c.cod_tip_documento
   and a.cod_mod_padre in (7, 9)
   and a.cod_tra_padre = 388
   and a.REVERSADO = 'N'
   and a.FECHA = l.fec_operacion
   and nvl(trim(a.cotizacion), ' ') <> ' '
   and b.cod_persona = fug_obt_cli_principal(a.NRO_CUENTA)
   and a.COD_USU_REVERSION is null
   and a.COD_TIP_MOVIMIENTO in ('C', 'D')
   and a.NRO_DOCUMENTO = l.nro_operacion
   and b.COD_PERSONA = i.cod_persona
   and a.COD_OFI_ORIGEN = o.cod_oficina
   and o.cod_pais = u.cod_pais
   and o.cod_ciudad = u.cod_ciudad
   and u.cod_departamento = e.cod_departamento
   and a.FECHA = mov.fecha
   and a.HORA = mov.hora
   and a.COD_USUARIO = mov.cod_usuario
   and a.NRO_SECUENCIA <> mov.nro_secuencia
   and pal_cam.FU_CON_MON_A_MONEDA(a.COD_MONEDA, 'USD', A.MONTO) < fug_obt_pardinamico('BCP_MTO_INF_CAMBIOS')
union
Select a.fecha as fecha,
       substr(a.hora, 1, 5) as hora,
       case
         when b.TIPO = 'F' then
          (select aa.pri_nombre || ' ' || aa.seg_nombre
             from ba_per_fisicas aa
            where aa.cod_persona = b.COD_PERSONA)
         when b.tipo = 'J' then
          (select bb.raz_social
             from ba_per_juridicas bb
            where bb.cod_persona = b.COD_PERSONA)
         else
          null
       end nombre_cliente,
       case
         when b.TIPO = 'F' then
          (select aa.pri_apellido || ' ' || aa.seg_apellido
             from ba_per_fisicas aa
            where aa.cod_persona = b.COD_PERSONA)
         when b.tipo = 'J' then
          (select bb.nom_comercial
             from ba_per_juridicas bb
            where bb.cod_persona = b.COD_PERSONA)
         else
          null
       end apellido_cliente,

       b.nro_documento as documento,
       c.abreviatura as tip_documento,
       decode(b.TIPO, 'F', 'Fisica', 'J', 'Jurídica') as tip_persona,
       case
         when (select 1
                 from ge_clientes gc
                where gc.cod_persona = b.COD_PERSONA) is not null then
          'Establecido'
         when (select 1
                 from ge_clientes gc
                where gc.cod_persona = b.COD_PERSONA) is null then
          'Ocacional'
         else
          null
       end as tipo_de_cliente,
       (select bp.cod_pai_iso
          from ba_paises bp
         where bp.cod_pais = b.cod_pais) Nacionalidad,
       i.descripcion as sucursal,
       e.descripcion as zona_geografica,
       decode(cod_tip_movimiento, 'D', 'Compra', 'C', 'Venta', 0) tipo_de_operacion,
       a.des_tra_padre as operacion,
       decode(cod_tip_movimiento, 'D', a.monto, mov.monto) monto_recibido,
       decode(cod_tip_movimiento, 'D', a.cod_moneda, mov.cod_moneda) moneda_recibida,
       decode(cod_tip_movimiento, 'C', a.monto, mov.monto) monto_entregado,
       decode(cod_tip_movimiento, 'C', a.cod_moneda, mov.cod_moneda) moneda_entregada
  from gv_movimientos a,
       ba_personas b,
       ba_tip_documentos c,
       ge_clientes l,
       ba_oficinas o,
       ba_ciudades i,
       ba_departamentos e,
       (select ah.fecha,
               ah.hora,
               ah.cod_usuario,
               ah.nro_secuencia,
               ah.monto,
               ah.cod_moneda
          from ah_movimientos_his ah
         where ah.monto is not null
           and ah.cod_mod_padre in (7, 9)
           and ah.cod_tra_padre = 388
           and ah.REVERSADO = 'N'
           and ah.cod_usuario in ('HOMEBANK', 'HBANK')
        union
        select cc.fecha,
               cc.hora,
               cc.cod_usuario,
               cc.nro_secuencia,
               cc.monto,
               cc.cod_moneda
          from cc_movimientos_his cc
         where cc.monto is not null
           and cc.cod_mod_padre in (7, 9)
           and cc.cod_tra_padre = 388
           and cc.REVERSADO = 'N') mov
 where a.cod_usuario in ('HOMEBANK', 'HBANK')
   and b.cod_tip_documento = c.cod_tip_documento
   and a.cod_mod_padre in (7, 9)
   and a.cod_tra_padre = 388
   and a.REVERSADO = 'N'
   and nvl(trim(a.cotizacion), ' ') <> ' '
   and b.cod_persona = fug_obt_cli_principal(a.NRO_CUENTA)
   and a.COD_USU_REVERSION is null
   and a.COD_TIP_MOVIMIENTO in ('C', 'D')
   and a.NRO_SECUENCIA in (1, 2)
   and ((fug_es_empleado(b.cod_persona) = 'S' and
       (select count(1)
            from gv_movimientos b
           where b.FECHA = a.FECHA
             and b.HORA = a.HORA
             and b.cod_usuario = a.cod_usuario
             and b.NRO_DOCUMENTO = a.NRO_DOCUMENTO
             and b.cod_moneda = a.cod_moneda) = 1) or
       (((SELECT COUNT(1)
             FROM LC_MOVIMIENTOS_HIS LM
            WHERE A.FECHA = LM.FECHA
              AND A.HORA = LM.HORA
              and A.COD_USUARIO = LM.COD_USUARIO
              AND A.NRO_DOCUMENTO = LM.NRO_DOCUMENTO
              AND A.COD_MONEDA != LM.COD_MONEDA) > 0) or
       ((SELECT COUNT(1)
             FROM CC_MOVIMIENTOS_HIS CM
            WHERE A.FECHA = CM.FECHA
              AND A.HORA = CM.HORA
              and A.COD_USUARIO = CM.COD_USUARIO
              AND A.NRO_DOCUMENTO = CM.NRO_DOCUMENTO
              AND A.COD_MONEDA != CM.COD_MONEDA) > 0) or
       ((SELECT COUNT(1)
             FROM AH_MOVIMIENTOS_HIS AM
            WHERE A.FECHA = AM.FECHA
              AND A.HORA = AM.HORA
              and A.COD_USUARIO = AM.COD_USUARIO
              AND A.NRO_DOCUMENTO = AM.NRO_DOCUMENTO
              AND A.COD_MONEDA != AM.COD_MONEDA) > 0) or
       ((SELECT COUNT(1)
             FROM GE_MOVIMIENTOS GM
            WHERE A.FECHA = GM.FECHA
              AND A.HORA = GM.HORA
              and A.COD_USUARIO = GM.COD_USUARIO
              AND A.NRO_DOCUMENTO = GM.NRO_DOCUMENTO
              AND A.COD_MONEDA != GM.COD_MONEDA) > 0)))
   and l.cod_persona = b.COD_PERSONA
   and o.cod_oficina = a.COD_OFI_ORIGEN
   and i.cod_pais = o.cod_pais
   and i.cod_ciudad = o.cod_ciudad
   and i.cod_departamento = e.cod_departamento
   and a.FECHA = mov.fecha
   and a.HORA = mov.hora
   and a.COD_USUARIO = mov.cod_usuario
   and a.NRO_SECUENCIA <> mov.nro_secuencia
   and pal_cam.FU_CON_MON_A_MONEDA(a.COD_MONEDA, 'USD', A.MONTO) < fug_obt_pardinamico('BCP_MTO_INF_CAMBIOS')
;

