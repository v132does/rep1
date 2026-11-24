CREATE OR REPLACE FORCE VIEW IT.GV_SHA_PROVEEDORES AS
select
descripcion,nro_documento,NRO_CTA_PPROV,cod_ente,cod_per_ente,ULT_NRO_TIMBRADO,telefono,direccion,
dir_correo,tip_persona,pais,tip_doc_pais,tip_documento,fec_vto_documento,tip_iva,cod_actividad,actividad,
       raz_social, nom_comercial, naturaleza, tip_act_internacional, ramo, gestor, can_empleados, can_socios,
       fec_apertura, can_sucursales, age_retencion,
        denominacion,
        pri_nombre,
        seg_nombre,
        pri_apellido,
        seg_apellido,
        est_civil,
        fec_nacimiento,
        cod_sexo,
        pais_nacionalidad
 from (
SELECT e.descripcion, p.nro_documento, fug_obt_parentes(e.cod_ente, 'NRO_CTA_PPROV') NRO_CTA_PPROV, e.cod_ente, e.cod_persona cod_per_ente,
       fug_obt_parentes(e.cod_ente, 'ULT_NRO_TIMBRADO') ULT_NRO_TIMBRADO,
       (SELECT AREA || TELEFONO
           FROM ba_telefonos t
          WHERE t.principal = 'S'
            AND t.cod_persona = e.cod_persona) telefono,
       (SELECT DIRECCION
           FROM ba_direcciones d
          WHERE d.principal = 'S'
            AND d.cod_persona = e.cod_persona) AS direccion, p.dir_correo, p.tipo tip_persona, pa.descripcion pais, pai_doc.descripcion tip_doc_pais,
       tip_doc.descripcion tip_documento, 'Nro. Documento', p.fec_vto_documento, p.tip_iva, p.cod_actividad, ac.descripcion actividad,

       j.raz_social, j.nom_comercial, j.naturaleza, j.tip_act_internacional, r.descripcion ramo, u.nombre gestor, j.can_empleados, j.can_socios,
       j.fec_apertura, j.can_sucursales, j.age_retencion,
       Null denominacion,
       --campos de personas fisicas
       NULL pri_nombre,
        --f.pri_nombre,
       NULL seg_nombre,
        --f.seg_nombre,
       NULL pri_apellido,
        --f.pri_apellido,
       NULL seg_apellido,
        --f.seg_apellido,
       NULL est_civil,
        --f.est_civil,
       NULL fec_nacimiento,
        --f.fec_nacimiento,
       NULL cod_sexo,
        --f.cod_sexo,
       NULL pais_nacionalidad --panac.descripcion pais_nacionalidad
  FROM ge_entes e, ba_personas p, ba_per_juridicas j, ba_ramos r, ba_paises pa, ba_tip_documentos pai_doc, ba_tip_documentos tip_doc, ge_clientes cli,
       ba_usuarios u, ge_actividades ac
 WHERE e.tipo = 'PV'
   AND p.cod_persona = e.cod_persona
   AND p.cod_persona = j.cod_persona
   AND p.cod_persona = cli.cod_persona(+)
   AND r.cod_ramo = j.cod_ramo(+)
   AND pa.cod_pais = p.cod_pais
   AND pai_doc.cod_tip_documento = p.cod_pai_documento
   AND tip_doc.cod_tip_documento = p.cod_tip_documento
   AND u.cod_usuario(+) = cli.cod_usu_gestion
   AND ac.cod_actividad = p.cod_actividad


UNION

SELECT e.descripcion, p.nro_documento, fug_obt_parentes(e.cod_ente, 'NRO_CTA_PPROV') NRO_CTA_PPROV, e.cod_ente, e.cod_persona cod_per_ente,
       fug_obt_parentes(e.cod_ente, 'ULT_NRO_TIMBRADO') ULT_NRO_TIMBRADO,
       (SELECT AREA || TELEFONO
           FROM ba_telefonos t
          WHERE t.principal = 'S'
            AND t.cod_persona = e.cod_persona) telefono,
       (SELECT DIRECCION
           FROM ba_direcciones d
          WHERE d.principal = 'S'
            AND d.cod_persona = e.cod_persona) AS direccion, p.dir_correo, p.tipo tip_persona, pa.descripcion pais, pai_doc.descripcion tip_doc_pais,
       tip_doc.descripcion tip_documento, 'Nro. Documento', p.fec_vto_documento, p.tip_iva, p.cod_actividad, ac.descripcion,
 --Campos de personas juridicas
       NULL,
        --j.raz_social,
       NULL,
        --j.nom_comercial ,
       NULL,
        --j.naturaleza,
       NULL,
        --j.tip_act_internacional,
       NULL,
        --r.descripcion,
       u.nombre gestor, NULL,
        --j.can_empleados,
       NULL,
        --j.can_socios,
       NULL,
        --j.fec_apertura,
       NULL,
        --j.can_sucursales,
       NULL,
        --j.age_retencion
        f.pri_nombre||' '|| f.seg_nombre||' '|| f.pri_apellido||' '|| f.seg_apellido,
       f.pri_nombre, f.seg_nombre, f.pri_apellido, f.seg_apellido, f.est_civil, f.fec_nacimiento, f.cod_sexo, panac.descripcion pais_nacionalidad
  FROM ge_entes e, ba_personas p, ba_per_fisicas f, ba_paises pa, ba_tip_documentos pai_doc, ba_tip_documentos tip_doc, ge_clientes cli, ba_usuarios u,
       ge_actividades ac, ba_paises panac
 WHERE e.tipo = 'PV'
   AND p.cod_persona = e.cod_persona
   AND p.cod_persona = f.cod_persona
   AND p.cod_persona = cli.cod_persona(+)
   AND panac.cod_pais = f.cod_pai_nacionalidad
   AND pa.cod_pais = p.cod_pais
   AND pai_doc.cod_tip_documento = p.cod_pai_documento
   AND tip_doc.cod_tip_documento = p.cod_tip_documento
   AND u.cod_usuario(+) = cli.cod_usu_oficial
   AND ac.cod_actividad = p.cod_actividad
   )
;

