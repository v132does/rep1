create or replace force view it.iv_mpupmmdd as
select lpad( lpad(fug_obt_ofi_cliente(c.cod_persona),2,'0')|| c.cod_persona ,10,' ')        ||
         '  '                                 ||
         fug_obt_tipo_act_esperada(c.cod_persona, c.fecha)                                  ||
         lpad(c.can_tra_credito, 4, '0')      ||
         lpad(ltrim(rtrim(to_char(round(c.mto_pro_credito/g.val_conversion,2),'999999999.99'))), 17, '0') ||
         lpad(c.can_tra_debito, 4, '0')       ||
         lpad(ltrim(rtrim(to_char(round(c.mto_pro_debito/g.val_conversion,2),'999999999.99'))), 17, '0')  ||
         '*' CADENA
  from cr_act_esperadas c, ge_cotizaciones g
  where c.fecha = g.fecha
      and g.cod_moneda = 'USD'
      and trunc(c.fecha) = pag_cal.FU_OBT_FEC_ACTUAL(1)
      and round(c.mto_pro_credito/g.val_conversion) > 0
      and round(c.mto_pro_debito/g.val_conversion) > 0
      and exists (select (1) from ge_cta_clientes gc where gc.cod_persona = c.cod_persona and gc.relacion = 'P') -- solo clientes principales
      and fug_obt_tipo_act_esperada(c.cod_persona, c.fecha) in ('D','M')
  order by c.fec_insercion asc
;

