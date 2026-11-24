create or replace procedure it.prl_gen_mov_ope_fut_valeco(
p_nro_operacion IN VARCHAR

)
is
  v_ropfu lc_ope_futuras%rowtype;
  v_gmovi ge_movimientos%rowtype;
  v_rposi lc_posiciones%rowtype;
  --
  v_cod_mon_local      ba_monedas.cod_moneda%type;
  v_cotizacion         lc_ope_futuras.cotizacion%type;
  v_afe_posicion       lc_tip_operaciones.afe_posicion%type;
  v_afe_limite         lc_tip_operaciones.afe_limite%type;
  v_cod_tip_ope_bcp    lc_tip_operaciones.cod_tip_ope_bcp%type;
  v_cod_tip_ope_cambio ge_movimientos.cod_tip_ope_cambio%type;
  v_mto_equ_base       ge_movimientos.mto_equ_local%type;
  v_mto_equ_futuro     ge_movimientos.mto_equ_local%type;
  v_nro_secuencia      ge_movimientos.nro_secuencia%type := 0;
  v_fec_actual         ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(7);
  v_cod_ofi_trading    ge_movimientos.cod_oficina%type := fug_obt_pardinamico('LCA_COD_OFI_UTILIDAD');
  v_decimales          number(10);
  v_por_forward            number(18,2);
  --
  /*
  cursor ope is select nro_operacion,plazo
                  from lc_ope_futuras
                 where estado = 'N'
                   and fec_est_activo = v_fec_actual
                   and nro_operacion= p_nro_operacion ;
  */
  --**** Inserta los movimientos al Confirmar la Operación Futura ****--
  procedure lp_ins_mov_operacion is
  begin
    --
    select cod_oficina
      into v_gmovi.cod_ofi_origen
      from ba_usuarios
     where cod_usuario = user;
    --
    v_nro_secuencia :=  v_nro_secuencia + 1;
    --
    v_gmovi.nro_secuencia      := v_nro_secuencia;
    v_gmovi.fecha              := pae_cnf.fu_obt_fec_actual(7);
    v_gmovi.fec_valor          := v_gmovi.fecha;
    v_gmovi.hora               := to_char(sysdate,'hh24:mi:ss');
    v_gmovi.cod_persona        := v_ropfu.cod_persona;
    v_gmovi.nro_documento      := v_ropfu.nro_operacion;
    v_gmovi.concepto           := 'Alta Ope. Futura Nro. '||v_ropfu.nro_operacion;
    v_gmovi.cod_usuario        := user;
    v_gmovi.estado             := 'N';
    v_gmovi.reversado          := 'N';
    --
    v_gmovi.cod_mod_padre      := 7;
    v_gmovi.cod_mad_padre      := 76;
    v_gmovi.cod_tra_padre      := 761;
    --
    v_gmovi.cod_modulo         := v_ropfu.cod_modulo;
    v_gmovi.cod_oficina        := v_ropfu.cod_oficina;
    v_gmovi.referencia         := v_ropfu.nro_cuenta;
    v_gmovi.cod_modalidad      := v_ropfu.cod_mad_transaccion;
    v_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_cambio;
    --
    v_gmovi.cod_ref_cambio     := v_ropfu.cod_tip_referencia;
    v_gmovi.nro_documento2     := v_ropfu.nro_referencia;
    --**** Movimiento por Operacion Futura ****--
    --
    v_gmovi.cod_transaccion := 2356;
    --
    v_gmovi.monto         := v_ropfu.monto;
    v_gmovi.cod_moneda    := v_ropfu.cod_moneda;
    v_gmovi.cotizacion    := v_cotizacion;
    v_gmovi.mto_equ_local := v_mto_equ_base;
    --
    pag_gen.pr_ins_ge_movimiento(v_gmovi);

  exception
    when others then
      raise_application_error(-20000,'Error al generar el movimientos. '||sqlerrm);
  end;
  --
  --**** Actualiza el Límite ****--
  procedure lp_afe_limite is
  begin
    --wa:07/2013 Comentado inferior, agregado 2da Linea, debe afectar acorde a lo
    --parametrizado, no en duro.
    --if v_ropfu.monto > 0 and v_ropfu.cod_mad_transaccion = 71 then
    if v_ropfu.monto > 0 then
        --wa:07/2013 recuperamos el porcentaje de la operacion futura. *****************
        --Inicio de Modificacion
        v_por_forward:=NULL;
        begin
          if v_ropfu.plazo between 0 and 180  then
              v_por_forward:= to_number(nvl(fug_obt_pardinamico('CAM_AFE_LIM_FORWARD_180',7),0));
              if  v_por_forward <> 0 then
                  v_por_forward:= (pal_cam.fu_con_mon_a_moneda(v_ropfu.cod_moneda,
                                                        'USD',
                                                         v_ropfu.monto,--v_ropfu.monto,
                                                         v_cotizacion) * v_por_forward)/100;
              end if;
          else
              v_por_forward:= to_number(nvl(fug_obt_pardinamico('CAM_AFE_LIM_FORWARD_MAS_180',7),0));
              if  v_por_forward <> 0 then
                  v_por_forward:= (pal_cam.fu_con_mon_a_moneda(v_ropfu.cod_moneda,
                                                        'USD',
                                                         v_ropfu.monto,--v_ropfu.monto,
                                                         v_cotizacion) * v_por_forward)/100;
              end if;
          end if;
        exception
          when others then
            raise_application_error(-20000,'Error al calc. monto forward : '||sqlerrm);
        end;
       --wa:07/2013 Insertamos la retención de cambio *********************************
       begin
           insert into lc_retenciones
             (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
              cod_ofi_origen, nro_boleta, cod_retencion, monto,
              fec_inicio, fec_fin, cod_usuario, liberado,
              detallado, cod_moneda, cod_tip_referencia, nro_referencia)
           values(7,70,v_ropfu.cod_oficina,v_ropfu.nro_cuenta,
           v_ropfu.cod_oficina,v_ropfu.nro_operacion ,2, v_por_forward,
           v_gmovi.fecha,v_ropfu.fec_vencimiento,user,'N',
           'N','USD',999,v_ropfu.nro_referencia);
       exception
         when others then
          raise_application_error(-20000,'Error al insertar retencion : '||sqlerrm);

       end;
       --Fin de Modificaciòn

      update lc_cta_cambios
         set mto_utilizado = mto_utilizado +v_por_forward,
             fec_ult_movimiento = v_gmovi.fecha
       where nro_cuenta = v_ropfu.nro_cuenta;

       --
       -- Genera el movimiento por el límite utilizado.
       v_gmovi.cod_oficina        := v_ropfu.cod_oficina;
       v_gmovi.cod_modalidad      := v_ropfu.cod_mad_transaccion;
       v_gmovi.concepto           := 'Límite Utilizado Ope. Futura';
       v_gmovi.cod_tip_ope_cambio := null;
       v_gmovi.cod_transaccion    := 760;
       --
       v_nro_secuencia := v_nro_secuencia + 1;
       v_gmovi.nro_secuencia := v_nro_secuencia;
       --
       v_gmovi.monto         := v_por_forward;--v_ropfu.monto;
       v_gmovi.cod_moneda    := v_ropfu.cod_moneda;
       v_gmovi.cotizacion    := v_cotizacion;
       v_gmovi.mto_equ_local := v_mto_equ_base;
       --
       pag_gen.pr_ins_ge_movimiento(v_gmovi);
       --
       /*
        ---------------------------------------------------------------------
        :GLOBAL.MD_CDRETEN := 777; -- caso unico : hablar con NANCY
        :GLOBAL.MD_FCFINRE := TO_CHAR(:ABMC.SCR_FCLIQUI,'DD/MM/YYYY');
        ---------------------------------------------------------------------
        GENERA_MOV_FGDIARI;
       */
    end if;
  exception
    when others then
      raise_application_error(-20000,'Error al actualizar el Límite. '||sqlerrm);
  end;
  --
  --**** Actualiza la posición de Cambio ****--
  procedure lp_afe_posicion is
  begin
    -- inicializa variables
    v_rposi.mto_com_efe_act := 0;
    v_rposi.mto_com_efe_loc := 0;
    v_rposi.mto_com_nef_act := 0;
    v_rposi.mto_com_nef_loc := 0;
    v_rposi.mto_vta_efe_act := 0;
    v_rposi.mto_vta_efe_loc := 0;
    v_rposi.mto_vta_nef_act := 0;
    v_rposi.mto_vta_nef_loc := 0;
    --
    if v_ropfu.cod_mad_transaccion = 71 then
      -- Actualiza los campos de Compra
      if v_afe_posicion = 'E' then
        v_rposi.mto_com_efe_act := v_ropfu.monto;
        v_rposi.mto_com_efe_loc := v_mto_equ_base;
      else
        v_rposi.mto_com_nef_act := v_ropfu.monto;
        v_rposi.mto_com_nef_loc := v_mto_equ_base;
      end if;
    else
      -- Actualiza los campos de Ventas
      if v_afe_posicion = 'E' then
        v_rposi.mto_vta_efe_act := v_ropfu.monto;
        v_rposi.mto_vta_efe_loc := v_mto_equ_base;
      else
        v_rposi.mto_vta_nef_act := v_ropfu.monto;
        v_rposi.mto_vta_nef_loc := v_mto_equ_base;
      end if;
    end if;
    --
    begin
      -- Modifica la posición de cambio
      update lc_posiciones
         set mto_com_efe_act = nvl(mto_com_efe_act,0) + v_rposi.mto_com_efe_act,
             mto_com_efe_loc = nvl(mto_com_efe_loc,0) + v_rposi.mto_com_efe_loc,
             mto_com_nef_act = nvl(mto_com_nef_act,0) + v_rposi.mto_com_nef_act,
             mto_com_nef_loc = nvl(mto_com_nef_loc,0) + v_rposi.mto_com_nef_loc,
             mto_vta_efe_act = nvl(mto_vta_efe_act,0) + v_rposi.mto_vta_efe_act,
             mto_vta_efe_loc = nvl(mto_vta_efe_loc,0) + v_rposi.mto_vta_efe_loc,
             mto_vta_nef_act = nvl(mto_vta_nef_act,0) + v_rposi.mto_vta_nef_act,
             mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + v_rposi.mto_vta_nef_loc
       where cod_ofi_cambio  = v_ropfu.cod_oficina
         and cod_moneda      = v_ropfu.cod_moneda
         and cod_tip_ope_bcp = v_cod_tip_ope_bcp;
      --
      if sql%notfound then
        -- Si no existe inserta un nuevo registro
        insert into lc_posiciones(cod_moneda,
                                  cod_tip_ope_bcp,
                                  cod_ofi_cambio,
                                  mto_com_efe_act,
                                  mto_com_efe_loc,
                                  mto_com_nef_act,
                                  mto_com_nef_loc,
                                  mto_vta_efe_act,
                                  mto_vta_efe_loc,
                                  mto_vta_nef_act,
                                  mto_vta_nef_loc)
                          values (v_ropfu.cod_moneda,
                                  v_cod_tip_ope_bcp,
                                  v_ropfu.cod_oficina,
                                  v_rposi.mto_com_efe_act,
                                  v_rposi.mto_com_efe_loc,
                                  v_rposi.mto_com_nef_act,
                                  v_rposi.mto_com_nef_loc,
                                  v_rposi.mto_vta_efe_act,
                                  v_rposi.mto_vta_efe_loc,
                                  v_rposi.mto_vta_nef_act,
                                  v_rposi.mto_vta_nef_loc);
      end if;
      --
    end;
  exception
    when others then
      raise_application_error(-20000,'Error al modificar la Posición de Cambio. '||sqlerrm);
  end;
  --
