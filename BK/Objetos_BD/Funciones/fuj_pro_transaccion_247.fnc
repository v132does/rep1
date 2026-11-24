CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_247
 (p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
  p_nro_caja in varchar2,        -- Nro de Caja
  p_nro_boleta in varchar2    -- nro de operacion de cambios
 )
 RETURN VARCHAR2
 IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 247;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida    varchar2(4000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := ''; -- sin errores
  -- variables para guardar los datos de la operacion principal
  v_ope_cod_usuario   varchar2(10);
  v_ope_hora          varchar2(10);
  v_ope_fecha         date;
  v_ope_cod_moneda    varchar2(3);
  v_existe            varchar2(1) := 'N';
  --montos de la operacion
  v_che_nue_bco       number(18,2) := 0;
  v_che_otr_bco       number(18,2) := 0;
  v_che_otr_tar       number(18,2) := 0;
  v_che_otr_suc       number(18,2) := 0;
  v_mto_efectivo      number(18,2) := 0;
  ---
  rg_exo_tmp       ge_exoneraciones_tmp%rowtype;
  v_nro_pedido     ge_exoneraciones_tmp.nro_pedido%TYPE;
  -- Cursor de movimientos de la operacion
  cursor movimientos is
  Select a.nro_secuencia, a.cod_moneda, a.monto, a.estado, 
         a.cod_usuario, a.fecha, a.hora,a.cod_oficina,a.cod_ofi_origen,
         a.cod_transaccion, a.nro_documento2 nro_pedido
    from ge_movimientos a
   where nro_documento = to_number(p_nro_boleta)
     and estado = 'J'
     and reversado = 'N'
     --DYDMR-2548 ITGF - Retomar Mov Pend p/ Caja - Cobro de Cargos - SC 21582
     --and cod_tra_padre in (150,323,324,536,309,305,322,532)
     and (nvl(FUP_EXI_GRU_TRANSAC(31, a.cod_tra_padre, 4, 41), 'N') = 'S'
         or exists (select 1
                        from ge_transacciones t
                       where t.cod_transaccion = a.cod_tra_padre
                         and t.cod_modulo = a.cod_mod_padre
                         and t.cod_modalidad = a.cod_mad_padre
                         and t.cod_tasa is not null
                         and t.rutina1 is null
                         and nvl(t.afecta,'N') = 'N'
                         and fug_obt_tip_mov_contable(t.cod_modulo, t.cod_modalidad, t.cod_transaccion) = 'C'))
   order by nro_secuencia
   for update of a.cod_oficina;--ver!!
  mv movimientos%rowtype;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  v_nro_secuencia number := 0;
  begin
      -- sumar a los saldos  -- Actualizo el control de caja
      update cj_controles
         set tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_che_nue_bco,0),
             tot_che_otr_bco = nvl(tot_che_otr_bco,0) + nvl(v_che_otr_bco,0) + nvl(v_che_otr_tar,0) + nvl(v_che_otr_suc,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_che_otr_bco,0) + nvl(v_che_otr_tar,0) + nvl(v_che_otr_suc,0),
             sal_actual = nvl(sal_actual,0) + nvl(v_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_ope_cod_moneda
         and fecha = v_fec_caja;
       
      If nvl(v_mto_efectivo,0) > 0 then
        v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
      -- genero el movimiento 
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento,  monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_ope_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_mto_efectivo,'E','D');
      End if;
      If nvl(v_che_nue_bco,0) > 0 then
         v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
          insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento,  monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_ope_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_che_nue_bco,'C','D');
      End if;
      If nvl(v_che_otr_bco,0) > 0 then
          v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
          insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento,  monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_ope_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_che_otr_bco,'O','D');
      End if;
      If nvl(v_che_otr_tar,0) > 0 then
          v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
          insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento,  monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_ope_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_che_otr_tar,'T','D');
      End if;
      If nvl(v_che_otr_suc,0) > 0 then
          v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
          insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento,  monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_ope_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, v_che_otr_suc,'S','D');
      End if;            
  end lp_gen_transaccion;
