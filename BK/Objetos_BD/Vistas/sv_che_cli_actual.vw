CREATE OR REPLACE FORCE VIEW IT.SV_CHE_CLI_ACTUAL AS
select registro,fec_devolucion,orden, cod_ofi_camara, cod_moneda
  from
--Cabecera
(
--GS
select 'RECPERSONA'||
       '1'||lpad(fug_obt_cod_banco,3,'0')||
       to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd')||
       lpad(to_char(count(fir.cod_persona)),6,'0') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       ' ' nro_documento,
       nvl(b.cod_ofi_camara, fug_obt_ofi_matriz) cod_ofi_camara,
       'C' orden,
       0 fila,
       nvl(b.cod_moneda, 'GS') cod_moneda
  from ge_calendarios c, cc_che_recibidos x, cc_che_devueltos b, ge_par_dinamicos p, cc_che_dev_firmantes fir, ba_personas per
 where c.cod_modulo = 4
 and nvl(b.fecha, c.fec_actual) = c.fec_actual
 and x.fec_proceso(+) = fec_actual
 and x.nro_cheque = b.nro_cheque(+)
 and x.nro_cuenta = b.nro_cuenta(+)
 and x.monto = b.monto(+)
 and x.cod_ofi_camara = b.cod_ofi_camara(+)
 and x.fec_proceso = b.fecha
 and nvl(b.cod_moneda, 'GS') = pag_gen.fu_obt_mon_local
 and nvl(x.com_directa, 'N') = 'N'
 and nvl(b.dev_com_directa, 'N') = 'N'
 and b.nro_cuenta = fir.nro_cuenta
 and b.nro_cheque = fir.nro_cheque
 and fir.cod_persona = per.cod_persona
 and p.parametro = 'MTO_CHE_RET_CERO'
 and p.cod_moneda = nvl(b.cod_moneda, 'GS')
 and nvl(b.monto, p.val_parametro) >= to_number(p.val_parametro)
group by nvl(b.fecha, c.fec_actual), nvl(b.cod_ofi_camara, fug_obt_ofi_matriz), nvl(b.cod_moneda, 'GS')
union
--USD
select 'RECPERSONA'||
       '1'||lpad(fug_obt_cod_banco,3,'0')||
       to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd')||
       lpad(to_char(count(fir.cod_persona)),6,'0') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       ' ' nro_documento,
       nvl(b.cod_ofi_camara, fug_obt_ofi_matriz) cod_ofi_camara,
       'C' orden,
       0 fila,
       nvl(b.cod_moneda, 'USD') cod_moneda
  from ge_calendarios c, cc_che_recibidos x, cc_che_devueltos b, ge_par_dinamicos p, cc_che_dev_firmantes fir, ba_personas per
 where c.cod_modulo = 4
 and nvl(b.fecha, c.fec_actual) = c.fec_actual
 and x.fec_proceso(+) = fec_actual
 and x.nro_cheque = b.nro_cheque(+)
 and x.nro_cuenta = b.nro_cuenta(+)
 and x.monto = b.monto(+)
 and x.cod_ofi_camara = b.cod_ofi_camara(+)
 and x.fec_proceso = b.fecha
 and nvl(b.cod_moneda, 'USD') <> pag_gen.fu_obt_mon_local
 and p.parametro = 'MTO_CHE_RET_CERO'
 and p.cod_moneda = nvl(b.cod_moneda, 'USD')
 and b.nro_cuenta = fir.nro_cuenta
 and b.nro_cheque = fir.nro_cheque
 and fir.cod_persona = per.cod_persona
 and nvl(b.monto, p.val_parametro) >= to_number(p.val_parametro)
group by nvl(b.fecha, c.fec_actual), nvl(b.cod_ofi_camara, fug_obt_ofi_matriz), nvl(b.cod_moneda, 'USD')
union --Detalle
select lpad(nvl(x.cod_bco_receptor,'0'),4,'0')||
       /*
       rpad(replace(fug_cta_formateada(cta.cod_modulo,
                               cta.cod_modalidad,
                               cta.cod_oficina,
                               che.nro_cuenta,
                               cta.cod_moneda),' ',''),12,' ')||
       */
       lpad(cta.nro_cuenta,12,'0')||
       --rpad(che.nro_cheque,8,' ')||
       lpad(che.nro_cheque,8,'0')||
       rpad(to_char(tip.abreviatura),3,' ')||
       rpad(per.nro_documento,15,' ')||
       rpad(decode(per.tipo,'F',rtrim(fis.pri_apellido)||' '||
                           rtrim(fis.seg_apellido)||' '||
                           rtrim(fis.pri_nombre)||' '||
                           rtrim(fis.seg_apellido),
                       'J',rtrim(jur.raz_social)),60,' ') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       per.nro_documento,
       che.cod_ofi_camara,
       'D' orden,
       rownum fila,
       che.cod_moneda
  from cc_che_recibidos x,
       cc_che_devueltos che,
       ge_calendarios c,
       ge_cuentas cta,
       ba_tip_documentos tip,
       ba_personas per,
       ba_per_fisicas fis,
       ba_per_juridicas jur,
       cc_che_dev_firmantes fir
 where c.cod_modulo = 4
   and che.fecha = c.fec_actual
   and x.fec_proceso = c.fec_actual
   and x.nro_cheque = che.nro_cheque
   and x.nro_cuenta = che.nro_cuenta
   and x.monto = che.monto
   and x.fec_proceso = che.fecha
   and x.cod_ofi_camara = che.cod_ofi_camara
   and ((che.cod_moneda = pag_gen.fu_obt_mon_local and
         x.com_directa = 'N' and
         che.dev_com_directa = 'N') or
        (che.cod_moneda <> pag_gen.fu_obt_mon_local))
   and che.nro_cuenta = cta.nro_cuenta
   and che.nro_cuenta = fir.nro_cuenta
   and che.nro_cheque = fir.nro_cheque
   and fir.cod_persona = per.cod_persona
   and per.cod_tip_documento = tip.cod_tip_documento
   and per.cod_persona = fis.cod_persona(+)
   and per.cod_persona = jur.cod_persona(+)
   /*and per.cod_persona = (select min(cod_persona) from cc_che_dev_firmantes b
                           where b.nro_cuenta = che.nro_cuenta
                             and b.nro_cheque = che.nro_cheque)*/
   and che.monto >= (SELECT to_number(p.val_parametro)
                       FROM ge_par_dinamicos p
                      WHERE p.parametro = 'MTO_CHE_RET_CERO'
                        AND p.cod_moneda = che.cod_moneda)
 order by nro_documento
)
order by orden, fila
;