begin
  --
  v_cod_mon_local  := pag_gen.fu_obt_mon_local;
  v_decimales      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local,null);
  /*for o in ope loop
    select *
      into v_ropfu
      from lc_ope_futuras
     where nro_operacion = o.nro_operacion;
     */

     select *
      into v_ropfu
      from lc_ope_futuras
     where  estado = 'N'
      and fec_est_activo = v_fec_actual
      and nro_operacion= p_nro_operacion;
    --
  if sql%found then
         --
    v_cotizacion     := pag_gen.fu_obt_cotizacion(v_ropfu.cod_moneda,v_fec_actual);
    v_mto_equ_base   := round(v_ropfu.monto * v_cotizacion,v_decimales);
    v_mto_equ_futuro := round(v_ropfu.monto * v_ropfu.cot_vencimiento,v_decimales);
    -- Obtiene el Tipo de Operación de Cambio
    if v_ropfu.cod_mad_transaccion = 71 then
      -- Es una Compra a Futuro
      v_cod_tip_ope_cambio := fug_obt_pardinamico('TIP_OPE_COM_FUTURA');
    else
      -- Es una Venta a Futuro
      v_cod_tip_ope_cambio := fug_obt_pardinamico('TIP_OPE_VEN_FUTURA');
    end if;
    --
    begin
      select nvl(afe_posicion,'N'), nvl(afe_limite,'N'), cod_tip_ope_bcp
        into v_afe_posicion, v_afe_limite, v_cod_tip_ope_bcp
        from lc_tip_operaciones o
       where cod_tip_operacion = v_cod_tip_ope_cambio;
    exception
      when others then
        raise_application_error(-20000,'Error al buscar Tipo de Operación de Cambio. '||sqlerrm);
    end;
    --
    -- Inserta Movimientos de confirmación de la Operación
    lp_ins_mov_operacion;
    --
    --**** Actualiza el Límite ****--
    if v_afe_limite = 'S' then
      lp_afe_limite;
    end if;
    --
    --**** Actualiza la posición de Cambio ****--
    if v_afe_posicion <> 'N' then
      lp_afe_posicion;
    end if;
    --
  end if;
  --end loop;
end;
/

