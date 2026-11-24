create or replace function it.FUJ_PRO_TRANSACCION_300(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_moneda in varchar2 default pag_gen.FU_OBT_MON_LOCAL,
      p_cod_retencion in varchar2 default null )
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;               -- Caja
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_transaccion number(3) := 300;        -- Transaccion de apertura
  v_tex_impresion varchar2(4000);
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_sysdate           date := sysdate;
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(8000) := 'Operacion confirmada'; -- sin errores
  v_can           number := 0;

  v_tip_monto     varchar2(1);
  v_nro_corte number default 1;

  -- Procedimiento interno para generar movimiento de corte
  procedure lp_gen_transaccion  is
  begin
  insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          monto, tip_monto, tipo, fec_modificacion)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1, -- 1=secuencia
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          0,'O','N', to_date(to_char(pae_cnf.FU_OBT_FEC_ACTUAL(9),'dd/mm/yyyy')||' '||v_hor_actual,'dd/mm/yyyy hh24:mi:ss'));
  end lp_gen_transaccion;

  procedure lp_gen_corte_tmp(p_nro_corte in number)  is
  begin
  insert into cj_cortes_tmp
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre,des_tra_padre, nro_corte,
          cod_oficina, cod_moneda, nro_caja,
          monto, tip_monto, fec_modificacion,cod_retencion)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1, -- 1=secuencia
          v_cod_transaccion,fug_obt_des_transaccion(9,91,300),
          p_nro_corte,
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          0,'O',to_date(to_char(pae_cnf.FU_OBT_FEC_ACTUAL(9),'dd/mm/yyyy')||' '||v_hor_actual,'dd/mm/yyyy hh24:mi:ss'),
          p_cod_retencion);
  end lp_gen_corte_tmp;

  function lf_obt_reg_tmp return boolean is
    v_existe varchar2(1) default 'N';
  begin
    begin
      select 'S' into v_existe
      from cj_cortes_tmp
      where fecha <= pag_cal.fu_obt_fec_anterior(v_cod_modulo)
      and rownum = 1;
    exception
      when no_data_found then
      v_existe := 'N';
      when others then
      v_existe := 'N';
    end;
    if v_existe = 'S' then
      return true;
    else
      return false;
    end if;
  end;
begin
  if p_cod_retencion = 1 then
    v_tip_monto := 'O';
  elsif p_cod_retencion = 2 then
    v_tip_monto := 'T';
  elsif p_cod_retencion = 3 then
    v_tip_monto := 'S';
  end if;
  begin
    select count(*)
      into v_can
      from cj_movimientos a
     where (a.cod_mod_padre = v_cod_modulo
        or (a.cod_mod_padre = 6   --RI: 16/12/2010
        /*DYDMR-3151 08/03/16*//*and  a.cod_tra_padre = 361))*/
      and FUP_EXI_GRU_TRANSAC(803, a.cod_tra_padre, 9, 91) = 'S'))
       and (a.cod_mad_padre = v_cod_modalidad
        or (a.cod_mod_padre = 6
       /*DYDMR-3151 08/03/16*//*and  a.cod_tra_padre = 361))*/ --RI: 16/12/2010
       and FUP_EXI_GRU_TRANSAC(803, a.cod_tra_padre, 9, 91) = 'S'))  
       and a.nro_caja = p_nro_caja
       and (a.cod_usuario = v_cod_usuario
        or (a.cod_usuario <> v_cod_usuario  --RI: 02/12/2010
       /*DYDMR-3151 08/03/16*//*and  a.cod_tra_padre = 361))*/
       and FUP_EXI_GRU_TRANSAC(803, a.cod_tra_padre, 9, 91) = 'S'))
       and a.cod_moneda = pag_gen.fu_obt_mon_local
       --and a.cod_tra_padre != v_cod_transaccion
       and a.cod_tra_padre not in (v_cod_transaccion,202,203,110,133)
       and a.estado != 'R'
       and a.tip_monto = v_tip_monto
       and a.tip_monto in ('O','S','T')
     /*DYDMR-3151 08/03/16*//*and a.fec_insercion < v_sysdate;*/
       and a.fec_insercion <= v_sysdate;
