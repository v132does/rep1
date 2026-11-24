CREATE OR REPLACE PACKAGE BODY IT.PAG_CAR is
   g_fre_proceso VARCHAR2(1);
   g_db_prod     VARCHAR2(1) := fug_ind_produccion;

PROCEDURE PR_OBT_CARGOS
 (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_CARGO IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_IVA_INCLUIDO  IN VARCHAR2 DEFAULT 'S'
 ,P_COD_TAS_CARGO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 )
 IS
--v_mto_exonerado number(21,2);
v_val_base      number(18,2) := p_monto;
v_fec_vigencia  date;
v_tip_valor     varchar2(1);
v_tipo          varchar2(1);
v_redondeo      number(1);
v_tas_personalizada varchar2(1);
---
v_val_exo_cargo    ge_movimientos.val_tasa%type;
v_val_exo_impuesto ge_movimientos.val_tasa%type;
begin
  /*
  || PCC-Exoneración y Extorno de Comisiones y Tasas
  || Se ejecuta si el proceso no es mensual
  || o la base de datos no es producción
  */
  IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
     -- busco el valor de la tasa
     begin
        v_val_exo_cargo := fug_obt_val_tasa(p_cod_modulo,
                                            p_cod_modalidad,
                                            p_cod_ofi_origen,
                                            null,
                                            p_cod_moneda,
                                            0, 'N', NULL,
                                            p_cod_tra_cargo,
                                            trunc(sysdate));
     exception
        when others then
           raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
     end;
  END IF;
  ---
  begin
     select tas_personalizada
       into v_tas_personalizada
       from ge_cuentas
       where nro_cuenta = p_nro_cuenta;
  exception
     when no_data_found then
        raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no registrada');
  end;
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',P_COD_MODULO,P_COD_MODALIDAD,P_cod_moneda);
  -- busco el valor de la tasa
  pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
       p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
       v_val_base, nvl(v_tas_personalizada,'N'), p_cod_tas_cargo,
       p_cod_tra_cargo, trunc(sysdate),
       p_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
  if v_tip_valor = 'V' then
     -- si es un valor, se toma directamente
     p_val_cargo     := nvl(p_val_tas_cargo,0);
     v_val_exo_cargo := nvl(v_val_exo_cargo,0);
  else
     -- es un porcentaje
     p_val_cargo     := round(nvl(v_val_base,0)*
                              nvl(p_val_tas_cargo,0)/100,v_redondeo);
     v_val_exo_cargo := round(nvl(p_monto,0)*
                              nvl(v_val_exo_cargo,0)/100,v_redondeo);
    --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
    --Agregado por JIRA DYDMR-10316--
    if nvl(p_val_cargo,0) > 0 then
       p_val_cargo     := pag_gen.FU_OBT_VAL_FINAL(p_val_cargo);
    end if;
    if nvl(v_val_exo_cargo,0) > 0 then
       v_val_exo_cargo := pag_gen.FU_OBT_VAL_FINAL(v_val_exo_cargo);
    end if;
  end if;
  -- veo si la cuenta tiene transaccion prohibida
  if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                  p_cod_tra_cargo,
                                  p_cod_modulo,
                                  p_cod_modalidad) = 'S' then
     IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
        prg_ins_exoneracion(p_cod_tra_cargo, p_cod_modulo,
                            p_cod_modalidad, p_cod_moneda,
                            p_nro_cuenta, null, p_cod_tas_cargo,
                            v_val_exo_cargo,
                            v_val_exo_cargo, null,
                            v_val_exo_cargo);
     END IF;
  ELSE
    -- no tiene transaccion prohibida, se calcula

    -- busco el impuesto asociado a este cargo
    begin
      select cod_tra_hijo
        into p_cod_tra_impuesto
        from ge_transacciones_det
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_tra_cargo
         and cod_mod_hijo = p_cod_modulo
         and cod_mad_hijo = p_cod_modalidad
         and rownum = 1;
      --> PCC-Exoneración y Extorno de Comisiones y Tasas
      IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
         begin
            v_val_exo_impuesto := fug_obt_val_tasa(p_cod_modulo,
                                                   p_cod_modalidad,
                                                   p_cod_ofi_origen,
                                                   null,
                                                   p_cod_moneda,
                                                   0, 'N', NULL,
                                                   p_cod_tra_impuesto,
                                                   trunc(sysdate));
         exception
            when others then
               raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
         end;
      END IF;
      --<
      -- veo si la cuenta tiene exoneracion de impuestos
      /*if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then*/
         -- Se encontró impuesto asociado, se calcula
      pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
            p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
            p_val_cargo, nvl(v_tas_personalizada,'N'), p_cod_tas_impuesto,
            p_cod_tra_impuesto, trunc(sysdate),
            p_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
      if v_tip_valor = 'V' then
         -- si es un valor, se toma directamente
         p_val_impuesto     := nvl(p_val_tas_impuesto,0);
         v_val_exo_impuesto := nvl(v_val_exo_impuesto,0);
      else
         --
         -- es un porcentaje, se considera incluido en el cargo
         p_val_impuesto := round(nvl(p_val_cargo,0)*
                           nvl(p_val_tas_impuesto,0)/(100+p_val_tas_impuesto),v_redondeo);
         v_val_exo_impuesto := round(nvl(v_val_exo_cargo,0)*
                               nvl(v_val_exo_impuesto,0)/(100+v_val_exo_impuesto),v_redondeo);
         --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
         p_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_val_impuesto);
         v_val_exo_impuesto := pag_gen.FU_OBT_VAL_FINAL(v_val_exo_impuesto);
      end if;
      -- resto el monto del impuesto al cargo, porque va incluido
      if nvl(p_iva_incluido,'S') = 'S' then
         p_val_cargo := nvl(p_val_cargo,0) - nvl(p_val_impuesto,0);
         v_val_exo_cargo := nvl(v_val_exo_cargo,0) - nvl(p_val_impuesto,0);
      end if;
      if p_val_cargo < 0 then
         raise_application_error(-20000,'Impuesto mas alto que el Cargo');
      end if;
      --> PCC-Exoneración y Extorno de Comisiones y Tasas
      IF g_fre_proceso <> 'M' OR g_db_prod = 'N' and
         ( (nvl(p_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
           (nvl(p_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) ) then
            prg_ins_exoneracion(p_cod_tra_cargo, p_cod_modulo,
                                p_cod_modalidad, p_cod_moneda,
                                p_nro_cuenta, null, p_cod_tas_cargo,
                                (nvl(v_val_exo_cargo, 0) - nvl(p_val_cargo, 0)),
                                 v_val_exo_cargo, null,
                                (nvl(v_val_exo_cargo, 0) - nvl(p_val_cargo, 0)));
      END IF;
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'S' then
         p_val_impuesto := 0;
         IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
            prg_ins_exoneracion(p_cod_tra_impuesto, p_cod_modulo,
                                p_cod_modalidad, p_cod_moneda,
                                p_nro_cuenta, null, p_cod_tas_impuesto,
                                v_val_exo_impuesto,
                                v_val_exo_impuesto, null,
                                v_val_exo_impuesto);
         end if;
       elsif g_fre_proceso <> 'M' OR g_db_prod = 'N' then
          if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                          p_cod_tra_cargo,
                                          p_cod_modulo,
                                          p_cod_modalidad) = 'S' then
             null;
          elsif (nvl(p_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
                (nvl(p_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
             prg_ins_exoneracion(p_cod_tra_impuesto, p_cod_modulo,
                                 p_cod_modalidad, p_cod_moneda,
                                 p_nro_cuenta, null, p_cod_tas_impuesto,
                                 (nvl(v_val_exo_impuesto, 0) - nvl(p_val_impuesto, 0)),
                                  v_val_exo_impuesto, null,
                                 (nvl(v_val_exo_impuesto, 0) - nvl(p_val_impuesto, 0)));
          END IF;
       --<
       end if;
    exception
       when no_data_found then
          p_val_impuesto := 0;
       when others then
          raise_application_error(-20000,'Al leer Impuesto '||sqlerrm);
    end;
  end if;
end ;

PROCEDURE PR_DEB_CRE_BATCH
 (P_COD_DEB_CRE IN GE_DEB_CRE_BATCH.COD_DEB_CRE_BATCH%TYPE
 ,P_NRO_CUENTA  IN VARCHAR2 DEFAULT NULL
 --,P_LUGAR OUT VARCHAR2
 --,P_HUBO_ERROR OUT VARCHAR2
 )
 IS

   v_fecha          ge_calendarios.fec_actual%type;
   v_hora           ge_movimientos.hora%type := to_char(sysdate,'HH24:MI:SS');
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   v_tra_padre      ge_transacciones.cod_transaccion%type;
   v_transaccion    ge_transacciones.cod_transaccion%type;
   v_mod_padre      ge_transacciones.cod_modulo%type;
   v_mad_padre      ge_transacciones.cod_modalidad%type;
   v_concepto       ge_movimientos.concepto%type;
   v_fcproxi        DATE;
   rv_gcale         GE_CALENDARIOS%ROWTYPE;
   ---
   --v_nro_cta        cb_rubros.cod_rubro%type;
   v_cuenta         ge_cuentas.nro_cuenta%type;
   v_mto_pago       ge_cuentas.sal_contable%type;
   v_nro_documento  ge_movimientos.nro_documento%type;
   v_nro_documento2 ge_movimientos.nro_documento2%type;
   v_estado         ge_cuentas.estado%type;
   --v_moneda         ba_monedas.cod_moneda%type;
   v_tipo           varchar2(1);
   ---
   r_gmovi          ge_movimientos%rowtype;
   v_cod_ofi_origen ba_oficinas.cod_oficina%type;
   v_cod_moneda     varchar2(3);--  := pag_gen.fu_obt_mon_local; -- moneda de la cuenta
   v_cod_usuario    varchar2(10) := upper(user);              -- usuario
   v_tip_mov_contra varchar2(1);
   v_sobregiro      ge_deb_cre_batch.sobregiro%type;
   v_cob_parcial    ge_deb_cre_batch.cob_parcial%type;
   v_pendiente      ge_deb_cre_batch.pendiente%type;
   v_pro_error      ge_deb_cre_batch.pro_error%type;
   v_cantidad       number;
   v_mon_corte      ba_monedas.cod_moneda%type := 'x';
   v_mto_mov        ge_movimientos.monto%type;
   v_cod_tas_cargo  ge_movimientos.cod_tasa%type;
   v_val_tas_cargo  ge_movimientos.val_tasa%type;
   v_mto_cargo      ge_movimientos.monto%type;
   v_tra_iva        ge_movimientos.cod_transaccion%type;
   v_cod_tas_iva    ge_movimientos.cod_tasa%type;
   v_val_tas_iva    ge_movimientos.val_tasa%type;
   v_mto_iva        ge_movimientos.monto%type;
   v_sal_disponible ge_movimientos.monto%type;
   v_mto_total      ge_movimientos.monto%type;
   v_mto_tot_cargo  ge_movimientos.monto%type;
   v_lugar          varchar2(3000);
   v_hubo_error     varchar2(1):='N';
   v_cod_error      ge_deb_cre_errores.cod_error%type;
   v_nro_reg        ge_deb_cre_errores.nro_secuencia%type;
   v_cod_mad_cta    ge_movimientos.cod_modalidad%type;
   v_redondeo       number(2);
   v_mto_cargo_par  ge_movimientos.monto%type;
   v_mto_iva_par    ge_movimientos.monto%type;
   v_tip_mov        ge_deb_cre_batch.tip_movimiento%type;
   --v_corte varchar2(1):='N';
   v_dif_hora       ge_deb_cre_batch.dif_hora%type;
   v_cta_contra     ge_cuentas.nro_cuenta%type;
   v_mod_contra     ge_cuentas.cod_modulo%type;
   v_mad_contra     ge_cuentas.cod_modalidad%type;
   v_ofi_contra     ge_cuentas.cod_oficina%type;
   v_rub_contra     cb_rubros.cod_rubro%type;
   v_tra_contra     ge_transacciones.cod_transaccion%type;
   v_contra         number;
   v_exi_contra     varchar2(1) := 'N';
   v_existe         varchar2(1) := 'N';
   v_pre_proceso    ge_deb_cre_batch.pre_proceso%type;
   v_pos_proceso    ge_deb_cre_batch.pos_proceso%type;
   v_iva_incluido   ge_deb_cre_batch.iva_incluido%type;
   v_error          varchar2(4000);
   v_val_max_tae    ge_movimientos.monto%type;
   v_cod_mon_local  varchar2(3) := pag_gen.fu_obt_mon_local;
   v_red_mon_local  number(2)   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local);
   v_cotizacion     ge_cotizaciones.val_conversion%type;
   ---
   v_cod_programa     ge_procesos_det.cod_programa%TYPE;
   v_rowcount PLS_INTEGER := 0;
   v_mensaje varchar2(3000);
   v_cant_registros PLS_INTEGER := 0;
   v_sql_count VARCHAR2(32767);
   
   --- Cursor Dinámico
   TYPE t_tipo_cursor IS REF CURSOR;
   c_cursor    t_tipo_cursor;
   v_sentencia ge_deb_cre_batch.det_sql%type;
   --cursor de detalles
   cursor det(p_moneda in varchar2) is
     select a.*, b.cod_modulo, b.cod_modalidad, b.cod_oficina
       from ge_cuentas b, ge_deb_cre_batch_det a
      where cod_deb_cre_batch = P_COD_DEB_CRE
        and a.cod_moneda = p_moneda --la moneda de CORTE o de la cuenta
        and a.nro_cuenta = b.nro_cuenta (+);

--procesar errores
procedure lp_error is
PRAGMA AUTONOMOUS_TRANSACTION;--para q comitee solo esto
begin
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --inserta tabla de errores
  begin
    insert into ge_deb_cre_errores
      (fecha, hora, cod_usuario, nro_secuencia, cod_deb_cre_batch, nro_cuenta, cod_moneda,
      sal_disponible, mto_operacion, cod_tra_padre, cod_error, msj_error)
    values
       (v_fecha, v_hora, v_cod_usuario, v_nro_reg, p_cod_deb_cre, v_cuenta, v_cod_moneda,
       v_sal_disponible, v_mto_mov, v_tra_padre, v_cod_error, v_lugar);
  exception
    when others then
      raise_application_error(-20001,'Al grabar errores '||to_char(v_fecha,'dd/mm/yyyy')||'-'||v_hora||'-'||v_cod_usuario
                              ||'-'||v_nro_reg||'-'||p_cod_deb_cre||'-'||v_cuenta||'. '||sqlerrm);
  end;
  commit;
  --si no procesa con error finaliza el proceso, sino continúa con el sig registro
  if v_pro_error = 'N' then
   raise_application_error(-20000,nvl(v_lugar,sqlerrm));
  end if;
end;

--generar movimientos pendientes
procedure lp_gen_mov_pendiente is
begin
/*
  insert into ge_deb_cre_pendientes
    (fecha, hora, cod_usuario, nro_cuenta, cod_moneda, cod_mod_padre, cod_mad_padre, cod_tra_padre,
     cod_tra_cargo, mto_cargo, cod_tas_cargo, val_tas_cargo, cod_tra_impuesto, mto_impuesto,
     cod_tas_impuesto, val_tas_impuesto, cod_deb_cre_batch, concepto)
  values
    (v_fecha, v_hora, v_cod_usuario, v_cuenta, v_cod_moneda, v_mod_padre, v_mad_padre, v_tra_padre,
     v_transaccion, (v_mto_cargo - v_mto_cargo_par), v_cod_tas_cargo, v_val_tas_cargo, v_tra_iva, (v_mto_iva - v_mto_iva_par),
     v_cod_tas_iva, v_val_tas_iva, p_cod_deb_cre, v_concepto);
*/
 -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
   If  v_sal_disponible = 0 and v_estado = 'I' then
      null;
   else
    insert into ge_mov_pendientes
     (nro_cuenta,fecha, cod_modulo, cod_modalidad, cod_transaccion,
      cod_mod_padre, cod_mad_padre, cod_tra_padre,
      monto,
      hora, cod_usuario,  cod_moneda,
      cod_oficina, cod_error, estado, cod_ofi_origen,
      concepto, cod_tasa, val_tasa, nro_documento, saldo,
      motivo)
      values
      (v_cuenta, v_fecha, v_mod_padre, v_mad_padre, v_transaccion,
       v_mod_padre, v_mad_padre, v_transaccion,
       (v_mto_cargo - v_mto_cargo_par)+(v_mto_iva - v_mto_iva_par),
       v_hora, user, v_cod_moneda,
       pag_cta.g_ctas.cod_oficina, pag_cta.g_cod_error, 'I',pag_cta.g_ctas.cod_oficina,
       v_concepto,V_COD_TAS_CARGO, V_VAL_TAS_CARGO,
       v_cuenta , (v_mto_cargo - v_mto_cargo_par)+(v_mto_iva - v_mto_iva_par),
       pag_cta.G_MSJ_ERROR);
    End if;
exception
  when others then
    v_cod_error := 200;
    v_lugar := 'Ins.Mvto.Pendiente ' || to_char(v_fecha,'dd/mm/yyyy'||'-'||v_hora||'-'||v_cod_usuario||'-'||v_cuenta||'. '||sqlerrm);
    v_hubo_error := 'S';
    lp_error;
end;

--generar movimiento contrapartida
procedure lp_gen_mov_contraparte
(p_cta_contra in ge_cuentas.nro_cuenta%type,
p_mod_contra in ge_cuentas.cod_modulo%type,
p_mad_contra in ge_cuentas.cod_modalidad%type,
p_ofi_contra in ge_cuentas.cod_oficina%type,
p_rub_contra in cb_rubros.cod_rubro%type,
p_tra_contra in ge_transacciones.cod_transaccion%type,
p_moneda in ge_cuentas.cod_moneda%type) is
begin
  /*if v_tra_contra is not null then --si tiene transacción, buscar el tipo de mov. x el asiento
    v_retorno := fug_obt_tip_mov_contable(v_mod_padre,v_mad_padre, v_tra_contra);
    if v_retorno = 'N' or v_retorno is null then
       null;
    else
       v_nro_cta := null;
    end if;
  end if;*/ --OJO VER CON AGUS

  if p_cta_contra is not null then
    --v_nro_secuencia := v_nro_secuencia + 1;
     if v_nro_Secuencia > 990 then
        --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
        v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
        v_nro_secuencia := -999;
     end if;

    --- Actualizar los datos de las cuentas con movimientos.
    PAG_CTA.PR_ACT_OPERACION
         (p_cta_contra      -- P_NRO_CUENTA
         ,v_hora        -- P_HORA
         ,v_tip_mov_contra        -- P_TIP_MOVIMIENTO
         ,p_moneda  -- P_COD_MONEDA
         ,v_mto_total     -- P_MONTO
         ,v_tra_padre   -- P_COD_TRA_PADRE
         ,p_tra_contra -- P_COD_TRANSACCION
         ,null          --P_NRO_DOCUMENTO
         ,v_cotizacion  --P_COTIZACION
--         ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/10
         ,pag_cta.g_ctas.cod_oficina  --Ofic. de la cuenta
         ,v_mod_padre   -- P_COD_MOD_PADRE
         ,v_mad_padre   -- P_COD_MAD_PADRE
         ,null          --P_COD_TASA
         ,null          --P_VAL_TASA
         ,v_concepto    -- P_CONCEPTO
         ,'N'           -- p_EMI_AVISO
         ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
         ,v_fecha       -- P_FEC_VALOR
         ,null          -- P_COD_BANCO
         ,null          -- P_COD_CAUSA
         ,round((v_mto_cargo * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

    if pag_cta.fu_obt_cod_error() <> 0 then
      v_cod_error := pag_cta.G_COD_ERROR;
      v_hubo_error := 'S';
      raise_application_error(-20040, 'Mov.Cta.Contrapart. '||p_cta_contra||'.'||pag_cta.fu_obt_msj_error());
    end if;
  else --mov contra rubro contable o transacción
    if v_nro_Secuencia > 990 then
       --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
       v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
       v_nro_secuencia := -999;
    end if;
    v_nro_secuencia := v_nro_secuencia + 1;

    r_gmovi.cod_modulo     := v_mod_padre; --de la transac padre
    r_gmovi.cod_modalidad  := v_mad_padre; --de la transac padre
--    r_gmovi.cod_oficina    := v_cod_ofi_origen;
    r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
    r_gmovi.nro_cuenta      := null;
    r_gmovi.cod_moneda      := p_moneda;
    r_gmovi.cod_usuario     := v_cod_usuario;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := v_fecha;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    ---
    r_gmovi.fec_valor       := v_fecha;
    r_gmovi.cod_tra_padre   := v_tra_padre;
    r_gmovi.cod_mod_padre   := v_mod_padre;
    r_gmovi.cod_mad_padre   := v_mad_padre;
    r_gmovi.cod_transaccion := nvl(p_tra_contra, v_transaccion); --si tiene transacción
    r_gmovi.monto           := v_mto_total;
    r_gmovi.nro_documento   := v_nro_documento;
    r_gmovi.nro_documento2  := v_nro_documento2;
    r_gmovi.cod_tasa        := null;
    r_gmovi.val_tasa        := null;
    r_gmovi.cotizacion      := null;
    r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.concepto        := v_concepto;
    r_gmovi.estado          := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.nro_caja        := null;
    r_gmovi.cod_rubro       := p_rub_contra; --si tiene rubro
    if p_rub_contra is not null then
      r_gmovi.tip_mov_rubro   := v_tip_mov_contra;
    else
      r_gmovi.tip_mov_rubro   := null;
    end if;

    PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
  end if;
exception
  when others then
    if sqlcode <= -20000 then
      raise; --cae el pag_cta
    else
      v_cod_error := 115;
      v_lugar := 'Mvto.contrapartida '||sqlerrm;
      v_hubo_error := 'S';
      raise_application_error(-20030,v_lugar); --error grave xq ya hizo el movimiento de la cuenta
    end if;
end;

PROCEDURE LP_ACT_SAL_MENSUAL (P_TOTAL IN NUMBER,
                              P_CDMODUL IN NUMBER,
                              P_CDMODAL IN NUMBER,
                              P_CDOFICI IN NUMBER,
                              P_NRCUENT IN VARCHAR2)IS
V_DIAS    NUMBER(2,0);
v_minpa   cc_cta_corrientes.sal_total%type;
v_acsaldi cc_cta_corrientes.sal_total%type;
v_salinic cc_cta_corrientes.sal_total%type;
v_ctdiast NUMBER(7);
v_atransf cc_cta_corrientes.sal_total%type;
v_ctacomb varchar2(1);
v_monto   number;
BEGIN
if v_cod_mad_cta = 41 then
/* Actualizar CTAS. CTES.
*/
  select nvl(cc.sal_total, 0) - nvl(cc.sal_retenido, 0),
         decode(nro_cta_cte,'',0, nvl(cco.sal_minimo, FUG_OBT_SAL_MIN_TRASPASO(nro_cta_cte))),
         nvl(cc.cta_combinada, 'N')
    into v_salinic, v_atransf, v_ctacomb
    from cc_cta_combinadas cco,
         cc_cta_corrientes cc
   where cco.nro_cta_cte(+) = cc.nro_cuenta
     and cc.cod_modulo    = p_cdmodul
     and cc.cod_modalidad = p_cdmodal
     and cc.cod_oficina   = p_cdofici
     and cc.nro_cuenta    = p_nrcuent;
  If v_ctacomb = 'S' and v_salinic >  v_atransf Then
    v_salinic := v_atransf;
  End If;
  UPDATE cc_sal_mensuales
     SET sal_ini_mes = nvl(v_salinic, 0)
   WHERE cod_modulo    = p_cdmodul
     AND cod_modalidad = p_cdmodal
     AND cod_oficina   = p_cdofici
     AND nro_cuenta    = p_nrcuent
     AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
     AND mes           = to_number(to_char(v_fcproxi,'MM'));
  IF v_fecha + 1 <> v_fcproxi THEN
     V_DIAS := TO_NUMBER(TO_CHAR(v_fcproxi,'DD')) - 1;
     /* Actualiza valores saldo acumulado del mes*/
     UPDATE cc_sal_mensuales
        SET sal_acu_diario = v_dias * nvl(v_salinic, 0)
      WHERE cod_modulo    = p_cdmodul
        AND cod_modalidad = p_cdmodal
        AND cod_oficina   = p_cdofici
        AND nro_cuenta    = p_nrcuent
        AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
        AND mes           = to_number(to_char(v_fcproxi,'MM'));
    -- SALDOS DEUDORES --
    ------------------------------------------------------------
     If nvl(v_salinic, 0) < 0 Then
       UPDATE cc_sal_mensuales
         SET sal_acu_deudor = v_dias * nvl(v_salinic, 0) * -1,
             can_dia_deudor = v_DIAS,
             sal_acu_acreedor = 0,
             can_dia_acreedor = 0
       WHERE cod_modulo    = p_cdmodul
         AND cod_modalidad = p_cdmodal
         AND cod_oficina   = p_cdofici
         AND nro_cuenta    = p_nrcuent
         AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
         AND mes           = to_number(to_char(v_fcproxi,'MM'));
   -- SALDOS ACREEDORES -- menor a cero
    ------------------------------------------------------------
     Else
       UPDATE cc_sal_mensuales
          SET sal_acu_acreedor = v_dias * nvl(v_salinic, 0),
              can_dia_acreedor = v_DIAS,
              sal_acu_deudor = 0,
              can_dia_deudor = 0
        WHERE cod_modulo    = p_cdmodul
          AND cod_modalidad = p_cdmodal
          AND cod_oficina   = p_cdofici
          AND nro_cuenta    = p_nrcuent
          AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
          AND mes           = to_number(to_char(v_fcproxi,'MM'));
     End If;
  END IF;
ELSIF v_cod_mad_cta = 31 then
/* ACTUALIZAR AHORROS
*/
  If v_tip_mov = 'D' then
     v_monto := p_total * -1;
  elsif v_tip_mov = 'C' then
     v_monto := p_total;
  end if;
--
   UPDATE AH_SAL_MENSUALES
      SET SAL_INI_MES = nvl(SAL_INI_MES,0) + nvl(v_monto,0)
    WHERE COD_MODULO = p_cdmodul
      AND COD_MODALIDAD = p_cdmodal
      AND COD_OFICINA = p_cdofici
      AND NRO_CUENTA = p_nrcuent
      AND ANO = to_number(to_char(v_fcproxi,'YYYY'))
      AND MES = to_number(to_char(v_fcproxi,'MM'));
   IF v_fecha + 1 <> v_fcproxi THEN
      v_dias := TO_NUMBER(TO_CHAR(v_fcproxi,'DD')) - 1;
      /* Actualiza valores saldo acumulado del mes*/
      UPDATE AH_SAL_MENSUALES
         SET SAL_ACU_DIARIO = NVL(SAL_ACU_DIARIO,0) + v_dias * NVL(v_monto,0)
       WHERE COD_MODULO = p_cdmodul
         AND COD_MODALIDAD = p_cdmodal
         AND COD_OFICINA = p_cdofici
         AND NRO_CUENTA = p_nrcuent
         AND ANO = TO_NUMBER(TO_CHAR(v_fcproxi,'YYYY'))
         AND MES = TO_NUMBER(TO_CHAR(v_fcproxi,'MM'));
         --IF SQL%NOTFOUND THEN
           --  RAISE_APPLICATION_ERROR(-20000,'No se encontro registro de mes proximo en AH_SAL_MENSUALES');
         --END IF;
   END IF;
END IF;

EXCEPTION
  when no_data_found then
    null;
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error '||p_nrcuent||' '||sqlerrm);
END;

--proceso principal
BEGIN
  DBMS_APPLICATION_INFO.SET_ACTION('PRC_LIQ_CAR_SOBREGIROS');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRC_LIQ_CAR_SOBREGIROS ejecutando PAG_CAR.PR_DEB_CRE_BATCH');
  v_hubo_error     := 'N';
  v_nro_reg        := 0;
  v_fecha          := pag_cal.FU_OBT_FEC_ACTUAL(1);
  rv_gcale         := pag_cal.fu_obt_reg_cal(1);
  v_fcproxi        := rv_gcale.fec_proxima;
  --v_hora           := fug_ini_hora(sysdate,'HH24:MI:SS');--to_char(sysdate,'HH24:MI:SS');
  v_hora := to_char(sysdate,'HH24:MI:SS');
  v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
  
  v_nro_secuencia  := -999; --hacer x operación de deb/cred, no x cuenta
  v_lugar := null;
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --busco oficina origen
  begin
    select cod_oficina
      into v_cod_ofi_origen
      from ba_usuarios
     where cod_usuario = user;
  exception
    when others then
       raise_application_error(20009,'Al recup. oficina del usuario '||sqlerrm);
  end;
  -----------------------------
  --OJO VER PARA PROCESAR 'TODOS' LOS DEBITOS CREDITOS CUANDO NO RECIBE PARAMETRO
  --
  begin
    select tip_movimiento, det_sql,
           cod_transaccion, cod_mod_padre, cod_mad_padre,
           descripcion, cod_transaccion, sobregiro,
           cob_parcial, pendiente, pro_error, dif_hora,
           pre_proceso, pos_proceso, iva_incluido
    into   v_tipo, v_sentencia,
           v_tra_padre, v_mod_padre, v_mad_padre,
           v_concepto, v_transaccion, v_sobregiro,
           v_cob_parcial, v_pendiente, v_pro_error, v_dif_hora,
           v_pre_proceso, v_pos_proceso, v_iva_incluido
    from   GE_DEB_CRE_BATCH
    where  COD_DEB_CRE_BATCH = P_COD_DEB_CRE;
    --agregar order by al query si no tiene, siempre x moneda (posición 3)
    if instr(upper(v_sentencia),'ORDER')= 0 THEN
      v_sentencia := v_sentencia ||' ORDER BY 3';
    end if;
  exception
    when no_data_found then
      v_cod_error := 100; --menores al 100 son del pag_cta.
      v_lugar := 'No existen datos para el Crédito / Débito '||p_cod_deb_cre;
      v_hubo_error := 'S';
      raise_application_error(-20000,v_lugar);
    when others then
      v_cod_error := 100;
      v_lugar := 'Recup.Déb.Créd. '||p_cod_deb_cre || ' - ' ||sqlerrm;
      v_hubo_error := 'S';
      raise_application_error(-20000,v_lugar);
  end;
  --tipo de mov. de contrapartida
  if v_tipo = 'C' then
    v_tip_mov_contra := 'D';
  else
    v_tip_mov_contra := 'C';
  end if;
  /*
  || PCC-Exoneración y Extorno de Comisiones y Tasas
  || PAG_CAR.PR_DEB_CRE_BATCH(8) y al PAG_CAR.PR_DEB_CRE_BATCH(9)
  || Se llama desde el PRC_LIQ_CAR_SOBREGIROS
  */
  IF p_cod_deb_cre in (8, 9) THEN
     v_cod_programa := 'PRC_LIQ_CAR_SOBREGIROS';
  ELSE
     v_cod_programa := 'PAG_CAR.PR_DEB_CRE_BATCH(' || p_cod_deb_cre || ')';
  END IF;
  g_fre_proceso := fug_obt_fre_proceso(v_cod_programa);
  ---
  --verificar parámetros de contrapartida generales (no x moneda aún)
  if fug_obt_tip_mov_contable(v_mod_padre, v_mad_padre, v_transaccion) not in ( v_tip_mov_contra, 'A') and
     fug_obt_tip_mov_contable(3, 31, v_transaccion) not in ( v_tip_mov_contra, 'A') and
     fug_obt_tip_mov_contable(4, 41, v_transaccion) not in ( v_tip_mov_contra, 'A') then
    v_exi_contra := 'S'; --exigir contrapartida
    begin
      select 1
        into v_contra
        from ge_deb_cre_batch_det
       where cod_deb_cre_batch = p_cod_deb_cre;
    exception
      when no_data_found then
        v_cod_error := 102;
        v_lugar := 'No existen Parámetros de Contrapartida. Verifique proceso '||p_cod_deb_cre;
        v_hubo_error := 'S';
        raise_application_error(-20000,v_lugar);
      when too_many_rows then
        null;
      when others then
        v_cod_error := 102;
        v_lugar := 'Recup.Déb.Créd.Det '||p_cod_deb_cre || ' - ' ||sqlerrm;
        v_hubo_error := 'S';
        raise_application_error(-20000,v_lugar);
    end;
  end if;

  v_mto_total := 0;
  v_mto_tot_cargo := 0;
  -----------------------------
  if v_hubo_error = 'N' then
    -- ejecuto proceso previo si existe
    if v_pre_proceso is not null then
        sql_util.ejecute_dml('BEGIN '||v_pre_proceso||'; END;', v_error);
        v_error := replace(v_error,'SQL_UTIL.EJECUTE_DML','*');
        if v_error is not null then
           v_cod_error := 104;
           v_hubo_error := 'S';
           v_lugar := 'Proceso previo '||v_error;
           raise_application_error(-20000,v_lugar);
        end if;
    end if;
   -- if p_nro_cuenta is not null then
    v_sentencia := replace(v_sentencia,'&NRO_CUENTA',p_nro_cuenta);
    --Recuperamos la cantidad total de registros a ser procesados
    v_sql_count := 'SELECT COUNT(*) FROM (' || rtrim(v_sentencia, ';') || ')';
    EXECUTE IMMEDIATE v_sql_count INTO v_cant_registros;
  --  end if;
    --
    open c_cursor for v_sentencia;
    loop
      fetch c_cursor into v_cuenta, v_mto_pago, v_cod_moneda, v_cantidad, v_nro_documento, v_nro_documento2;
      --sólo al iniciar verificar si trae datos
      -- RI : 21/10/09 : Si el cursor no trae nada no debe dar error
     /* if c_cursor%notfound and v_nro_reg = 0 then
        v_cod_error := 101;
        v_lugar := 'El SQL definido no recupera datos. Verifique.';
        v_hubo_error := 'S';
        lp_error;
        raise_application_error(-20000,v_lugar); --debe caer el proceso ya que está mal definido
      end if;*/
      exit when c_cursor%notfound;
      v_rowcount := v_rowcount + 1;
      -- Solo entra aquí cada 10,000 registros
      IF MOD(v_rowcount, 10000) = 0 THEN
        v_mensaje := v_rowcount||' cuentas procesadas de '||v_cant_registros;
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
      END IF;
      v_cotizacion := nvl(pag_gen.fu_obt_cotizacion( v_cod_moneda, v_fecha),1);
      v_nro_reg := v_nro_reg + 1;
      if v_dif_hora = 'S' then
        --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
        v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
      end if;
      pag_cta.pr_set_nro_documento2(v_nro_documento2);
      --limpiar variables
      v_cod_tas_cargo  := 0;
      v_val_tas_cargo  := 0;
      v_mto_cargo      := 0;
      v_tra_iva        := null;
      v_cod_tas_iva    := null;
      v_val_tas_iva    := null;
      v_mto_iva        := 0;
      v_cod_mad_cta    := null;
      v_sal_disponible := 0;
      v_mto_mov        := 0;
      v_mto_cargo_par  := 0;
      v_mto_iva_par    := 0;
      pag_cta.g_sobregira := 'N';
      v_val_max_tae    := 0;
      --verificar monto
      if nvl(v_mto_pago,0) <= 0 then
        v_cod_error := 102;
        v_lugar := 'Monto definido en el SQL debe ser mayor a cero: ' || v_mto_pago;
        v_hubo_error := 'S';
        lp_error;
        raise_application_error(-20000,v_lugar); --debe caer el proceso ya que está mal definido
      end if;
      --verificar cantidad
      if v_cantidad <= 0 then
        v_cod_error := 102;
        v_lugar := 'Cantidad definida en el SQL debe ser mayor a cero: ' || v_cantidad;
        v_hubo_error := 'S';
        lp_error;
        raise_application_error(-20000,v_lugar); --debe caer el proceso ya que está mal definido
      end if;
      --cantidad sólo permitida para cargos
      if v_cantidad > 0 and v_tipo <> 'G' then
        v_cod_error := 103;
        v_lugar := '''Cantidad'''' sólo válida para Cargos: ' || v_cantidad;
        v_hubo_error := 'S';
        lp_error;
        raise_application_error(-20000,v_lugar); --debe caer el proceso ya que está mal definido
      end if;
      --- Recuperar datos de la cuenta
      pag_cta.pr_obt_cuenta(v_cuenta);
      if pag_cta.g_cod_error <> 0 then
        v_cod_error := 104;
        v_lugar := 'Recup. datos de la cuenta ' || v_cuenta || ' - ' ||pag_cta.g_msj_error;
        v_hubo_error := 'S';
        lp_error;
        goto siguiente;
      end if;
      v_cod_mad_cta := pag_cta.g_ctas.cod_modalidad;
      v_sal_disponible := pag_cta.fu_sal_dis_combinada;
      v_estado         := pag_cta.G_CTAS.estado;
      --- Verificar monedas -- --OJO VER CON AGUS
      --v_mto_pago := pag_gen.fu_con_mon_a_moneda(v_moneda, pag_cta.g_ctas.cod_moneda,v_mto_pago);
      if v_cod_moneda <> pag_cta.g_ctas.cod_moneda then
        v_cod_error := 105;
        v_lugar := 'Moneda de la Cuenta y del SQL diferentes ' || v_cod_moneda || ' - ' ||pag_cta.g_ctas.cod_moneda;
        v_hubo_error := 'S';
        lp_error;
        goto siguiente;
      end if;
      --ahorro, cta cte y tarjetas
      if v_cod_mad_cta not in (31,41) and substr(v_cod_mad_cta,1,1) <> 5 then
        v_cod_error := 106;
        v_lugar := 'Modalidad de la Cuenta no permite Déb./Créd. ' || v_cuenta || ' - ' ||v_cod_mad_cta;
        v_hubo_error := 'S';
        lp_error;
        goto siguiente;
      end if;
      --redondeo
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_mod_padre,v_mad_padre,v_cod_moneda);

      -------------------------------------------------corte
      --si tiene indicador para generar mov con diferente hora, cambia la hora por cada cuenta y ya no se hay corte x moneda
      if v_dif_hora = 'N' then
        --corte por moneda para la contrapartida
        if v_mon_corte <> v_cod_moneda then
          if v_mon_corte <> 'x' then
            --corte, buscar parametrización y generar movimiento de contrapartida
            for reg in det(v_mon_corte) loop
              v_existe := 'S';
              --- INSERTAR MOVIMIENTO CONTRAPARTIDA ---
              v_cta_contra := reg.nro_cuenta;
              v_mod_contra := reg.cod_modulo;
              v_mad_contra := reg.cod_modalidad;
              v_ofi_contra := reg.cod_oficina;
              v_rub_contra := reg.cod_rubro;
              v_tra_contra := reg.cod_transaccion;
              v_lugar := 'cta : '||reg.nro_cuenta||' lp_grn_mov_contraparte';
              lp_gen_mov_contraparte(v_cta_contra,v_mod_contra,v_mad_contra,v_ofi_contra,v_rub_contra,v_tra_contra,v_mon_corte);
            end loop;
            if v_existe <> 'S' and v_exi_contra = 'S' then
               v_cod_error := 118;
                v_lugar := 'No existe Parámetro de Contrapartida para la Moneda. Verifique. '||v_cod_moneda;
                v_hubo_error := 'S';
                raise_application_error(-20000,v_lugar);
            end if;
          end if;--corte
          v_mon_corte := v_cod_moneda;
          v_mto_total := 0;
          v_mto_tot_cargo := 0;
        end if;--cambia moneda
      else
        --cerar monto total, ya que se genera un movimiento x cuenta y una contraparte si tiene parametrizada
        v_mto_total := 0;
        v_mto_tot_cargo := 0;
      end if;
      -------------------------------------------------corte

      --determinar el monto del movimiento
      if v_tipo in ('D', 'C') then
        v_mto_mov := v_mto_pago;
        v_tip_mov := v_tipo;
      elsif v_tipo = 'G' then
        v_tip_mov := 'D'; --debe hacer débito
        --es cargo, calcular el monto e impuesto, en base al monto imponible
        begin
          v_lugar := 'cta : '||v_cuenta||' pr_obt_Cargos';
          PR_OBT_CARGOS(pag_cta.g_ctas.cod_oficina,v_cuenta,v_cod_moneda,v_mto_pago,pag_cta.G_CTAS.cod_modulo, pag_cta.g_ctas.cod_modalidad,
             v_transaccion, v_iva_incluido,v_cod_tas_cargo, v_val_tas_cargo, v_mto_cargo, v_tra_iva, v_cod_tas_iva, v_val_tas_iva, v_mto_iva);
        exception
          when others then
            v_cod_error := 107;
            v_lugar := sqlerrm;
            v_hubo_error := 'S';
            lp_error;
            goto siguiente;
        end;
        -- Para evitar que continue con los pasos siguientes si no hay nada que cobrar...
        if (nvl(v_mto_cargo,0)+ nvl(v_mto_iva,0)) = 0 then
           goto siguiente;
        end if;
        --si tiene cantidad
        if v_cantidad > 0 then
          v_mto_cargo := nvl(v_mto_cargo,0) * v_cantidad; --si tiene cantidad se multiplica
          v_mto_iva := nvl(v_mto_iva,0) * v_cantidad; --si tiene cantidad se multiplica
        end if;

        --Verificar si excede el límite s/ TAE para Sobregiro
        if pag_cta.g_ctas.cod_modulo = 4 and pag_cta.g_ctas.cod_modalidad = 41 then
          v_val_max_tae := fuc_obt_val_max_tae(v_cuenta,pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,v_transaccion,v_mto_cargo);
          if v_mto_cargo > v_val_max_tae then
             v_mto_cargo := v_val_max_tae; /*fuc_obt_val_max_tae(v_cuenta,
                                                pag_cta.g_ctas.cod_modulo,
                                                pag_cta.g_ctas.cod_modalidad,
                                                v_transaccion,
                                                v_mto_cargo);*/
              --Volver a Calcular el IVA
              v_mto_iva := round(nvl(v_mto_cargo,0)*nvl(v_val_tas_iva,0)/(100),v_redondeo);
          end if;
        end if;
        --

        --monto operación es el cargo + el impuesto
        v_mto_mov := nvl(v_mto_cargo,0) + nvl(v_mto_iva,0);

      end if;

      --v_nro_secuencia := v_nro_secuencia + 1;
      --si es crédito o si es débito/cargo y el saldo es suficiente, genera el movimiento
      if v_tipo = 'C' or v_sal_disponible >= v_mto_mov then
        if v_tipo = 'G' and v_mto_cargo > 0 then --generar mov x el cargo
          --v_nro_secuencia := v_nro_secuencia + 1;
          --- Actualizar los datos de las cuentas con movimientos.
          if v_nro_Secuencia > 990 then
            --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
            v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
            v_nro_secuencia := -999;
          end if;
          v_lugar := '1- PR_aCT_OPERACION';
          PAG_CTA.PR_ACT_OPERACION
               (v_cuenta      -- P_NRO_CUENTA
               ,v_hora        -- P_HORA
               ,v_tip_mov        -- P_TIP_MOVIMIENTO
               ,v_cod_moneda  -- P_COD_MONEDA
               ,v_mto_cargo     -- P_MONTO
               ,v_tra_padre   -- P_COD_TRA_PADRE
               ,v_transaccion -- P_COD_TRANSACCION
               ,v_nro_documento  --P_NRO_DOCUMENTO
               ,v_cotizacion          --P_COTIZACION
               -- ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/10
               ,pag_cta.g_ctas.cod_oficina --Ofic.de la cuenta
               ,v_mod_padre   -- P_COD_MOD_PADRE
               ,v_mad_padre   -- P_COD_MAD_PADRE
               ,v_cod_tas_cargo          --P_COD_TASA
               ,v_val_tas_cargo          --P_VAL_TASA
               ,v_concepto    -- P_CONCEPTO
               ,'N'           -- p_EMI_AVISO
               ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
               ,v_fecha       -- P_FEC_VALOR
               ,null          -- P_COD_BANCO
               ,null          -- P_COD_CAUSA
               ,round((v_mto_cargo * v_cotizacion),v_red_mon_local)); -- P_MTO_EQU_LOCAL

          if pag_cta.fu_obt_cod_error() <> 0 then
            v_cod_error := pag_cta.G_COD_ERROR;
            v_lugar := 'Mov.Cta.(cargo) '||pag_cta.fu_obt_msj_error();
            v_hubo_error := 'S';
            lp_error;
            goto siguiente;
          else
            --acumular monto
            v_lugar := 'cta : '||v_cuenta||' acum MONTO';
            v_mto_total := v_mto_total + v_mto_cargo;
            v_mto_tot_cargo := v_mto_tot_cargo + v_mto_cargo;
          end if;
          if v_mto_iva > 0 then --generar movimiento x el iva
            --v_nro_secuencia := v_nro_secuencia + 1;
            --- Actualizar los datos de las cuentas con movimientos.
            if v_nro_Secuencia > 990 then
              --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
              v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
              v_nro_secuencia := -999;
            end if;
            v_lugar := '2- PR_ACT_OPERACION';
            PAG_CTA.PR_ACT_OPERACION
                 (v_cuenta      -- P_NRO_CUENTA
                 ,v_hora        -- P_HORA
                 ,v_tip_mov        -- P_TIP_MOVIMIENTO
                 ,v_cod_moneda  -- P_COD_MONEDA
                 ,v_mto_iva    -- P_MONTO
--                 ,v_tra_padre   -- P_COD_TRA_PADRE
                 ,v_tra_iva -- P_COD_TRA_PADRE
                 ,v_tra_iva -- P_COD_TRANSACCION
                 ,v_nro_documento  --P_NRO_DOCUMENTO
                 ,v_cotizacion     --P_COTIZACION
--              ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/10
                 ,pag_cta.g_ctas.cod_oficina --Ofic.de la cuenta
                 ,v_mod_padre   -- P_COD_MOD_PADRE
                 ,v_mad_padre   -- P_COD_MAD_PADRE
                 ,v_cod_tas_iva          --P_COD_TASA
                 ,v_val_tas_iva          --P_VAL_TASA
                 ,v_concepto    -- P_CONCEPTO
                 ,'N'           -- p_EMI_AVISO
                 ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                 ,v_fecha       -- P_FEC_VALOR
                 ,null          -- P_COD_BANCO
                 ,null          -- P_COD_CAUSA
                 ,round((v_mto_iva * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

            if pag_cta.fu_obt_cod_error() <> 0 then
              v_cod_error := pag_cta.G_COD_ERROR;
              v_lugar := 'Mov.Cta.(iva) '||pag_cta.fu_obt_msj_error();
              v_hubo_error := 'S';
              lp_error;
              goto siguiente;
            else
              --acumular monto
              v_mto_total := v_mto_total + v_mto_iva;
            end if;
          end if;
          -- actualizar el acumulado de saldos mensuales solo si se corre como proceso mensual
          if to_char(v_fcproxi,'mmyyyy') <> to_char(v_Fecha,'mmyyyy') then
            LP_ACT_SAL_MENSUAL(v_mto_mov, pag_cta.g_ctas.cod_modulo,
                               pag_Cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_oficina,
                               v_cuenta);
          end if;

        else --generar mov x el monto del movimiento
          --v_nro_secuencia := v_nro_secuencia + 1;
          --- Actualizar los datos de las cuentas con movimientos.
          if v_nro_Secuencia > 990 then
            --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
            v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
            v_nro_secuencia := -999;
          end if;
          v_lugar := '3- PR_ACT_OPERACION';
          PAG_CTA.PR_ACT_OPERACION
               (v_cuenta      -- P_NRO_CUENTA
               ,v_hora        -- P_HORA
               ,v_tip_mov        -- P_TIP_MOVIMIENTO
               ,v_cod_moneda  -- P_COD_MONEDA
               ,v_mto_mov     -- P_MONTO
               ,v_tra_padre   -- P_COD_TRA_PADRE
               ,v_transaccion -- P_COD_TRANSACCION
               ,v_nro_documento  --P_NRO_DOCUMENTO
               ,v_cotizacion     --P_COTIZACION
--               ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN RI: 22/03/10
               ,pag_cta.g_ctas.cod_oficina --Ofic.de la cuenta
               ,v_mod_padre   -- P_COD_MOD_PADRE
               ,v_mad_padre   -- P_COD_MAD_PADRE
               ,null          --P_COD_TASA
               ,null          --P_VAL_TASA
               ,v_concepto    -- P_CONCEPTO
               ,'N'           -- p_EMI_AVISO
               ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
               ,v_fecha       -- P_FEC_VALOR
               ,null          -- P_COD_BANCO
               ,null          -- P_COD_CAUSA
               ,round((v_mto_cargo * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

          if pag_cta.fu_obt_cod_error() <> 0 then
            v_cod_error := pag_cta.G_COD_ERROR;
            v_lugar := 'Mov.Cta. '||pag_cta.fu_obt_msj_error();
            v_hubo_error := 'S';
            lp_error;
            goto siguiente;
          else
            --acumular monto
            v_mto_total := v_mto_total + v_mto_mov;
          end if;
          -- actualizar el acumulado de saldos mensuales solo si se corre como proceso mensual
          if to_char(v_fcproxi,'mmyyyy') <> to_char(v_Fecha,'mmyyyy') then
            LP_ACT_SAL_MENSUAL(v_mto_mov, pag_cta.g_ctas.cod_modulo,
                               pag_Cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_oficina,
                               v_cuenta);
          end if;
        end if; --cargo o crédito/débito
        --
      else --es débito o cargo y no tiene saldo suficiente, recalcular hasta el cargo e iva hasta el disponible
        if v_sobregiro = 'S' then --si permite sobregiro
          if v_cod_mad_cta <> 41 then
            v_cod_error := 108;
            v_lugar := 'Saldo Insuficiente. Modalidad de la Cta. no permite Sobregiros';
            v_hubo_error := 'S';
            lp_error;
            goto siguiente;
          else --sólo cta cte
            --generar el débito -> cargo o débito normal
            if v_tipo = 'G' and v_mto_cargo > 0 then --generar mov x el cargo
              --v_nro_secuencia := v_nro_secuencia + 1;
              --setear variable para sobregiro del pag_cta
              pag_cta.g_sobregira := 'S';
              --- Actualizar los datos de las cuentas con movimientos.
              if v_nro_Secuencia > 990 then
                --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
                v_nro_secuencia := -999;
              end if;
              v_lugar := '4- PR_ACT_OPERACION';
              PAG_CTA.PR_ACT_OPERACION
                   (v_cuenta      -- P_NRO_CUENTA
                   ,v_hora        -- P_HORA
                   ,v_tip_mov        -- P_TIP_MOVIMIENTO
                   ,v_cod_moneda  -- P_COD_MONEDA
                   ,v_mto_cargo    -- P_MONTO
                   ,v_tra_padre   -- P_COD_TRA_PADRE
                   ,v_transaccion -- P_COD_TRANSACCION
                   ,v_nro_documento  --P_NRO_DOCUMENTO
                   ,v_cotizacion     --P_COTIZACION
--                   ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/10
                   ,pag_cta.g_ctas.cod_oficina --Ofic.de la cuenta
                   ,v_mod_padre   -- P_COD_MOD_PADRE
                   ,v_mad_padre   -- P_COD_MAD_PADRE
                   ,v_cod_tas_cargo          --P_COD_TASA
                   ,v_val_tas_cargo          --P_VAL_TASA
                   ,v_concepto    -- P_CONCEPTO
                   ,'N'           -- p_EMI_AVISO
                   ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                   ,v_fecha       -- P_FEC_VALOR
                   ,null          -- P_COD_BANCO
                   ,null          -- P_COD_CAUSA
                   ,round((v_mto_cargo * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

              if pag_cta.fu_obt_cod_error() <> 0 then
                v_cod_error := pag_cta.G_COD_ERROR;
                v_lugar := 'Mov.Cta.(cargo - sobreg) '||pag_cta.fu_obt_msj_error();
                v_hubo_error := 'S';
                lp_error;
                goto siguiente;
              else
                --acumular monto
                v_mto_total := v_mto_total + v_mto_cargo;
                v_mto_tot_cargo := v_mto_tot_cargo + v_mto_cargo;
              end if;
              if v_mto_iva > 0 then --generar movimiento x el iva
                --v_nro_secuencia := v_nro_secuencia + 1;
                --- Actualizar los datos de las cuentas con movimientos.
                if v_nro_Secuencia > 990 then
                  --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                  v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
                  v_nro_secuencia := -999;
                end if;
                v_lugar := '5- PR_ACT_OPERACION';
                PAG_CTA.PR_ACT_OPERACION
                     (v_cuenta      -- P_NRO_CUENTA
                     ,v_hora        -- P_HORA
                     ,v_tip_mov        -- P_TIP_MOVIMIENTO
                     ,v_cod_moneda  -- P_COD_MONEDA
                     ,v_mto_iva   -- P_MONTO
--                     ,v_tra_padre   -- P_COD_TRA_PADRE
                     ,v_tra_iva -- P_COD_TRA_PADRE
                     ,v_tra_iva -- P_COD_TRANSACCION
                     ,v_nro_documento  --P_NRO_DOCUMENTO
                     ,v_cotizacion     --P_COTIZACION
--                   ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/10
                     ,pag_cta.g_ctas.cod_oficina --Ofic.de la cuenta
                     ,v_mod_padre   -- P_COD_MOD_PADRE
                     ,v_mad_padre   -- P_COD_MAD_PADRE
                     ,v_cod_tas_iva          --P_COD_TASA
                     ,v_val_tas_iva          --P_VAL_TASA
                     ,v_concepto    -- P_CONCEPTO
                     ,'N'           -- p_EMI_AVISO
                     ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                     ,v_fecha       -- P_FEC_VALOR
                     ,null          -- P_COD_BANCO
                     ,null          -- P_COD_CAUSA
                     ,round((v_mto_iva * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

                if pag_cta.fu_obt_cod_error() <> 0 then
                  v_cod_error := pag_cta.G_COD_ERROR;
                  v_lugar := 'Mov.Cta.(iva - sobreg) '||pag_cta.fu_obt_msj_error();
                  v_hubo_error := 'S';
                  lp_error;
                  goto siguiente;
                else
                  --acumular monto
                  v_mto_total := v_mto_total + v_mto_iva;
                end if;
              end if;
              -- actualizar el acumulado de saldos mensuales solo si se corre como proceso mensual
              if to_char(v_fcproxi,'mmyyyy') <> to_char(v_Fecha,'mmyyyy') then
                  LP_ACT_SAL_MENSUAL(v_mto_mov, pag_cta.g_ctas.cod_modulo,
                                     pag_Cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_oficina,
                                     v_cuenta);
              end if;

            else --generar débito normal
              --v_nro_secuencia := v_nro_secuencia + 1;
              --- Actualizar los datos de las cuentas con movimientos.
              if v_nro_Secuencia > 990 then
               --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
               v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
               v_nro_secuencia := -999;
              end if;
              v_lugar := '6- PR_ACT_OPERACION';
              PAG_CTA.PR_ACT_OPERACION
                     (v_cuenta      -- P_NRO_CUENTA
                     ,v_hora        -- P_HORA
                     ,v_tip_mov        -- P_TIP_MOVIMIENTO
                     ,v_cod_moneda  -- P_COD_MONEDA
                     ,v_mto_mov     -- P_MONTO
                     ,v_tra_padre   -- P_COD_TRA_PADRE
                     ,v_transaccion -- P_COD_TRANSACCION
                     ,v_nro_documento   --P_NRO_DOCUMENTO
                     ,v_cotizacion      --P_COTIZACION
--                   ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/10
                     ,pag_cta.g_ctas.cod_oficina  --Ofic. de la cuenta
                     ,v_mod_padre   -- P_COD_MOD_PADRE
                     ,v_mad_padre   -- P_COD_MAD_PADRE
                     ,null          --P_COD_TASA
                     ,null          --P_VAL_TASA
                     ,v_concepto    -- P_CONCEPTO
                     ,'N'           -- p_EMI_AVISO
                     ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                     ,v_fecha       -- P_FEC_VALOR
                     ,null          -- P_COD_BANCO
                     ,null          -- P_COD_CAUSA
                     ,round((v_mto_cargo * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

              if pag_cta.fu_obt_cod_error() <> 0 then
                v_cod_error := pag_cta.G_COD_ERROR;
                v_lugar := 'Mov.Cta.(sobreg) '||pag_cta.fu_obt_msj_error();
                v_hubo_error := 'S';
                lp_error;
                goto siguiente;
              else
                --acumular monto
                v_mto_total := v_mto_total + v_mto_mov;
              end if;
              -- actualizar el acumulado de saldos mensuales solo si se corre como proceso mensual
              if to_char(v_fcproxi,'mmyyyy') <> to_char(v_Fecha,'mmyyyy') then
                LP_ACT_SAL_MENSUAL(v_mto_mov, pag_cta.g_ctas.cod_modulo,
                                   pag_Cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_oficina,
                                   v_cuenta);
              end if;
          end if;--cargo o débito
        end if; --fin tipo cta
          --
        else --sin sobregiro
          --sólo si tiene algo de saldo disponible

          if v_cob_parcial = 'S' then --si permite cobro parcial, sólo para cargos está permitido
            /*if v_sal_disponible = 0 then
              v_cod_error := 109;
              v_lugar := 'Cuenta sin Saldo Disponible ' || v_cuenta || ' - ' ||v_sal_disponible;
              v_hubo_error := 'S';
              lp_error;
              goto siguiente;
            end if;                */  -- RI: ver que hacer con esto

            --recalcular montos para cobrarle hasta el monto disponible
            v_mto_cargo_par := round(v_sal_disponible * v_mto_cargo / v_mto_total, v_redondeo);
            v_mto_iva_par := v_sal_disponible - v_mto_cargo_par;
            --generar débito x cargo parcial
            --v_nro_secuencia := v_nro_secuencia + 1;
            --- Actualizar los datos de las cuentas con movimientos.
            if v_nro_Secuencia > 990 then
              --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
              v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
              v_nro_secuencia := -999;
            end if;
            v_lugar := '8- PR_ACT_OPERACION';
            PAG_CTA.PR_ACT_OPERACION
                 (v_cuenta         -- P_NRO_CUENTA
                 ,v_hora           -- P_HORA
                 ,v_tip_mov        -- P_TIP_MOVIMIENTO
                 ,v_cod_moneda     -- P_COD_MONEDA
                 ,v_mto_cargo_par  -- P_MONTO
                 ,v_tra_padre      -- P_COD_TRA_PADRE
                 ,v_transaccion    -- P_COD_TRANSACCION
                 ,v_nro_documento  --P_NRO_DOCUMENTO
                 ,v_cotizacion     --P_COTIZACION
--               ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/2010
                 ,pag_cta.g_ctas.cod_oficina  --Ofic. de la cuenta
                 ,v_mod_padre      -- P_COD_MOD_PADRE
                 ,v_mad_padre      -- P_COD_MAD_PADRE
                 ,v_cod_tas_cargo  --P_COD_TASA
                 ,v_val_tas_cargo  --P_VAL_TASA
                 ,v_concepto    -- P_CONCEPTO
                 ,'N'           -- p_EMI_AVISO
                 ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                 ,v_fecha       -- P_FEC_VALOR
                 ,null          -- P_COD_BANCO
                 ,null          -- P_COD_CAUSA
                 ,round((v_mto_cargo * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

            if pag_cta.fu_obt_cod_error() <> 0 then
              v_cod_error := pag_cta.G_COD_ERROR;
              v_lugar := 'Mov.Cta.(cargo - sobreg) '||pag_cta.fu_obt_msj_error();
              v_hubo_error := 'S';
              lp_error;
              goto siguiente;
            else
              --acumular monto
              v_mto_total := v_mto_total + v_mto_cargo_par;
              v_mto_tot_cargo := v_mto_tot_cargo + v_mto_cargo_par;
            end if;
            if v_mto_iva > 0 then --generar movimiento x el iva
              --v_nro_secuencia := v_nro_secuencia + 1;
              --- Actualizar los datos de las cuentas con movimientos.
              if v_nro_Secuencia > 990 then
                --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');        
                v_nro_secuencia := -999;
              end if;
              v_lugar := 'Crear movimiento del IVA.';
              PAG_CTA.PR_ACT_OPERACION
                   (v_cuenta      -- P_NRO_CUENTA
                   ,v_hora        -- P_HORA
                   ,v_tip_mov        -- P_TIP_MOVIMIENTO
                   ,v_cod_moneda  -- P_COD_MONEDA
                   ,v_mto_iva_par     -- P_MONTO
--                   ,v_tra_padre   -- P_COD_TRA_PADRE
                   ,v_tra_iva -- P_COD_TRA_PADRE
                   ,v_tra_iva -- P_COD_TRANSACCION
                   ,v_nro_documento    --P_NRO_DOCUMENTO
                   ,v_cotizacion       --P_COTIZACION
--                   ,v_cod_ofi_origen -- P_COD_OFI_ORIGEN --RI: 22/03/2010
                   ,pag_cta.g_ctas.cod_oficina  --Ofic. de la cuenta
                   ,v_mod_padre   -- P_COD_MOD_PADRE
                   ,v_mad_padre   -- P_COD_MAD_PADRE
                   ,v_cod_tas_iva          --P_COD_TASA
                   ,v_val_tas_iva          --P_VAL_TASA
                   ,v_concepto    -- P_CONCEPTO
                   ,'N'           -- p_EMI_AVISO
                   ,v_nro_secuencia -- P_NRO_SECUENCIA IN OUT
                   ,v_fecha       -- P_FEC_VALOR
                   ,null          -- P_COD_BANCO
                   ,null          -- P_COD_CAUSA
                   ,round((v_mto_iva * v_cotizacion),v_red_mon_local));-- P_MTO_EQU_LOCAL

              if pag_cta.fu_obt_cod_error() <> 0 then
                v_cod_error := pag_cta.G_COD_ERROR;
                v_lugar := 'Mov.Cta.(iva - sobreg) '||pag_cta.fu_obt_msj_error();
                v_hubo_error := 'S';
                lp_error;
                goto siguiente;
              else
                --acumular monto
                v_mto_total := v_mto_total + v_mto_iva_par;
              end if;
            end if;--iva
            -- actualizar el acumulado de saldos mensuales solo si se corre como proceso mensual
            if to_char(v_fcproxi,'mmyyyy') <> to_char(v_Fecha,'mmyyyy') then
               LP_ACT_SAL_MENSUAL(v_mto_mov, pag_cta.g_ctas.cod_modulo,
                                  pag_Cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_oficina,
                                  v_cuenta);
            end if;

            If v_pendiente = 'S' and (v_mto_cargo - v_mto_cargo_par) > 0 then
              --generar movimiento pendiente para intentar cobrar posteriormente
              v_lugar := 'cta : '||v_cuenta||'LP_GEN_MOV_PENDIENTE';
              lp_gen_mov_pendiente; --pasar el saldo
             --goto siguiente;
            End if;
           else --sin cobro parcial
            If v_pendiente = 'S' then   --Generar movimiento pendiente
              v_lugar := 'cta : '||v_cuenta||'LP_GEN_MOV_PENDIENTE';
              lp_gen_mov_pendiente;
            else
              v_cod_error := 111;
              v_lugar := 'Cuenta con Saldo Insuficiente. No permite Sobregiro ni Cobro Parcial.';
              v_hubo_error := 'S';
              lp_error;
              goto siguiente;
            end if;
          end if;--cobro parcial
        end if;--sobregiro
      end if;
      --fin movimientos de cuentas
      --generar movimiento de contrapartida para cada cuenta si tiene diferente hora
      if v_dif_hora = 'S' and v_mto_total > 0 then
        --corte, buscar parametrización y generar movimiento de contrapartida
        for reg in det(v_cod_moneda) loop
          v_existe := 'S';
          --- INSERTAR MOVIMIENTO CONTRAPARTIDA ---
          v_cta_contra := reg.nro_cuenta;
          v_mod_contra := reg.cod_modulo;
          v_mad_contra := reg.cod_modalidad;
          v_ofi_contra := reg.cod_oficina;
          v_rub_contra := reg.cod_rubro;
          v_tra_contra := reg.cod_transaccion;
          v_lugar := 'cta : '||REG.NRO_cuenta||'LP_GEN_MOV_CONTRAPARTE';
          lp_gen_mov_contraparte(v_cta_contra,v_mod_contra,v_mad_contra,v_ofi_contra,v_rub_contra,v_tra_contra,v_cod_moneda);
        end loop;
        if v_existe <> 'S' and v_exi_contra = 'S' then
           v_cod_error := 118;
            v_lugar := 'No existe Parámetro de Contrapartida para la Moneda. Verifique. '||v_cod_moneda;
            v_hubo_error := 'S';
            raise_application_error(-20000,v_lugar);
        end if;
      end if;

      --- Siguiente registro
      <<siguiente>>
      null;
    end loop; --hasta aquí procesamiento de cuentas
    --setear variable para sobregiro del pag_cta
    pag_cta.g_sobregira := 'N';
    --generar contrapartida por el ultimo corte
    if v_dif_hora = 'N' then
      if v_mon_corte <> 'x' then
        --corte, buscar parametrización y generar movimiento de contrapartida
        for reg in det(v_mon_corte) loop
          v_existe := 'S';
          --- INSERTAR MOVIMIENTO CONTRAPARTIDA ---
          v_cta_contra := reg.nro_cuenta;
          v_mod_contra := reg.cod_modulo;
          v_mad_contra := reg.cod_modalidad;
          v_ofi_contra := reg.cod_oficina;
          v_rub_contra := reg.cod_rubro;
          v_tra_contra := reg.cod_transaccion;
          v_lugar := 'cta : '||REG.NRO_cuenta||'LP_GEN_MOV_CONTRAPARTE';
          lp_gen_mov_contraparte(v_cta_contra,v_mod_contra,v_mad_contra,v_ofi_contra,v_rub_contra,v_tra_contra,v_mon_corte);
        end loop;
        if v_existe <> 'S' and v_exi_contra = 'S' then
           v_cod_error := 118;
            v_lugar := 'No existe Parámetro de Contrapartida para la Moneda. Verifique. '||v_mon_corte;
            v_hubo_error := 'S';
            raise_application_error(-20000,v_lugar);
        end if;
      end if;
    end if; --dif hora
    --
    g_monto := v_mto_total;
    g_mto_cargo := v_mto_tot_cargo;
    -- ejecuto proceso posterior si existe
    if v_pos_proceso is not null and v_hubo_error = 'N' then
        sql_util.ejecute_dml('BEGIN '||v_pos_proceso||'; END;', v_error);
        v_error := replace(v_error,'SQL_UTIL.EJECUTE_DML','*');
        if v_error is not null then
           v_cod_error := 108;
           v_hubo_error := 'S';
           v_lugar := 'Proceso Posterior '||v_error;
           raise_application_error(-20000,v_lugar);
        end if;
    end if;

    --
  end if;
  DBMS_APPLICATION_INFO.SET_ACTION(NULL);
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
exception
  when others then
    --setear variable para sobregiro del pag_cta
    pag_cta.g_sobregira := 'N';
--    if sqlcode < -20000 then
  --    raise;
    --else
      raise_application_error(-20000,'Deb.Cre.Batch. - Lugar : '||v_lugar||' Cta : '||v_cuenta||' - '||sqlerrm);
--    end if;
END;

--proceso para el listado
PROCEDURE PR_DEB_CRE_BATCH_TMP (
   p_parametros in varchar2)
IS
   v_cuenta         ge_cuentas.nro_cuenta%type;
   v_mto_pago       ge_cuentas.sal_contable%type;
   v_moneda         ba_monedas.cod_moneda%type;
   v_oficina        ba_oficinas.cod_oficina%type;
   v_cantidad       number;
   --- Cursor Dinamico
   TYPE t_tipo_cursor IS REF CURSOR;
   c_cursor    t_tipo_cursor;
   v_sentencia      ge_deb_cre_batch.det_sql%type;
   cursor deb is
      select cod_deb_cre_batch,det_sql
        from   GE_DEB_CRE_BATCH
       where  instr(' '||p_parametros,' '||COD_DEB_CRE_BATCH||'-') > 0; -- = P_COD_DEB_CRE;
BEGIN
   delete from ge_deb_cre_batch_tmp;
   ---
   for db in deb loop
   ---
   v_sentencia := db.det_Sql;
   open c_cursor for v_sentencia;
   loop
      fetch c_cursor into v_cuenta, v_mto_pago, v_moneda, v_cantidad;
      exit when c_cursor%notfound;
      --- Recuperar datos de la cuenta de ahorro
      pag_cta.pr_obt_cuenta(v_cuenta);
      if pag_cta.g_cod_error <> 0 then
        raise_application_error(-20000,'Error al recuperar datos de la cuenta ' || v_cuenta || ' - ' ||sqlerrm);
      else
        v_oficina := pag_cta.g_ctas.cod_oficina;
      end if;
      ---
      insert into ge_deb_cre_batch_tmp (
      cod_deb_cre_batch,nro_cuenta,monto,cod_moneda,cod_oficina, cantidad)
      values (db.cod_deb_cre_batch,v_cuenta,v_mto_pago,v_moneda,v_oficina, v_cantidad);
   end loop;
   close c_cursor;
   end loop;

   COMMIT;
END;

--Funcion que devuelve modulo,modalidad,transaccion del cargo
PROCEDURE FU_OBT_PAR_CARGO
(P_COD_DEB_CRE    IN GE_DEB_CRE_BATCH.COD_DEB_CRE_BATCH%TYPE
,P_COD_MODULO    OUT GE_CUENTAS.COD_MODULO%TYPE
,P_COD_MODALIDAD OUT GE_CUENTAS.COD_MODALIDAD%TYPE
,P_COD_TRANSACCION OUT GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ) IS
BEGIN
  select b.cod_mod_padre, b.cod_mad_padre, b.cod_tra_padre
    into p_cod_modulo, p_cod_modalidad, p_cod_transaccion
    from ge_deb_cre_batch b
   where b.cod_deb_cre_batch = p_cod_deb_cre;
EXCEPTION
  when others then
    raise_application_error(-20000,'Liq.Sobregiros - No se ha encontrado transaccion de comisiones por sobregiro en gestion. Codigo 11.');
END;

PROCEDURE PR_CUO_ANU_TARJETAS(P_COD_DEB_CRE IN GE_DEB_CRE_BATCH.COD_DEB_CRE_BATCH%TYPE)
IS

  v_fecha          ge_calendarios.fec_actual%type;
  v_hora           ge_movimientos.hora%type;
  v_nro_secuencia  ge_movimientos.nro_secuencia%type;
  v_tra_padre      ge_transacciones.cod_transaccion%type;
  v_transaccion    ge_transacciones.cod_transaccion%type;
  v_mod_padre      ge_transacciones.cod_modulo%type;
  v_mad_padre      ge_transacciones.cod_modalidad%type;
  v_concepto       ge_movimientos.concepto%type;
  v_nro_tarjeta    ta_tarjetas.nro_tarjeta%type;
  v_cuenta         ge_cuentas.nro_cuenta%type;
  v_estado         ge_cuentas.estado%type;
  v_tipo           varchar2(1);
  r_gmovi          ge_movimientos%rowtype;
  v_cod_ofi_origen ba_oficinas.cod_oficina%type;
  v_cod_moneda     varchar2(3);
  v_cod_usuario    varchar2(10) := upper(user);
  v_sobregiro      ge_deb_cre_batch.sobregiro%type;
  v_cob_parcial    ge_deb_cre_batch.cob_parcial%type;
  v_pendiente      ge_deb_cre_batch.pendiente%type;
  v_pro_error      ge_deb_cre_batch.pro_error%type;
  v_mto_mov        ge_movimientos.monto%type;
  v_cod_tas_cargo  ge_movimientos.cod_tasa%type;
  v_val_tas_cargo  ge_movimientos.val_tasa%type;
  v_mto_cargo      ge_movimientos.monto%type;
  v_tra_iva        ge_movimientos.cod_transaccion%type;
  v_cod_tas_iva    ge_movimientos.cod_tasa%type;
  v_val_tas_iva    ge_movimientos.val_tasa%type;
  v_mto_iva        ge_movimientos.monto%type;
  v_sal_disponible ge_movimientos.monto%type;
  v_lugar          varchar2(3000);
  v_hubo_error     varchar2(1) := 'N';
  v_cod_error      ge_deb_cre_errores.cod_error%type;
  v_nro_reg        ge_deb_cre_errores.nro_secuencia%type;
  v_cod_mad_cta    ge_movimientos.cod_modalidad%type;
  v_redondeo       number(2);
  v_mto_cargo_par  ge_movimientos.monto%type;
  v_mto_iva_par    ge_movimientos.monto%type;
  v_dif_hora       ge_deb_cre_batch.dif_hora%type;
  v_pre_proceso    ge_deb_cre_batch.pre_proceso%type;
  v_pos_proceso    ge_deb_cre_batch.pos_proceso%type;
  v_iva_incluido   ge_deb_cre_batch.iva_incluido%type;
  v_error          varchar2(4000);
  v_ofi_cta        ge_cuentas.nro_cuenta%type;
  v_cod_mod_cta    ba_modulos.cod_modulo%type;
  v_cod_persona    ta_tarjetas.cod_persona%type;
  v_fec_vencimiento ta_tarjetas.fec_vencimiento%type;
  v_can_cuo_anual   ta_tipos.can_cuo_anual%type;
  v_cuo_cobro      number;
  v_por_exo_cuo_anual ta_tipos.por_exo_cuo_anual%type;
  v_con_reg_mes_actual    number;
  v_fec_aux_cuota  date;
  v_nro_lote       number(6);
  
  -- Cursor Dinamico
  TYPE t_tipo_cursor IS REF CURSOR;
  c_cursor    t_tipo_cursor;
  v_sentencia ge_deb_cre_batch.det_sql%type;

  cursor c_mov is
  select a.*
    from ta_cuo_anual a
   where a.estado = 'G' --G=Generada, pendiente de cobro--
     and ((a.ano*100) + a.mes) <= to_number(to_char(v_fecha,'yyyymm'));
 
  --procesar errores
  procedure lp_error is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    --inserta tabla de errores
    begin
      insert into ge_deb_cre_errores
        (fecha,
         hora,
         cod_usuario,
         nro_secuencia,
         cod_deb_cre_batch,
         nro_cuenta,
         cod_moneda,
         sal_disponible,
         mto_operacion,
         cod_tra_padre,
         cod_error,
         msj_error)
      values
        (v_fecha,
         v_hora,
         v_cod_usuario,
         v_nro_reg,
         p_cod_deb_cre,
         v_cuenta,
         v_cod_moneda,
         v_sal_disponible,
         v_mto_mov,
         v_tra_padre,
         v_cod_error,
         v_lugar);
    exception
      when others then
        raise_application_error(-20001,
                                'Al grabar errores ' ||
                                to_char(v_fecha, 'dd/mm/yyyy') || '-' ||
                                v_hora || '-' || v_cod_usuario || '-' ||
                                v_nro_reg || '-' || p_cod_deb_cre || '-' ||
                                v_cuenta || '. ' || sqlerrm);
    end;
    commit;
    --si no procesa con error finaliza el proceso, sino continua con el sig registro
    if v_pro_error = 'N' then
      raise_application_error(-20000, nvl(v_lugar, sqlerrm));
    end if;
  end;

  --generar movimientos pendientes
  procedure lp_gen_mov_pendiente is
  begin
    -- Si la cuenta esta inactiva
    If v_estado = 'I' then
      insert into ge_mov_pendientes
        (nro_cuenta,
         fecha,
         cod_modulo,
         cod_modalidad,
         cod_transaccion,
         cod_mod_padre,
         cod_mad_padre,
         cod_tra_padre,
         monto,
         hora,
         cod_usuario,
         cod_moneda,
         cod_oficina,
         cod_error,
         estado,
         cod_ofi_origen,
         concepto,
         cod_tasa,
         val_tasa,
         nro_documento,
         saldo,
         motivo)
      values
        (v_cuenta,
         v_fecha,
         v_mod_padre,
         v_mad_padre,
         v_transaccion,
         v_mod_padre,
         v_mad_padre,
         v_transaccion,
         (v_mto_cargo - v_mto_cargo_par) + (v_mto_iva - v_mto_iva_par),
         v_hora,
         user,
         v_cod_moneda,
         pag_cta.g_ctas.cod_oficina,
         pag_cta.g_cod_error,
         'I',
         pag_cta.g_ctas.cod_oficina,
         v_concepto,
         V_COD_TAS_CARGO,
         V_VAL_TAS_CARGO,
         v_cuenta,
         (v_mto_cargo - v_mto_cargo_par) + (v_mto_iva - v_mto_iva_par),
         pag_cta.G_MSJ_ERROR);
    End if;
  exception
    when others then
      v_cod_error  := 200;
      v_lugar      := 'Ins.Mvto.Pendiente ' ||
                      to_char(v_fecha,
                              'dd/mm/yyyy' || '-' || v_hora || '-' ||
                              v_cod_usuario || '-' || v_cuenta || '. ' ||
                              sqlerrm);
      v_hubo_error := 'S';
      lp_error;
  end;

  --Registro las excepciones
  procedure lp_ins_excepcion (p_mensaje varchar2) is
  begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
    --inserta tabla de errores
    begin
      insert into ge_deb_cre_excepciones
        (fecha, hora, cod_usuario, nro_secuencia, cod_deb_cre_batch, nro_cuenta, cod_moneda,
        sal_disponible, mto_operacion, cod_tra_padre, mensaje)
      values
         (v_fecha, v_hora, v_cod_usuario, v_nro_reg, p_cod_deb_cre, v_cuenta, v_cod_moneda,
         v_sal_disponible, v_mto_mov, v_tra_padre, p_mensaje);
    exception
      when others then
        raise_application_error(-20013,'Al grabar excepciones '||to_char(v_fecha,'dd/mm/yyyy')||'-'||v_hora||'-'||v_cod_usuario
                                ||'-'||v_nro_reg||'-'||p_cod_deb_cre||'-'||v_cuenta||'. '||sqlerrm);
    end;
  end;
    --
  procedure pl_obt_cargos(p_cod_ofi_origen   in ge_cuentas.cod_oficina%type,
                          p_nro_cuenta       in ge_cuentas.nro_cuenta%type,
                          p_cod_moneda       in ge_cuentas.cod_moneda%type,
                          p_monto            in ge_movimientos.monto%type,
                          p_cod_modulo       in ge_cuentas.cod_modulo%type,
                          p_cod_modalidad    in ge_cuentas.cod_modalidad%type,
                          p_cod_tra_cargo    in ge_movimientos.cod_transaccion%type,
                          p_iva_incluido     in varchar2 default 'S',
                          p_val_cargo        out ge_movimientos.val_tasa%type,
                          p_cod_tra_impuesto out ge_movimientos.cod_transaccion%type,
                          p_cod_tas_impuesto out ge_movimientos.cod_tasa%type,
                          p_val_tas_impuesto out ge_movimientos.val_tasa%type,
                          p_val_impuesto     out ge_movimientos.val_tasa%type) is
    v_val_base          number(18, 2) := p_monto;
    v_fec_vigencia      date;
    v_tip_valor         varchar2(1);
    v_tipo              varchar2(1);
    v_redondeo          number(1);
    v_tas_personalizada varchar2(1);
  begin
    p_val_cargo := v_val_base;
    -- veo si la cuenta tiene transaccion prohibida
    if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                    p_cod_tra_cargo,
                                    p_cod_modulo,
                                    p_cod_modalidad) = 'N' then
      -- no tiene transaccion prohibida, se calcula
      begin
        select tas_personalizada
          into v_tas_personalizada
          from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          raise_application_error(-20000,
                                  'Cuenta ' || p_nro_cuenta ||
                                  ' no registrada');
      end;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        P_COD_MODULO,
                                        P_COD_MODALIDAD,
                                        P_cod_moneda);

      -- busco el impuesto asociado a este cargo
      begin
        select cod_tra_hijo
          into p_cod_tra_impuesto
          from ge_transacciones_det
         where cod_modulo = p_cod_modulo
           and cod_modalidad = p_cod_modalidad
           and cod_transaccion = p_cod_tra_cargo
           and cod_mod_hijo = p_cod_modulo
           and cod_mad_hijo = p_cod_modalidad
           and cod_tra_hijo <> p_cod_tra_cargo -- Que la transaccion hijo sea diferente de la padre
           and rownum = 1
           and exists (select 0
                  from ge_transacciones x
                 where x.cod_modulo = cod_mod_hijo
                   and x.cod_modalidad = cod_mad_hijo
                   and x.cod_transaccion = cod_tra_hijo
                   and x.cod_tasa is not null);

      exception
         when no_data_found then
            p_cod_tra_impuesto := p_cod_tra_cargo ;
         when others then
            raise_application_error(-20000, 'Al leer Impuesto ' || sqlerrm);
      end;

      -- veo si la cuenta tiene exoneracion de impuestos
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then
          -- Se encontro impuesto asociado, se calcula
          pag_gen.pr_obt_val_tasa(p_cod_modulo,
                                  p_cod_modalidad,
                                  p_cod_ofi_origen,
                                  p_nro_cuenta,
                                  p_cod_moneda,
                                  p_val_cargo,
                                  nvl(v_tas_personalizada, 'N'),
                                  p_cod_tas_impuesto,
                                  p_cod_tra_impuesto,
                                  trunc(sysdate),
                                  p_val_tas_impuesto,
                                  v_fec_vigencia,
                                  v_tip_valor,
                                  v_tipo); ---OUT
          if v_tip_valor = 'V' then
            -- si es un valor, se toma directamente
            p_val_impuesto := nvl(p_val_tas_impuesto, 0);
          else
            -- es un porcentaje, se considera incluido en el cargo
            if nvl(p_iva_incluido, 'S') = 'S' then
              p_val_impuesto := round(nvl(p_val_cargo, 0) *
                                      nvl(p_val_tas_impuesto, 0) /
                                      (100 + p_val_tas_impuesto),
                                      v_redondeo);
            else
              p_val_impuesto := round(nvl(p_val_cargo, 0) *
                                      nvl(p_val_tas_impuesto, 0) / 100,
                                      v_redondeo);
            end if;
            --verificar si el monto a cobrar esta limitado x el minimo y maximo de la tasa
            p_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_val_impuesto);
          end if;
          -- resto el monto del impuesto al cargo, porque va incluido
          if nvl(p_iva_incluido, 'S') = 'S' then
            p_val_cargo := nvl(p_val_cargo, 0) - nvl(p_val_impuesto, 0);
          end if;
          if p_val_cargo < 0 then
            raise_application_error(-20000,
                                    'Impuesto mas alto que el Cargo');
          end if;
        else
          p_val_impuesto := 0;
        end if;
    end if;
  end;

  --Proceso Principal
BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=5; END;
  v_hubo_error    := 'N';
  v_nro_reg       := 0;
  v_fecha         := pag_cal.fu_obt_fec_actual(5);
  --v_hora          := fug_ini_hora(sysdate, 'HH24:MI:SS');
  v_hora := to_char(sysdate,'HH24:MI:SS');
  v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
  v_nro_secuencia := -999;
  v_lugar         := null;

  --- Verifica para ejecutar solo el primer día habil del mes.
  --IF pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(5) = v_fecha THEN
  -- SC 9719 PN: se agrega un control para que solo se ejecute una vez duerante el mes.
  
  begin
    select nvl(count(*),0)
      into v_con_reg_mes_actual
      from ta_cuo_anual t
     where to_char(t.fec_generacion, 'MM/YYYY') = to_char(v_fecha, 'MM/YYYY');
  exception
    when others then 
      v_con_reg_mes_actual := 0;
  end;      
    
  IF nvl(v_con_reg_mes_actual,0) = 0 THEN
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    --busco oficina origen
    begin
      select cod_oficina
        into v_cod_ofi_origen
        from ba_usuarios
       where cod_usuario = user;
    exception
      when others then
        raise_application_error(20009,
                                'Al recup. oficina del usuario ' || sqlerrm);
    end;
    --Recuperamos los registros a procesar mediante el sql parametrizado
    begin
      select tip_movimiento,
             det_sql,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             descripcion,
             cod_transaccion,
             sobregiro,
             cob_parcial,
             pendiente,
             pro_error,
             dif_hora,
             pre_proceso,
             pos_proceso,
             iva_incluido
        into v_tipo,
             v_sentencia,
             v_tra_padre,
             v_mod_padre,
             v_mad_padre,
             v_concepto,
             v_transaccion,
             v_sobregiro,
             v_cob_parcial,
             v_pendiente,
             v_pro_error,
             v_dif_hora,
             v_pre_proceso,
             v_pos_proceso,
             v_iva_incluido
        from ge_deb_cre_batch
       where cod_deb_cre_batch = p_cod_deb_cre;
      --agregar order by al query si no tiene, siempre x moneda (posicion 3)
      if instr(upper(v_sentencia), 'ORDER') = 0 THEN
        v_sentencia := v_sentencia || ' ORDER BY 3';
      end if;
    exception
      when no_data_found then
        v_cod_error  := 100; --menores al 100 son del pag_cta.
        v_lugar      := 'No existen datos para el Crédito / Débito ' ||
                        p_cod_deb_cre;
        v_hubo_error := 'S';
        raise_application_error(-20000, v_lugar);
      when others then
        v_cod_error  := 100;
        v_lugar      := 'Recup.Deb.Cred. ' || p_cod_deb_cre || ' - ' ||
                        sqlerrm;
        v_hubo_error := 'S';
        raise_application_error(-20000, v_lugar);
    end;

    if v_hubo_error = 'N' then
      -- ejecuto proceso previo si existe
      if v_pre_proceso is not null then
        sql_util.ejecute_dml('BEGIN ' || v_pre_proceso || '; END;', v_error);
        v_error := replace(v_error, 'SQL_UTIL.EJECUTE_DML', '*');
        if v_error is not null then
          v_cod_error  := 104;
          v_hubo_error := 'S';
          v_lugar      := 'Proceso previo ' || v_error;
          raise_application_error(-20000, v_lugar);
        end if;
      end if;

      open c_cursor for v_sentencia;
      loop
        fetch c_cursor
          into v_cuenta,
               v_nro_tarjeta,
               v_cod_persona,
               v_fec_vencimiento,
               v_cod_moneda,
               v_mto_cargo,
               v_can_cuo_anual,
               v_cuo_cobro,
               v_por_exo_cuo_anual;

        exit when c_cursor%notfound;
        v_nro_reg   := v_nro_reg + 1;




        if v_dif_hora = 'S' then
          --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
          v_hora := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
        end if;

        --limpiar variables
        v_cod_tas_cargo  := 0;
        v_val_tas_cargo  := 0;
        v_mto_iva        := 0;
        v_mto_mov        := 0;
        v_mto_cargo_par  := 0;
        v_mto_iva_par    := 0;
        v_cod_tas_iva    := null;
        v_val_tas_iva    := null;
        v_cod_mad_cta    := null;

        --verificar monto
        if nvl(v_mto_cargo, 0) <= 0 then
          v_cod_error  := 102;
          v_lugar      := 'Monto de la Cuota Anual para la Cuenta: '||v_cuenta||' no puede ser '||nvl(v_mto_cargo, 0);
          v_hubo_error := 'S';
          lp_error;
          raise_application_error(-20000, v_lugar); --debe caer el proceso ya que esta mal definido
        end if;
        -- verificar % de exoneración de cuota anual
        if v_por_exo_cuo_anual is null then
          v_por_exo_cuo_anual := 0;
        end if;
        --Recuperar datos de la cuenta
        pag_cta.pr_obt_cuenta(v_cuenta);
        if pag_cta.g_cod_error <> 0 then
          v_cod_error  := 104;
          v_lugar      := 'Recup. datos de la cuenta ' || v_cuenta || ' - ' ||
                          pag_cta.g_msj_error;
          v_hubo_error := 'S';
          lp_error;
          goto sig;
        end if;
        v_cod_mad_cta := pag_cta.g_ctas.cod_modalidad;
        v_estado      := pag_cta.G_CTAS.estado;
        v_ofi_cta     := pag_cta.G_CTAS.cod_oficina;
        v_cod_mod_cta := pag_cta.G_CTAS.cod_modulo;
        --Excepcion por Transaccion prohibida
        if pag_cta.fu_ver_tra_prohibida(v_cuenta,
                                        v_transaccion,
                                        pag_cta.G_CTAS.cod_modulo,
                                        pag_cta.g_ctas.cod_modalidad) = 'S' then
           lp_ins_excepcion ('Cuenta posee transaccion prohibida para: '||v_transaccion);
           goto sig;
        end if;
        --ahorro, cta cte y tarjetas
        if v_cod_mod_cta <> 5 then
          v_cod_error  := 106;
          v_lugar      := 'Módulo de la Cuenta debe corresponder a Tarjetas ' ||
                          v_cuenta || ' - ' || v_cod_mad_cta;
          v_hubo_error := 'S';
          lp_error;
          goto sig;
        end if;
        --redondeo
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          v_mod_padre,
                                          v_mad_padre,
                                          v_cod_moneda);


         --es cargo, calcular el monto e impuesto, en base al monto imponible
        begin
          v_lugar := 'cta : ' || v_cuenta || ' pr_obt_Cargos';
          PL_OBT_CARGOS(pag_cta.g_ctas.cod_oficina,
                        v_cuenta,
                        v_cod_moneda,
                        v_mto_cargo,
                        pag_cta.G_CTAS.cod_modulo,
                        pag_cta.g_ctas.cod_modalidad,
                        v_transaccion,
                        'N',
                        v_mto_cargo,
                        v_tra_iva,
                        v_cod_tas_iva,
                        v_val_tas_iva,
                        v_mto_iva);
        exception
          when others then
            v_cod_error  := 107;
            v_lugar      := sqlerrm;
            v_hubo_error := 'S';
            lp_error;
            goto sig;
        end;
        --monto operacion es el cargo + el impuesto si está configurado

          v_mto_mov := nvl(v_mto_cargo, 0) + nvl(v_mto_iva, 0);
        -- Calcula el monto correspondiente a la cuota actual.
          v_mto_mov := round((v_mto_mov / v_can_cuo_anual),v_redondeo);
        -- Calcula el monto a cobrar según % definido
          v_mto_mov := v_mto_mov - round((v_mto_mov * v_por_exo_cuo_anual / 100),v_redondeo);

        --Punto de reversion
        prg_cre_savepoint('punto_reversion');
        begin
          --modificaciones rpavon--
          --Calcular la fecha auxiliar--
          select to_date('01'||to_char(v_fecha,'/mm/yyyy'),'dd/mm/yyyy')
            into v_fec_aux_cuota
            from dual;
          --Ciclo para grabar las cuotas--
          for v_con_cuota IN 1..v_can_cuo_anual loop
              insert into ta_cuo_anual(nro_cuenta,concepto,nro_tarjeta,cod_persona,fec_vencimiento,cod_moneda,
                                       mto_cuo_anual,can_cuo_anual,cuo_cobro,por_exo_cuo_anual,
                                       ano, mes, estado, nro_cuota, periodo, fec_generacion)
              values (v_cuenta,                      
                      substr(v_concepto,1,35),
                      v_nro_tarjeta, v_cod_persona, v_fec_vencimiento, v_cod_moneda,
                      v_mto_mov, v_can_cuo_anual, 0, v_por_exo_cuo_anual,
                      to_number(to_char(v_fec_aux_cuota,'yyyy')),
                      to_number(to_char(v_fec_aux_cuota,'mm')),
                      'G', v_con_cuota, to_number(to_char(v_fecha,'yyyy')), v_fecha);
              select add_months(v_fec_aux_cuota,1)
                into v_fec_aux_cuota
                from dual;
          end loop;
        end;
        <<sig>>
        null;
        end loop;
        --commit; -- Se fializa el ingreso de información a la tabla auxiliar de cobro.
      
      --Procesa las TC canceladas para no generar registros de Ctas ya canceladas--
      update ta_cuo_anual a
        set a.estado = 'C'
        where a.estado = 'G'
          and exists (select 1 from ta_cta_tarjetas x
                       where x.estado = 'C'
                         and x.nro_cuenta = a.nro_cuenta);
      
      --Generar los movimientos de las cuentas vigentes--
        for k in c_mov loop

        --v_cuo_cobro := k.cuo_cobro + 1;
        v_cuo_cobro := k.nro_cuota;
        --Recuperar datos de la cuenta
        pag_cta.pr_obt_cuenta(k.nro_cuenta);
        if pag_cta.g_cod_error <> 0 then
          v_cod_error  := 105;
          v_lugar      := 'Recup. datos de la cuenta ' || k.nro_cuenta || ' - ' ||
                          pag_cta.g_msj_error;
          v_hubo_error := 'S';
          lp_error;
          goto siguiente;
        end if;
        v_cod_mad_cta := pag_cta.g_ctas.cod_modalidad;
        v_estado      := pag_cta.G_CTAS.estado;
        v_ofi_cta     := pag_cta.G_CTAS.cod_oficina;
        v_cod_mod_cta := pag_cta.G_CTAS.cod_modulo;

        --Genera movimiento por el cargo
        if v_tipo = 'G' and k.mto_cuo_anual > 0 then
          --select s_nro_cob_cargo.nextval into v_nro_documento from dual;
          --v_nro_documento2 := null; --v_nro_tarjeta;
          v_nro_secuencia  := v_nro_secuencia + 1;
          if v_nro_Secuencia > 990 then
            v_nro_secuencia := -999;
          end if;
          v_lugar := '1- Mov. por el Cargo';

          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fecha;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_modulo      := v_mod_padre;
          r_gmovi.cod_modalidad   := v_cod_mad_cta;
          r_gmovi.cod_oficina     := v_ofi_cta;
          r_gmovi.cod_moneda      := k.cod_moneda;
          r_gmovi.fec_valor       := v_fecha;
          r_gmovi.cod_tra_padre   := v_tra_padre;
          r_gmovi.cod_mod_padre   := v_mod_padre;
          r_gmovi.cod_mad_padre   := v_cod_mad_cta;
          r_gmovi.nro_cuenta      := k.nro_cuenta;
          r_gmovi.cod_transaccion := v_transaccion;
          r_gmovi.monto           := k.mto_cuo_anual;
          r_gmovi.referencia      := k.nro_tarjeta;
          r_gmovi.nro_documento2  := k.cod_persona;
          r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := k.concepto||' '||v_cuo_cobro||'/'||k.can_cuo_anual;--'CUOTA ANUAL X/N';
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);

        end if;

        --Se actualiza por la clave primaria--
        update ta_cuo_anual a
           set a.cuo_cobro = v_cuo_cobro,
               a.estado = 'P',
               a.fec_mov = v_fecha,
               a.hor_mov = v_hora,
               a.cod_usu_mov = v_cod_usuario
         where a.nro_cuenta = k.nro_cuenta
           and a.ano = k.ano
           and a.mes = k.mes
           and a.periodo = k.periodo;
        --
        <<siguiente>>
        null;
      end loop;
      --Ejecuta Proceso Posterior--
        if v_pos_proceso is not null and v_hubo_error = 'N' then
          sql_util.ejecute_dml('BEGIN ' || v_pos_proceso || '; END;',
                               v_error);
          v_error := replace(v_error, 'SQL_UTIL.EJECUTE_DML', '*');
          if v_error is not null then
            v_cod_error  := 108;
            v_hubo_error := 'S';
            v_lugar      := 'Proceso Posterior ' || v_error;
            raise_application_error(-20000, v_lugar);
          end if;
        end if;
    end if;
  ELSE
    raise_application_error(-20000, 'El proceso fue corrido en el mes actual y solo puede ser ejecutado una vez al mes.');    
  END IF;
exception
  when others then
    prg_rol_savepoint('punto_reversion');	
    raise_application_error(-20000,
                            'Deb.Cre.Batch.Tar. - Lugar : ' || v_lugar ||
                            ' Cta : ' || v_cuenta || ' - ' || sqlerrm);
END;
end pag_car;
/
