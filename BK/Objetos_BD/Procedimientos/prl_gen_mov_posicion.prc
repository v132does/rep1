CREATE OR REPLACE PROCEDURE IT.PRL_GEN_MOV_POSICION
 IS
    /* Genera los movimientos de contabilizacion de la posicion de cambios */

    rv_gcale                 ge_calendarios%rowtype;
    v_fcanter              ge_calendarios.fec_anterior%type;
    v_hora                  ge_movimientos.hora%type;
    v_secuencia            number(4) := 0;
    r_gmovi                ge_movimientos%rowtype;
    v_fcdehoy              date;
    v_cod_modalidad         ge_movimientos.cod_modalidad%type;
    v_cod_mad_padre         ge_movimientos.cod_mad_padre%type;
    v_redondeo_ml number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,pag_gen.fu_obt_mon_local);
    v_cod_oficina          number(4) := pal_cam.FU_OBT_OFI_CAMBIO(FUN_OBT_OFI_MATRIZ);
    v_cod_mon_local        varchar2(4) := pag_gen.FU_OBT_MON_LOCAL;
    v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;
    --
    cursor datos is
              select 188 cod_transaccion, nvl(a.cod_moneda,b.cod_moneda) cod_moneda,
               sum((b.monto+nvl((a.tot_compra-a.tot_venta),0))) pos_actual,
               round(sum((b.monto+nvl((a.tot_compra-a.tot_venta),0))*(fug_obt_cotizacion(nvl(a.cod_moneda,b.cod_moneda) ))),v_redondeo_ml) pos_mon_local
                from lc_saldos_res a, (select cod_moneda, tip_posicion, mto_nef_compra-mto_nef_venta monto
                                         from lc_sal_posiciones b
                                        where tip_posicion = 'O'
                                      union all
                                      select cod_moneda, tip_posicion, mto_efe_compra-mto_efe_venta monto
                                        from lc_sal_posiciones b
                                       where tip_posicion = 'E') b
                where a.fecha(+) = v_fcdehoy
                and a.cod_moneda(+) = b.cod_moneda
                and a.tipo(+) = b.tip_posicion
                group by nvl(a.cod_moneda,b.cod_moneda)
        union
                SELECT 189, COD_MONEDA, SUM(DECODE(COD_MAD_TRANSACCION, 71,MONTO, (MONTO * -1))) monto,
                     round(SUM(DECODE(COD_MAD_TRANSACCION, 71,MONTO, (MONTO * -1)))*(fug_obt_cotizacion(a.cod_moneda )),v_redondeo_ml) pos_mon_local
                  FROM LC_OPE_FUTURAS A
                 WHERE A.ESTADO = 'N'
                   and ((v_ind_dev_val_economico = 'N') or 
                        (v_ind_dev_val_economico = 'S' and 
                        exists (select 1 
                                  from ba_cod_referencias x
                                 where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                                   and x.val_minimo = a.nro_cuenta||'#'||a.nro_operacion)))
                 GROUP BY COD_MONEDA
        union
                SELECT 1899, COD_MONEDA, SUM(DECODE(COD_MAD_TRANSACCION, 71,MONTO, (MONTO * -1))) monto,
                     round(SUM(DECODE(COD_MAD_TRANSACCION, 71,MONTO, (MONTO * -1)))*(fug_obt_cotizacion(a.cod_moneda )),v_redondeo_ml) pos_mon_local
                  FROM LC_OPE_FUTURAS A
                 WHERE A.ESTADO = 'N'
                   and v_ind_dev_val_economico = 'S'
                   and not exists (select 1 
                                     from ba_cod_referencias x
                                    where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                                      and x.val_minimo = a.nro_cuenta||'#'||a.nro_operacion)
                 GROUP BY COD_MONEDA
        ;
     -- cursor para traslados de diferencia de compra venta por oficinas
     cursor c_traslados is
     select 187 cod_transaccion, a.cod_moneda cod_moneda, a.cod_ofi_origen cod_oficina,
            sum(decode(b.cod_mad_hijo,71,monto,0)) -
            sum(decode(b.cod_mad_hijo,72,monto,0)) tot_oficina
       from lc_tip_operaciones b, ge_movimientos a
      where cod_mod_padre = 7
        and cod_mad_padre in (71,72,73,74)
        and estado = 'N'
        and reversado = 'N'
        and cod_moneda <> pag_gen.fu_obt_mon_local
        and nro_secuencia in (1,2,3,4)--DYDMR-7423 - Operaciones de Cambio con Ctas. Combinadas se registran en la secuencia 4.-
        and a.cod_tip_ope_cambio = b.cod_tip_operacion
        and a.cod_ofi_origen <> v_cod_oficina
        and b.afe_posicion <> 'N'
      group by a.cod_moneda, a.cod_ofi_origen;

