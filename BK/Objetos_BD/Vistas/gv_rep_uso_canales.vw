create or replace force view it.gv_rep_uso_canales as
select distinct bw.cod_canal as nro_caja,
                decode(bw.cod_canal,
                       '994',
                       decode(bw.cod_per_vinculada,
                              null,
                              'BANCA MOVIL',
                              'Ipad'),
                       '999',
                       'BANCA WEB',
                       'OTROS') as canal,
                decode(bw.cod_per_vinculada,
                       null,
                       b.cod_persona,
                       bw.cod_per_vinculada) as cod_persona,
                decode(bw.cod_per_vinculada,
                       null,
                       b.nro_documento,
                       fue_obt_nro_doc_persona(bw.cod_per_vinculada)) as nro_doc,
                decode(bw.cod_per_vinculada,
                       null,
                       FUE_OBT_TIP_DOC_ABREVIATURA(fue_obt_doc_principal(b.cod_persona)),
                       FUE_OBT_TIP_DOC_ABREVIATURA(fue_obt_doc_principal(bw.cod_per_vinculada))) as tip_doc,
                decode(bw.cod_per_vinculada,
                       null,
                       b.nom_completo,
                       fue_obt_nom_persona(bw.cod_per_vinculada)) as nombre_cliente,
                decode(bw.cod_per_vinculada,
                       null,
                       g.cod_oficina,
                       fug_obt_ofi_cliente(bw.cod_per_vinculada)) as cod_sucursal,
                decode(bw.cod_per_vinculada,
                       null,
                       o.descripcion,
                       fue_obt_des_oficina(fug_obt_ofi_cliente(bw.cod_per_vinculada))) as desc_sucursal,
                decode(bw.cod_per_vinculada,
                       null,
                       g.cod_usu_oficial,
                       fug_obt_cod_usu_oficial(bw.cod_per_vinculada)) as cod_gestor,
                decode(bw.cod_per_vinculada,
                       null,
                       u.nombre,
                       fue_obt_nom_usuario(fug_obt_cod_usu_oficial(bw.cod_per_vinculada))) as nombre_gestor,
                decode(bw.cod_per_vinculada,
                       null,
                       nvl(s.descripcion,
                           'Segmento del Cliente No Especificado'),
                       nvl(fug_obt_des_segmento(fug_obt_seg_cliente(bw.cod_per_vinculada)),
                           'Segmento del Cliente No Especificado')) as segmento_cliente,
                decode(bw.cod_per_vinculada, null, 'INDIVIDUOS', 'EMPRESAS') as banca,
                trunc(max(bw.fec_insercion))as fec_insercion,
                CASE
                  WHEN b.cod_persona <> bw.cod_per_vinculada THEN
                   b.cod_persona
                  ELSE
                   NULL
                END as per_vinculada,
                fue_obt_nom_persona(CASE
                  WHEN b.cod_persona <> bw.cod_per_vinculada THEN
                   b.cod_persona
                  ELSE
                   NULL
                END) as nom_per_vinculada
  from bw_bitacora     bw,
       ba_personas     b,
       ge_clientes     g,
       ba_oficinas     o,
       ba_usuarios     u,
       ge_seg_clientes s
 where bw.cod_persona     = b.nro_documento --bw.cod_persona almacena numeros de documento 11/03/2014
   and b.cod_persona      = g.cod_persona
   and g.cod_oficina      = o.cod_oficina
   and g.cod_usu_oficial  = u.cod_usuario
   and g.cod_seg_cliente  = s.cod_seg_cliente (+)
   and bw.tipo            = 'SAL'
   and bw.cod_tip_mensaje = '005'
   and bw.cod_sesion      is not null
 group by bw.cod_canal,
          b.cod_persona,
          b.nro_documento,
          b.nom_completo,
          g.cod_oficina,
          o.descripcion,
          g.cod_usu_oficial,
          u.nombre,
          s.descripcion,
          bw.cod_per_vinculada

union all

select distinct '999'     as nro_caja,
       'WEB ANTERIOR'     as canal,
       decode(bw.cod_per_principal,
                       null,
                       b.cod_persona,
                       bw.cod_per_principal) as cod_persona,
                decode(bw.cod_per_principal,
                       null,
                       b.nro_documento,
                       fue_obt_nro_doc_persona(bw.cod_per_principal)) as nro_doc,
                decode(bw.cod_per_principal,
                       null,
                       FUE_OBT_TIP_DOC_ABREVIATURA(fue_obt_doc_principal(b.cod_persona)),
                       FUE_OBT_TIP_DOC_ABREVIATURA(fue_obt_doc_principal(bw.cod_per_principal))) as tip_doc,
                decode(bw.cod_per_principal,
                       null,
                       b.nom_completo,
                       fue_obt_nom_persona(bw.cod_per_principal)) as nombre_cliente,
                decode(bw.cod_per_principal,
                       null,
                       g.cod_oficina,
                       fug_obt_ofi_cliente(bw.cod_per_principal)) as cod_sucursal,
                decode(bw.cod_per_principal,
                       null,
                       o.descripcion,
                       fue_obt_des_oficina(fug_obt_ofi_cliente(bw.cod_per_principal))) as desc_sucursal,
                decode(bw.cod_per_principal,
                       null,
                       g.cod_usu_oficial,
                       fug_obt_cod_usu_oficial(bw.cod_per_principal)) as cod_gestor,
                decode(bw.cod_per_principal,
                       null,
                       u.nombre,
                       fue_obt_nom_usuario(fug_obt_cod_usu_oficial(bw.cod_per_principal))) as nombre_gestor,
                decode(bw.cod_per_principal,
                       null,
                       nvl(s.descripcion,
                           'Segmento del Cliente No Especificado'),
                       nvl(fug_obt_des_segmento(fug_obt_seg_cliente(bw.cod_per_principal)),
                           'Segmento del Cliente No Especificado')) as segmento_cliente,
                decode(bw.cod_per_principal, null, 'INDIVIDUOS', 'EMPRESAS') as banca,
                trunc(max(bw.fec_insercion)),

                CASE
                  WHEN b.cod_persona <> bw.cod_per_principal THEN
                   b.cod_persona
                  ELSE
                   NULL
                END as per_vinculada,
                fue_obt_nom_persona(CASE
                  WHEN b.cod_persona <> bw.cod_per_principal THEN
                   b.cod_persona
                  ELSE
                   NULL
                END) as nom_per_vinculada
  from bw_movimientos  bw,
       ba_personas     b,
       ge_clientes     g,
       ba_oficinas     o,
       ba_usuarios     u,
       ge_seg_clientes s
 where bw.cod_per_ingreso = b.cod_persona
   and b.cod_persona      = g.cod_persona
   and g.cod_oficina      = o.cod_oficina
   and g.cod_usu_oficial  = u.cod_usuario
   and g.cod_seg_cliente  = s.cod_seg_cliente (+)
   and bw.cod_respuesta   = '000'
   and bw.nro_caja        = '999'
   and bw.cod_tip_mensaje = '005'
 group by b.cod_persona,
          b.nro_documento,
          b.nom_completo,
          g.cod_oficina,
          o.descripcion,
          g.cod_usu_oficial,
          u.nombre,
          s.descripcion,
          bw.cod_per_principal
;

