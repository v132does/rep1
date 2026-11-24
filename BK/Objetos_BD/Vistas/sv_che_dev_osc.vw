create or replace force view it.sv_che_dev_osc as
select registro,fec_devolucion,orden,fec_regularizacion,regularizado
  from
(
select
       '01'||
       rpad(che.nro_cuenta,16,' ') ||
       rpad(che.nro_cheque,8,' ')||
       lpad(' ',8,' ')||
       to_char(che.fecha,'ddmmyyyy')||
       decode(che.cod_moneda,'USD','0001','GS','6900')||
       lpad(replace(trim(to_char(che.monto,'999999999999999.99')),'.',''),17,0)||
       rpad(nvl(fug_obt_parcausales(che.cod_causa,'COD_DEV_OSC'),' '),3,' ')||
       lpad(decode(che.cod_bco_receptor,'',pag_gen.FU_OBT_COD_ENTIDAD(),'1'||lpad(che.cod_bco_receptor,3,'0')),4,' ')||
       rpad(to_char(tip.abreviatura),4,' ')||
       rpad(per.nro_documento,15,' ')||
       rpad(decode(per.tipo,'F',rpad(rtrim(fis.pri_nombre)  ,70,' ')                                  ||
                                replace(rpad(nvl(ltrim(rtrim(fis.seg_nombre  )),'*'),15,' '),'*',' ') ||
                                replace(rpad(nvl(ltrim(rtrim(NULL            )),'*'),15,' '),'*',' ') ||
                                rpad(rtrim(fis.pri_apellido),15,' ')                                  ||
                                replace(rpad(nvl(ltrim(rtrim(fis.seg_apellido)),'*'),15,' '),'*',' '),
                            'J',rtrim(jur.raz_social)),145,' ')||
       rpad(fue_obt_dir_principa(per.cod_persona),30,' ')||
       rpad(fue_obt_tel_principa(per.cod_persona),20,' ') registro,
       che.fecha fec_devolucion,
       per.nro_documento,
       'D' orden,
       che.fec_regularizacion,
       --TO_CHAR(che.fec_regularizacion,'dd/mm/yyyy hh24:mi:ss') fec_regularizacion, -- modificado
       che.regularizado regularizado
  from cc_che_devueltos che,
       ge_cuentas cta,
       ba_tip_documentos tip,
       ba_personas per,
       ba_per_fisicas fis,
       ba_per_juridicas jur,
       cc_che_dev_firmantes fir
 where che.nro_cuenta = cta.nro_cuenta
   and che.cod_causa in (106,107,239,110,108,128) --IF, CUENTA CANCELADA, INHABILITADO, TEXTO DEF., FIRMA DEF, ONP
   and cta.cod_modalidad = 41
   and che.nro_cuenta = fir.nro_cuenta
   and che.nro_cheque = fir.nro_cheque
   and fir.cod_persona = per.cod_persona
   and per.cod_tip_documento = tip.cod_tip_documento
   and per.cod_persona = fis.cod_persona(+)
   and per.cod_persona = jur.cod_persona(+)
 order by nro_documento
)
order by orden
;
/
