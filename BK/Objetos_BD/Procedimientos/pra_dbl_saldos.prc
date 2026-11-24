create or replace procedure it.pra_dbl_saldos(p_nro_cuenta     ge_bloqueos.nro_cuenta%type,
                                              p_nro_cta_debito ge_bloqueos.nro_cuenta%type,
                                              p_fec_inicio     ge_bloqueos.fec_inicio%type,
                                              p_monto          ge_bloqueos.monto%type,
                                              p_nro_documento  ge_bloqueos.nro_documento%type,
                                              p_cod_moneda     ge_movimientos.cod_moneda%type,
                                              p_cod_causa      ge_bloqueos.cod_causa%type,
                                              p_cod_oficina    ge_movimientos.cod_oficina%type,
                                              p_cod_modulo     ge_movimientos.cod_modulo%type,
                                              p_cod_modalidad  ge_movimientos.cod_modalidad%type,
                                              p_cod_error      out number) is

  v_det_error     varchar2(4000);
  v_lugar         varchar2(4000);
  v_cod_error     number;
  v_fec_actual    ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
  r_gmovi         ge_movimientos%rowtype;
  v_horario       varchar2(1) := 'D';
  v_est_modulo    ba_modulos.estado%type;
  v_es_nocturno   varchar2(1) := 'N';
  v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
  v_hora          varchar2(8) := to_char(sysdate, 'hh24:mi:ss');
  v_cod_mon_local ba_monedas.cod_moneda%type;

begin
  -- Actualiza estado y fecha
  begin
    update ah_cta_vistas
       set estado = 'N', fec_cam_estado = v_fec_actual
     where nro_cuenta = p_nro_cta_debito; -- cta caja de ahorro
  exception
    when others then
      v_det_error := 'No se puede actualizar estado a N.';
      it.prg_ins_log_programas('PRA_DBL_SALDOS',
                               v_lugar || ' - ' || v_det_error,
                               null,
                               null);
  end;
  if sql%notfound then
    v_cod_error := 99;
    v_lugar     := 'Actualiza estado en ah_cta_vistas.';
    v_det_error := 'Ningun registro procesado para la cuenta ' ||
                   p_nro_cta_debito;
  
    it.prg_ins_log_programas('PRA_DBL_SALDOS',
                             v_lugar || ' - ' || v_det_error,
                             null,
                             p_nro_cta_debito);
  
  end if;
  -- Si no hubo error en el desbloqueo de saldo 
  -- Se elimina el registro de ge_bloqueos
  if nvl(v_cod_error, 0) = 0 then
    delete from ge_bloqueos
     where nro_cuenta = p_nro_cta_debito -- p_nro_cuenta
       and nro_documento = p_nro_documento
       and cod_causa = p_cod_causa
       and tipo = 'S';
  
    if sql%notfound then
      v_lugar     := 'Elimina registro de ge_bloqueos.';
      v_det_error := 'Ningun registro procesado para la cuenta ' ||
                     p_nro_cta_debito;
    
      it.prg_ins_log_programas('PRA_DBL_SALDOS',
                               v_lugar || ' - ' || v_det_error,
                               null,
                               p_nro_cta_debito);
    end if;
    -- Inserta movimiento
    v_horario    := 'D';
    v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
  
    if v_est_modulo != 2 then
      v_horario     := 'N';
      v_es_nocturno := 'S';
    else
      v_horario     := 'D';
      v_es_nocturno := 'N';
    end if;
    if v_nro_secuencia + 2 > 999 then
      v_nro_secuencia := 0;
      v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
      r_gmovi.hora    := v_hora;
    end if;
    pag_cta.g_horario := v_horario;
    v_nro_secuencia   := 0;
    v_cod_mon_local   := pag_gen.fu_obt_mon_local;
  
    -- Inicializa 
    r_gmovi.cod_usuario       := user;
    r_gmovi.hora              := v_hora;
    r_gmovi.nro_secuencia     := v_nro_secuencia + 1;
    r_gmovi.cod_modulo        := p_cod_modulo;
    r_gmovi.cod_modalidad     := p_cod_modalidad;
    r_gmovi.cod_oficina       := p_cod_oficina;
    r_gmovi.nro_cuenta        := p_nro_cta_debito;
    r_gmovi.cod_moneda        := p_cod_moneda;
    r_gmovi.fec_valor         := v_fec_actual;
    r_gmovi.fecha             := v_fec_actual;
    r_gmovi.cod_tra_padre     := 317;
    r_gmovi.cod_transaccion   := 415;
    r_gmovi.nro_documento     := null;
    r_gmovi.monto             := NULL;
    r_gmovi.estado            := 'N';
    r_gmovi.est_cuenta        := 'N';
    r_gmovi.cod_causa         := p_cod_causa;
    r_gmovi.cod_ofi_origen    := p_cod_oficina;
    r_gmovi.concepto          := NULL;
    r_gmovi.cod_tasa          := NULL;
    r_gmovi.val_tasa          := NULL;
    r_gmovi.reversado         := 'N';
    r_gmovi.cod_usu_reversion := NULL;
    r_gmovi.hor_reversion     := NULL;
    r_gmovi.emi_aviso         := 'N';
    r_gmovi.protegido         := 'N';
    r_gmovi.cod_mod_padre     := p_cod_modulo;
    r_gmovi.cod_mad_padre     := p_cod_modalidad;
  
    pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
    p_cod_error := v_cod_error;
  else
    p_cod_error := v_cod_error;
    rollback;
  end if;
exception
  when others then
    v_lugar     := 'When others del proceso PRA_DBL_SALDOS.';
    v_det_error := sqlerrm;
    it.prg_ins_log_programas('PRA_DBL_SALDOS',
                             v_lugar || ' - ' || v_det_error,
                             null,
                             null);
  
end;
/

