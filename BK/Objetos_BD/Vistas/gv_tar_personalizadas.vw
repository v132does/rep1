CREATE OR REPLACE FORCE VIEW IT.GV_TAR_PERSONALIZADAS AS
SELECT decode(t.tipo, 'F', 'FIJA', 'V', 'VARIABLE') tarifa,
       p.cod_persona cod_persona,
       p.nom_completo nom_completo,
       f.cod_tasa cod_tasa,
       t.descripcion des_tasa,
       r.abreviatura tip_tarifa,
       f.fec_vigencia fec_vigencia,
       f.val_minimo val_minimo,
       f.val_maximo val_maximo,
       f.val_tasa val_tasa,
       f.val_extension por_exonaracion,
       f.fec_vencimiento fec_vencimiento,
       f.fec_insercion fec_insercion,
       c.cod_usu_oficial gestor,
       uo.nombre nom_gestor,
       f.usu_insercion usu_alta,
       ui.nombre nom_usu_alta,
       decode(ct.cod_ente, NULL, 'NO', 'SI') nomina,
       e.descripcion empresa,
       p.descripcion paquete,
       'VIGENTE' Estado
  FROM ge_tas_fechas      f,
       ge_tasas           t,
       cc_cta_corrientes  ct,
       ge_cta_clientes    cc,
       ge_clientes        c,
       ba_personas        p,
       ba_cod_referencias r,
       ba_usuarios        uo,
       ba_usuarios        ui,
       ge_entes           e,
       ge_paq_cuentas     pc,
       ge_paquetes        p
 WHERE ct.estado IN ('A', 'N')
   AND f.cod_tasa = t.cod_tasa
   AND f.nro_cuenta = ct.nro_cuenta
   AND ct.nro_cuenta = cc.nro_cuenta
   AND cc.relacion = 'P'
   AND cc.cod_persona = c.cod_persona
   AND cc.cod_persona = p.cod_persona
   AND r.dominio = 'TIP_VALOR'
   AND t.tip_valor = r.val_minimo
   AND c.cod_usu_oficial = uo.cod_usuario
   AND f.usu_insercion = ui.cod_usuario
   AND ct.cod_ente = e.cod_ente(+)
   AND ct.nro_cuenta = pc.nro_cuenta(+)
   AND pc.cod_paquete = p.cod_paquete(+)
   AND (f.cod_modulo <> 4 OR f.cod_modulo IS NULL)
   AND (f.cod_modalidad <> 41 OR f.cod_modalidad IS NULL)
   AND (f.cod_sub_modalidad <> 5 OR f.cod_sub_modalidad IS NULL)
   AND NOT EXISTS (SELECT 1
          FROM ge_mov_sin_costo sc
         WHERE sc.cod_tas_limite = t.cod_tasa)
UNION
--ctas ahorros
SELECT decode(t.tipo, 'F', 'FIJA', 'V', 'VARIABLE') tarifa,
       p.cod_persona cod_persona,
       p.nom_completo nom_completo,
       f.cod_tasa cod_tasa,
       t.descripcion des_tasa,
       r.abreviatura tip_tarifa,
       f.fec_vigencia fec_vigencia,
       f.val_minimo val_minimo,
       f.val_maximo val_maximo,
       f.val_tasa val_tasa,
       f.val_extension por_exonaracion,
       f.fec_vencimiento fec_vencimiento,
       f.fec_insercion fec_insercion,
       c.cod_usu_oficial gestor,
       uo.nombre nom_gestor,
       f.usu_insercion usu_alta,
       ui.nombre nom_usu_alta,
       decode(ct.cod_ente, NULL, 'NO', 'SI') nomina,
       e.descripcion empresa,
       p.descripcion paquete,
       'VIGENTE' Estado
  FROM ge_tas_fechas      f,
       ge_tasas           t,
       ah_cta_vistas      ct,
       ge_cta_clientes    cc,
       ge_clientes        c,
       ba_personas        p,
       ba_cod_referencias r,
       ba_usuarios        uo,
       ba_usuarios        ui,
       ge_entes           e,
       ge_paq_cuentas     pc,
       ge_paquetes        p
 WHERE ct.estado IN ('A', 'N')
   AND f.cod_tasa = t.cod_tasa
   AND f.nro_cuenta = ct.nro_cuenta
   AND ct.nro_cuenta = cc.nro_cuenta
   AND cc.relacion = 'P'
   AND cc.cod_persona = c.cod_persona
   AND cc.cod_persona = p.cod_persona
   AND r.dominio = 'TIP_VALOR'
   AND t.tip_valor = r.val_minimo
   AND c.cod_usu_oficial = uo.cod_usuario
   AND f.usu_insercion = ui.cod_usuario
   AND ct.cod_ente = e.cod_ente(+)
   AND ct.nro_cuenta = pc.nro_cuenta(+)
   AND pc.cod_paquete = p.cod_paquete(+)
   AND (f.cod_modulo <> 3 OR f.cod_modulo IS NULL)
   AND (f.cod_modalidad <> 31 OR f.cod_modalidad IS NULL)
   AND (f.cod_sub_modalidad <> 5 OR f.cod_sub_modalidad IS NULL)
   AND NOT EXISTS (SELECT 1
          FROM ge_mov_sin_costo sc
         WHERE sc.cod_tas_limite = t.cod_tasa)
