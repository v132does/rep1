CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_261
 (p_nro_operacion  in varchar2,   -- Nro de referencia de la operacion
  p_nro_caja       in varchar2,   -- Nro de Caja
  p_cod_bien       in number
 )
RETURN varchar2
IS
  v_cod_usuario     ba_usuarios.cod_usuario%type:=user;
  v_cod_moneda      ba_monedas.cod_moneda%type;
  v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;  
--
  v_fec_caja        date;              -- fecha de la caja  
  v_tipo            varchar2(01) := 'D' ;     -- 'C' credito para la caja (egreso) o vice versa  
  v_tip_monto       varchar2(01) := 'O';       -- E efectivo / O cheque otros Bcos  
  v_estado          number(1);         -- estado de la caja  
  v_sal_actual      number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques     number(18,2);      -- saldo actual de la caja en cheques  
-- variables del el movimiento
  v_hora            varchar2(8);
  v_nro_secuencia   ge_movimientos.nro_secuencia%type:=0;  
  v_cod_modulo      ge_movimientos.cod_modulo%type := 26;        -- modulo Caja
  v_cod_modalidad   ge_movimientos.cod_modalidad%type := 261;
  v_cod_transaccion ge_movimientos.cod_transaccion%type := 261;
  v_cod_mod_padre       number(3) := 26 ; ---- modulo del préstamo
  v_cod_mad_padre       number(3) := 261; ---- modalidad del préstamo  
  v_fec_actual      ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina     ge_movimientos.cod_oficina%type;
  v_nro_documento   ge_movimientos.nro_documento%type;
  v_emi_aviso       ge_movimientos.emi_aviso%type := 'S';  
--
  v_msj_salida      varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta   varchar2(03) := '000'; -- sin errores
  v_msj_respuesta   varchar2(100) := 'OK'; -- sin errores
  v_movimientos     varchar2(1):= 'N';  
  v_efectivo        ge_movimientos.monto%type;
  v_cheque          ge_movimientos.monto%type;
--  v_cta_contable    ge_movimientos.monto%type;
  v_monto_cheque_n  ge_movimientos.monto%type;  
  v_monto           ge_movimientos.monto%type := 0;  
  v_cod_tra_cheque  ge_movimientos.cod_transaccion%type;    
--
  cursor c_cobros is
    select cod_transaccion, sum(monto) monto, 
           min(hora) hora, cod_moneda
      from ge_movimientos c
     where cod_tra_padre = v_cod_transaccion
       and fecha  = v_fec_actual
       and nro_documento = p_cod_bien
       and c.hora = (select min (hora)
                     from ge_movimientos d
                    where d.fecha = c.fecha
                      and d.cod_usuario = c.cod_usuario
                      and d.estado = 'J'                      
                      and d.nro_documento = c.nro_documento
                      and d.cod_tra_padre = c.cod_tra_padre)
     group by cod_transaccion, cod_moneda;
-- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
       update cj_controles
         set tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_cheque,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_cheque,0),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_monto_cheque_n,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;

       v_nro_secuencia := 0;

       --si retoma operacion tiene q pasarle modulo y modalidad de la operacion
       --solo si retoma el usuario es el del mov. sino es el user
      -- genero el movimiento por el pago de la cuota (cheque y/o efectivo)
      if v_efectivo > 0 then
        -- genero el movimiento por el efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hora, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_mod_padre, v_cod_modulo), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_mad_padre, v_cod_modalidad),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_documento, v_efectivo,'E', v_tipo);  -- es debito
      end if;
      if v_cheque > 0 then
        -- genero el movimiento por el deposito en cheques (local - otros bcos )
        if v_cod_tra_cheque = 607 then --24hs
          v_tip_monto := 'O';
        elsif v_cod_tra_cheque = 610 then --48hs
          v_tip_monto := 'T';
        elsif v_cod_tra_cheque = 632 then --72hs
          v_tip_monto := 'S';
        elsif v_cod_tra_cheque = 632 and v_cod_moneda <> v_cod_mon_local then --72hs
          v_tip_monto := 'X';
        end if;
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hora, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_mod_padre, v_cod_modulo), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_mad_padre, v_cod_modalidad),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_documento, v_cheque ,v_tip_monto , v_tipo); -- es debito
      end if;
      if v_monto_cheque_n > 0 then
        -- genero el movimiento por el deposito en cheques (local - ntro bco )
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hora, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,
            decode(nvl(v_hora,'X'),'X', v_cod_mad_padre, v_cod_modulo), --ve si retoma
            decode(nvl(v_hora,'X'),'X', v_cod_mad_padre, v_cod_modalidad),--ve si retoma
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_documento, v_monto_cheque_n ,'C' , v_tipo); -- es debito
       end if;
  end lp_gen_transaccion;