/* Obtiene la cuenta contable para generar asientos. */
PROCEDURE LP_OBT_CTA_CONTABLE
 (P_COD_MODALIDAD IN NUMBER,
  P_COD_TRANSACCION IN NUMBER
 ,P_COD_MONEDA IN GE_TIP_ASIENTOS.COD_MONEDA%TYPE
 ,P_COD_RUBRO IN OUT GE_TIP_ASIENTOS.COD_RUBRO%TYPE
 ,P_TIPO IN OUT VARCHAR2
 )
 IS
BEGIN
   select GE_TIP_ASIENTOS.cod_rubro, GE_TIP_ASIENTOS.TIP_MOVIMIENTO
     into p_cod_rubro, p_tipo
     from cb_rubros, ge_tip_asientos, ge_transacciones x
    where ge_tip_asientos.cod_tip_asiento = X.cod_tip_asiento
      and cb_rubros.cod_rubro(+) = ge_tip_asientos.cod_rubro
      and ge_tip_asientos.cod_moneda = p_cod_moneda
      and (ge_tip_asientos.cod_sec_contable = 'X' or ge_tip_asientos.cod_sec_contable is null)
      and x.cod_modalidad = p_cod_modalidad
      and x.cod_transaccion = p_cod_transaccion;
exception
   when no_data_found then
      p_cod_rubro     := null;
      p_tipo := null;
   when too_many_rows then
      raise_application_error(-20000,
      'Asientos duplicados p/As '||p_cod_transaccion||
      ' Moneda '||p_cod_moneda);
END;

