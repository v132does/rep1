CREATE OR REPLACE FORCE VIEW IT.GV_INV_CHEQUES AS
SELECT b.cod_persona,
       fue_obt_nom_persona(b.cod_persona) titular,
       a.cod_banco || '-' || fug_obt_des_banco(a.cod_banco) banco,
       a.nro_cheque,
       decode(a.cod_usuario, 'INICIO', a.usu_modificacion, 'CIERRE', a.usu_modificacion,
              a.cod_usuario) cod_usuario,
       a.fecha,
       a.cod_ofi_origen,
       fue_obt_des_oficina(a.cod_ofi_origen) des_oficina,
       a.nro_boleta,
       a.cod_retencion,
       a.fec_final,
       a.monto,
       a.cod_moneda,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, 'GS', monto, NULL, a.fecha, NULL), 0) mto_equ_local,
       a.nro_referencia,
       a.cta_libradora,
       a.estado,
       case
          when a.estado = 'C' then 'Confirmado'
          when a.estado = 'E' then 'Enviado'
          when a.estado = 'I' then 'Ingresado'
          when a.estado = 'D' then 'Devuelto'
       end estado_desc,
       a.nro_cuenta,
       fug_obt_des_causa(a.cod_cau_devolucion) cod_cau_devolucion,
       a.cod_ofi_compensacion,
       a.nro_caja,
       a.nro_bol_deposito,
       a.fec_vencimiento,
       a.nro_cta_deposito,
       decode(cod_modulo, 5, 'TARJETAS', 6, 'PRESTAMOS', 3, 'AHORROS') modulo,
       NULL librador,
       NULL nro_documento,
       NULL nro_cuota,
       NULL estado_cheque,
       NULL fec_fin_renegociacion,
       null fecha_pago_cuota,
       a.usu_modificacion usu_modificacion,
       null des_motivo,
       null mot_entrega,
       fup_obt_fec_desembolso(a.nro_cuenta) fec_desembolso
  FROM ge_cta_clientes b, cc_che_enviados a
 WHERE b.nro_cuenta = a.nro_cuenta
   /*AND a.estado = 'I'*/
   AND  nvl(fup_obt_tip_descuento(b.cod_modalidad), 'M') <> 'C'
   AND b.relacion = 'P'
