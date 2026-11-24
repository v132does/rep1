create or replace procedure it.prp_gen_asi_fideicomiso(p_proceso         varchar2,
                                                      p_nro_cuenta      in pr_cta_prestamos.nro_cuenta%type,
                                                      p_modulo          in pr_cta_prestamos.cod_modulo%type,
                                                      p_hora            in ge_movimientos.hora%type,
                                                      p_cod_mod_destino in number,
                                                      p_error           out varchar2,
                                                      p_men_error       out varchar2) is
  --Realiza generacion de movimientos por el pase a fideicomiso y restitucion
  v_secuencia ge_movimientos.nro_secuencia%type := 0;
  v_det_error ge_log_errores.det_error%type;
  --v_horamovim ge_movimientos.hora%type:=null;
  v_cod_modulo       ba_modulos.cod_modulo%type;
  v_cod_modalidad    ge_modalidades.cod_modalidad%type;
  v_modalidad_origen ge_modalidades.cod_modalidad%type;
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_nro_cuenta       pr_cta_prestamos.nro_cuenta%type;
  v_cod_moneda       pr_cta_prestamos.cod_moneda%type;
  v_fcdehoy          date := pag_cal.fu_obt_fec_actual(6);
  v_mone_local       ba_monedas.cod_moneda%type;
  v_cotizacion       ge_cotizaciones.val_compra%type;
  v_sal_cap          pr_cuotas.sal_capital%type;
  v_sal_intautor     pr_cuotas.sal_capital%type;
  v_sal_int          pr_cuotas.sal_interes%type;
  rp_pcpre           pr_cta_prestamos%rowtype;
  v_tipo             pr_cta_prestamos.tipo%type;
  v_cod_transaccion  ge_transacciones.cod_transaccion%type;
  v_descripcion      ge_transacciones.descripcion%type;
  v_adevengar        pr_cuotas.sal_capital%type;
  v_mto_prev         ge_movimientos.monto%type;
  v_mto_dev_suspenso pr_cta_prestamos.dev_suspenso%type;
  v_mto_capital      ov_ope_vencidas.sal_tot_batch%type;
  v_mto_prevision    ge_movimientos.monto%type;
  r_vcven            ov_cta_vencidas%rowtype;
  v_cod_tra_padre    ge_movimientos.cod_tra_padre%type;
  v_sig              number;

  ex_error exception;

  /* Realizar insercion de movimientos por el pase a fideicomiso. */
  procedure pr_ins_asiento(p_cod_tra_padre   in ge_movimientos.cod_tra_padre%type,
                           p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                           p_monto           in ge_movimientos.monto%type,
                           p_concepto        in ge_movimientos.concepto%type,
                           p_hora            in ge_movimientos.hora%type,
                           p_error           out varchar2,
                           p_men_error       out varchar2) is
    r_mvto     ge_movimientos%rowtype;
    v_redondeo number(5);
  BEGIN
    p_error := 0;

    if v_secuencia + 3 > 999 then
      v_secuencia := 0;
    else
      v_secuencia := v_secuencia + 1;
    end if;
    if p_proceso = 'RES' then
      r_mvto.cod_modalidad   := v_modalidad_origen;
      r_mvto.cod_mad_padre  := v_cod_modalidad;
    else
      r_mvto.cod_modalidad   := v_cod_modalidad;
      r_mvto.cod_mad_padre  := v_cod_modalidad;
    end if;
    r_mvto.nro_secuencia   := v_secuencia;
    r_mvto.cod_usuario     := upper(user);
    r_mvto.hora            := p_hora;
    r_mvto.cod_modulo      := v_cod_modulo;
    --r_mvto.cod_modalidad   := v_cod_modalidad;
    r_mvto.cod_oficina     := v_cod_oficina;
    r_mvto.nro_cuenta      := v_nro_cuenta;
    r_mvto.cod_moneda      := v_cod_moneda;
    r_mvto.cod_tra_padre   := p_cod_tra_padre;
    r_mvto.cod_transaccion := p_cod_transaccion;
    r_mvto.fecha           := v_fcdehoy;
    r_mvto.fec_valor       := v_fcdehoy;
    r_mvto.nro_documento   := NULL;
    r_mvto.monto           := p_monto;
    r_mvto.estado          := 'N';
    -- r_mvto.est_cuenta      := p_estado;
    r_mvto.cod_ofi_origen := v_cod_oficina;
    r_mvto.concepto       := p_concepto;
    r_mvto.reversado      := 'N';
    r_mvto.emi_aviso      := 'N';
    r_mvto.protegido      := 'N';
    r_mvto.cod_mod_padre  := v_cod_modulo;
   -- r_mvto.cod_mad_padre  := v_cod_modalidad;
    if r_mvto.cod_moneda = v_mone_local then
      --es moneda local
      r_mvto.mto_equ_local := null;
      r_mvto.cotizacion    := null;
    else
      --es moneda extranjera debe redondear a los decimales de la moneda local
      v_redondeo           := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                  v_cod_modulo,
                                                  v_cod_modalidad,
                                                  v_mone_local);
      r_mvto.mto_equ_local := ROUND(p_monto * v_cotizacion, v_redondeo);
      r_mvto.cotizacion    := v_cotizacion;
    end if;
    pag_gen.pr_ins_ge_movimiento(r_mvto);
  exception
    when others then
      p_error     := 100;
      p_men_error := substr('Error al insertar mvto. por pase a fideicomiso ' ||
                            v_nro_cuenta || sqlerrm,
                            1,
                            4000);
  end;
  /* Obtener saldos capital e interes de un prestamo. */
  procedure pr_obt_cap_int_pres(p_nro_cuenta  in pr_cta_prestamos.nro_cuenta%type,
                                p_sal_capital in out pr_cuotas.sal_capital%type,
                                p_sal_interes in out pr_cuotas.sal_interes%type,
                                p_sal_x       in out pr_cuotas.sal_capital%type) is
  begin
    select sum(nvl(sal_capital, 0)),
           sum(nvl(sal_interes, 0) + nvl(sal_int_documentado, 0))
      into p_sal_capital, p_sal_interes
      from pr_cuotas
     where nro_cuenta = p_nro_cuenta
       and nro_cuota > 0
       and estado not in ('N', 'X');
    --
    select sum(nvl(sal_interes, 0) + nvl(sal_int_documentado, 0))
      into p_sal_x
      from pr_cuotas
     where nro_cuenta = p_nro_cuenta
       and nro_cuota > 0
       and estado = 'X';
    --
  exception
    when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error('-20021',
                                'NO pudo obtener capital PR_CUOTAS ' ||
                                'p/el prestamo ' || p_nro_cuenta);
      end if;
  end;
  /* Obtener saldos capital y prevision para operaciones vencidas */
  procedure pr_obt_cap_prv_ope_venc(p_nro_cuenta    in pr_cta_prestamos.nro_cuenta%type,
                                    p_sal_capital   in out ov_cta_vencidas.sal_tot_batch%type,
                                    p_sal_prevision in out ge_movimientos.monto%type) is
  begin
    SELECT t.sal_tot_batch, nvl(ov_previsiones.monto, 0)
      into p_sal_capital, p_sal_prevision
      FROM ov_cta_vencidas t,
           ge_clientes ge,
           ge_cta_clientes gcc,
           (SELECT a.monto, a.nro_cuenta
              FROM ov_previsiones a
             WHERE a.fecha = (SELECT MAX(b.fecha)
                                FROM ov_previsiones b
                               WHERE a.nro_cuenta = b.nro_cuenta)) ov_previsiones

     WHERE t.nro_cuenta = gcc.nro_cuenta
       AND ge.cod_persona = gcc.cod_persona
       AND gcc.relacion = 'P'
       AND t.est_batch <> 'C'
       AND ov_previsiones.nro_cuenta(+) = t.nro_cuenta
       and t.nro_cuenta = p_nro_cuenta;

  exception
    when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error('-20021',
                                'NO pudo obtener capital PR_CUOTAS ' ||
                                'p/el prestamo ' || p_nro_cuenta);
      end if;
  end;
  /* Recupera monto prevision de ge_cla_operaciones. */
  function fu_obt_prevision(p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type)
    return number is
    v_prevision ge_cla_operaciones.tot_prevision%type;
  begin
    select nvl(sum(nvl(monto, 0)), 0)
      into v_prevision
      from pr_previsiones
     where nro_cuenta = p_nro_cuenta
       and fecha = (select max(fecha)
                      from pr_previsiones
                     where nro_cuenta = p_nro_cuenta
                       and fecha <= v_fcdehoy);
    return v_prevision;
  exception
    when others then
      if sqlcode <= -20000 then
        raise;
      else
        raise_application_error(-20000,
                                'Recup. Prevision - Cta: ' || p_nro_cuenta);
      end if;
  end;

