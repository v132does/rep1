CREATE OR REPLACE PROCEDURE IT.PRB_INF_REN_FIJA is

--Genera informe de renta fija para España
v_success boolean:=true;
v_fecha date;


 --Verifica si existen clientes que no tengan asignado COD_ISIN O COD_EMISOR
   cursor c_datos is
   select c.nro_cuenta,
       FUG_OBT_PARADICIONAL(c.nro_cuenta,'COD_ISIN') cod_isin,
       FUG_OBT_PARADICIONAL(c.nro_cuenta,'COD_EMISOR')cod_emisor
     from cb_sal_inventarios_his d,cb_sal_inventarios_det_his c, cb_rubros r
      where d.fecha=c.fecha
      and d.nro_referencia=c.nro_referencia
      and d.cod_rubro=r.cod_rubro
      --and r.cod_consolidacion in(12801,12810,12811,12864)
     and nvl(fue_obt_des_refcodes('COD_CONSOLIDACION',r.cod_consolidacion),'N')='S'
      and trunc(c.fecha)= trunc(v_fecha)
      and (FUG_OBT_PARADICIONAL(c.nro_cuenta,'COD_ISIN') is null or FUG_OBT_PARADICIONAL(c.nro_cuenta,'COD_EMISOR') is null)
      and d.cod_modulo <> 2
    union
    select c.nro_cuenta,
        decode(fue_obt_des_refcodes('COD_ISIN',C.NRO_CUENTA),'Referencia  no registrada en el Sistema',null,fue_obt_des_refcodes('COD_ISIN',C.NRO_CUENTA))cod_isin,
        decode(fue_obt_des_refcodes('COD_EMISOR',C.NRO_CUENTA),'Referencia  no registrada en el Sistema',null,fue_obt_des_refcodes('COD_EMISOR',C.NRO_CUENTA))cod_emisor
      from cb_sal_inventarios_his d,cb_sal_inventarios_det_his c, cb_rubros r
      where d.fecha=c.fecha
      and d.nro_referencia=c.nro_referencia
      and d.cod_rubro=r.cod_rubro
      --and r.cod_consolidacion in(12801,12810,12811,12864)
      and nvl(fue_obt_des_refcodes('COD_CONSOLIDACION',r.cod_consolidacion),'N')='S'
      and trunc(c.fecha)= trunc(v_fecha)
      and d.cod_modulo = 2
      and ((decode(fue_obt_des_refcodes('COD_ISIN',C.NRO_CUENTA),'Referencia  no registrada en el Sistema',null,fue_obt_des_refcodes('COD_ISIN',C.NRO_CUENTA)) is null) or
      ( decode(fue_obt_des_refcodes('COD_EMISOR',C.NRO_CUENTA),'Referencia  no registrada en el Sistema',null,fue_obt_des_refcodes('COD_EMISOR',C.NRO_CUENTA)) is null));



