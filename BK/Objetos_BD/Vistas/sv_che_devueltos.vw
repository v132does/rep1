CREATE OR REPLACE VIEW IT.SV_CHE_DEVUELTOS AS
select registro,fec_devolucion,orden, cod_ofi_camara, nro_cuenta, nro_cheque, fecha, cod_moneda
  from
--Cabecera
(
--GS
select distinct 'RECCHEQUES'||
       '1'||lpad(fug_obt_cod_banco,3,'0')||
       to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd')||
       lpad(to_char(nvl(c.monto,0)),17,'0')||
       lpad(to_char(c.cantidad),6,'0') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       nvl(b.cod_ofi_camara, fug_obt_ofi_matriz) cod_ofi_camara,
       'C' orden,
       0 fila, null nro_cuenta, null nro_cheque, b.fecha fecha, nvl(b.cod_moneda, 'GS') cod_moneda
  from /*ge_calendarios c,*/ cc_che_recibidos x
     , cc_che_devueltos b
     , ge_par_dinamicos p
     , (select count(b2.nro_cuenta||b2.nro_cheque||b2.monto||cod_causa) cantidad,sum(b2.monto) monto,b2.fecha,b2.cod_moneda
  from ge_cuentas cta2, /*ge_calendarios,*/ cc_che_recibidos x2, cc_che_devueltos b2
 where /*ge_calendarios.cod_modulo = 4
   and*/ cta2.nro_cuenta = b2.nro_cuenta
   /*and fecha = fec_anterior
   and x.fec_proceso = fec_anterior*/
   and x2.nro_cheque = b2.nro_cheque
   and x2.nro_cuenta = b2.nro_cuenta
   and x2.monto = b2.monto
   and x2.cod_ofi_camara = b2.cod_ofi_camara
   and x2.fec_proceso = b2.fecha
   and ((b2.cod_moneda = pag_gen.fu_obt_mon_local and
         x2.com_directa = 'N' and
         b2.dev_com_directa = 'N') or
        (b2.cod_moneda <> pag_gen.fu_obt_mon_local))
   and b2.monto < (SELECT to_number(p2.val_parametro)
                    FROM ge_par_dinamicos p2
                   WHERE p2.parametro = 'MTO_CHE_RET_CERO'
                     AND p2.cod_moneda = b2.cod_moneda)
group by b2.fecha,b2.cod_moneda) c
 where /*c.cod_modulo = 4
   and nvl(b.fecha, c.fec_anterior) = c.fec_anterior
   and x.fec_proceso(+) = c.fec_anterior
   and*/ x.nro_cheque = b.nro_cheque(+)
   and x.nro_cuenta = b.nro_cuenta(+)
   and x.monto = b.monto(+)
   and x.cod_ofi_camara = b.cod_ofi_camara(+)
   and x.fec_proceso=b.fecha(+)
   and b.fecha=c.fecha
   AND B.COD_MONEDA=c.cod_moneda
   and nvl(b.cod_moneda, 'GS') = pag_gen.fu_obt_mon_local
   and nvl(x.com_directa, 'N') = 'N'
   and nvl(b.dev_com_directa, 'N') = 'N'
   and p.parametro = 'MTO_CHE_RET_CERO'
   and p.cod_moneda = nvl(b.cod_moneda, 'GS')
   and nvl(b.monto, 0) < to_number(p.val_parametro)
--USD
union
select 'RECCHEQUES'||
       '1'||lpad(fug_obt_cod_banco,3,'0')||
       to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd')||
       lpad(to_char(round(nvl(sum(b.monto),0)*100)),17,'0')||
       lpad(to_char(count(distinct b.nro_cuenta||b.nro_cheque||b.monto||cod_causa)),6,'0') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       nvl(b.cod_ofi_camara, fug_obt_ofi_matriz) cod_ofi_camara,
       'C' orden,
       0 fila, null nro_cuenta, null nro_cheque, b.fecha fecha, nvl(b.cod_moneda, 'USD')
  from /*ge_calendarios c,*/ cc_che_recibidos x, cc_che_devueltos b, ge_par_dinamicos p
 where /*c.cod_modulo = 4
   and nvl(b.fecha, c.fec_anterior) = c.fec_anterior
   and x.fec_proceso(+) = c.fec_anterior
   and*/ x.nro_cheque = b.nro_cheque(+)
   and x.nro_cuenta = b.nro_cuenta(+)
   and x.monto = b.monto(+)
   and x.cod_ofi_camara = b.cod_ofi_camara(+)
   and nvl(b.cod_moneda, 'USD') <> pag_gen.fu_obt_mon_local
   and p.parametro = 'MTO_CHE_RET_CERO'
   and p.cod_moneda = nvl(b.cod_moneda, 'USD')
   and nvl(b.monto, 0) < to_number(p.val_parametro)
group by b.fecha /*nvl(b.fecha, c.fec_anterior)*/, nvl(b.cod_ofi_camara, fug_obt_ofi_matriz), nvl(b.cod_moneda, 'USD')
union--Detalle
select lpad(nvl(x.cod_bco_receptor,'0'),4,'0')||
       /*
       rpad(replace(fug_cta_formateada(cta.cod_modulo,
                               cta.cod_modalidad,
                               cta.cod_oficina,
                               cta.nro_cuenta,
                               cta.cod_moneda),' ',''),12,' ')||
       */
       --lpad(cta.nro_cuenta,12,'0')|| se informa la cuenta seg?n el cmc7
       nvl(substr(x.banda_cmc7,5,12),lpad(cta.nro_cuenta,12,'0'))||
       --rpad(b.nro_cheque,8,' ')||
       lpad(b.nro_cheque,8,'0')||
       decode(b.cod_moneda, pag_gen.fu_obt_mon_local,
       lpad(to_char(b.monto),17,'0'),
       lpad(to_char(round(b.monto*100)),17,'0'))||
       lpad(NVL(fug_obt_parcausales(b.cod_causa,'COD_DEV_BCP'),'01'),2,'0')||
       to_char(b.fecha,'yyyymmdd') registro,
       --to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       b.cod_ofi_camara,
       'D' orden,
       rownum fila, b.nro_cuenta, b.nro_cheque, b.fecha, b.cod_moneda
  from ge_cuentas cta, /*ge_calendarios,*/ cc_che_recibidos x, cc_che_devueltos b
 where /*ge_calendarios.cod_modulo = 4
   and*/ cta.nro_cuenta = b.nro_cuenta
   /*and fecha = fec_anterior
   and x.fec_proceso = fec_anterior*/
   and x.nro_cheque = b.nro_cheque
   and x.nro_cuenta = b.nro_cuenta
   and x.monto = b.monto
   and x.fec_proceso = b.fecha
   and x.cod_ofi_camara = b.cod_ofi_camara
   and ((b.cod_moneda = pag_gen.fu_obt_mon_local and
         x.com_directa = 'N' and
         b.dev_com_directa = 'N') or
        (b.cod_moneda <> pag_gen.fu_obt_mon_local))
   and b.monto < (SELECT to_number(p.val_parametro)
                    FROM ge_par_dinamicos p
                   WHERE p.parametro = 'MTO_CHE_RET_CERO'
                     AND p.cod_moneda = b.cod_moneda)
)
order by orden, fila
;