/******************************************************************************/
--BLOQUE PRINCIPAL
/******************************************************************************/
BEGIN
    v_fcdehoy := pag_cal.fu_obt_fec_actual(7);
    rv_gcale  := pag_cal.fu_obt_reg_cal(7);
    v_fcanter := rv_gcale.fec_anterior;
    v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
    --v_hora    := fug_ini_hora(sysdate, 'HH24:MI:SS');
    v_hora := to_char(sysdate,'HH24:MI:SS');
    v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
    -- cancelo los movimientos del dia anterior
    insert into ge_movimientos
          (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, nro_cuenta, cod_moneda, cod_oficina,
           cod_error, cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa, cod_banco,
           cod_ofi_origen, concepto, cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado,
           cod_usu_reversion, hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
           cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja, cotizacion, cod_bco_central,
           nro_documento, nro_documento2, nro_documento3, nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador,
           tip_mov_rubro,cod_tip_ope_cambio, referencia, cod_persona, cod_sit_contable)
    select v_fcdehoy, v_hora, user, nro_secuencia, v_fcdehoy, monto * -1, nro_cuenta, cod_moneda, cod_oficina,
           cod_error, cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa, cod_banco,
           cod_ofi_origen, 'Canc.de Posicion Dia Anterior', cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado,
           cod_usu_reversion, hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
           cod_transaccion, cod_modulo, cod_modalidad, null, nro_caja, cotizacion, cod_bco_central,
           nro_documento, nro_documento2, nro_documento3, nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador,
           tip_mov_rubro,cod_tip_ope_cambio, referencia, cod_persona, cod_sit_contable
      from lc_movimientos_his
     where fecha = v_fcanter
       and cod_mod_padre = 7
       and cod_tra_padre in (188,189,1899)
       and monto > 0;
    -- genero los movimientos por el traslado de compra - venta
    -- genero los movimientos por la posicion actual
    --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
    --wa:para pk
    v_hora:= fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
    for mv in c_traslados loop
       if nvl(mv.tot_oficina,0) <> 0 then
          r_gmovi.cod_modulo      := 7;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.cod_moneda      := mv.cod_moneda;
          r_gmovi.cod_usuario     := user;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fcdehoy;
          --
          r_gmovi.fec_valor       := v_fcdehoy;
          r_gmovi.cod_mod_padre   := 7;
          if mv.tot_oficina > 0 then
            r_gmovi.cod_modalidad   := 72;
            r_gmovi.cod_mad_padre   := 72;
          else
            r_gmovi.cod_modalidad   := 71;
            r_gmovi.cod_mad_padre   := 71;
          end if;
          r_gmovi.nro_documento   := null;
          r_gmovi.nro_documento2  := null;
          r_gmovi.nro_documento3  := null;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;

          r_gmovi.emi_aviso       := 'N';
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          --
          v_secuencia := v_secuencia + 1;
          r_gmovi.nro_secuencia   := v_secuencia;
          r_gmovi.cod_tra_padre   := mv.cod_transaccion;
          r_gmovi.cod_transaccion := mv.cod_transaccion;
          r_gmovi.cod_oficina     := mv.cod_oficina;
          r_gmovi.cod_ofi_origen  := mv.cod_oficina;
          r_gmovi.monto           := abs(mv.tot_oficina) ;
          r_gmovi.mto_equ_local   := round(abs(mv.tot_oficina) * fug_obt_cotizacion(mv.cod_moneda));
          r_gmovi.concepto        := 'Traslado a la Oficina '||v_cod_oficina;
          LP_OBT_CTA_CONTABLE
           (r_gmovi.cod_modalidad ,
            r_gmovi.cod_transaccion,
            r_gmovi.cod_moneda,
            r_gmovi.cod_rubro,
            r_gmovi.tip_mov_rubro
           );
          r_gmovi.cod_rubro := substr(r_gmovi.cod_rubro,1,10)||ltrim(to_char(v_cod_oficina,'000'))||substr(r_gmovi.cod_rubro,14,2);

          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          ---
          v_secuencia := v_secuencia + 1;
          r_gmovi.nro_secuencia   := v_secuencia;
          r_gmovi.cod_oficina     := v_cod_oficina;
          r_gmovi.cod_ofi_origen  := v_cod_oficina;
          r_gmovi.monto           := r_gmovi.monto * -1;
          r_gmovi.mto_equ_local   := r_gmovi.mto_equ_local * -1;
          r_gmovi.concepto        := 'Traslado a la Oficina '||v_cod_oficina;
          r_gmovi.cod_rubro := substr(r_gmovi.cod_rubro,1,10)||ltrim(to_char(mv.cod_oficina,'000'))||substr(r_gmovi.cod_rubro,14,2);

          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          --
          v_secuencia := v_secuencia + 1;
          r_gmovi.nro_secuencia   := v_secuencia;
          r_gmovi.cod_transaccion := 1187;
          r_gmovi.cod_tra_padre   := 1187;
          r_gmovi.cod_moneda      := v_cod_mon_local;
          r_gmovi.cod_oficina     := mv.cod_oficina;
          r_gmovi.cod_ofi_origen  := mv.cod_oficina;
          r_gmovi.monto           := round(abs(mv.tot_oficina) * fug_obt_cotizacion(mv.cod_moneda));
          r_gmovi.mto_equ_local   := null;
          r_gmovi.concepto        := 'Traslado a la Oficina '||v_cod_oficina;
          LP_OBT_CTA_CONTABLE
           (r_gmovi.cod_modalidad ,
            r_gmovi.cod_transaccion,
            r_gmovi.cod_moneda,
            r_gmovi.cod_rubro,
            r_gmovi.tip_mov_rubro
           );
          r_gmovi.cod_rubro := substr(r_gmovi.cod_rubro,1,10)||ltrim(to_char(v_cod_oficina,'000'))||substr(r_gmovi.cod_rubro,14,2);

          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          --
          v_secuencia := v_secuencia + 1;
          r_gmovi.nro_secuencia   := v_secuencia;
          r_gmovi.cod_oficina     := v_cod_oficina;
          r_gmovi.cod_ofi_origen  := v_cod_oficina;
          r_gmovi.monto           := r_gmovi.monto * -1;
          r_gmovi.mto_equ_local   := null;
          r_gmovi.concepto        := 'Traslado a la Oficina '||v_cod_oficina;
          r_gmovi.cod_rubro := substr(r_gmovi.cod_rubro,1,10)||ltrim(to_char(mv.cod_oficina,'000'))||substr(r_gmovi.cod_rubro,14,2);

          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      end if;

    end loop;

    -- genero los movimientos por la posicion actual
    --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
    --wa:para pk
    v_hora:= fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
    r_gmovi.cod_rubro := null;
    r_gmovi.tip_mov_rubro := null;


    for mv in datos loop

       if nvl(mv.pos_actual,0) <> 0 then
          r_gmovi.cod_modulo      := 7;
          r_gmovi.cod_oficina     := v_cod_oficina;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.cod_moneda      := mv.cod_moneda;
          r_gmovi.cod_usuario     := user;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fcdehoy;
          --
          r_gmovi.fec_valor       := v_fcdehoy;
          r_gmovi.cod_mod_padre   := 7;
          if mv.pos_actual > 0 then
            r_gmovi.cod_modalidad   := 71;
            r_gmovi.cod_mad_padre   := 71;
          else
            r_gmovi.cod_modalidad   := 72;
            r_gmovi.cod_mad_padre   := 72;
          end if;
          r_gmovi.nro_documento   := null;
          r_gmovi.nro_documento2  := null;
          r_gmovi.nro_documento3  := null;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;
          r_gmovi.cod_ofi_origen  := v_cod_oficina;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          --
          v_secuencia := v_secuencia + 1;
          r_gmovi.nro_secuencia   := v_secuencia;
          r_gmovi.cod_tra_padre   := mv.cod_transaccion;
          r_gmovi.cod_transaccion := mv.cod_transaccion;
          r_gmovi.monto           := abs(mv.pos_actual) ;
          r_gmovi.mto_equ_local   := abs(mv.pos_mon_local);
          r_gmovi.concepto        := 'Posicion Actual';
          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      end if;

    end loop;

END;
/

