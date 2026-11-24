create or replace force view it.gv_recaudaciones as
select a.cod_ente, a.nro_operacion nro_boleta, a.fec_operacion fec_recaudacion,
         a.nro_cta_credito nro_cta_recaudora, a.cod_moneda,
         'EFECTIVO' tip_deposito, null nro_cheque, null banco, null cod_banco,
         a.mto_efectivo importe, null est_cheque, null nro_cta_cheque,
         b.nom_depositante depositante,
         a.depositante cod_depositante,
         fue_obt_tip_doc_abreviatura(b.cod_tip_documento) tip_documento,
         b.nro_documento, a.hora,
         a.ref_pago, fue_obt_des_oficina(a.cod_oficina) Oficina,
         a.cod_oficina
    from ge_rec_movimientos a,
         ge_rec_depositantes b
   where a.cod_ente = b.cod_ente
     and a.depositante = b.cod_depositante
     and a.estado = 'N'
     and a.mto_efectivo > 0
union all -- cheques bbva.
  select distinct a.cod_ente, a.nro_operacion nro_boleta, a.fec_operacion fec_recaudacion,
         a.nro_cta_credito nro_cta_recaudora, a.cod_moneda,
         'CHEQUE' tip_deposito, e.nro_cheque,
         fug_obt_des_banco(7) banco,
         7 cod_banco,
         nvl(e.mto_cheque,a.mto_che_cnb) importe,
         decode(g.liberado/*lib_posterior*/,'S','Confirmado','Pend. de Confirmación') est_cheque,
         e.nro_cta_cheque,
         b.nom_depositante depositante,
         a.depositante cod_depositante,
         fue_obt_tip_doc_abreviatura(b.cod_tip_documento) tip_documento,
         b.nro_documento, a.hora,
         a.ref_pago, fue_obt_des_oficina(a.cod_oficina) Oficina,
         a.cod_oficina
    from ge_rec_movimientos a,
         ge_rec_depositantes b,
         ah_retenciones g,
         (select c.nro_cuenta,
                 c.nro_documento nro_bol_cheque,
                 d.nro_documento nro_cheque,
                 d.monto mto_cheque,
                 d.nro_cuenta nro_cta_cheque,
                 pac_che.fu_obt_est_cheque(d.nro_cuenta, d.nro_documento) est_cheque
            from cj_movimientos c,
                 cj_movimientos d
           where c.cod_mod_padre = 9
             and c.cod_mad_padre = 91
             and c.cod_tra_padre = 371
             and d.cod_tra_padre = 355
             and c.estado = 'N'
             and c.nro_documento = d.nro_doc_referencia) e
   where a.cod_ente = b.cod_ente
     and a.depositante = b.cod_depositante
     and a.estado = 'N'
     and g.nro_cuenta = a.nro_cta_credito
     and g.nro_documento = a.nro_operacion
     and g.cod_retencion is not null
     and a.mto_che_cnb > 0
     and e.nro_cuenta = a.nro_cta_credito
     and a.nro_operacion = e.nro_bol_cheque

union all -- cheques o/b.
  select a.cod_ente, a.nro_operacion nro_boleta, a.fec_operacion fec_recaudacion,
         a.nro_cta_credito nro_cta_recaudora, a.cod_moneda,
         case when c.nro_cheque is not null then 'CHEQUE'
           else 'CHEQUE NO DETALLADO' end tip_deposito, c.nro_cheque,
         decode(fug_obt_des_banco(c.cod_banco),'Banco no registrado en el Sistema',null,fug_obt_des_banco(c.cod_banco)) banco,
         c.cod_banco,
         case when c.monto > 0 then c.monto
           else a.mto_che_cob end importe,
         fug_obt_est_cheque(c.fec_final, c.nro_cheque, c.cod_moneda, c.estado, c.liberado, c.monto) est_cheque,
         null,
         b.nom_depositante depositante,
         a.depositante cod_depositante,
         fue_obt_tip_doc_abreviatura(b.cod_tip_documento) tip_documento,
         b.nro_documento, a.hora,
         a.ref_pago, fue_obt_des_oficina(a.cod_oficina) Oficina,
         a.cod_oficina
    from ge_rec_movimientos a,
         ge_rec_depositantes b,
         cc_che_enviados c
   where a.cod_ente = b.cod_ente
     and a.depositante = b.cod_depositante
     and a.estado = 'N'
     and a.mto_che_cob > 0
     and c.fecha(+) = a.fec_operacion
     and c.nro_boleta(+) = a.nro_operacion
     and c.cod_moneda(+) = a.cod_moneda
