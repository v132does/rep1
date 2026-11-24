create or replace force view it.wv_not_cli_bajas as
select x.COD_PERSONA,
       x.NOMBRE,
       x.TIPO_DOC,
       x.NRO_DOC_CI,
       x.SUCURSAL_CLIENTE,
       x.ORIGEN,
       x.ORIGEN_BAJA,
       x.COD_DESTINO,
       x.MEDIO,
       x.ESTADO_SUSCRIPCION,
       x.TIPO_SUSCRIPCION,
       x.FECHA_BAJA,
       x.COD_USU_BAJA,
       decode(x.COD_USU_BAJA,
              null,
              null,
              fuy_obt_cat_usuario(x.COD_USU_BAJA)) USU_BAJA_CATEGORIA,
       decode(x.COD_USU_BAJA,
              null,
              null,
              fue_obt_des_refcodes('COD_CAT_USUARIO',
                                   FUY_OBT_CAT_USUARIO(x.COD_USU_BAJA))) USU_BAJA_CAT_DESC,
       decode(x.COD_USU_BAJA,
              null,
              null,
              fue_obt_des_oficina(fug_obt_ofi_usuario(x.COD_USU_BAJA))) SUCURSAL_USU_BAJA,
       x.GESTOR_CLIENTE,
       x.OFICINA_GESTOR,
       x.AREA_DE_NEGOCIOS,
       x.TIPO_PERSONA
  from (select a.cod_persona,
               fue_obt_nom_persona(a.cod_persona) NOMBRE,
               fue_obt_tip_doc_abreviatura(FUE_OBT_DOC_PRINCIPAL(a.cod_persona)) TIPO_DOC,
               fue_obt_nro_doc_persona(a.cod_persona) NRO_DOC_CI,
               fue_obt_des_oficina(fug_obt_ofi_cliente(a.cod_persona)) SUCURSAL_CLIENTE,
               fuw_not_cli_obt_origen(a.cod_persona) AS ORIGEN,
               fuw_not_cli_obt_ori_baja(a.cod_persona) AS ORIGEN_BAJA,
               fuw_not_cli_obt_medio(a.cod_persona) AS COD_DESTINO,
               fuw_not_obt_des_medio(fuw_not_cli_obt_medio(a.cod_persona)) MEDIO,
               decode(a.activo, 'S', 'ACTIVO', 'INACTIVO') estado_suscripcion,
               fuw_not_cli_tip_suscripcion(a.cod_persona) TIPO_SUSCRIPCION,
               fug_obt_gestor(A.COD_PERSONA) GESTOR_CLIENTE,
               fue_obt_des_oficina(fug_obt_ofi_oficial(a.cod_persona)) OFICINA_GESTOR,
               fug_obt_des_segmento(FUG_OBT_SEG_CLIENTE(a.cod_persona)) AREA_DE_NEGOCIOS,
               fuw_obt_homebanking(a.cod_persona, '', 'P') TIPO_PERSONA,
               decode(a.activo, 'N', TRUNC(a.fec_modificacion), null) FECHA_BAJA,
               fuw_not_cli_obt_usu_baja(a.cod_persona) COD_USU_BAJA
          from bw_not_cli_suscriptos a
         where a.activo = 'N'
        UNION
        select a.cod_persona,
               fue_obt_nom_persona(a.cod_persona) nombre,
               fue_obt_tip_doc_abreviatura(FUE_OBT_DOC_PRINCIPAL(a.cod_persona)) TIPO_DOC,
               fue_obt_nro_doc_persona((a.cod_persona)) NRO_DOC_CI,
               fue_obt_des_oficina(fug_obt_ofi_cliente((a.cod_persona))) SUCURSAL_CLIENTE,
               fuw_not_cli_obt_origen(a.cod_persona) AS ORIGEN,
               fuw_not_cli_obt_ori_baja(a.cod_persona) AS ORIGEN_BAJA,
               fuw_not_cli_obt_medio (a.cod_persona) COD_DESTINO,
               fuw_not_obt_des_medio(fuw_not_cli_obt_medio (a.cod_persona)) MEDIO,
               decode(a.activo, 'S', 'ACTIVO', 'INACTIVO') estado_suscripcion,
               fuw_not_cli_tip_suscripcion(a.cod_persona) TIPO_SUSCRIPCION,
               fug_obt_gestor(A.COD_PERSONA) GESTOR_CLIENTE,
               fue_obt_des_oficina(fug_obt_ofi_oficial(a.cod_persona)) OFICINA_GESTOR,
               fug_obt_des_segmento(FUG_OBT_SEG_CLIENTE(a.cod_persona)) AREA_DE_NEGOCIOS,
               fuw_obt_homebanking(a.cod_persona, '', 'P') TIPO_PERSONA,
               trunc(max(h.fec_insercion)) fecha_baja,
               fuw_not_cli_obt_usu_baja(a.cod_persona)  cod_usu_baja
          from bw_not_cli_destino_his h, bw_not_cli_suscriptos a
         where h.activo_old = 'S'
           and h.activo_new is null
           and h.novedad = 'E'
           and exists
         (select 1
                  from bw_not_cli_destino_his y
                 where (y.cod_persona_old = h.cod_persona_old or
                       y.cod_persona_new = h.cod_persona_new)
                   and Y.activo_old = 'N'
                   and Y.activo_new = 'N'
                   and trunc(Y.FEC_INSERCION) = trunc(h.fec_insercion))
           and (h.cod_persona_old = a.cod_persona or
               h.cod_persona_new = a.cod_persona)
           and trunc(h.fec_insercion) = (select trunc(max(fec_insercion))
                                           from bw_not_cli_destino_his y
                                           where (y.cod_persona_old = h.cod_persona_old or
                                                 y.cod_persona_new = h.cod_persona_new)
                                             and Y.activo_new = 'N'
                                             and y.cod_destino_old = h.cod_destino_old)
           group by a.cod_persona,h.usu_insercion,h.cod_destino_old, h.cod_destino_new,a.activo,h.usu_modificacion)x
order by to_number(x.cod_persona, '9999999');

