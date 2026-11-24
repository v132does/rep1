create or replace force view it.bv_ver_dat_hechauka as
select a.nro_factura,
    nvl(prov.timbrado,fug_obt_parentes(a.cod_proveedor,'ULT_NRO_TIMBRADO')) timbrado,
    nvl(prov.fecha,a.fec_pago) fecha, a.fec_pago,
    xx.cod_persona cod_per_ente,
    FUE_OBT_NOM_ENTE(xx.cod_ente) Nom_ente,
    nvl(substr(prov.ruc, 1, instr(prov.ruc, '-') -1), decode(instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)),'-'),0,
    fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)),substr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), 1,
    instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)),'-') -1)))  ruc_retenido,
    nvl(substr(prov.ruc, instr(prov.ruc, '-') + 1, length(prov.ruc) - instr(prov.ruc, '-')),
    decode(instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)),'-'),0,
    fue_obt_ruc_dig_verificador(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor))),
    substr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), '-') +1,
    length(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor))) - instr(fue_obt_nro_doc_persona(fue_obt_per_ente(a.cod_proveedor)), '-')))) ruc_digito,
    SUBSTR(LPAD(a.nro_retencion,13,'0'),1,3)||'-'||SUBSTR(LPAD(a.nro_retencion,13,'0'),4,3)
    ||'-'||SUBSTR(LPAD(a.nro_retencion,13,'0'),7,7) nro_retencion,

     pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.mto_renta,a.cotizacion) MONTO_RENTA,
     pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.monto_iva,a.cotizacion) monto_iva,
     pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.mto_ret_renta,a.cotizacion) MONTO_RET_RENTA,
     pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.monto_retencion,a.cotizacion) monto_retencion
   from ge_ret_proveedores a, pv_compras prov,
   (select cod_persona,cod_ente from ge_entes where tipo= 'PV')xx
   where a.nro_factura = prov.nro_factura (+)
   and a.cod_proveedor = prov.cod_ent_proveedor (+)
   and a.cod_proveedor=xx.cod_ente(+)
   and a.estado = 'N';