union -- Transferencias Interna.
  select g.cod_ente,
         mov_cre.nro_documento,
         mov_cre.fecha fec_recaudacion,
         mov_cre.nro_cuenta nro_cta_recaudadora,
         mov_cre.cod_moneda,
         'TRANSFERENCIA' tip_deposito,
         null nro_cheque,
         fug_obt_des_banco(7) banco,
         7 cod_banco,
         mov_cre.monto importe,
         null est_cheque,
         null,
         g.nom_depositante depositante,
         g.cod_depositante,
         fue_obt_tip_doc_abreviatura(g.cod_tip_documento) tip_documento,
         g.nro_documento,
         /*mov_cre.hora*/to_char(mov_cre.fec_insercion, 'hh24:mi:ss') hora, --DYDMR-10712
         mov_cre.concepto ref_pago,
         fue_obt_des_oficina(mov_cre.cod_oficina) Oficina,
         mov_cre.cod_oficina
    from ge_movimientos mov_cre,
         (select fecha, hora, cod_usuario, nro_cuenta, nro_documento
            from ge_movimientos
           where reversado = 'N'
             and cod_tra_padre = 388
             and cod_transaccion = 503) mov_deb,
         ge_entes c,
         ge_par_entes d,
         ge_cta_clientes e,
         ba_personas f,
         ge_rec_depositantes g
   where mov_cre.cod_tra_padre = 388
     and mov_cre.cod_transaccion = 602
     and mov_cre.reversado = 'N'
     and mov_deb.fecha = mov_cre.fecha
     and mov_deb.hora = mov_cre.hora
     and mov_deb.cod_usuario = mov_cre.cod_usuario
     and mov_deb.nro_documento = mov_cre.nro_documento
     and c.tipo = 'SV'
     and c.cod_ente = d.cod_ente
     and d.parametro in ('NRO_CTA_CRE_GS', 'NRO_CTA_CRE_USD')
     and d.val_parametro = mov_cre.nro_cuenta
     and e.nro_cuenta = mov_deb.nro_cuenta
     and e.relacion = 'P'
     and f.cod_persona = e.cod_persona
     and ((ltrim(g.nro_documento,'0') = f.nro_documento)
      or (instr(g.nro_doc_adicional, f.nro_documento) > 0 ))
     and g.cod_depositante =
         (select max(h.cod_depositante)
            from ge_rec_depositantes h
           where h.nro_documento = g.nro_documento)
union -- Transferencias SIPAP del día.
  select c.cod_ente, a.nro_documento, a.fecha fec_recaudacion,
         b.nro_cta_beneficiario nro_cta_recaudadora,  a.cod_moneda,
         'TRANSFERENCIA' tip_deposito, null nro_cheque,
         fug_obt_des_banco(7) banco,
         7 cod_banco,
         a.monto importe,
         null est_cheque, null, e.nom_depositante depositante,
         e.cod_depositante, fue_obt_tip_doc_abreviatura(e.cod_tip_documento) tip_documento,
         e.nro_documento, /*a.hora*/to_char(a.fec_insercion, 'hh24:mi:ss'), --DYDMR-10712
         a.concepto ref_pago,
         fue_obt_des_oficina(a.cod_oficina) Oficina,
         a.cod_oficina
    from ge_movimientos        a,
         ge_snp_transferencias b,
         ge_entes              c,
         ge_par_entes          d,
         ge_rec_depositantes   e
   where a.fecha = b.fecha
     and a.hora = b.hora
     and a.cod_usuario = b.cod_usuario
     and a.nro_documento = b.nro_referencia
     and a.reversado = 'N'
     and a.cod_transaccion = 602
     and b.nro_ref_externa is not null
     and b.fec_recepcion is not null
     and c.tipo = 'SV'
     and c.cod_persona = b.cod_per_beneficiario
     and d.cod_ente = c.cod_ente
     and d.parametro in ('NRO_CTA_CRE_GS','NRO_CTA_CRE_USD')
     and d.val_parametro = b.nro_cta_beneficiario
     and e.cod_ente = d.cod_ente
     and ((ltrim(e.nro_documento,'0') = b.nro_doc_solicitante)
       or (instr(e.nro_doc_adicional, b.nro_doc_solicitante) > 0))
     and e.cod_depositante = (select max(cod_depositante)
                              from ge_rec_depositantes d
                             where d.nro_documento = e.nro_documento)
order by 3,1,5,6,2
;