begin

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  p_error     := 0;
  p_men_error := NULL;
  if p_proceso = 'FID' then
    v_cod_tra_padre := 981;
    v_sig           := 1;
  elsif p_proceso = 'RES' then
    v_cod_tra_padre := 982;
    v_sig           := -1;
    v_modalidad_origen:= to_number(fug_obt_paradicional(p_nro_cuenta,
                                     'MOD_CAM_MOD_DESTINO'));
  end if;
  if p_modulo = 6 then
    pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, rp_pcpre);
    pr_obt_cap_int_pres(p_nro_cuenta, v_sal_cap, v_sal_int, v_sal_intautor);
    v_adevengar        := rp_pcpre.val_int_devengar; --se usa en pr_pro_cam_est_prest
    v_mto_prev         := fu_obt_prevision(rp_pcpre.nro_cuenta);
    v_mto_dev_suspenso := rp_pcpre.dev_suspenso;
    v_cod_modulo       := p_modulo;
    v_cod_modalidad    := p_cod_mod_destino;
    v_cod_oficina      := rp_pcpre.cod_oficina;
    v_nro_cuenta       := rp_pcpre.Nro_Cuenta;
    v_cod_moneda       := rp_pcpre.cod_moneda;
    v_mone_local       := pag_gen.fu_obt_mon_local;
    v_fcdehoy          := pag_cal.fu_obt_fec_actual(6);
    if rp_pcpre.cod_moneda <> v_mone_local then
      v_cotizacion := pag_gen.fu_obt_cotizacion(rp_pcpre.cod_moneda,
                                                v_fcdehoy);
    else
      v_cotizacion := null;
    end if;
    if nvl(v_sal_cap, 0) > 0 then
      /************
           CAPITAL
      **************/
      if rp_pcpre.estado IN ('C') then
        v_tipo := rp_pcpre.tipo;
      else
        v_tipo := null;
      end if;
      --obtiene la transaccion a utilizar
      prp_obt_tran_fideicomiso(p_modulo,
                               'CA',
                               rp_pcpre.estado,
                               p_cod_mod_destino,
                               v_tipo,
                               p_nro_cuenta,
                               v_cod_transaccion,
                               v_descripcion);

      if v_cod_transaccion is not null then
        if v_cod_transaccion < 0 then
          --error
          p_error     := 110;
          p_men_error := 'Codigo de transaccion no encontrado ' ||
                         'Modulo; ' || p_modulo || ' Estado: ' ||
                         rp_pcpre.estado || ' Modalidad: ' ||
                         p_cod_mod_destino || ' Tipo: ' || 'Capital' ||
                         ' Nro cuenta: ' || p_nro_cuenta;

          raise ex_error;

        else
          --genera asiento por el capital
          pr_ins_asiento(v_cod_tra_padre,
                         v_cod_transaccion,
                         v_sal_cap * v_sig,
                         v_descripcion,
                         p_hora,
                         p_error,
                         p_men_error);
        end if;
      end if;
    end if;
    if p_error = 0 and nvl(v_sal_int, 0) > 0 then
      v_cod_transaccion := null;
      /******************
       INTERESES A COBRAR
      *********************/
      --obtiene la transaccion a utilizar
      prp_obt_tran_fideicomiso(p_modulo,
                               'IN',
                               rp_pcpre.estado,
                               p_cod_mod_destino,
                               null,
                               p_nro_cuenta,
                               v_cod_transaccion,
                               v_descripcion);

      if v_cod_transaccion is not null then
        if v_cod_transaccion < 0 then
          --error
          p_error     := 110;
          p_men_error := 'Codigo de transaccion no encontrado ' ||
                         'Modulo; ' || p_modulo || ' Estado: ' ||
                         rp_pcpre.estado || ' Modalidad: ' ||
                         p_cod_mod_destino || ' Tipo: ' ||
                         'Interes a cobrar' || ' Nro cuenta: ' ||
                         p_nro_cuenta;
          raise ex_error;

        else
          --genera asiento por el Intereses a cobrar
          pr_ins_asiento(v_cod_tra_padre,
                         v_cod_transaccion,
                         v_sal_int * v_sig,
                         v_descripcion,
                         p_hora,
                         p_error,
                         p_men_error);
        end if;
      end if;
    end if;
    if p_error = 0 and nvl(v_adevengar, 0) > 0 then
      v_cod_transaccion := null;
      /******************
       INTERESES A DEVENGAR
      *********************/
      --obtiene la transaccion a utilizar
      prp_obt_tran_fideicomiso(p_modulo,
                               'ID',
                               rp_pcpre.estado,
                               p_cod_mod_destino,
                               null,
                               p_nro_cuenta,
                               v_cod_transaccion,
                               v_descripcion);
      if v_cod_transaccion is not null then
        if v_cod_transaccion < 0 then
          --error
          p_error     := 110;
          p_men_error := 'Codigo de transaccion no encontrado ' ||
                         'Modulo; ' || p_modulo || ' Estado: ' ||
                         rp_pcpre.estado || ' Modalidad: ' ||
                         p_cod_mod_destino || ' Tipo: ' ||
                         'Interes a devengar' || ' Nro cuenta: ' ||
                         p_nro_cuenta;
          raise ex_error;

        else
          --genera asiento por el intereses a devengar
          pr_ins_asiento(v_cod_tra_padre,
                         v_cod_transaccion,
                         v_adevengar * v_sig,
                         v_descripcion,
                         p_hora,
                         p_error,
                         p_men_error);
        end if;
      end if;
    end if;
    if p_error = 0 and nvl(v_mto_prev, 0) > 0 then
      v_cod_transaccion := null;
      /********************
       PREVISIONES
      *********************/
      --obtiene la transaccion a utilizar
      prp_obt_tran_fideicomiso(p_modulo,
                               'PR',
                               rp_pcpre.estado,
                               p_cod_mod_destino,
                               null,
                               p_nro_cuenta,
                               v_cod_transaccion,
                               v_descripcion);
      if v_cod_transaccion is not null then
        if v_cod_transaccion < 0 then
          --error
          p_error     := 110;
          p_men_error := 'Codigo de transaccion no encontrado ' ||
                         'Modulo; ' || p_modulo || ' Estado: ' ||
                         rp_pcpre.estado || ' Modalidad: ' ||
                         p_cod_mod_destino || ' Tipo: ' || 'Previsiones' ||
                         ' Nro cuenta: ' || p_nro_cuenta;
          raise ex_error;

        else
          --genera asiento por la prevision
          pr_ins_asiento(v_cod_tra_padre,
                         v_cod_transaccion,
                         v_mto_prev * v_sig,
                         v_descripcion,
                         p_hora,
                         p_error,
                         p_men_error);
        end if;
      end if;
    end if;
    if p_error = 0 and nvl(v_mto_dev_suspenso, 0) > 0 then
      v_cod_transaccion := null;
      /********************
       DEVENGADO EN SUSPENSO
      *********************/
      --obtiene la transaccion a utilizar
      prp_obt_tran_fideicomiso(p_modulo,
                               'IS',
                               rp_pcpre.estado,
                               p_cod_mod_destino,
                               null,
                               p_nro_cuenta,
                               v_cod_transaccion,
                               v_descripcion);
      if v_cod_transaccion is not null then
        if v_cod_transaccion < 0 then
          --error
          p_error     := 110;
          p_men_error := 'Codigo de transaccion no encontrado ' ||
                         'Modulo; ' || p_modulo || ' Estado: ' ||
                         rp_pcpre.estado || ' Modalidad: ' ||
                         p_cod_mod_destino || ' Tipo: ' ||
                         'Devengado en suspenso' || ' Nro cuenta: ' ||
                         p_nro_cuenta;
          raise ex_error;

        else
          --genera asiento por el devengado en suspenso
          pr_ins_asiento(v_cod_tra_padre,
                         v_cod_transaccion,
                         v_mto_dev_suspenso * v_sig,
                         v_descripcion,
                         p_hora,
                         p_error,
                         p_men_error);
        end if;
      end if;
    end if;
  elsif p_modulo = 15 then
    v_cod_transaccion := null;
    pav_ove.pr_obt_dat_ope_vencida(p_nro_cuenta, r_vcven);
    pr_obt_cap_prv_ope_venc(p_nro_cuenta, v_mto_capital, v_mto_prevision);
    v_cod_modulo    := p_modulo;
    v_cod_modalidad := p_cod_mod_destino;
    v_cod_oficina   := r_vcven.cod_oficina;
    v_nro_cuenta    := r_vcven.nro_cuenta;
    v_cod_moneda    := r_vcven.cod_moneda;
    v_mone_local    := pag_gen.fu_obt_mon_local;
    v_fcdehoy       := pag_cal.fu_obt_fec_actual(6);
    if rp_pcpre.cod_moneda <> v_mone_local then
      v_cotizacion := pag_gen.fu_obt_cotizacion(rp_pcpre.cod_moneda,
                                                v_fcdehoy);
    else
      v_cotizacion := null;
    end if;
    /********************
          CAPITAL
    *********************/
    --obtiene la transaccion a utilizar por operaciones vencidas
    prp_obt_tran_fideicomiso(p_modulo,
                             'CA',
                             rp_pcpre.estado,
                             p_cod_mod_destino,
                             null,
                             p_nro_cuenta,
                             v_cod_transaccion,
                             v_descripcion);
    if v_cod_transaccion is not null and nvl(v_mto_capital, 0) > 0 then
      --genera asiento por el capital
      pr_ins_asiento(v_cod_tra_padre,
                     v_cod_transaccion,
                     v_mto_capital * v_sig,
                     v_descripcion,
                     p_hora,
                     p_error,
                     p_men_error);
    end if;
    if p_error = 0 and nvl(v_mto_prevision, 0) > 0 then
      v_cod_transaccion := null;
      /********************
       PREVISIONES
      *********************/
      --obtiene la transaccion a utilizar
      prp_obt_tran_fideicomiso(p_modulo,
                               'PR',
                               rp_pcpre.estado,
                               p_cod_mod_destino,
                               null,
                               p_nro_cuenta,
                               v_cod_transaccion,
                               v_descripcion);
      if v_cod_transaccion is not null then
        if v_cod_transaccion < 0 then
          --error
          p_error     := 110;
          p_men_error := 'Codigo de transaccion no encontrado ' ||
                         'Modulo: ' || p_modulo || ' Estado: ' ||
                         rp_pcpre.estado || ' Modalidad: ' ||
                         p_cod_mod_destino || ' Tipo: ' || 'Previsiones' ||
                         ' Nro cuenta: ' || p_nro_cuenta;
          raise ex_error;

        else
          --genera asiento por la prevision
          pr_ins_asiento(v_cod_tra_padre,
                         v_cod_transaccion,
                         v_mto_prevision * v_sig,
                         v_descripcion,
                         p_hora,
                         p_error,
                         p_men_error);
        end if;
      end if;
    end if;
  end if;

exception
  when ex_error then
    v_det_error := p_error || ' ' || p_men_error;
    prg_ins_log_programas('PRP_GEN_ASI_FIDEICOMISO',
                          substr(v_det_error, 1, 4000),
                          null,
                          null);
  when others then
    v_det_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                   DBMS_UTILITY.format_error_stack;

    it.prg_ins_log_programas('PRP_GEN_ASI_FIDEICOMISO',
                             substr(v_det_error, 1, 4000),
                             null,
                             null);
end prp_gen_asi_fideicomiso;
/

