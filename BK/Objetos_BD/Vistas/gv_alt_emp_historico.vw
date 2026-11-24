CREATE OR REPLACE FORCE VIEW IT.GV_ALT_EMP_HISTORICO AS
SELECT t.cod_empresa, t.nro_cedula, t.pri_nombre, t.seg_nombre, t.pri_apellido,
       t.seg_apellido, t.ape_casada, t.fec_nacimiento, t.sexo, t.est_civil,
       t.direccion, t.ciudad, t.telefono, t.sueldo, t.usu_insercion,
       t.fec_insercion, t.usu_modificacion, t.fec_modificacion, t.tip_documento,
       t.nro_solicitud, t.error, t.nro_cta_ahorro as cta_asignada, t.sobregiro, t.tip_contrato,
       t.direc_kit, t.nro_lote, t.estado
FROM GE_PAG_SUE_EMP_TMP t WHERE t.nro_lote is not null
UNION
SELECT g.cod_empresa, g.nro_cedula, g.pri_nombre, g.seg_nombre, g.pri_apellido,
       g.seg_apellido, g.ape_casada, g.fec_nacimiento, g.sexo, g.est_civil,
       g.direccion, g.ciudad, g.telefono, g.sueldo, g.usu_insercion,
       g.fec_insercion, g.usu_modificacion, g.fec_modificacion, g.tip_documento,
       g.nro_solicitud, g.error, g.nro_cuenta, g.sobregiro, g.tip_contrato,
       g.direc_kit, g.nro_lote, g.estado
FROM GE_PAG_SUE_EMP g WHERE g.nro_lote is not null;

