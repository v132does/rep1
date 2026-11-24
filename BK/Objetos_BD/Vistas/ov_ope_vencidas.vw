create or replace force view it.ov_ope_vencidas as
select a.nro_cuenta NRO_OPERACION,
       a.COD_MONEDA,
       a.COD_MODALIDAD,
       case
         when e.tipo = 'F' then
          trim(pf.pri_nombre) || ' ' || trim(pf.seg_nombre)
         else
          trim(E.NOM_COMPLETO)
       end as NOM_CLIENTE,
       trim(pf.pri_apellido) || ' ' || trim(pf.seg_apellido) as APE_CLIENTE,
       e.TIPO,
       trim(replace(e.nro_documento, chr(10), '')) NRO_DOC_CLIENTE,
       e.cod_tip_documento COD_TIPO_DOC_CLIENTE,
       pf.cod_sexo SEXO,
       c.cli_confidencial,
       c.cli_especial,
       fug_es_empleado(pf.cod_persona) es_funcionario,
       nvl(to_char(pf.fec_nacimiento,'DD/MM/YYYY'), to_char(pj.fec_apertura,'DD/MM/YYYY')) fec_nacimiento,
       decode(b.relacion, 'Y', 'C', b.relacion) RELACION,
       vin.NOM_CONYUGE,
       vin.APE_CONYUGE,
       vin.nro_documento NRO_DOC_CONYUGE,
       vin.cod_tip_documento COD_TIP_DOC_CONYUGE,
       vin.cod_sexo SEXO_CONYUGE,
       a.en_juicio JUDICIALIZADO,
       to_char(a.fec_juicio, 'DD/MM/YYYY') FEC_JUICIO,
       a.cod_ent_juicio,
       null INFORMCONF,
       null FEC_INFORMCONF,
       null INHIBIDO,
       null FEC_INHIBICION,
       NVL(a.mto_origen, 0) mto_origen,
       NVL(a.val_tasa, 0) VAL_TASA,
       a.estado,
       e.cod_rub_primario,
       e.cod_rub_secundario,
       e.cod_rub_terciario,
       a.cod_rub_economico,
       c.cod_oficina cod_ofi_cliente,
       a.cod_oficina cod_ofi_operacion,
       fug_obt_paradicional(a.nro_cuenta,'PRE_COD_ENT_COM_CARTERA') ent_com_cartera,
       c.cod_seg_cliente,
       to_char(a.fec_insercion,'DD/MM/YYYY') fec_insercion,
       a.denominacion,
       a.nro_cta_origen,
       a.fec_apertura,
       a.sal_tot_batch,
       a.dia_atraso,
       a.dia_atr_inicial,
       a.sal_total,
       a.sal_anterior,
       a.fec_ini_mora,
       to_char(a.fec_modificacion,'DD/MM/YYYY') fec_modificacion,
       c.cod_usu_oficial
  from ov_cta_vencidas a,
       ge_cta_clientes b,
       ge_clientes c,
       GE_MODALIDADES D,
       ba_personas e,
       ba_per_fisicas pf,
       ba_per_juridicas pj,
       (select trim(b.pri_nombre) || ' ' || trim(b.seg_nombre) NOM_CONYUGE,
               trim(b.pri_apellido) || ' ' || trim(b.seg_apellido) as APE_CONYUGE,
               c.nro_documento,
               c.cod_tip_documento,
               b.cod_sexo,
               a.cod_persona
          from ba_vinculos a, ba_per_fisicas b, ba_personas c
         where a.cod_per_vinculo = b.cod_persona
           and a.tipo = 'E'
           and c.cod_persona = b.cod_persona) vin
 where a.COD_MODALIDAD = D.COD_MODALIDAD
   and a.nro_cuenta = b.nro_cuenta
   and b.cod_persona = c.cod_persona
   and b.cod_persona = vin.cod_persona(+)
   and c.cod_persona = e.cod_persona
   and e.cod_persona = b.cod_persona
   and e.cod_persona = pf.cod_persona(+)
   and e.cod_persona = pj.cod_persona(+);

