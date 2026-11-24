CREATE OR REPLACE PROCEDURE IT.PRG_VER_COB_CARGOS
 (p_nro_cta_ori  in ge_cuentas.nro_cuenta%type,
 p_nro_cta_des   in ge_cuentas.nro_cuenta%type,
 p_cod_modulo    in ge_cuentas.cod_modulo%type,
 p_cod_modalidad in ge_cuentas.cod_modalidad%type,
 p_cod_oficina   in ba_oficinas.cod_oficina%type,
 p_cod_moneda    in ge_cuentas.cod_moneda%type,
 p_monto         in GE_MOVIMIENTOS.MONTO%TYPE,
 p_concepto      in ge_movimientos.concepto%type,
 p_nro_boleta    in ge_movimientos.nro_documento%type,
 p_fecha         in date,
 p_hora          in out ge_movimientos.hora%type,
 p_cargo         in out number,
 p_nro_secuencia in out number,
 p_procesar      in varchar2 default 'S',
 p_cotizacion    in number  default null,
 p_estado        in varchar2 default 'N')
 IS
  v_fecha    DATE;
--  v_hora     ge_movimientos.hora%type;
  v_cobrar   varchar2(1):='N';
  v_cod_tasa ge_movimientos.cod_tasa%type;
  v_val_tasa ge_movimientos.val_tasa%type;
  rv_pres    pr_cta_prestamos%rowtype;
  r_gmovi    ge_movimientos%rowtype;
  v_redondeo_ml number(5);

BEGIN
  --x tipo de implementacion
  if fug_obt_tip_implementacion in (1,7) then
    v_fecha := p_fecha;
    p_nro_secuencia := nvl(p_nro_secuencia,0);
    v_cobrar := pag_cta.FU_VER_TRA_PROHIBIDA(p_nro_cta_des,572,p_cod_modulo,p_cod_modalidad);
    if v_cobrar = 'S' then -- tiene transaccion prohibida
       v_cobrar := 'N';
    else  
       v_cobrar := pag_cta.FU_VER_TRA_PROHIBIDA(p_nro_cta_ori,572,p_cod_modulo,p_cod_modalidad); 
       if v_cobrar = 'S' then -- tiene transaccion prohibida
          v_cobrar := 'N';
       else        
         --Verificar si se va a cobrar el impuesto ley 125
         v_cobrar := FUG_VER_EXO_IMPUESTO(p_nro_cta_ori, p_nro_cta_des);
       end if;  
    end if;
    If v_cobrar = 'S' then
      PRG_OBT_MTO_IMPUESTO(p_nro_cta_ori,
                    p_cod_oficina,
                    p_monto,
                    p_cargo,
                    v_cod_tasa,
                    v_val_tasa);
      --v_imp_credito := :cuentas.u_monto - nvl(v_impuesto,0);
    End if;

    If v_cobrar = 'S' and nvl(p_cargo,0) > 0 then
      --procesa
      if nvl(p_procesar,'S') ='S' then
        if v_fecha is null then
          v_fecha := pag_cal.fu_obt_fec_actual(1); -- fecha de hoy
        end if;
        if p_hora is null then
          p_hora := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
        end if;

        p_nro_secuencia := p_nro_secuencia + 1;

        r_gmovi.nro_secuencia   := p_nro_secuencia;
        r_gmovi.cod_usuario     := substr(upper(user), 1, 6);
        r_gmovi.hora            := p_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.cod_modulo      := p_cod_modulo;
        r_gmovi.cod_modalidad   := p_cod_modalidad;
        r_gmovi.cod_oficina     := p_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := p_cod_moneda;
        r_gmovi.fec_valor       := v_fecha;
        r_gmovi.cod_tra_padre   := 572;
        r_gmovi.cod_mod_padre   := p_cod_modulo;
        r_gmovi.cod_mad_padre   := p_cod_modalidad;
        r_gmovi.cod_transaccion := 572;
        r_gmovi.monto           := p_cargo;
        r_gmovi.nro_documento   := p_nro_boleta;
        r_gmovi.cod_tasa        := v_cod_tasa;
        r_gmovi.val_tasa        := v_val_tasa;
        r_gmovi.cotizacion      := p_cotizacion;
        r_gmovi.cod_ofi_origen  := p_cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := nvl(p_concepto,'Cobro de Cargos');
        r_gmovi.estado          := p_estado;
        r_gmovi.reversado       := 'N';
        v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo,p_cod_modalidad,pag_gen.FU_OBT_MON_LOCAL);
        r_gmovi.mto_equ_local   := round(p_cotizacion * p_cargo,v_redondeo_ml);
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      end if;
    else
      p_cargo :=0;
    End if;
  else
    p_cargo :=0;
  end if;
EXCEPTION
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'Ver Cobro Cargos: '|| sqlerrm);
END;
/