Begin
-------------------------PROCESO PRINCIPAL-------------------------
  -- Inicializacion de la aplicacion y el modulo
  Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= v_cod_modulo; End;
  v_nro_documento := p_cod_bien;
  for reg in c_cobros loop
     v_movimientos := 'S';
     v_hora        := reg.hora;
     v_monto       := v_monto + nvl(reg.monto,0);
     v_cod_moneda  := reg.cod_moneda;
     if reg.cod_transaccion = 740 then
       v_efectivo := reg.monto;
     elsif reg.cod_transaccion in (607, 610, 632) then
       v_cheque := reg.monto;
       v_cod_tra_cheque := reg.cod_transaccion;
     elsif reg.cod_transaccion = 606 then
       v_monto_cheque_n := reg.monto;
/*     elsif reg.cod_transaccion = 842 then
       v_cta_contable := reg.monto;*/
     end if;
  end loop;
  -- Obtengo los datos de la caja --
  prj_obt_datos_caja( p_nro_caja,
                      v_cod_moneda,
                      v_cod_oficina,
                      v_fec_caja,
                      v_estado,
                      v_sal_actual,
                      v_sal_cheques );
 
    if v_cod_respuesta = '000' then
      --actualizar el movimiento
      begin
        update ge_movimientos
           set estado           = 'N',
               nro_caja         = to_number(p_nro_caja),
               cod_oficina      = v_cod_oficina,
               emi_aviso        = v_emi_aviso
          where cod_tra_padre   = v_cod_transaccion
            and fecha           = v_fec_actual
            and hora            = v_hora
            and estado          = 'J';
      exception
        when no_data_found then
         v_cod_respuesta := '002';
         v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
        when others then
         v_cod_respuesta := '999';
         v_msj_respuesta := 'Error al Act. movim.pendientes :'||SQLERRM;
      end;  
    end if;
--  end if;
  if v_cod_respuesta = '000' then
    v_cod_modulo    := 9;
    v_cod_modalidad := 91;
    lp_gen_transaccion;
  end if;
  -- Sin no hay errores modifica la tabla Bienes.
  if v_cod_respuesta = '000' then
	   begin
	   	 update bu_bienes
	   	    set fec_venta = v_fec_actual,
	   	        estado		= 'V'
	   	  where cod_bien = p_cod_bien;
	   exception
       when no_data_found then
         v_cod_respuesta := '002';
         v_msj_respuesta := 'No encontro bien para modificar'||sqlerrm;
       when others then
         v_cod_respuesta := '999';
         v_msj_respuesta := 'Error al Act. bien :'||SQLERRM;
      end;
  end if;
  if v_cod_respuesta = '000' then
    v_msj_respuesta := 'Operación Confirmada';
  end if;
  pag_cta.pr_nro_caja(null);
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'Operación Confirmada');
 return(v_msj_salida);
exception
    when others then
       pag_cta.pr_nro_caja(null);
       v_msj_salida := p_nro_operacion||'~'||'999'||'~!'||sqlerrm;
      return(v_msj_salida);
end;
/

