create or replace function it.FUJ_VAL_TRANSACCION_999(
      p_nro_operacion   in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja        in varchar2,   -- Nro de Caja
      p_mostrar         in varchar2)   -- Parámetro para ejecutar

return VARCHAR2 is
/*YA NO SE UTILIZA, SE DEFINE TODO EN PANTALLA 03/04/06*/
/*Recupera la cotización de las monedas q tengan definida en ge_cotizaciones
la cotización de la fecha de hoy*/

  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;        -- Caja
  v_cod_modalidad number(3) := 91;    -- Caja
  v_cod_transaccion number(4) := 999; -- cod de transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  --
  v_cod_oficina number(3);                   -- oficina de la caja

  v_estado       number(1);             -- estado de la caja
  v_fec_caja     date;                  -- fecha de la caja
  v_sal_actual   number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques  number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'OK'; -- sin errores
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;

  v_fec_actual date  := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_mon_fuerte varchar2(3) :=pag_gen.fu_obt_mon_fuerte;
  v_cont number :=1;
cursor mone is
  select a.cod_moneda, b.descripcion
  from ba_monedas b, ge_cotizaciones a
  where b.cod_moneda = a.cod_moneda
  and fecha = v_fec_actual
  and a.cod_moneda <> pag_gen.fu_obt_mon_local
  order by a.cod_moneda;

begin
  if p_mostrar is not null then
    --recuperar las monedas q tienen cotización del día
    for reg in mone loop
      --moneda fuerte en primer lugar
      if reg.cod_moneda = v_mon_fuerte then
        v_det_campos := v_det_campos || fuj_des_campo('MONEDA1',reg.cod_moneda,NULL)||
               fuj_des_campo('DESCRI1',reg.descripcion,NULL)||
               fuj_des_campo('COMPRA1',pal_cam.fu_obt_cot_compra(reg.cod_moneda),NULL)||
               fuj_des_campo('VENTA1',pal_cam.fu_obt_cot_venta(reg.cod_moneda),NULL);
      else
        v_cont := v_cont + 1;
        if v_cont = 2 then
          v_det_campos := v_det_campos || fuj_des_campo('MONEDA2',reg.cod_moneda,NULL)||
                 fuj_des_campo('DESCRI2',reg.descripcion,NULL)||
                 fuj_des_campo('COMPRA2',pal_cam.fu_obt_cot_compra(reg.cod_moneda),NULL)||
                 fuj_des_campo('VENTA2',pal_cam.fu_obt_cot_venta(reg.cod_moneda),NULL);
        elsif v_cont = 3 then
          v_det_campos := v_det_campos || fuj_des_campo('MONEDA3',reg.cod_moneda,NULL)||
                 fuj_des_campo('DESCRI3',reg.descripcion,NULL)||
                 fuj_des_campo('COMPRA3',pal_cam.fu_obt_cot_compra(reg.cod_moneda),NULL)||
                 fuj_des_campo('VENTA3',pal_cam.fu_obt_cot_venta(reg.cod_moneda),NULL);
        elsif v_cont = 4 then
          v_det_campos := v_det_campos || fuj_des_campo('MONEDA4',reg.cod_moneda,NULL)||
                 fuj_des_campo('DESCRI4',reg.descripcion,NULL)||
                 fuj_des_campo('COMPRA4',pal_cam.fu_obt_cot_compra(reg.cod_moneda),NULL)||
                 fuj_des_campo('VENTA4',pal_cam.fu_obt_cot_venta(reg.cod_moneda),NULL);
        elsif v_cont = 5 then
          v_det_campos := v_det_campos || fuj_des_campo('MONEDA5',reg.cod_moneda,NULL)||
                 fuj_des_campo('DESCRI5',reg.descripcion,NULL)||
                 fuj_des_campo('COMPRA5',pal_cam.fu_obt_cot_compra(reg.cod_moneda),NULL)||
                 fuj_des_campo('VENTA5',pal_cam.fu_obt_cot_venta(reg.cod_moneda),NULL);
        elsif v_cont = 6 then
          v_det_campos := v_det_campos || fuj_des_campo('MONEDA6',reg.cod_moneda,NULL)||
                 fuj_des_campo('DESCRI6',reg.descripcion,NULL)||
                 fuj_des_campo('COMPRA6',pal_cam.fu_obt_cot_compra(reg.cod_moneda),NULL)||
                 fuj_des_campo('VENTA6',pal_cam.fu_obt_cot_venta(reg.cod_moneda),NULL);
        elsif v_cont = 7 then
          v_det_campos := v_det_campos || fuj_des_campo('MONEDA7',reg.cod_moneda,NULL)||
                 fuj_des_campo('DESCRI7',reg.descripcion,NULL)||
                 fuj_des_campo('COMPRA7',pal_cam.fu_obt_cot_compra(reg.cod_moneda),NULL)||
                 fuj_des_campo('VENTA7',pal_cam.fu_obt_cot_venta(reg.cod_moneda),NULL);
        end if;
      end if;
    end loop;
    if v_det_campos is null then
      --no existe cotizacion
      v_cod_respuesta:='001';
      v_msj_respuesta:='No existe cotización definida para las monedas en fecha actual';
    end if;
  end if;

  /*  select fuj_des_campo('MONEDA1',cod_moneda,NULL)||
           fuj_des_campo('DESCRI1',descripcion,NULL)||
           fuj_des_campo('COMPRA1',pal_cam.fu_obt_cot_compra(cod_moneda),NULL)||
           fuj_des_campo('VENTA1',pal_cam.fu_obt_cot_venta(cod_moneda),NULL)
      into v_det_campos
      from ba_monedas
      where cod_moneda ='USD';
    --pesos
       select v_det_campos || fuj_des_campo('MONEDA2',cod_moneda,NULL)||
          fuj_des_campo('DESCRI2',descripcion,NULL)||
          fuj_des_campo('COMPRA2',pal_cam.fu_obt_cot_compra(cod_moneda),NULL)||
          fuj_des_campo('VENTA2',pal_cam.fu_obt_cot_venta(cod_moneda),NULL)
     into v_det_campos
     from ba_monedas
     where cod_moneda ='ARP';
    --euros
       select v_det_campos || fuj_des_campo('MONEDA3',cod_moneda,NULL)||
          fuj_des_campo('DESCRI3',descripcion,NULL)||
          fuj_des_campo('COMPRA3',pal_cam.fu_obt_cot_compra(cod_moneda),NULL)||
          fuj_des_campo('VENTA3',pal_cam.fu_obt_cot_venta(cod_moneda),NULL)
     into v_det_campos
     from ba_monedas
     where cod_moneda ='EUR';
    --reales
     select v_det_campos || fuj_des_campo('MONEDA4',cod_moneda,NULL)||
            fuj_des_campo('DESCRI4',descripcion,NULL)||
            fuj_des_campo('COMPRA4',pal_cam.fu_obt_cot_compra(cod_moneda),NULL)||
            fuj_des_campo('VENTA4',pal_cam.fu_obt_cot_venta(cod_moneda),NULL)
       into v_det_campos
       from ba_monedas
       where cod_moneda ='RS';
  end if;*/

 /* falta armar el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_999;
/

