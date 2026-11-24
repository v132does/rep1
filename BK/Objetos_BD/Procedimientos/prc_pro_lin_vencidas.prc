create or replace procedure it.prc_pro_lin_vencidas is
  -- proceso que actualiza en forma automatica las lineas temporales vencidas de Plan Sueldos 
  v_fec_proxima date;
  v_fec_inicio  date;
  v_fec_actual  date;
  v_sue_promedio cc_lin_sobregiros.monto%type;
  v_cod_ente     cc_cta_corrientes.cod_ente%type;
  v_can_mes      number;
  v_porcentaje   number;
  v_redondeo     number;
  cursor lineas is
         select a.nro_secuencia, a.cod_persona, a.fec_inicio, 
                a.fec_vencimiento, b.nro_cuenta, b.nro_sec_padre,
                a.cod_moneda,
                a.rowid fil_linea, b.rowid fil_cuenta
           from cc_lin_sobregiros b, cc_lin_sobregiros a
          where a.fec_vencimiento < v_fec_proxima
            and a.estado = 'A' -- activa
            and a.tipo = 'T' -- temporal
            and a.cod_persona is not null
            and a.nro_secuencia = b.nro_sec_padre
            and a.cod_campana is null
            and b.tipo = a.tipo
            and b.nro_cuenta is not null
            --and b.monto = a.monto
            and b.fec_vencimiento = a.fec_vencimiento
            and b.fec_inicio = a.fec_inicio
            and exists (select 0
                         from cc_cta_corrientes c
                        where c.nro_cuenta = b.nro_cuenta
                          and c.cod_ente is not null);

begin
   v_fec_proxima := pag_cal.FU_OBT_FEC_PROXIMA(4);
   v_fec_actual  := pag_cal.FU_OBT_FEC_ACTUAL(4);
   for ln in lineas loop
     begin
       select cod_ente
         into v_cod_ente
         from cc_cta_corrientes 
        where nro_cuenta = ln.nro_cuenta;
     exception
       when others then
         raise_application_error(-20000,'Error al Buscar Código de Ente. '||sqlerrm);
     end;
     v_can_mes     := fug_obt_parentes(v_cod_ente,'MES_PRO_SUELDO');
     v_porcentaje  := fug_obt_parentes(v_cod_ente,'POR_PRO_SUELDO');
     v_redondeo    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,ln.cod_moneda,null);
     --
     -- ri : 29/01/2010 : Se comenta temporalmente la exigencia de los parametros
     -- ya que no se actualizara monto 
     /*if v_can_mes is null then
       raise_application_error(-20001,'Parámetro MES_PRO_SUELDO se debe cargar para el Código de Entidad '||v_cod_ente);
     elsif v_porcentaje is null then
       raise_application_error(-20001,'Parámetro POR_PRO_SUELDO se debe cargar para el Código de Entidad '||v_cod_ente);
     end if;*/
     --
     --v_fec_inicio  := add_months(v_fec_proxima, v_can_mes*-1);
     --     
     --v_sue_promedio := round(pag_sue.fu_cre_men_promedio(ln.nro_cuenta,v_fec_inicio,v_fec_proxima)*v_porcentaje/100,v_redondeo);
     -- actualizo la fecha
     update cc_lin_sobregiros
        set fec_inicio = v_fec_actual,/*,
            monto = v_sue_promedio,*/
            fec_vencimiento = add_months(v_fec_proxima,1)
      where rowid = ln.fil_linea;
      --
      update cc_lin_sobregiros
         set fec_inicio = v_fec_actual,/*,
             monto = v_sue_promedio,*/
             fec_vencimiento = add_months(v_fec_proxima,1)
       where rowid = ln.fil_cuenta;
   end loop;
end;
/

