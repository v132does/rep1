CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_358
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
 )
 RETURN long
 IS

-- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo      number(3)      := 9;    -- Caja
  v_cod_modalidad   number(3)      := 91;   -- Caja
  v_cod_transaccion number(4)      := 358;  -- transaccion
  v_cod_usuario     varchar2(10);--   := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_nro_cuenta        varchar2(20);      -- numero de cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  -- Datos de salida
  v_msj_salida    long;--varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta varchar2(4000) := 'Operacion Confirmada'; -- sin errores

  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';     -- 'C' credito para la caja (egreso)
  v_tip_monto     varchar2(1)  := 'E';     -- E efectivo
  v_nro_secuencia number(3) := 0;           -- secuencia del mov.

  v_mon_local     varchar2(3) := pag_gen.fu_obt_mon_local; -- moneda local
  v_mod_cobro     number(3) := 6 ; ---- modulo del préstamo
  v_mad_cobro     number(3);       ---- modalidad del préstamo

  --- para operaciones pendientes
  v_hora                varchar2(8) :=null;  --- para recuperar hora de oper.pendiente
  v_cod_tran_pend       number(4);           --- transaccion efectivo o cheque
  v_mto_desembolsar     number(18,2);        --- monto a desembolsar (ge_mov)
  v_nro_documento       number(15);
  v_existe              varchar2(1);
  -- cursor para desembolso en cta. recien se actualiza luego de pasar por caja
  -- actualiza la cta.ahorro y borra estos registros en estado J
  cursor cta_credito is
    select nro_cuenta, cod_moneda, nro_secuencia, monto, cod_ofi_origen,
    cod_mod_padre, cod_mad_padre, nro_documento
     from ge_movimientos 
     where fecha        = v_fec_actual 
     and hora           = v_hora  
     and cod_tra_padre   = 358 
     and  cod_transaccion = 602 
     and estado          = 'J' 
     for update ;

  reg        cta_credito%rowtype;
  v_sec_aux  ge_movimientos.nro_secuencia%type;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja

      update cj_controles
         set sal_actual   = nvl(sal_actual,0) - nvl(v_mto_desembolsar,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_desembolsar,0),
             can_creditos = nvl(can_creditos,0) + decode(v_mto_desembolsar,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;

       v_nro_secuencia := 0;

        -- genero el movimiento por el desembolso  - efectivo -

       --v_nro_secuencia := v_nro_secuencia + 1;

       begin
        select nro_secuencia
          into v_nro_secuencia
          from cj_movimientos a
         where a.fecha = v_fec_actual
           and a.hora = v_hor_actual
           and a.nro_caja = to_number(p_nro_caja)
           and a.nro_secuencia = (select max(nro_secuencia)
                                    from cj_movimientos b
                                   where b.fecha = v_fec_actual
                                     and b.hora = v_hor_actual
                                     and b.nro_caja = to_number(p_nro_caja));
       if sql%found then
          v_nro_secuencia := v_nro_secuencia + 1;
       end if;
       exception
         when no_data_found then
            v_nro_secuencia := 1;
         when others then
            v_cod_respuesta := '999';
            v_msj_respuesta := 'ERROR al traer.nro.secuencia :'||SQLERRM;
       end;

        --FECHA,HORA,COD_USUARIO,NRO_SECUENCIA

        --v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (nro_cuenta,fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           (p_nro_cuenta,v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            v_nro_documento, v_mto_desembolsar,'E', v_tipo);

  end lp_gen_transaccion;

  ---------------- INICIO DEL PROCESO PRINCIPAL ------------------
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 -- Valido la moneda
 if p_nro_cuenta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Cuenta.';
 else
    -- obtengo datos de la cuenta  prestamo --
    begin
      Select p.cod_moneda, p.estado, p.cod_modulo, p.cod_modalidad
        into v_cod_moneda, v_est_cuenta, v_mod_cobro, v_mad_cobro
        from ge_cuentas p
       where p.nro_cuenta = p_nro_cuenta;

      if v_mod_cobro <> 6  then
        v_cod_respuesta := '004';
        v_msj_respuesta := 'ERROR: Cuenta no es de Préstamo !';
      end if;
      ----- aqui veo si viene de retomar pendiente o no -----
      prj_ver_pen_caja(p_nro_cuenta,
                       v_cod_transaccion,
                       v_fec_actual,
                       v_cod_usuario,
                       v_hora,
                       v_cod_tran_pend,
                       v_cod_respuesta,
                       v_msj_respuesta);
      --carga como actual la hora del movimiento
      v_hor_actual := v_hora;
      if v_cod_usuario is null then
        --no se retoma, tonces el usuario es el cajero
        v_cod_usuario := upper(user);
      end if;
 
      if v_cod_respuesta = '000' then  ---- error no hay pendientes
         v_cod_respuesta := '005';
         v_msj_respuesta := 'ERROR: no hay pendientes para esta Cta.!';
      else--retoma
         v_cod_respuesta := '000';
         Begin
            select sum(nvl(monto,0)) into v_mto_desembolsar 
            from  ge_movimientos 
            where fecha         = v_fec_actual 
            and  hora          = v_hora 
            and  cod_tra_padre = v_cod_transaccion 
            and  cod_modulo    = 6  --- para que no tome lo de ahorros porque no afecta a la caja
            and  estado        = 'J' ;
         exception
            when no_data_found then
                v_cod_respuesta := '008';
                v_msj_respuesta := 'ERROR: No encuentra desembolso pendiente para esta cta.';
            when others then
                v_cod_respuesta := '009';
                v_msj_respuesta := 'ERROR: al buscar mov.desembolso pendiente.'||sqlerrm;
            end;
      end if;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro de Cuenta no existe!';
      when others then
        v_cod_respuesta := '007';
        v_msj_respuesta := 'ERROR' || sqlerrm;
    end;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- Obtengo los datos de la caja --
       prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques);
       if v_estado = -1 then
          v_cod_respuesta := '006'; -- error, no existe registro de caja
          v_msj_respuesta := 'Caja inexistente!!';
       elsif v_estado in (0,2) then
          v_cod_respuesta := '004'; -- error
          v_msj_respuesta := 'Realice la Apertura de Caja previamente';
       elsif v_fec_caja <> v_fec_actual then
          v_cod_respuesta := '005'; -- error
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
       end if;
    end if;
    if v_cod_respuesta = '000' then
       -- verifico importe
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_desembolsar,v_cod_transaccion);

       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- Actualiza cta ahorro si es desembolso en cta
          for reg in cta_credito loop
             begin
               delete from ge_movimientos where current of cta_credito;
             exception
               when others then
                 v_cod_respuesta := '110';
                 v_msj_respuesta := 'ERROR al Borrar de ge_movimientos :'||SQLERRM;
             end;
             v_sec_aux       := reg.nro_secuencia-1;
             v_nro_documento := reg.nro_documento;

             pag_cta.pr_act_operacion(reg.nro_cuenta,
 						       v_hora,--HORA
     						   'C',
     						   reg.cod_moneda,      --Moneda de la Operación
     						   reg.monto,
     						   358,--COD_TRA_PADRE (Desembolso de Préstamo)
     						   602,-- COD_TRA_HIJO (602)
                   reg.nro_documento,
     						   NULL,                    --COTIZACION
     						   reg.cod_ofi_origen,      --cod_ofi_origen
     						   reg.cod_mod_padre,       --cod_mod_padre
    						   reg.cod_mad_padre,       --cod_mad_padre
    						   null,                    --cod_tasa
    						   null,                    --val_tasa
     						   'Desembolso Solicitud : '||reg.nro_documento,
    						   'S',                     --emi_aviso
    						   v_sec_aux,               --- porque el proc.le suma 1
    						   v_fec_actual);

             if pag_cta.fu_obt_cod_error() <> 0 then
                v_cod_respuesta :='010';
                v_msj_respuesta := 'Error al act.cta.'||pag_cta.g_cod_error||'-'||pag_cta.g_msj_error;
             end if;

          end loop;
          --
          if v_nro_documento is null then --- busco el nro_documento
             begin
               select nro_documento into v_nro_documento
               from ge_movimientos 
               where fecha   = v_fec_actual 
               and hora    = v_hora  
               and cod_tra_padre   = 358 
               and cod_transaccion in (602,840) 
               and estado = 'J' 
               and rownum = 1;
             exception
                when others then
                   null;
             end;
          end if;
 
          --si ya existe la pk, hallar sgte seg y actualizar ge_mov. e insertar cj_mov.
  			  /*begin
	  		     select 'S'
 		  		   into v_existe
 			  	   from cj_movimientos
				     where fecha = v_fec_actual
  				   and hora = v_hor_actual -- la hora del mov
	  			   and cod_usuario = v_cod_usuario;
		  	  exception
			       when no_data_found then
				       v_existe :='N';
				     when others then
               v_cod_respuesta := '990';
               v_msj_respuesta := 'ERROR AL RECUP.CJ_MOVIMIENTOS EXISTENTE:'||SQLERRM;
		      end;
          if v_existe = 'S' then
		         v_hor_actual:= PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hor_actual);
   		    end if;*/
          -- Actualiza operaciones pendientes   : caja y estado
          begin
             update ge_movimientos set estado='N' ,
                     nro_caja = to_number(p_nro_caja),
                     cod_oficina = v_cod_oficina
              where cod_tra_padre = v_cod_transaccion and
                     fecha         = v_fec_actual and
                     hora          = v_hora and
                     estado        = 'J';
          exception
             when no_data_found then
                v_cod_respuesta := '002';
                v_msj_respuesta := 'No encontro ge_movimientos pendientes :'||sqlerrm;
             when others then
                v_cod_respuesta := '999';
                v_msj_respuesta := 'ERROR al Act.movim.pendientes :'||SQLERRM;
          end;

           /*  if pag_cta.g_cod_error <> 0 then
                -- actualizacion con problemas
                v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
                v_msj_respuesta := pag_cta.g_msj_error;
             else -- genero la transaccion en caja
           */

          lp_gen_transaccion();

           --  end if;
       end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_358;
/