UNION
--variables
--ctas corrientes
SELECT decode(t.tipo, 'F', 'FIJA', 'V', 'VARIABLE') tarifa,
       p.cod_persona cod_persona,
       p.nom_completo nom_completo,
       tr.cod_tasa tarifa,
       t.descripcion des_tarifa,
       r.abreviatura tip_tarifa,
       tr.fec_vigencia,
       NULL,
       tr.val_hasta,
       tr.val_tasa,
       tr.val_extension por_exonaracion,
       tr.fec_vencimiento,
       tr.fec_insercion fec_insercion,
       c.cod_usu_oficial gestor,
       uo.nombre nom_gestor,
       tr.usu_insercion usu_alta,
       ui.nombre nom_usu_alta,
       decode(ct.cod_ente, NULL, 'NO', 'SI') nomina,
       e.descripcion empresa,
       p.descripcion paquete,
       'VIGENTE' Estado
  FROM ge_tas_rangos      tr,
       ge_tasas           t,
       cc_cta_corrientes  ct,
       ge_cta_clientes    cc,
       ge_clientes        c,
       ba_personas        p,
       ba_cod_referencias r,
       ba_usuarios        uo,
       ba_usuarios        ui,
       ge_entes           e,
       ge_paq_cuentas     pc,
       ge_paquetes        p
 WHERE ct.estado IN ('A', 'N')
   AND tr.cod_tasa = t.cod_tasa
   AND tr.nro_cuenta = ct.nro_cuenta
   AND tr.nro_cuenta = cc.nro_cuenta
   AND cc.relacion = 'P'
   AND cc.cod_persona = c.cod_persona
   AND cc.cod_persona = p.cod_persona
   AND r.dominio = 'TIP_VALOR'
   AND t.tip_valor = r.val_minimo
   AND c.cod_usu_oficial = uo.cod_usuario
   AND tr.usu_insercion = ui.cod_usuario
   AND ct.cod_ente = e.cod_ente(+)
   AND ct.nro_cuenta = pc.nro_cuenta(+)
   AND pc.cod_paquete = p.cod_paquete(+)
   AND (tr.cod_modulo <> 4 OR tr.cod_modulo IS NULL)
   AND (tr.cod_modalidad <> 41 OR tr.cod_modalidad IS NULL)
   AND (tr.cod_sub_modalidad <> 5 OR tr.cod_sub_modalidad IS NULL)
   AND NOT EXISTS (SELECT 1
          FROM ge_mov_sin_costo sc
         WHERE sc.cod_tas_limite = t.cod_tasa)
