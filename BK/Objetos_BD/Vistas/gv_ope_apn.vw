create or replace force view it.gv_ope_apn as
Select t.nom_solicitante,
       t.ape_solicitante,
       p.descripcion Pais_Origen,
       t.pri_nom_beneficiario,
       t.ape_beneficiario,
       c.descripcion ciu_beneficiario,
       fue_obt_des_departamento(c.cod_departamento) Departamento,
       t.doc_beneficiario,
       t.fec_operacion,
       t.cta_beneficiario,
       t.swf_bco_destino,
       decode(t.cod_moneda, 'PYG', 'GS', t.cod_moneda) Moneda,
       t.referencia,
       t.des_mot_tranf,
       t.cod_mtcn,
       t.cod_pais_iso,
       t.est_transf Estado_transferencia,
       t.mot_rechazo Motivo_rechazo,
       t.mto_transf Monto
  from ge_apn_datos t, ba_personas tt, ba_paises p, ba_ciudades c
 where t.doc_beneficiario = tt.nro_documento
   and t.est_beneficiario is not null
   and p.cod_pai_iso(+) = t.cod_pais_iso
   and c.cod_pais(+) = nvl(p.cod_pais, 1)
   and c.cod_ciudad = (t.ciu_beneficiario);

