create or replace procedure it.prp_gen_dto_masivos is
  v_fec_actual date default pag_cal.fu_obt_fec_actual(1);
  v_error      varchar2(500);
  v_mensaje    varchar2(500);
  v_tot_cap    number;
  v_TOT_INTERES PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
  v_TOT_INT_ADELANTADO PR_CTA_PRESTAMOS.SAL_INT_ADELANTADO%TYPE;
  v_TOT_MORA PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
  v_TOT_MORA_INTERES  PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
  v_TOT_MORA_INT_ADE  PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
  v_TOT_PUNITORIO  PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
  v_TOT_IMPUESTO  PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
  v_TOT_CARGO  PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE;
  v_TOT_CARGO_IVA  PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE;
  v_TOT_INT_DESCONTADO  PR_CUOTAS.SAL_INTERES%TYPE;
  v_DIA_MORA  PR_CTA_PRESTAMOS.DIA_ATRASO%TYPE;
  r_gauto           ge_autorizaciones%rowtype;
  v_hora            ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia   ge_movimientos.nro_secuencia%type;
  r_gmovi           ge_movimientos%rowtype;
  cursor c_ctas is
  select a.*, b.nro_cuota
    from pr_cta_prestamos a, pr_cuotas b, pr_cob_masivos_tmp c
  where c.nro_cuenta = a.nro_cuenta
    and b.nro_cuenta = a.nro_cuenta
    and b.nro_cuota = c.nro_cuota
    and b.estado <> 'N'
  order by a.nro_cuenta, b.nro_cuota;

  PROCEDURE pp_ins_autorizacion(p_gauto in ge_autorizaciones%rowtype) IS
  BEGIN
    delete ge_autorizaciones
     where nro_cuenta      = p_gauto.nro_cuenta
       and cod_autorizacion < 0;
    insert into ge_autorizaciones
      (cod_autorizacion, nro_cuenta, cod_tra_padre,
       cod_mod_padre, cod_mad_padre, cod_transaccion,
       cod_modulo, cod_modalidad, valor, fec_vencimiento,
       cod_usu_autorizador, observacion)
    values
      (s_cod_autorizacion.nextval, p_gauto.nro_cuenta, p_gauto.cod_tra_padre,
       p_gauto.cod_mod_padre, p_gauto.cod_mad_padre, p_gauto.cod_transaccion,
       p_gauto.cod_modulo, p_gauto.cod_modalidad, p_gauto.valor, p_gauto.fec_vencimiento,
       p_gauto.cod_usu_autorizador, p_gauto.observacion);
   exception
      when others then
        raise;
   END;
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
-- descuento
  for k in c_ctas loop
    pap_pre.pr_obt_deu_prestamo(k.nro_cuenta,
                                v_fec_actual,
                                k.nro_cuota,
                                k.nro_cuota,
                                k.cod_oficina,
                                null,
                                v_error,
                                v_mensaje,
                                v_tot_cap,
                                v_TOT_INTERES,
                                v_TOT_INT_ADELANTADO,
                                v_TOT_MORA,
                                v_TOT_MORA_INTERES,
                                v_TOT_MORA_INT_ADE,
                                v_TOT_PUNITORIO,
                                v_TOT_IMPUESTO,
                                v_TOT_CARGO,
                                v_TOT_CARGO_IVA,
                                v_TOT_INT_DESCONTADO,
                                v_DIA_MORA,
                                360,'N','N','N');
    --
    r_gauto.cod_usu_autorizador := user;
    r_gauto.nro_cuenta          := k.nro_cuenta;
    r_gauto.cod_tra_padre       := 360;
    r_gauto.cod_mod_padre       := 6;
    r_gauto.cod_mad_padre       := k.cod_modalidad;
    r_gauto.cod_modulo          := 6;
    r_gauto.cod_modalidad       := k.cod_modalidad;
    r_gauto.fec_vencimiento     := v_fec_actual;
    r_gauto.observacion         := 'PROCESO_MASIVO';

    if nvl(v_TOT_MORA,0) <> 0 then
       r_gauto.valor            := nvl(v_TOT_MORA,0);
       r_gauto.cod_transaccion  := pap_pre.fu_obt_tra_concepto('MO',k.estado, k.tipo, k.tip_interes, k.tip_renovacion);
       pp_ins_autorizacion(r_gauto);
    end if;
    if nvl(v_TOT_MORA_INTERES,0) <> 0 then
       r_gauto.valor            := nvl(v_TOT_MORA_INTERES,0);
       r_gauto.cod_transaccion  := pap_pre.fu_obt_tra_concepto('MI',k.estado, k.tipo, k.tip_interes, k.tip_renovacion);
       pp_ins_autorizacion(r_gauto);
    end if;
    if nvl(v_TOT_MORA_INT_ADE,0) <> 0 then
       r_gauto.valor            := nvl(v_TOT_MORA_INT_ADE,0);
       r_gauto.cod_transaccion  := pap_pre.fu_obt_tra_concepto('MA',k.estado, k.tipo, k.tip_interes, k.tip_renovacion);
       pp_ins_autorizacion(r_gauto);
    end if;
    if nvl(v_TOT_PUNITORIO,0) <> 0 then
       r_gauto.valor            := nvl(v_TOT_PUNITORIO,0);
       r_gauto.cod_transaccion  := pap_pre.fu_obt_tra_concepto('PU',k.estado, k.tipo, k.tip_interes, k.tip_renovacion);
       pp_ins_autorizacion(r_gauto);
    end if;
    if nvl(v_TOT_IMPUESTO,0) <> 0 then
       r_gauto.valor            := nvl(v_TOT_IMPUESTO,0);
       r_gauto.cod_transaccion  := pap_pre.fu_obt_tra_concepto('IM',k.estado, k.tipo, k.tip_interes, k.tip_renovacion);
       pp_ins_autorizacion(r_gauto);
    end if;
    if nvl(v_TOT_CARGO,0) <> 0 then
       r_gauto.valor            := nvl(v_TOT_CARGO,0);
       r_gauto.cod_transaccion  := pap_pre.fu_obt_tra_concepto('CG',k.estado, k.tipo, k.tip_interes, k.tip_renovacion);
       pp_ins_autorizacion(r_gauto);
    end if;
      --eliminar las autorizaciones negativas
       delete ge_autorizaciones
       where nro_cuenta      = k.nro_cuenta
         and cod_autorizacion < 0;
  end loop;
  -- cobro
  /*for c in c_ctas loop
    v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
    pap_pre.pr_obt_deu_prestamo(c.nro_cuenta,
                                v_fec_actual,
                                c.nro_cuota,
                                c.nro_cuota,
                                c.cod_oficina,
                                null,
                                v_error,
                                v_mensaje,
                                v_tot_cap,
                                v_TOT_INTERES,
                                v_TOT_INT_ADELANTADO,
                                v_TOT_MORA,
                                v_TOT_MORA_INTERES,
                                v_TOT_MORA_INT_ADE,
                                v_TOT_PUNITORIO,
                                v_TOT_IMPUESTO,
                                v_TOT_CARGO,
                                v_TOT_CARGO_IVA,
                                v_TOT_INT_DESCONTADO,
                                v_DIA_MORA,
                                360,'N','N','N','N');
   --
   v_nro_secuencia := 0;
    pap_pre.pr_cob_prestamo(c.nro_cuenta,
                            (nvl(v_tot_cap,0) + nvl(v_TOT_INTERES,0) + nvl(v_TOT_INT_ADELANTADO,0)),
                            'N',
                            c.cod_oficina,
                            c.nro_cuota,
                            c.nro_cuota,
                            'COBRO PRESTAMO CTA: '||c.nro_cuenta,
                            v_fec_actual,
                            v_hora,
                            v_nro_secuencia,
                            360,
                            6,
                            c.cod_modalidad);
    --
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := v_fec_actual;
    -- Aumento la secuencia
    v_nro_secuencia         := v_nro_secuencia + 1;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
     --
     r_gmovi.cod_modulo      := 6;
     r_gmovi.cod_modalidad   := c.cod_modalidad;
     r_gmovi.cod_oficina     := c.cod_oficina;
     r_gmovi.cod_moneda      := c.cod_moneda;
     r_gmovi.fec_valor       := v_fec_actual;
     r_gmovi.cod_tra_padre   := 360;
     r_gmovi.cod_mod_padre   := 6;
     r_gmovi.cod_mad_padre   := c.cod_modalidad;
     r_gmovi.cod_transaccion := 842;
     r_gmovi.monto           := (nvl(v_tot_cap,0) + nvl(v_TOT_INTERES,0) + nvl(v_TOT_INT_ADELANTADO,0));
     r_gmovi.nro_documento   := c.nro_cuenta;
     r_gmovi.cod_ofi_origen  := c.cod_oficina;
     r_gmovi.emi_aviso       := 'N';
     r_gmovi.concepto        := 'Cobro Cuenta '||c.nro_cuenta;
     r_gmovi.estado          := 'N';
     r_gmovi.reversado       := 'N';
     r_gmovi.cod_rubro       := '111201110200099';--:det_cta_contable.cod_rubro;
     r_gmovi.tip_mov_rubro   := 'D';

     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
  end loop;*/
end;
/