begin
 -- Valido la boleta
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de la Operación.';
 else
    -- tomo los datos de la operacion principal
    declare
       v_nro_caja number(4);
    begin
      Select cod_usuario,hora,fecha,nro_caja,cod_moneda
        into v_ope_cod_usuario,  v_ope_hora,  v_ope_fecha, v_nro_caja,v_ope_cod_moneda
        from ge_movimientos a
       where estado = 'J'
         and a.nro_documento = to_number(p_nro_boleta)
         and reversado = 'N'
         --DYDMR-2548 ITGF - Retomar Mov Pend p/ Caja - Cobro de Cargos - SC 21582
         --and cod_tra_padre in (150,323,324,536,309,305,322,532)
         and (nvl(FUP_EXI_GRU_TRANSAC(31, a.cod_tra_padre, 4, 41), 'N') = 'S'
             or exists (select 1
                        from ge_transacciones t
                       where t.cod_transaccion = a.cod_tra_padre
                         and t.cod_modulo = a.cod_mod_padre
                         and t.cod_modalidad = a.cod_mad_padre
                         and t.cod_tasa is not null
                         and t.rutina1 is null
                         and nvl(t.afecta,'N') = 'N'
                         and fug_obt_tip_mov_contable(t.cod_modulo, t.cod_modalidad, t.cod_transaccion) = 'C'))
         and rownum = 1;
      if v_nro_caja is not null then
         v_cod_respuesta := '008';
         v_msj_respuesta := 'Operacion ya fue retomada en la Caja '||v_nro_caja;
      end if;               
    exception
       when no_data_found then
          v_cod_respuesta := '001';
          v_msj_respuesta := 'Operacion no registrada';
    end;   
    if v_cod_respuesta = '000' then 
      -- Inicializacion de la aplicacion y el modulo
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
      v_existe := 'N';
      -- Obtengo los datos de la caja en las monedas intervinientes --
       prj_obt_datos_caja(p_nro_caja,
                          v_ope_cod_moneda,
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
        v_msj_respuesta := 'Caja no esta habilitada en '||mv.cod_moneda||' para esta Operacion';
      elsif v_fec_caja <> v_fec_actual then
        v_cod_respuesta := '005'; -- error
        v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
      end if;
      for mv in movimientos loop
         v_existe := 'S';
         if v_cod_respuesta <> '000' then
            exit; -- sale cuando ya hay error
         end if;
         If mv.cod_transaccion = 740 then --Efectivo
            v_mto_efectivo   := mv.monto;
         elsif mv.cod_transaccion = 606 then --C/Ntro.Banco
            v_che_nue_bco   := mv.monto;
         elsif mv.cod_transaccion = 607 then --C/O/Bancos
            v_che_otr_bco := mv.monto;
         elsif mv.cod_transaccion = 610 then --C/O/Bancos
            v_che_otr_tar := mv.monto;
         elsif mv.cod_transaccion = 632 then --C/O/Bancos
            v_che_otr_suc := mv.monto;                        
         End if;
         --actualizar la oficina del movimiento q pasa x caja, si retoma en otra
         if v_cod_oficina <> mv.cod_ofi_origen then
            update ge_movimientos
               set cod_oficina = v_cod_oficina --la oficina q retoma
             where current of movimientos; 
         end if;
         v_nro_pedido := mv.nro_pedido;
      end loop;
      if v_existe = 'N' and v_cod_respuesta = '000' then
         v_cod_respuesta := '007'; -- error
         v_msj_respuesta := 'Operacion no debe ser ingresada a Caja.';
      end if;       
      if v_cod_respuesta = '000'  then
        -- actualizo los movimientos a 'N' y las cuentas asociadas a cada movimiento
        -- actualizo el movimiento al estado nuevo
         update ge_movimientos
            set estado = 'N',
                nro_caja = to_number(p_nro_caja)
          where cod_usuario = v_ope_cod_usuario
            and fecha       = v_ope_fecha
            and hora        = v_ope_hora;
        -- genero el movimiento en caja
        lp_gen_transaccion();
      end if;   
      --
    end if;      
    /*
    || PCC-Exoneración y Extorno de Comisiones y Tasas
    */
    begin
       select * 
         into rg_exo_tmp
         from ge_exoneraciones_tmp a
        where a.nro_pedido = v_nro_pedido;
    exception
       when no_data_found then
          rg_exo_tmp.nro_pedido := null;
       when too_many_rows then
          raise_application_error(-20000,'Mas de 1 solicitud pendiente para '||v_nro_pedido);
       when others then
          raise_application_error(-20000,'Al Obt.Exoneracion:'||sqlerrm);
    end;
    if rg_exo_tmp.nro_pedido is not null then
       prg_ins_exoneracion(rg_exo_tmp.cod_transaccion,
                           rg_exo_tmp.cod_modulo,
                           rg_exo_tmp.cod_modalidad,
                           rg_exo_tmp.cod_moneda,
                           rg_exo_tmp.nro_cuenta,
                           rg_exo_tmp.cod_persona,
                           rg_exo_tmp.cod_tasa,
                           rg_exo_tmp.mto_exoneracion,
                           rg_exo_tmp.mto_a_cobrar,
                           rg_exo_tmp.usu_insercion,
                           rg_exo_tmp.mto_exoneracion);
       update ge_exoneraciones_tmp a
          set a.estado = 'A'
        where a.nro_pedido = v_nro_pedido;
    end if;
    ---
  end if;
 
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'Operacion confirmada');
  return(v_msj_salida);

exception
   when others then
     v_cod_respuesta := '999';
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     nvl(v_msj_respuesta,SQLERRM);
     return(v_msj_salida);    
end;
/

