create or replace force view it.gv_set_pagos as
select w.fec_pago,
           w.hora,
           w.fec_pago fec_valor,
           w.cliente,
           w.tip_documento,
           w.Nro_documento,
           w.nom_completo,
           w.Tipo Tipo_persona,
           decode(w.tipo,'F','Fisica','Juridica') Tipo_desc,
           w.RUC,
           w.tip_orden,
           w.Impuesto,
           w.nro_orden NRO_ORDEN,
           w.nro_operacion,
           w.nro_boleta NRO_BOLET,
           w.nro_cta_debito,
           w.estado,
           w.Cant_reintento,
           w.cod_error,
           w.msg_error,
           w.monto,
           w.gestor,
           w.Oficina,
          FUG_OBT_DES_SEGMENTO(FUG_OBT_SEG_CLIENTE(w.cliente)) area_cliente
    from (
         select trunc(p.fec_insercion) fec_pago,
                p.hora,
                p.fec_pago fec_valor,
                fug_obt_cli_principal(p.nro_cta_debito,'P') cliente,
                fue_obt_tip_doc_abreviatura(pe.cod_tip_documento) tip_documento,
                fue_obt_nro_doc_persona(pe.cod_persona) Nro_documento,
                pe.nom_completo,
                pe.tipo,
                p.ruc||'-'||p.dig_verificador RUC,
                p.tip_orden,
                decode(p.nro_impuesto,0,p.nro_impuesto||' - '||'Varios Impuestos',p.nro_impuesto||' - '||i.obligacion) Impuesto,
           p.nro_orden,
           p.nro_operacion,
           p.nro_boleta,
           p.nro_cta_debito,
           p.estado,
           p.cod_error,
           p.msg_error,
           p.monto,
           fug_obt_gestor(pe.cod_persona) gestor,
           fug_obt_ofi_cliente(pe.cod_persona) ||' - '||fue_obt_des_oficina(fug_obt_ofi_cliente(pe.cod_persona)) Oficina,
           (select o.nro_sec_renvio
             from ge_set_ordenes o
            where o.estado = 'E'
            and exists (select 1
                          from ge_set_pagos pa
                         where pa.nro_orden = o.nro_orden
                           and pa.nro_orden = p.nro_orden
                           and pa.estado <> 'C'))Cant_reintento

    from ge_set_pagos p,
         ge_set_impuestos i,
         ba_personas pe
    where p.nro_impuesto = i.cod_impuesto(+)
      and pe.cod_persona = fug_obt_cli_principal(p.nro_cta_debito,'P')) w
order by 1, 12;