UNION
--ctas ahorros
SELECT decode(t.tipo, 'F', 'FIJA', 'V', 'VARIABLE') tarifa,
       p.cod_persona cod_persona,
       p.nom_completo nom_completo,
       tr.cod_tasa tarifa,
       t.descripcion des_tarifa,
       r.abreviatura tip_tarifa,
       tr.fec_vigencia,
       NULL,
       tr.val_hasta,
       tr.val_tasa,
       tr.val_extension por_exonaracion,
       tr.fec_vencimiento,
       tr.fec_insercion fec_insercion,
       c.cod_usu_oficial gestor,
       uo.nombre nom_gestor,
       tr.usu_insercion usu_alta,
       ui.nombre nom_usu_alta,
       decode(ct.cod_ente, NULL, 'NO', 'SI') nomina,
       e.descripcion empresa,
       p.descripcion paquete,
       'VIGENTE' Estado
  FROM ge_tas_rangos      tr,
       ge_tasas           t,
       ah_cta_vistas      ct,
       ge_cta_clientes    cc,
       ge_clientes        c,
       ba_personas        p,
       ba_cod_referencias r,
       ba_usuarios        uo,
       ba_usuarios        ui,
       ge_entes           e,
       ge_paq_cuentas     pc,
       ge_paquetes        p
 WHERE ct.estado IN ('A', 'N')
   AND tr.cod_tasa = t.cod_tasa
   AND tr.nro_cuenta = ct.nro_cuenta
   AND tr.nro_cuenta = cc.nro_cuenta
   AND cc.relacion = 'P'
   AND cc.cod_persona = c.cod_persona
   AND cc.cod_persona = p.cod_persona
   AND r.dominio = 'TIP_VALOR'
   AND t.tip_valor = r.val_minimo
   AND c.cod_usu_oficial = uo.cod_usuario
   AND tr.usu_insercion = ui.cod_usuario
   AND ct.cod_ente = e.cod_ente(+)
   AND ct.nro_cuenta = pc.nro_cuenta(+)
   AND pc.cod_paquete = p.cod_paquete(+)
   AND (tr.cod_modulo <> 3 OR tr.cod_modulo IS NULL)
   AND (tr.cod_modalidad <> 31 OR tr.cod_modalidad IS NULL)
   AND (tr.cod_sub_modalidad <> 5 OR tr.cod_sub_modalidad IS NULL)
   AND NOT EXISTS (SELECT 1
          FROM ge_mov_sin_costo sc
         WHERE sc.cod_tas_limite = t.cod_tasa)
UNION
-- ge_tas_per_eliminadas
SELECT decode(f.tipo, 'F', 'FECHA', 'R', 'RANGO') tarifa,
       f.cod_persona cod_persona,
       p.nom_completo nom_completo,
       f.cod_tasa cod_tasa,
       t.descripcion des_tasa,
       NULL tip_tarifa,
       f.fec_vigencia fec_vigencia,
       f.val_minimo val_minimo,
       f.val_maximo val_maximo,
       f.val_tasa val_tasa,
       f.por_exoneracion,
       f.fec_vencimiento fec_vencimiento,
       t.fec_insercion fec_insercion,
       NULL gestor,
       NULL nom_gestor,
       f.usu_insercion usu_alta,
       NULL nom_usu_alta,
       NULL nomina,
       NULL empresa,
       NULL paquete,
      'ELIMINADA' Estado
  FROM ge_tas_per_eliminadas f, ba_personas p, ge_tasas t
 WHERE f.cod_persona = p.cod_persona
   AND f.cod_tasa = t.cod_tasa
UNION
SELECT decode(f.tipo, 'F', 'FECHA', 'R', 'RANGO') tarifa,
       p.cod_persona cod_persona,
       p.nom_completo nom_completo,
       f.cod_tasa cod_tasa,
       t.descripcion des_tasa,
       NULL tip_tarifa,
       f.fec_vigencia fec_vigencia,
       f.val_minimo val_minimo,
       f.val_maximo val_maximo,
       f.val_tasa val_tasa,
       f.por_exoneracion,
       f.fec_vencimiento fec_vencimiento,
       t.fec_insercion fec_insercion,
       NULL gestor,
       NULL nom_gestor,
       f.usu_insercion usu_alta,
       NULL nom_usu_alta,
       NULL nomina,
       NULL empresa,
       NULL paquete,
      'ELIMINADA' Estado
  FROM ge_tas_per_eliminadas f,
       ge_cta_clientes       gc,
       ba_personas           p,
       ge_tasas              t
 WHERE f.nro_cuenta = gc.nro_cuenta
   AND p.cod_persona = gc.cod_persona
   AND f.cod_tasa = t.cod_tasa
   AND gc.relacion = 'P'
;