begin

   select pag_cal.FU_OBT_FEC_ANT_HAB ((select f.pri_dia_mes from ge_calendarios f
   where f.cod_modulo=1),31,1) into v_fecha
   from dual;
   --v_fecha:=to_date('30/09/2011','dd/mm/yyyy');

   for x in c_datos loop
      begin
         dbms_output.put_line(c_datos%rowcount);
         v_success := false;
      end;
   end loop;

   if v_success = false then
       RAISE_APPLICATION_ERROR(-20000,'Existen clientes que no tienen asignado el COD_ISIN /y/o COD_EMISOR');
      return;
   end if;


  --se cera la tabla temporal en caso de que tenga datos
  begin
    execute immediate 'truncate table CB_INF_REN_TMP';
    exception when others then null;
  end;


  execute immediate('insert into CB_INF_REN_TMP
      select y.periodo
      ||lpad(y.Sociedad_informante,5,0)
      ||lpad(rownum,6,0)
      ||lpad(y.Tipo_registro,2,0)
      ||lpad(y.cod_emisor,5,0)
      ||rpad(y.codigo_isin,12,CHR(32))
      ||y.tipo_cartera
      ||y.Dudoso
      ||lpad(y.codigo_emisor_valor_cubierto,5,CHR(32))
      ||rpad(y.codigo_ISIN_valor_cubierto,12,CHR(32))
      ||rpad(y.tipo_cartera_valor_cubierto,2,CHR(32))
      ||lpad(y.nominal,18,0)
      ||''+''
      ||lpad(y.coste_excupon,18,0)
      ||''+''
      ||lpad(y.cupon_corrido,18,0)
      ||''+''
      ||lpad(y.periodica_y_pac,18,0)
      ||''+''
      ||lpad(y.plusvalia_bruto,18,0)
      ||''+''
      ||lpad(y.minusvalia_bruto,18,0)
      ||''+''
      ||lpad(y.microcoberturas_bruto,18,0)
      ||''+''
      ||lpad(y.correcciones_valor_especifica,18,0)
      ||''+''
      ||lpad(y.correcciones_valor_riesgo_pais,18,0)
      ||''+''
      ||lpad(y.valor_contable,18,0)
      ||''+''
      ||lpad(y.plusvalias_neto,18,0)
      ||''+''
      ||lpad(minusvalias_neto,18,0)
      ||''+''
      ||lpad(y.microcoberturas_neto,18,0)
      ||''+''
      ||lpad(y.can_cuentas,18,0) renta
       from (
      select x.periodo, x.Sociedad_informante,x.Tipo_registro,x.cod_emisor,x.codigo_isin,x.tipo_cartera, x.Dudoso,
      x.codigo_emisor_valor_cubierto,x.codigo_ISIN_valor_cubierto,x.tipo_cartera_valor_cubierto,
      trunc(sum(nvl(x.nominal,0))/1000) nominal,trunc(sum(nvl(x.coste_excupon,0))/1000) coste_excupon,x.cupon_corrido,trunc(sum(nvl(x.periodica_y_pac,0))/1000)periodica_y_pac,x.plusvalia_bruto,
      x.minusvalia_bruto,x.microcoberturas_bruto,x.correcciones_valor_especifica,x.correcciones_valor_riesgo_pais,
      trunc(sum(nvl(x.valor_contable,0))/1000) valor_contable,x.plusvalias_neto,x.minusvalias_neto,x.microcoberturas_neto,
      count(distinct x.nro_cuenta) can_cuentas
       from (
      select '''||to_char(v_fecha ,'yyyymm')||''' periodo,
          ''13407'' Sociedad_informante,
          ''01'' tipo_registro,
          yyy.val_parametro cod_emisor,
          ggg.val_parametro codigo_isin,
          ''08'' tipo_cartera,
          ''N'' Dudoso,
          '' '' codigo_emisor_valor_cubierto,
          '' '' codigo_ISIN_valor_cubierto,
          '' '' tipo_cartera_valor_cubierto,
          sum(nvl(c.sal_actual,0)) nominal,
          0 coste_excupon,
          0 cupon_corrido,
          0 periodica_y_pac,
          0 plusvalia_bruto,
          0 minusvalia_bruto,
          0 microcoberturas_bruto,
          0 correcciones_valor_especifica,
          0 correcciones_valor_riesgo_pais,
          decode(d.cod_moneda,''GS'',sum(nvl(c.sal_actual,0)),(sum(nvl(c.sal_actual,0)*fug_obt_cotizacion(d.cod_moneda,c.fecha)))) valor_contable,
          0 plusvalias_neto,
          0 minusvalias_neto,
          0 microcoberturas_neto,
          t.nro_cuenta
      from cb_sal_inventarios_his d,cb_sal_inventarios_det_his c, cb_rubros r, md_cta_documentos t,ge_cta_dat_adicionales ggg,
      ge_cta_dat_adicionales yyy
      where d.cod_rubro=r.cod_rubro
--      and r.cod_consolidacion in(12801,12810,12811,12864)
      and nvl(fue_obt_des_refcodes(''COD_CONSOLIDACION'',r.cod_consolidacion),''N'')=''S''
      and d.fecha=c.fecha
      and d.nro_referencia=c.nro_referencia
      and t.nro_cuenta=c.nro_cuenta
      and d.tip_saldo<>''A''
      and ggg.nro_cuenta=c.nro_cuenta
      and ggg.parametro=''COD_ISIN''
      and yyy.nro_cuenta=c.nro_cuenta
      and yyy.parametro=''COD_EMISOR''
      and to_char(d.fecha, ''dd/mm/yyyy'')='''||to_char(v_fecha, 'dd/mm/yyyy')||'''
      group by t.nro_cuenta,t.denominacion,ggg.val_parametro,yyy.val_parametro,d.cod_moneda
      union all
      select '''||to_char(v_fecha ,'yyyymm')||''' periodo,
          ''13407'' Sociedad_informante,
           ''01'' Tipo_registro,
          yyy.val_parametro cod_emisor,
          ggg.val_parametro codigo_isin,
          ''08'' Tipo_cartera,
          ''N'' Dudoso,
          '' '' codigo_emisor_valor_cubierto,
          '' '' codigo_ISIN_valor_cubierto,
          '' '' tipo_cartera_valor_cubierto,
          0 nominal,
          0 coste_excupon,
          0 cupon_corrido,
          0 periodica_y_pac,
          0 plusvalia_bruto,
          0 minusvalia_bruto,
          0 microcoberturas_bruto,
          0 correcciones_valor_especifica,
          0 correcciones_valor_riesgo_pais,
          decode(d.cod_moneda,''GS'',sum(nvl(c.sal_actual,0)),(sum(nvl(c.sal_actual,0)*fug_obt_cotizacion(d.cod_moneda,c.fecha))))*-1 valor_contable,
          0 plusvalias_neto,
          0 minusvalias_neto,
          0 microcoberturas_neto,
          t.nro_cuenta
      from cb_sal_inventarios_his d,cb_sal_inventarios_det_his c, cb_rubros r, md_cta_documentos t,ge_cta_dat_adicionales ggg,
      ge_cta_dat_adicionales yyy
      where d.cod_rubro=r.cod_rubro
      and r.cod_consolidacion in(12801,12810,12811,12864)
      and d.fecha=c.fecha
      and d.nro_referencia=c.nro_referencia
      and t.nro_cuenta=c.nro_cuenta
      and d.tip_saldo=''A''
      and ggg.nro_cuenta=c.nro_cuenta
      and ggg.parametro=''COD_ISIN''
      and yyy.nro_cuenta=c.nro_cuenta
      and yyy.parametro=''COD_EMISOR''
      and to_char(d.fecha, ''dd/mm/yyyy'')='''||to_char(v_fecha, 'dd/mm/yyyy')||'''
      group by t.nro_cuenta,t.denominacion,ggg.val_parametro,yyy.val_parametro,d.cod_moneda
      union all
      select '''||to_char(v_fecha ,'yyyymm')||''' periodo,
          ''13407'' Sociedad_informante,
           ''01'' Tipo_registro,
          yyy.val_parametro cod_emisor,
          ggg.val_parametro codigo_isin,
          ''08'' Tipo_cartera,
          ''N'' Dudoso,
          '' '' codigo_emisor_valor_cubierto,
          '' '' codigo_ISIN_valor_cubierto,
          '' '' tipo_cartera_valor_cubierto,
          0 nominal,
          0 coste_excupon,
          0 cupon_corrido,
          decode(d.cod_moneda,''GS'',sum(nvl(c.sal_actual,0)),(sum(nvl(c.sal_actual,0)*fug_obt_cotizacion(d.cod_moneda,c.fecha)))) periodica_y_pac,
          0 plusvalia_bruto,
          0 minusvalia_bruto,
          0 microcoberturas_bruto,
          0 correcciones_valor_especifica,
          0 correcciones_valor_riesgo_pais,
          0 valor_contable,
          0 plusvalias_neto,
          0 minusvalias_neto,
          0 microcoberturas_neto,
          t.nro_cuenta
      from cb_sal_inventarios_his d,cb_sal_inventarios_det_his c, cb_rubros r, md_cta_documentos t,ge_cta_dat_adicionales ggg,
      ge_cta_dat_adicionales yyy
      where d.cod_rubro=r.cod_rubro
--      and r.cod_consolidacion in(12801,12810,12811,12864)
      and nvl(fue_obt_des_refcodes(''COD_CONSOLIDACION'',r.cod_consolidacion),''N'')=''S''
      and d.fecha=c.fecha
      and d.nro_referencia=c.nro_referencia
      and t.nro_cuenta=c.nro_cuenta
      and d.tip_saldo in(''I'')
      and ggg.nro_cuenta=c.nro_cuenta
      and ggg.parametro=''COD_ISIN''
      and yyy.nro_cuenta=c.nro_cuenta
      and yyy.parametro=''COD_EMISOR''
      and to_char(d.fecha, ''dd/mm/yyyy'')='''||to_char(v_fecha, 'dd/mm/yyyy')||'''
      group by t.nro_cuenta,t.denominacion,ggg.val_parametro,yyy.val_parametro,d.cod_moneda
      union all
      select '''||to_char(v_fecha ,'yyyymm')||''' periodo,
          ''13407'' Sociedad_informante,
           ''01'' Tipo_registro,
          yyy.val_parametro cod_emisor,
          ggg.val_parametro codigo_isin,
          ''08'' Tipo_cartera,
          ''N'' Dudoso,
          '' '' codigo_emisor_valor_cubierto,
          '' '' codigo_ISIN_valor_cubierto,
          '' '' tipo_cartera_valor_cubierto,
          0 nominal,
          0 coste_excupon,
          0 cupon_corrido,
          decode(d.cod_moneda,''GS'',sum(nvl(c.sal_actual,0)),(sum(nvl(c.sal_actual,0)*fug_obt_cotizacion(d.cod_moneda,c.fecha))))*-1 periodica_y_pac,
          0 plusvalia_bruto,
          0 minusvalia_bruto,
          0 microcoberturas_bruto,
          0 correcciones_valor_especifica,
          0 correcciones_valor_riesgo_pais,
          0 valor_contable,
          0 plusvalias_neto,
          0 minusvalias_neto,
          0 microcoberturas_neto,
          t.nro_cuenta
      from cb_sal_inventarios_his d,cb_sal_inventarios_det_his c, cb_rubros r, md_cta_documentos t,ge_cta_dat_adicionales ggg,
      ge_cta_dat_adicionales yyy
      where d.cod_rubro=r.cod_rubro
--      and r.cod_consolidacion in(12801,12810,12811,12864)
      and nvl(fue_obt_des_refcodes(''COD_CONSOLIDACION'',r.cod_consolidacion),''N'')=''S''
      and d.fecha=c.fecha
      and d.nro_referencia=c.nro_referencia
      and t.nro_cuenta=c.nro_cuenta
      and d.tip_saldo in(''A'')
      and ggg.nro_cuenta=c.nro_cuenta
      and ggg.parametro=''COD_ISIN''
      and yyy.nro_cuenta=c.nro_cuenta
      and yyy.parametro=''COD_EMISOR''
      and to_char(d.fecha, ''dd/mm/yyyy'')='''||to_char(v_fecha, 'dd/mm/yyyy')||'''
      group by t.nro_cuenta,t.denominacion,ggg.val_parametro,yyy.val_parametro,d.cod_moneda
      union all
      select '''||to_char(v_fecha ,'yyyymm')||''' periodo,
          ''13407'' Sociedad_informante,
           ''01'' Tipo_registro,
          yyy.val_parametro cod_emisor,
          ggg.val_parametro codigo_isin,
          ''08'' Tipo_cartera,
          ''N'' Dudoso,
          '' '' codigo_emisor_valor_cubierto,
          '' '' codigo_ISIN_valor_cubierto,
          '' '' tipo_cartera_valor_cubierto,
          0 nominal,
          decode(d.cod_moneda,''GS'',sum(nvl(c.sal_actual,0)),(sum(nvl(c.sal_actual,0)*fug_obt_cotizacion(d.cod_moneda,c.fecha)))) coste_excupon,
          0 cupon_corrido,
          0 periodica_y_pac,
          0 plusvalia_bruto,
          0 minusvalia_bruto,
          0 microcoberturas_bruto,
          0 correcciones_valor_especifica,
          0 correcciones_valor_riesgo_pais,
          0 valor_contable,
          0 plusvalias_neto,
          0 minusvalias_neto,
          0 microcoberturas_neto,
          t.nro_cuenta
      from cb_sal_inventarios_his d,cb_sal_inventarios_det_his c, cb_rubros r, md_cta_documentos t,ge_cta_dat_adicionales ggg,
      ge_cta_dat_adicionales yyy
      where d.cod_rubro=r.cod_rubro
--      and r.cod_consolidacion in(12801,12810,12811,12864)
      and nvl(fue_obt_des_refcodes(''COD_CONSOLIDACION'',r.cod_consolidacion),''N'')=''S''
      and d.fecha=c.fecha
      and d.nro_referencia=c.nro_referencia
      and t.nro_cuenta=c.nro_cuenta
      and d.tip_saldo =''C''
      and ggg.nro_cuenta=c.nro_cuenta
      and ggg.parametro=''COD_ISIN''
      and yyy.nro_cuenta=c.nro_cuenta
      and yyy.parametro=''COD_EMISOR''
      and to_char(d.fecha, ''dd/mm/yyyy'')='''||to_char(v_fecha, 'dd/mm/yyyy')||'''
      group by t.nro_cuenta,t.denominacion,ggg.val_parametro,yyy.val_parametro,d.cod_moneda) x
      group by x.periodo, x.Sociedad_informante,x.Tipo_registro,x.tipo_registro,x.cod_emisor,x.codigo_isin,x.tipo_cartera,x.Dudoso,
      x.codigo_emisor_valor_cubierto,x.codigo_ISIN_valor_cubierto,x.tipo_cartera_valor_cubierto,
      x.cupon_corrido,x.plusvalia_bruto,
      x.minusvalia_bruto,x.microcoberturas_bruto,correcciones_valor_especifica,x.correcciones_valor_riesgo_pais,
      x.plusvalias_neto,x.minusvalias_neto,x.microcoberturas_neto)y');

commit;
end PRB_INF_REN_FIJA;
/

