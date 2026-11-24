CREATE OR REPLACE force VIEW IT.SV_CHE_DEV_ACTUAL AS
select registro,fec_devolucion,orden, cod_ofi_camara, nro_cuenta, nro_cheque, fecha, cod_moneda
  from
--Cabecera
(
--GS
select 'RECCHEQUES'||
       '1'||lpad(fug_obt_cod_banco,3,'0')||
       to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd')||
       lpad(to_char(nvl(sum(b.monto),0)),17,'0')||
       lpad(to_char(count(distinct b.nro_cuenta||b.nro_cheque||b.monto||cod_causa)),6,'0') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       nvl(b.cod_ofi_camara, fug_obt_ofi_matriz) cod_ofi_camara,
       'C' orden,
       0 fila, null nro_cuenta, null nro_cheque, null fecha, nvl(b.cod_moneda, 'GS') cod_moneda
  from ge_calendarios c, cc_che_recibidos x, cc_che_devueltos b, ge_par_dinamicos p
 where c.cod_modulo = 4
   and nvl(b.fecha, c.fec_actual) = c.fec_actual
   and x.fec_proceso(+) = c.fec_actual
   and x.nro_cheque = b.nro_cheque(+)
   and x.nro_cuenta = b.nro_cuenta(+)
   and x.monto = b.monto(+)
   and x.cod_ofi_camara = b.cod_ofi_camara(+)
   and nvl(b.cod_moneda, 'GS') = pag_gen.fu_obt_mon_local
   and nvl(x.com_directa, 'N') = 'N'
   and nvl(b.dev_com_directa, 'N') = 'N'
   and p.parametro = 'MTO_CHE_RET_CERO'
   and p.cod_moneda = nvl(b.cod_moneda, 'GS')
   and nvl(b.monto, p.val_parametro) >= to_number(p.val_parametro)
group by nvl(b.fecha, c.fec_actual), nvl(b.cod_ofi_camara, fug_obt_ofi_matriz), nvl(b.cod_moneda, 'GS')
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
       0 fila, null nro_cuenta, null nro_cheque, null fecha, nvl(b.cod_moneda, 'USD')
  from ge_calendarios c, cc_che_recibidos x, cc_che_devueltos b, ge_par_dinamicos p
 where c.cod_modulo = 4
   and nvl(b.fecha, c.fec_actual) = c.fec_actual
   and x.fec_proceso(+) = c.fec_actual
   and x.nro_cheque = b.nro_cheque(+)
   and x.nro_cuenta = b.nro_cuenta(+)
   and x.monto = b.monto(+)
   and x.cod_ofi_camara = b.cod_ofi_camara(+)
   and nvl(b.cod_moneda, 'USD') <> pag_gen.fu_obt_mon_local
   and p.parametro = 'MTO_CHE_RET_CERO'
   and p.cod_moneda = nvl(b.cod_moneda, 'USD')
   and nvl(b.monto, p.val_parametro) >= to_number(p.val_parametro)
group by nvl(b.fecha, c.fec_actual), nvl(b.cod_ofi_camara, fug_obt_ofi_matriz), nvl(b.cod_moneda, 'USD')
union--Detalle
select lpad(nvl(x.cod_bco_receptor,'0'),4,'0')||
       lpad(nvl(cta.nro_cuenta,'0'),12,'0')||
       lpad(b.nro_cheque,8,'0')||
       lpad(to_char(b.monto),17,'0')||
       lpad(fug_obt_parcausales((pae_uti.FU_OBT_VALOR (b.cod_causa,1,'S')),'COD_DEV_BCP'),2,'0')||
       to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd')||
       lpad(rownum,6,0)||
       RPAD(RPAD (NVL(fug_obt_parcausales((pae_uti.FU_OBT_VALOR (fue_obt_dat_camp_fec('CC_CHE_DEVUELTOS', b.nro_cuenta||','||b.nro_cheque, b.fecha),1,'S')),'COD_DEV_BCP'),' '),2,' ')||
       RPAD (NVL(fug_obt_parcausales((pae_uti.FU_OBT_VALOR (fue_obt_dat_camp_fec('CC_CHE_DEVUELTOS', b.nro_cuenta||','||b.nro_cheque, b.fecha),2,'S')),'COD_DEV_BCP'),' '),2,' ')||
       RPAD (NVL(fug_obt_parcausales((pae_uti.FU_OBT_VALOR (fue_obt_dat_camp_fec('CC_CHE_DEVUELTOS', b.nro_cuenta||','||b.nro_cheque, b.fecha),3,'S')),'COD_DEV_BCP'),' '),2,' ')||
       RPAD (NVL(fug_obt_parcausales((pae_uti.FU_OBT_VALOR (fue_obt_dat_camp_fec('CC_CHE_DEVUELTOS', b.nro_cuenta||','||b.nro_cheque, b.fecha),4,'S')),'COD_DEV_BCP'),' '),2,' ')||
       RPAD (NVL(fug_obt_parcausales((pae_uti.FU_OBT_VALOR (fue_obt_dat_camp_fec('CC_CHE_DEVUELTOS', b.nro_cuenta||','||b.nro_cheque, b.fecha),5,'S')),'COD_DEV_BCP'),' '),2,' '),20,' ')   
       ||
       RPAD(RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,1,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,5,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,9,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,13,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,17,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,21,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,25,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,29,3),b.cod_causa),' '),1,' ')||
       RPAD (NVL(fug_obt_cod_cau_bcp (substr(b.cod_sub_motivo,33,3),b.cod_causa),' '),1,' '),9,' ')
       registro,
       --to_char(pag_cal.fu_obt_fec_actual(4),'yyyymmdd') registro,
       pag_cal.fu_obt_fec_actual(4) fec_devolucion,
       b.cod_ofi_camara,
       'D' orden,
       rownum fila, b.nro_cuenta, b.nro_cheque, b.fecha, b.cod_moneda
  from ge_cuentas cta, ge_calendarios, cc_che_recibidos x, cc_che_devueltos b
 where ge_calendarios.cod_modulo = 4
   and cta.nro_cuenta = b.nro_cuenta
   and fecha = fec_actual
   and x.fec_proceso = fec_actual
   and x.nro_cheque = b.nro_cheque
   and x.nro_cuenta = b.nro_cuenta
   and x.monto = b.monto
   and x.cod_ofi_camara = b.cod_ofi_camara
   and ((b.cod_moneda = pag_gen.fu_obt_mon_local and
         x.com_directa = 'N' and
         b.dev_com_directa = 'N') or
        (b.cod_moneda <> pag_gen.fu_obt_mon_local))
   and b.monto >= (SELECT to_number(p.val_parametro)
                    FROM ge_par_dinamicos p
                   WHERE p.parametro = 'MTO_CHE_RET_CERO'
                     AND p.cod_moneda = b.cod_moneda)
)
order by orden, fila
;