UNION
SELECT b.cod_persona,
       fue_obt_nom_persona(b.cod_persona) titular,
       a.cod_banco || '-' || fug_obt_des_banco(a.cod_banco) banco,
       a.nro_cheque,
       decode(nvl(g.cod_usuario,a.usu_insercion), 'INICIO', nvl(g.usu_modificacion,a.usu_modificacion), 'CIERRE', g.usu_modificacion,
             nvl(g.cod_usuario,a.usu_insercion)) COD_USUARIO,
       nvl(g.fecha,a.fec_deposito),
       g.cod_ofi_origen,
       fue_obt_des_oficina(nvl(g.cod_ofi_origen, a.cod_oficina)) des_oficina,
       a.nro_boleta,
       g.cod_retencion,
       g.fec_final,
       decode(a.estado, 'E', a.monto * -1, a.monto) monto,
       a.cod_moneda,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, 'GS',
                                       decode(a.estado, 'E', a.monto * -1, a.monto), NULL, nvl(g.fecha,a.fec_deposito),
                                       NULL), 0) mto_equ_local,
       g.nro_referencia,
       a.cta_libradora,
       a.estado,
       case
          when a.estado = 'C' then 'Custodia'
          when a.estado = 'E' then 'Entregar'
          when a.estado = 'D' then 'Descontado'
          when a.estado = 'I' then 'Ingresado'
          when a.estado = 'A' then 'En Camara'
          when a.estado = 'B' then 'Devuelto'
          when a.estado = 'N' then 'Renegociado'
       end estado_desc,
       a.nro_referencia nro_cuenta,
       fug_obt_des_causa(a.cod_cau_devolucion),
       g.cod_ofi_compensacion,
       g.nro_caja,
       g.nro_bol_deposito,
       a.fec_vencimiento,
       g.nro_cta_deposito,
       'PRESTAMOS',
       li.nom_completo,
       li.nro_documento,
       a.nro_cuota,
       (Select upper(significado)from ba_cod_referencias where dominio = 'EST_CHE_CUSTODIA' and  val_minimo = a.estado ),
       a.fec_fin_renegociacion,
       fup_obt_pag_cuocta(b.nro_cuenta ,a.nro_cuota),
       g.usu_modificacion usu_modificacion,
       decode(a.mot_entrega,null,null,fug_obt_des_causa(a.mot_entrega)) des_motivo,
       a.mot_entrega  mot_entrega,
       decode(a.tip_servicio,'D',fup_obt_fec_desembolso(a.nro_referencia),null)
  FROM ge_cta_clientes b,
       ge_che_custodias a,
       pr_rel_chq_lib p,
       pr_chq_libradores li,
       cc_che_enviados g
 WHERE b.nro_cuenta = a.nro_referencia
   AND b.relacion = 'P'
   /*AND ((g.estado(+) = 'E' AND g.cta_libradora(+) <> '0') OR (g.estado(+) = 'I' AND g.cta_libradora(+) = '0'))*/
   AND (g.fecha(+) >= to_date(fug_obt_pardinamico('FEC_IMP_RUB_CHE_COM'), 'dd/mm/yyyy') AND
       pag_gen.fu_obt_cod_entidad = 2036)
   AND nvl(fup_obt_tip_descuento(b.cod_modalidad), 'M') = 'C'
   AND a.nro_cheque=p.nro_cheque
   AND p.nro_documento=li.nro_documento
   AND p.cod_tip_documento=li.cod_tip_documento
   AND g.nro_cheque(+)=a.nro_cheque
   and g.nro_cuenta(+)=  b.nro_cuenta
   AND g.nro_cheque(+)=p.nro_cheque
   AND g.cta_libradora(+)=p.cta_libradora
   AND g.cod_banco(+) = p.cod_banco
   AND li.nro_documento = p.nro_documento
   AND li.cod_tip_documento = p.cod_tip_documento
   union
SELECT g.cod_persona,
       fue_obt_nom_persona(g.cod_persona) titular,
       a.cod_banco || '-' || fug_obt_des_banco(a.cod_banco) banco,
       a.nro_cheque,       a.cod_usuario,
       a.fecha,
       a.cod_ofi_origen,
       fue_obt_des_oficina(a.cod_ofi_origen) des_oficina,
       a.nro_boleta,
       a.cod_retencion,
       a.fec_final,
       a.monto,
       a.cod_moneda,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, 'GS', a.monto, NULL, a.fecha, NULL), 0) mto_equ_local,
       a.nro_referencia,
       nvl(co.cta_libradora, a.cta_libradora),
       a.estado,
       case
          when a.estado = 'C' then 'Confirmado'
          when a.estado = 'E' then 'Enviado'
          when a.estado = 'I' then 'Ingresado'
          when a.estado = 'D' then 'Devuelto'
       end estado_desc,
       a.nro_cuenta,
       fug_obt_des_causa(a.cod_cau_devolucion),
       a.cod_ofi_compensacion,
       a.nro_caja,
       a.nro_bol_deposito,
       g.fec_vencimiento,
       a.nro_cta_deposito,
       'CAMBIOS',
       co.nom_completo,
       co.nro_documento,
       null,
       null,
       null,
       null,
       a.usu_modificacion usu_modificacion,
       null,
       null,
       null
 FROM cc_che_enviados a, lc_che_comprados g, lc_che_com_libradores co
 WHERE a.nro_cheque = g.nro_cheque(+)
   AND a.cod_banco = g.cod_banco(+)
   AND (a.fecha >= to_date(fug_obt_pardinamico('FEC_IMP_RUB_CHE_COM'), 'dd/mm/yyyy') AND
       pag_gen.fu_obt_cod_entidad = 2036)
   AND co.cta_libradora(+) = g.cta_libradora
   AND co.nro_cheque(+) = g.nro_cheque
   AND co.cod_banco(+) = g.cod_banco
   AND co.nro_operacion(+) = g.nro_operacion
   AND a.nro_cuenta IS NULL
   and a.nro_boleta = g.nro_operacion(+)
   /*AND a.estado ='I'*/;