--       and to_date(to_char(a.fecha,'dd/mm/yyyy')||' '||a.hora,'dd/mm/yyyy hh24:mi:ss') < v_sysdate;
  exception
    when others then
    v_can := 0;
  end;
  if v_can is null then
    v_can := 0;
  end if;
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
  --RI:02/12/2010: cuando el movimientos es de pago de prestamos c/cheque y es ingresado en ITGF
  --y luego retomado en caja, el usuario con que se graba el movimiento en caja es el usuario
  --original que realizó el cobro no el usuario del cajero.
  --RI:16/12/2010: tambien para el caso se da que el modulo y modalidad padre no corresponde al
  --de caja sino al de prestamos.
 --
 -- Valido la moneda
 if p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    -- obtengo el maximo monto permitido de operar para este usuario-------
    if v_cod_respuesta = '000' then
          -- Obtengo los datos de la caja ---------------------------------------
          prj_obt_datos_caja(p_nro_caja,
                             p_cod_moneda,
                             v_cod_oficina,
                             v_fec_caja,
                             v_estado,
                             v_sal_actual,
                             v_sal_cheques);
          -- para que tome el saldo anterior como monto de apertura

          if v_estado = -1 then
              v_cod_respuesta := '006'; -- error, no existe registro de caja
              v_msj_respuesta := 'Caja inexistente!!';
          elsif v_estado = 2 then -- caja cerrada
              v_cod_respuesta := '007';
              v_msj_respuesta := 'Caja Cerrada.';
          end if;
          if v_cod_respuesta = '000' then
            if nvl(v_can,0) = 0 then
              v_cod_respuesta := '008';
              v_msj_respuesta := 'No existen movimientos desde el último Corte.';
            else
              if v_cod_respuesta = '000' then
                lp_gen_transaccion;
              end if;
              if lf_obt_reg_tmp then
                begin
                  delete cj_cortes_tmp
                   where fecha <= pag_cal.fu_obt_fec_anterior(v_cod_modulo);
                end;
              end if;
              declare
                cursor c_cortes is
                select * from cj_movimientos m
                 where m.fecha = pae_cnf.fu_obt_fec_actual(v_cod_modulo)
                   and (m.cod_mod_padre = v_cod_modulo
                    or (m.cod_mod_padre = 6   --RI: 16/12/2010
                    and FUP_EXI_GRU_TRANSAC(803, m.cod_tra_padre, 9, 91) = 'S'))
                  -- /* DYDMR 1471 06/01/2014 */ and  m.cod_tra_padre = 361))
                   and (m.cod_mad_padre = v_cod_modalidad
                    or (m.cod_mod_padre = 6
                    and FUP_EXI_GRU_TRANSAC(803, m.cod_tra_padre, 9, 91) = 'S'))
                  -- /* DYDMR 1471 06/01/2014 */ and  m.cod_tra_padre = 361))
                   and m.nro_caja = p_nro_caja
                   and (m.cod_usuario = v_cod_usuario
                    or (m.cod_usuario <> v_cod_usuario --RI: 02/12/2010
                   and FUP_EXI_GRU_TRANSAC(803, m.cod_tra_padre, 9, 91) = 'S'))
                  -- /* DYDMR 1471 06/01/2014 */ and  m.cod_tra_padre = 361))
                   and m.cod_moneda = pag_gen.fu_obt_mon_local
                   and m.estado != 'R'
                   and m.tip_monto = v_tip_monto
--                 and m.hora < to_char(sysdate,'hh24:mi:ss')
--                 and to_char(m.fec_insercion,'hh24:mi:ss') < to_char(sysdate,'hh24:mi:ss')
                   and trunc(m.fec_insercion) <= trunc(sysdate)                              --CRO-JM-2014: JIRA-DYDMR-1053 Diferencia entre Cidesa y Listado ITGF
                   and m.cod_tra_padre not in (v_cod_transaccion,202,203,110,133)
                   and not exists (select 1 from cj_cortes_tmp c
                                    where c.fecha = m.fecha
                                      and c.hora = m.hora
                                      and c.cod_usuario = m.cod_usuario
                                      and c.nro_secuencia = m.nro_secuencia );

              begin
                begin
                  select nvl(max(nro_corte),0) + 1
                    into v_nro_corte
                    from cj_cortes_tmp
                   where fecha = pae_cnf.fu_obt_fec_actual(v_cod_modulo)
                     and cod_usuario = v_cod_usuario;
                exception
                  when no_data_found then
                  v_nro_corte := 1;
                  when others then
                  v_nro_corte := 1;
                end;
                for k in c_cortes loop
                  begin
                    insert into
                       cj_cortes_tmp(fecha,hora,cod_usuario,nro_secuencia,
                                     cod_tra_padre,des_tra_padre,cod_oficina,
                                     cod_moneda,nro_caja,monto,tip_monto,nro_corte,
                                     cod_retencion)
                     values(k.fecha,k.hora,k.cod_usuario,k.nro_secuencia,
                            k.cod_tra_padre,fug_obt_des_transaccion(k.cod_mod_padre,
                                                                    k.cod_mad_padre,
                                                                    k.cod_tra_padre),
                            k.cod_oficina,k.cod_moneda,k.nro_caja,k.monto,k.tip_monto,
                            v_nro_corte, p_cod_retencion);
                  exception
                    when others then
                      v_cod_respuesta := '009';
                      v_msj_respuesta := 'Error al registrar el Corte. #';
                  end;

                end loop;
                begin
                  lp_gen_corte_tmp(v_nro_corte);
                exception
                  when others then
                  v_cod_respuesta := '010';
                  v_msj_respuesta := sqlerrm;
                end;
              exception
                when others then
                  v_cod_respuesta := '009';
                  v_msj_respuesta := 'Error al registrar el Corte.';
              end;

            end if;
          end if;
      end if;
 end if;


 --imprimir comprobante
 if v_cod_respuesta = '000' then
   v_cod_respuesta := 'IMP';
   v_tex_impresion := fuj_imp_comprobante_300(v_nro_corte, v_cod_oficina, p_nro_caja);
   v_msj_respuesta := 'Corte Confirmado. Comprobante impreso.'||'~'||
                       v_tex_impresion||'~'||v_tex_impresion;
 end if;

 /* armo finalmente el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_300;
/

