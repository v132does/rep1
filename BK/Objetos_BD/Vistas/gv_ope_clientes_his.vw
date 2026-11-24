CREATE OR REPLACE FORCE VIEW IT.GV_OPE_CLIENTES_HIS AS
select ge_cuentas.nro_cuenta,
       ba_modulos.descripcion modulo,
       decode(ge_cuentas.cod_modalidad,
              41,
              'SOBREGIROS',
              ge_modalidades.descripcion) modalidad,
       ba_personas.cod_persona,
       ba_personas.nom_completo,
       ba_personas.tipo,
       ba_personas.cod_pais pais,
       ba_personas.cod_tip_documento tip_doc,
       ba_personas.nro_documento,
       ba_tip_documentos.abreviatura,
       ge_cuentas.cod_modulo,
       ge_cuentas.cod_modalidad,
       to_char(ge_cuentas.cod_oficina)cod_oficina,
       ge_cuentas.estado,
       ge_cuentas.cod_moneda cod_moneda,
       ge_cuentas.fec_apertura,
       ge_cuentas.fec_vencimiento,
       ge_cuentas.cod_tasa,
       ba_oficinas.descripcion oficina,
       ba_monedas.descripcion moneda,
       ba_monedas.cod_mon_bco_central,
       ge_clientes.cat_riesgo,
       nvl(fue_obt_des_refcodes('CAT_RIESGO', ge_clientes.cat_riesgo),
           'Sin categoria') riesgo,
       fug_cat_riesgo(ge_clientes.cat_riesgo) categoria,
       ge_clientes.cod_sec_contable,
     --FUG_OBT_MOD_SUP_RUBRO(ba_modulos.cod_modulo, ge_cuentas.nro_cuenta) tip_operacion,
       det.tip_operacion,
       det.rubro_bcp,
       det.fec_operacion,
       det.nro_operacion, det.cod_persona cod_per_crc
  from ba_tip_documentos,
       ge_cta_clientes,
       ba_personas,
       ba_oficinas,
       ge_clientes,
       ba_monedas,
       ba_modulos,
       ge_modalidades,
       ge_cuentas,
       (select nvl(substr(d.nro_operacion,1,INSTR(d.nro_operacion,'#')-1),d.nro_operacion) nro_operacion,
               substr(d.cta_con_cap_original,6,3) tip_operacion,
               substr(d.cta_con_cap_original,1,8)||substr(d.cta_con_cap_original,3,1)||substr(d.cta_con_cap_original,9,2) rubro_bcp,
               d.fecha fec_operacion, d.cod_persona
          from sb_crc_operaciones_det d
         where d.fecha = (SELECT MAX(fecha) from sb_crc_operaciones_det o
                           WHERE o.nro_operacion = nvl(substr(d.nro_operacion,1,INSTR(d.nro_operacion,'#')-1),d.nro_operacion))) det
 where ge_cuentas.nro_cuenta = ge_cta_clientes.nro_cuenta
   and ba_personas.cod_persona = ge_cta_clientes.cod_persona
   and ba_tip_documentos.cod_tip_documento = ba_personas.cod_tip_documento
   and ba_modulos.cod_modulo = ge_modalidades.cod_modulo
   and ge_modalidades.cod_modulo = ge_cuentas.cod_modulo
   and ge_modalidades.cod_modalidad = ge_cuentas.cod_modalidad
   and ba_oficinas.cod_oficina = ge_cuentas.cod_oficina
   and ba_personas.cod_persona = ge_clientes.cod_persona
   and ge_cuentas.cod_moneda = ba_monedas.cod_moneda
   and ge_cta_clientes.relacion = 'P'
   and ge_cuentas.cod_modulo in (3,4,5,6)
   and ge_cuentas.cod_modalidad not in (31,42,43)
   and ge_cta_clientes.nro_cuenta = det.nro_operacion (+)
   and ge_cta_clientes.cod_persona = det.cod_persona (+)
 order by ba_personas.cod_persona,
          ba_monedas.cod_mon_bco_central,
          ge_cuentas.cod_modalidad desc,
          ge_cuentas.fec_apertura
;

