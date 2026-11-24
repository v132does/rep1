create or replace package body it.pap_ser is
  g_cod_persona ba_personas.cod_persona%type;
  MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';
    g_mod_estado    ba_modulos.estado%TYPE;
  /*Verificar horario de movimientos cnb*/
   procedure lp_ver_hor_cnb(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
                           p_modulo         in ba_modulos.cod_modulo%type,
                           p_horario        out varchar2,
                           p_es_mov_noc     out varchar2,
                           p_es_cta_noc     out varchar2,
                           p_fec_actual     out date,
                           p_fec_valor      out date,
                           p_cod_error      out number,
                           p_men_error      out varchar2) is

    v_est_modulo ba_modulos.estado%type;
  begin
    p_cod_error  := 0;
    p_horario    := 'D'; -- dia normal
    p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
    v_est_modulo := pae_cnf.fu_obt_est_modulo(p_modulo);

    if v_est_modulo in (1,6) then
        p_cod_error := '1070';
        p_men_error := 'Modulo en proceso de cierre';
    elsif v_est_modulo = 2 then
        p_horario    := 'D'; -- dia normal
        p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'N';
        p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
    else --(3,4)
          p_horario := 'N'; -- noche
          if v_est_modulo <> 1 then
            p_fec_actual := pag_cal.fu_obt_fec_habil(p_fec_actual + 1,
                                                     1,
                                                     p_cod_ofi_origen);
          end if;
          p_es_mov_noc := 'S'; -- para grabar en las tablas nocturnas
          p_es_cta_noc := 'S'; -- solo para que llavee la cuenta nocturna
    end if;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
    g_mod_estado      := v_est_modulo;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 99;
      p_men_error := 'Ocurrio un error en la verificacion de horario';
      PRG_INS_LOG_PROGRAMAS('PAP_SER.LP_VER_HORARIO',
                            substr(DBMS_UTILITY.format_error_backtrace || ' ' ||
                                   DBMS_UTILITY.format_error_stack,
                                   1,
                                   4000),
                            null,
                            null);

  END lp_ver_hor_cnb;
--https://itti-digital.atlassian.net/browse/NVB-3811
  --controla el limite en monto y cantidad de operaciones por cliente segun parametros definidos
  function fu_control_limite(p_cod_persona varchar2,
                             p_mon_bcp     number,
                             p_monto       number) return varchar2 is

    v_lim_ope_sal     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_LIM_OPE_SAL');
    v_lim_meses       ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_LIM_MESES');
    v_lim_sum_sal     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_LIM_SUM_SAL');
    v_lim_ope_cliente ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_LIM_OPE_CLIENTE');
    v_fec_actual      ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
    v_can_operaciones number(3);
    v_sal_minimo      pr_parametros.sal_min_vigente%type;
    v_mto_mon_local   ge_movimientos.monto%type;
    v_mto_mon_fuerte  ge_movimientos.monto%type;
    v_mto_operacion   ge_movimientos.monto%type;
    v_cod_moneda      ba_monedas.cod_moneda%type;
    v_cod_mon_local   ge_par_generales.cod_mon_local%type := pag_gen.fu_obt_mon_local;
    v_cod_mon_fuerte  ge_par_generales.cod_mon_fuerte%type := pag_gen.fu_obt_mon_fuerte;
    v_respuesta       varchar2(80) := null;
    v_msj_error       varchar2(80) := null;
    v_mto_cot_fecha   ge_cotizaciones.val_venta%type := fug_obt_cotizacion(v_cod_mon_fuerte,
                                                                           v_fec_actual);
    v_det_error       ge_log_errores.det_error%type;

  begin

    --recupero moneda itgf
    v_cod_moneda := it.fue_obt_mon_bcp(p_mon_bcp);
    if v_cod_moneda not in (v_cod_mon_local, v_cod_mon_fuerte) then
      v_msj_error := 'Moneda no registrada en el Sistema';
    end if;
    if v_msj_error is null then
      --monto del salario minimo vigente
      begin
        select sal_min_vigente into v_sal_minimo from pr_parametros;
      exception
        when no_data_found then
          v_msj_error := 'Salario minimo no registrao en el sistema';
        when others then
          v_msj_error := 'Error la buscar salario minimo';
      end;
      if v_cod_moneda is not null and v_cod_moneda != v_cod_mon_local then
        v_mto_operacion := p_monto * v_mto_cot_fecha; --monto de la operacion a la cotizacion de la fecha
      else
        v_mto_operacion := p_monto;
      end if;
    end if;
    --primer control. operacion unica.
    if v_mto_operacion > v_sal_minimo * v_lim_ope_sal then
      -- operacion supera los salarios minimos establecidos
      v_msj_error := 'Operacion Supera los ' || v_lim_ope_sal ||
                     ' salarios minimos';
    end if;

    --si no hubo errores hasta aca entonces continua el control
    if v_msj_error is null then
      --cantidad y monto en operaciones en los ultimos meses
      select count(1)
        into v_can_operaciones
        from ge_mov_res_clientes h
       where h.fecha between add_months(v_fec_actual, v_lim_meses * -1) and
             v_fec_actual
         and h.cod_persona = p_cod_persona;

      if v_can_operaciones + 1 > v_lim_ope_cliente then
        --cantidad de operaciones en lapso de tiempo establecido supera parametrizacion
        v_msj_error := 'El Cliente supera cantidad de operaciones';
      end if;

    end if;
    if v_msj_error is null then
      --control en monto en lapso de tiempo
      v_mto_mon_local := 0;
      --monto de operaciones en los ultimos meses en moneda local
      begin
        select sum(h.monto) monto
          into v_mto_mon_local
          from ge_mov_res_clientes h
         where h.fecha between add_months(v_fec_actual, v_lim_meses) and
               v_fec_actual
           and h.cod_moneda = v_cod_mon_local
           and h.cod_persona = p_cod_persona
         group by h.cod_moneda, h.cod_persona;
      exception
        when no_data_found then
          v_mto_mon_local := 0;
      end;

      --monto de operaciones en los ultimos meses en moneda local
      begin
        select sum(h.mto_equ_local) monto
          into v_mto_mon_fuerte
          from ge_mov_res_clientes h
         where h.fecha between add_months(v_fec_actual, v_lim_meses) and
               v_fec_actual
           and h.cod_moneda = v_cod_mon_fuerte
           and h.cod_persona = p_cod_persona
         group by h.cod_moneda, h.cod_persona;
      exception
        when no_data_found then
          v_mto_mon_fuerte := 0;
      end;
      if nvl(v_mto_mon_local, 0) + nvl(v_mto_mon_fuerte, 0) >
         v_sal_minimo * v_lim_sum_sal then
        v_msj_error := 'El cliente supera el limite de operaciones en monto';
      elsif nvl(v_mto_mon_local, 0) + nvl(v_mto_mon_fuerte, 0) +
            v_mto_operacion > v_sal_minimo * v_lim_sum_sal then
        v_msj_error := 'Con esta operacion el cliente supera el limite';
      end if;
    end if;

    --si no hubo mensaje de error es porque el Cliente esta Ok para operar
    if v_msj_error is null then
      v_respuesta := 'OK';
    else
      v_respuesta := v_msj_error;
      v_det_error := 'Monto: ' || p_monto || 'Moneda: ' || p_mon_bcp ||
                     ' Error: ' || v_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.FU_CONTROL_LIMITE',
                            v_det_error,
                            p_cod_persona,
                            null);
    end if;
    return v_respuesta;
  exception
    when others then
      v_respuesta := sqlerrm;
      v_det_error := 'Monto: ' || p_monto || ' Moneda: ' || p_mon_bcp ||
                     ' Error: ' || v_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.FU_CONTROL_LIMITE',
                            v_det_error,
                            p_cod_persona,
                            null);
      return v_respuesta;
  end fu_control_limite;

 /*DA-1986 - Procesar Pago de Cuota Prestamo*/
 /*cobro cuota prestamo cnb*/
 procedure pr_gen_cob_cuotas(p_cod_ente   in number,
                             p_mov_id     in varchar2,
                             p_nro_cuenta in varchar2,
                             p_cod_moneda in ba_monedas.cod_mon_bco_central%type,
                             p_monto      in number,
                             p_cod_error  out number,
                             p_msj_error  out varchar2) is
   --VARIABLE
   v_par_ente        ge_par_entes.val_parametro%type;
   v_cod_ente_vision ge_entes.cod_ente%type;
   v_cuenta          ge_movimientos.nro_cuenta%type := p_nro_cuenta;
   v_cuenta_cnb      ge_movimientos.nro_cuenta%type;
   v_moneda          ba_monedas.cod_moneda%type := fue_obt_mon_bcp(p_cod_moneda);
   v_saldo           ge_movimientos.monto%type := p_monto;
   v_fecha_actual    DATE := it.pag_cal.fu_obt_fec_actual(1);
   v_hora            ge_movimientos.hora%TYPE;/* := to_char(sysdate,
                                                         'HH24:MI:SS');*/
   v_cotizacion      ge_cotizaciones.val_conversion%type := null;
   v_nro_documento   ge_movimientos.nro_documento%type := p_mov_id;
   v_existe          varchar2(1) default 'S';
   v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
   v_referencia      ge_movimientos.referencia%type := p_mov_id;
   v_cod_persona     ba_personas.cod_persona%type := fug_obt_cli_principal(v_cuenta);
   v_tip_ente        number(1) := 0;
   v_cod_mod_padre   number := 6;
   v_cod_mad_padre   number := 65;
   v_cod_tra_padre   number := 360;
   v_cod_transaccion number := 8521;
   v_factura         cb_lib_ventas.nro_factura%type;
   v_det_error       ge_log_errores.det_error%type;
   v_es_mov_noc      varchar2(2);
   r_pcpre           pr_cta_prestamos%ROWTYPE;
   v_ofi_cta_cnb      ba_oficinas.cod_oficina%type;
 begin
     p_cod_error:= 0;
                      
   if pae_cnf.fu_obt_est_modulo(6) != 2 then
     -- periodo de cierre, no debe poder procesar operacion
     p_cod_error := 99;
     p_msj_error := 'Modulo Cerrado. No se puede operar';
   else
     -- obtenemos la cuenta rubro
     if v_moneda = it.pag_gen.fu_obt_mon_local then
       --v_cuenta_cnb := it.fug_obt_parentes(p_cod_ente, 'CTA_OP_CNB_GS');
       v_par_ente  := 'CTA_OP_CNB_GS';
     elsif v_moneda = it.pag_gen.fu_obt_mon_fuerte then
       --v_cuenta_cnb := it.fug_obt_parentes(p_cod_ente, 'CTA_OP_CNB_USD');
       v_par_ente  := 'CTA_OP_CNB_USD';
     elsif p_cod_ente is null then
       p_cod_error := 1;
       p_msj_error := 'Codigo de Ente no puede ser nulo.';
     end if;
      -- Si el ente recibido como parametro corresponde a WEPA (RED DIFGITAL S.A)
      If p_cod_ente = nvl( fug_obt_pardinamico('COD_ENT_WEPA'), 9733 ) then
        --Obtenemos el ente de wepa donde la cta operativa configurada es la cta de vision
        v_cod_ente_vision := fug_obt_pardinamico('COD_ENT_WEPA_VISION');
        -- Obtenemos la cuenta
        v_cuenta_cnb      := fug_obt_parentes(v_cod_ente_vision, v_par_ente);
      Else
        v_cuenta_cnb      := fug_obt_parentes(p_cod_ente, v_par_ente);
      End if;
     --se llama al procedimiento para realizar
     if v_existe = 'S' then
       begin
         savepoint cobro_cuota;
         v_hora := fug_obt_mov_hora;/*fug_obt_hor_disponible(pag_cal.fu_obt_fec_actual(1),
                                          v_hora,
                                          USER,
                                          'N');*/

         pap_pre.PR_OBT_DAT_PRESTAMO(v_cuenta,r_pcpre);
         IF nvl(r_pcpre.en_juicio, 'N') = 'S' then
           p_cod_error := 6;
           p_msj_error := 'Cuenta en juicio';
           return;
         END IF;
         pap_pre.pr_cob_prestamo(v_cuenta,
                                 v_saldo,
                                 'N', --- Se pidio autorizacion
                                 r_pcpre.cod_oficina, --- oficina origen
                                 NULL,
                                 NULL,
                                 'Cobro de cuota de prestamo ' || v_cuenta,
                                 v_fecha_actual,
                                 v_hora,
                                 v_nro_secuencia,
                                 360,
                                 v_cod_mod_padre,
                                 v_cod_mad_padre);

         --actualizacion de referencia en el cobro
         update ge_movimientos t
            set t.referencia     = v_referencia,
                t.cod_persona    = v_cod_persona,
                t.nro_documento  = v_nro_documento,
                t.nro_documento2 = p_cod_ente
          where t.fecha = v_fecha_actual
            and t.hora = v_hora
            and t.cod_usuario = user
            and t.referencia is null;
       exception
         when others then
           p_cod_error := 4;
           p_msj_error := 'Ocurrio un error el proceso de cobro';
           rollback to cobro_cuota;
       end;
     end if;
     
     if p_cod_error= 0 then
         --debito saldo de cuenta operativa CNB
         begin
           v_nro_secuencia := v_nro_secuencia + 1;
           pag_cta.pr_obt_cuenta(v_cuenta_cnb);
           v_ofi_cta_cnb := pag_cta.g_ctas.cod_oficina;
           PAG_CTA.PR_SET_REFERENCIA(v_referencia); -- funciona
           pag_cta.pr_set_nro_documento2(p_cod_ente);
           pag_cta.PR_NRO_CAJA(p_nro_caja => null);
           pag_cta.pr_act_operacion(v_cuenta_cnb,
                                    v_hora,
                                    'D',
                                    v_moneda,
                                    v_saldo,
                                    v_cod_tra_padre,
                                    v_cod_transaccion,
                                    v_nro_documento,
                                    v_cotizacion,
                                    61,
                                    v_cod_mod_padre,
                                    v_cod_mad_padre,
                                    null,
                                    null,
                                    'Debito cobro cuota CNB ' || v_cuenta_cnb,
                                    'N',
                                    v_nro_secuencia,
                                    v_fecha_actual,
                                    null,
                                    null,
                                    null);
           if pag_cta.G_COD_ERROR != 0 then
             p_cod_error := 5;
             p_msj_error := pag_cta.G_MSJ_ERROR;
             rollback to cobro_cuota;
           else
             p_cod_error := 0;
             p_msj_error := 'Se han generado los movimientos';
             --end if;
           end if;
         exception
           when others then
             p_cod_error := 2;
             p_msj_error := 'Ocurrio un error el proceso de cobro';
         end;
   end if;
   end if;
   if nvl(p_cod_error, 0) != 0 then
     v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                    ' Monto: ' || p_monto || ' ' || p_cod_moneda ||
                    ' Error: Cod. ' || p_cod_error || '-' || p_msj_error;
     PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_COB_CUOTAS',
                           v_det_error,
                           null,
                           p_nro_cuenta);
   end if;
 exception
   when others then
     p_cod_error := 3;
     p_msj_error := SQLERRM;
     v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                    ' Monto: ' || p_monto || ' ' || p_cod_moneda ||
                    ' Error: Cod. ' || p_cod_error || '-' || p_msj_error;
     PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_COB_CUOTAS',
                           v_det_error,
                           null,
                           p_nro_cuenta);
 end pr_gen_cob_cuotas;

procedure lp_ver_horario IS
      v_est_modulo ba_modulos.estado%TYPE;
      v_cod_entidad ge_par_generales.cod_entidad%TYPE;

      v_horario        VARCHAR2(1) := 'D'; -- Dia normal
      v_es_mov_noc     VARCHAR2(1) := 'N'; -- Graba S/N mov nocturnos
      v_es_cta_noc     VARCHAR2(1) := 'N'; -- Graba S/N ctas noctunas
      v_fec_actual     DATE := pag_cal.fu_obt_fec_actual(3); -- fecha de hoy
      v_fec_valor      DATE := v_fec_actual;
      v_msj_respuesta  VARCHAR2(250);
      v_mod_estado     ba_modulos.estado%TYPE;

   BEGIN
      v_horario    := 'D'; -- Dia normal
      v_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc := 'N';
      v_fec_actual := pag_cal.fu_obt_fec_actual(6);

      v_cod_entidad := pag_gen.fu_obt_cod_entidad();

      if v_cod_entidad = 9999 then --si se trata de casas de credito
         v_est_modulo := pae_cnf.fu_obt_est_modulo(6);
      else
         --se busca el estado del modulo 3 debido a ser el primer modulo cuyo estado es modificado
         --en el proceso de cierre
         v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
      end if;

      IF v_est_modulo = 6 THEN
         -- En cierre.
         v_horario    := 'N'; -- Noche
         v_fec_actual := pag_cal.fu_obt_fec_proxima(6);

         v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         v_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna

         pag_ser.v_cod_respuesta := -1;
         v_msj_respuesta         := 'Sistema en cierre';
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto
         -- Verifica la hora --
         NULL;
      ELSE
         v_horario    := 'N'; -- Noche
         IF v_est_modulo = 1 THEN--En proceso de inicio
          v_fec_actual := pag_cal.fu_obt_fec_actual(6);
         ELSE
         v_fec_actual := pag_cal.fu_obt_fec_proxima(6);
         END IF;
         v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         v_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
      v_fec_valor       := trunc(SYSDATE);
      pag_cta.g_horario := v_horario;
      v_mod_estado := v_est_modulo;
   END lp_ver_horario;
--TRFS-1331
FUNCTION lp_ver_hor_transferencia(p_horario        OUT VARCHAR2
                          ,p_es_mov_noc     OUT VARCHAR2
                          ,p_es_cta_noc     OUT VARCHAR2
                          ,p_ult_cierre     IN  DATE
                          ,p_cod_ofi_origen IN  VARCHAR2
                          ,p_fec_actual     OUT DATE
                          ,p_fec_cie_caja   IN  DATE
                          ,p_fec_valor      OUT DATE) RETURN typ_MensajeRespuesta IS

      c_msg_sis_cierre constant varchar2(15) := '106';
      v_est_modulo     ba_modulos.estado%TYPE;
      v_retorno        typ_MensajeRespuesta := typ_MensajeRespuesta;
   BEGIN
     
      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      if nvl(v_tra_spi,'N') !='S' then
          p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(9);
          v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(9);
      elsif nvl(v_tra_spi,'N') ='S' then
          p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
          v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
      end if;
     IF v_est_modulo = 2 THEN
         -- El modulo esta abierto
         -- Verifica la hora --
         IF nvl(v_tra_spi,'N') !='S' then
           IF SYSDATE > p_ult_cierre AND trunc(p_ult_cierre) = p_fec_actual THEN
              p_horario    := 'T'; -- Tarde
              p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
              p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
           END IF;
         END IF;
      ELSE
         if nvl(fug_obt_pardinamico('BWE_BLO_HOR_CIERRE'),'N') = 'S' then
          p_horario:='N';
          p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
          p_es_cta_noc := 'S';
          p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
       end if;

      END IF;
      pag_cta.g_horario := p_horario;
      p_fec_valor:=trunc(sysdate);
      v_mod_estado := v_est_modulo;
      RETURN v_retorno;
   END;  
 FUNCTION fu_obt_deu_prest_cta
   (  p_nro_cuenta      IN pr_cuotas.nro_cuenta%TYPE,
      p_moneda          IN ba_monedas.cod_mon_bco_central%TYPE
   ) RETURN varchar2 IS
      --Datos de la cabecera.
      v_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE := 360;
      v_nom_titular   BA_PERSONAS.NOM_COMPLETO%TYPE;
      v_can_cuotas    NUMBER(3);
      v_cadena        VARCHAR2(32767);
      -- variables
      v_mto_cobrado        NUMBER(18, 2); -- Mto cobrado (no se despliega)
      v_tot_capital        NUMBER(18, 2); -- Capital (no se despliega )
      v_tot_interes        NUMBER(18, 2); -- Interes (no se despliega )
      v_tot_int_adelantado NUMBER(18, 2); -- Interes adelantado (no despliega)
      v_tot_mora           NUMBER(18, 2); -- Mora s/capital (no despliega)
      v_tot_mora_interes   NUMBER(18, 2); -- Mora s/Interes (DESPLIEGA : Mora s/interes )
      v_tot_mora_int_adel  NUMBER(18, 2); -- Mora interes adelantado (no desp)
      v_tot_impuesto       NUMBER(18, 2); -- Total impuesto (DESPLIEGA : ley 125/91)
      v_tot_cargo          NUMBER(18, 2); -- Total cargo (DESPLIEGA : Cargo + IVA )
      v_tot_cargo_iva      NUMBER(18, 2); -- Total cargo IVA  (no desp)
      v_tot_int_descontado NUMBER(18, 2); -- Total interes descontado (no desp)
      v_tot_a_cobrar       NUMBER(18, 2); -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
      v_tot_punitorio      NUMBER(18, 2); -- Total monto punitorio (DESPLIEGA : Punitorio)
      v_moneda             ba_monedas.cod_moneda%type; --nr
      v_cod_moneda         VARCHAR2(1);
      v_cod_ofi_origen     pr_movimientos_his.cod_ofi_origen%TYPE;
      v_dia_mora           pr_cta_prestamos.dia_atraso%TYPE;
      v_nro_cuenta         pr_cta_prestamos.nro_cuenta%TYPE;
      v_iva_devuelto       NUMBER(18, 2) := 0; -- Iva devuelto
      v_cantidad           NUMBER(3):=0;
      v_fec_actual         Date;
      v_cod_retorno        VARCHAR2(3) := '000';
      r_ctapre             pr_cta_prestamos%ROWTYPE;
      v_des_retorno        VARCHAR2(30) := 'OK';
      v_cod_error          NUMBER(3) := 0;

      CURSOR cta IS
         SELECT c.nro_cuenta
           FROM ba_personas a, ge_cta_clientes c, pr_cta_prestamos s
          WHERE a.cod_persona = c.cod_persona
            AND c.nro_cuenta = s.nro_cuenta
            AND (c.nro_cuenta = p_nro_cuenta) --OR replace(a.nro_documento,'-','') = p_nro_cuenta)
            AND c.relacion = 'P'
            AND s.estado <> 'N'
            AND nvl(instr(','||fug_obt_pardinamico('PRE_MOD_NEGADAS')||',', ','||s.cod_modalidad||','),0) = 0;

       --Cursor para recuperar los detalles: la cuota mas vencida de cada cuenta.
      CURSOR cuotas(v_nro_cuenta IN VARCHAR2) IS
         SELECT to_char(MIN(c.fec_vencimiento), 'ddmmyyyy') fec_vto, MIN(c.nro_cuota) nro_cuota
           FROM pr_cuotas c
          WHERE c.nro_cuenta = v_nro_cuenta
            AND c.nro_cuota > 0
            AND c.estado <> 'N'
          ORDER BY c.nro_cuota;

   BEGIN
      v_fec_actual      := pag_cal.fu_obt_fec_actual(3);
      lp_ver_horario;
      v_cod_ofi_origen := fug_obt_ofi_usuario(USER);
      v_moneda         := it.fue_obt_mon_bcp(p_moneda);
      v_can_cuotas := 0;
      IF v_cod_retorno = pag_ser.v_cod_aprobado THEN

     FOR r IN cta LOOP
            v_cantidad := v_cantidad+1;
            v_iva_devuelto := 0;
            v_nro_cuenta  := r.nro_cuenta;
            v_nom_titular := fue_obt_nom_persona(fug_obt_cli_principal(v_nro_cuenta));
            pap_pre.pr_obt_dat_prestamo(v_nro_cuenta, r_ctapre);
            --
            IF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_local THEN
               v_cod_moneda := '1';
            ELSIF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_fuerte THEN
               v_cod_moneda := '2';
            ELSE
               v_cod_retorno := pag_ser.v_mon_incorrecta;
               v_des_retorno := 'Moneda incorrecta.';
            END IF;
            IF nvl(r_ctapre.en_juicio, 'N') = 'S' then
              v_cod_retorno := pag_ser.v_cta_incorrecta;
              v_des_retorno := 'Cuenta en juicio';
            END IF;
            -- Se verifica si no tiene cobros pendientes de ser aplicados...
            DECLARE
               v_can_pag_pend NUMBER(5) := 0;
            BEGIN
               SELECT COUNT(*)
                 INTO v_can_pag_pend
                 FROM pr_cobros_noc
                WHERE nro_cuenta = v_nro_cuenta
                  AND estado = 'I';
               IF v_can_pag_pend > 0 THEN
                  v_cod_retorno := pag_ser.v_cuo_cancelada;
                  v_des_retorno := 'Cuota ya pagada';
               END IF;
            END;
            --Moneda de la cuenta es la misma que eligio el usuario.
            IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
                 FOR d IN cuotas(v_nro_cuenta) LOOP
                    v_can_cuotas := nvl(v_can_cuotas, 0) + 1;

                    pap_pre.pr_ini_autorizacion;
                    pap_pre.pr_obt_deu_prestamo(v_nro_cuenta, v_fec_actual, d.nro_cuota, d.nro_cuota,
                                                v_cod_ofi_origen, v_mto_cobrado, v_cod_error,
                                                v_des_retorno, v_tot_capital, v_tot_interes,
                                                v_tot_int_adelantado, v_tot_mora, v_tot_mora_interes,
                                                v_tot_mora_int_adel, v_tot_punitorio, v_tot_impuesto,
                                                v_tot_cargo, v_tot_cargo_iva, v_tot_int_descontado,
                                                v_dia_mora, v_cod_tra_padre, 'N'); --- cancela

                    IF v_cod_error <> 0 THEN
                       v_cod_retorno := pag_ser.v_err_proceso;
                       v_des_retorno := 'Error en la cuenta de prestamo';
                    ELSE
                       v_tot_mora     := nvl(v_tot_mora, 0) + nvl(v_tot_mora_int_adel, 0) +
                                         nvl(v_tot_mora_interes, 0);
                       v_tot_cargo    := nvl(v_tot_cargo, 0);
                       v_tot_a_cobrar := nvl(v_tot_capital, 0) + nvl(v_tot_interes, 0) +
                                         nvl(v_tot_mora, 0) + nvl(v_tot_impuesto, 0) +
                                         nvl(v_tot_int_adelantado,0) + nvl(v_tot_cargo, 0)+nvl(v_tot_punitorio,0);
                       v_cadena :=  to_char(v_nro_cuenta)||';'||to_char(d.nro_cuota)||';'||d.fec_vto||';'||v_tot_a_cobrar;
                    END IF;
                 END LOOP;
            END IF;
      EXIT WHEN v_cantidad = 10;
     END LOOP;
         IF v_nro_cuenta IS NULL THEN
            --No encontro la cuenta, emite mensaje de error.
            v_cod_retorno := pag_ser.v_cta_incorrecta;
            v_des_retorno := 'Cuenta o doc. inexistente';
         END IF;
      ELSE
         v_cadena := rpad(v_cod_retorno, 3, ' ') || rpad(v_des_retorno, 30, ' ') ||
                     rpad(v_nom_titular, 60, ' ') || lpad(to_char(v_can_cuotas), 3, '0');
      END IF;
      commit;
      RETURN v_cadena;
END fu_obt_deu_prest_cta;


function fu_es_conjunta(p_nro_cuenta in varchar2) return varchar2 is
    v_can_conjunta number;
  begin

    select count('S')
      into v_can_conjunta
      from ge_cta_clientes
     where nro_cuenta = p_nro_cuenta
       and relacion = 'Y'
       and rownum = 1;

    if nvl(v_can_conjunta, 0) > 0 then
      return 'S';
    else
      return 'N';
    end if;
  end;

  function fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type)
    return varchar2 is
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;

  begin
    select count(*)
      into v_can_user
      from ba_cod_referencias
     where dominio = 'USU_MOV_SERVICIO'
       and abreviatura = p_tip_user;

    v_nro_sec  := fue_obt_sig_secuencia('S_SER_USER_CNB');
    v_nro_user := mod(v_nro_sec, v_can_user);
    v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO',
                                              v_nro_user,
                                              p_tip_user);
    return v_user;
  end;

  function fu_obt_hora(p_cod_usuario varchar2) return varchar2 is
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;

  begin
    if upper(substr(p_cod_usuario, -1)) = 'B' then
      v_ind_usuario := 0;
    else
      v_ind_usuario := substr(p_cod_usuario, -1);
    end if;

    if v_ind_usuario > 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_movi' || v_ind_usuario);
    elsif v_ind_usuario = 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_movi');
    end if;

    v_nro_hor := mod(v_nro_sec, 86400);

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    return v_hora;
  end;

  function fu_obt_impuesto(p_monto number, p_moneda_bcp in number)
    return number is
    v_redondeo     number(1) := 0;
    v_mto_impuesto number(18, 2) := 0;
    v_tas_impuesto number(2) := 10;
    v_cod_moneda   ba_monedas.cod_moneda%type;
  begin
    begin
      select cod_moneda
        into v_cod_moneda
        from ba_monedas b
       where b.cod_mon_bco_central = p_moneda_bcp;
    exception
      when no_data_found then
        return 0;
    end;

    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                      null,
                                      null,
                                      v_cod_moneda);

    v_mto_impuesto := round((p_monto * v_tas_impuesto) / 100, v_redondeo);
    return v_mto_impuesto;
  exception
    when others then
      return 0;

  end fu_obt_impuesto;

  procedure pr_obt_dat_persona(p_cod_pais             in number,
                               p_tip_documento        in number,
                               p_nro_documento        in varchar2,
                               p_cod_persona          out varchar2,
                               p_pri_nombre           out varchar2,
                               p_seg_nombre           out varchar2,
                               p_pri_apellido         out varchar2,
                               p_seg_apellido         out varchar2,
                               p_cod_sexo             out varchar2,
                               p_cod_pai_nacionalidad out number,
                               p_fec_nacimiento       in out date,
                               p_fec_vto_documento    out date,
                               p_telefono             in out varchar2,
                               p_email                out varchar2,
                               p_direccion            out varchar2,
                               p_cod_profesion        out number,
                               p_desc_prof            out varchar2,
                               p_desc_prof_ing        out varchar2,
                               p_tip_operacion        in varchar2,
                               p_cod_error            out number,
                               p_msj_error            out varchar2) is
    v_tip_persona    varchar2(1);
    v_existe         number;
    v_fec_nacimiento ba_per_fisicas.fec_nacimiento%type;
    v_telefono       varchar2(20);
    v_det_error      ge_log_errores.det_error%type;
    v_cod_pais       ba_personas.cod_pais%type;
  begin
    if p_fec_nacimiento is null and nvl(p_tip_operacion, 'x') = 'E' then
      p_cod_error := 6;
      p_msj_error := 'La fecha de nacimiento no puede ser nulo ';
      return;
    end if;
    if nvl(p_telefono, 'x') = 'x' and nvl(p_tip_operacion, 'x') = 'E' then
      p_cod_error := 7;
      p_msj_error := 'El nro de celular no puede ser nulo ';
      return;
    end if;
    begin
      select p.tipo, p.cod_persona
        into v_tip_persona, p_cod_persona
        from ba_personas p
       where p.nro_documento = p_nro_documento
         and p.cod_tip_documento = p_tip_documento
         and p.cod_pais = p_cod_pais;
    exception
      when no_data_found then
        --no se encontro datos los parametros especificos, buscar solo por numero de documento
        begin
          select 1,p.tipo,p.cod_persona,cod_pais
            into v_existe,v_tip_persona,p_cod_persona,v_cod_pais
            from ba_personas p
           where p.nro_documento = p_nro_documento
             and p.cod_tip_documento = p_tip_documento;
        exception
          when no_data_found then
            p_cod_error := 1;
            p_msj_error := 'Persona no registrada en el sistema';
          when too_many_rows then
            p_cod_error := 2;
            p_msj_error := 'Error al recuperar datos de la persona. Existe mas de un registro.';
        end;
      when too_many_rows then
        p_cod_error := 2;
        p_msj_error := 'Error al recuperar datos de la persona. Existen datos similares.';
    end;
    if v_tip_persona = 'F' and nvl(p_cod_error, 0) = 0 then
      -- persona fisica
      begin
      
        select f.pri_nombre,
               f.seg_nombre,
               f.pri_apellido,
               f.seg_apellido,
               f.cod_sexo,
               f.cod_pai_nacionalidad,
               f.fec_nacimiento,
               p.fec_vto_documento,
               t.area || t.telefono telefono_principal,
               p.dir_correo email,
               d.direccion,
               f.cod_profesion,
               n.descripcion,
               n.deseng
          INTO p_pri_nombre,
               p_seg_nombre,
               p_pri_apellido,
               p_seg_apellido,
               p_cod_sexo,
               p_cod_pai_nacionalidad,
               v_fec_nacimiento,
               p_fec_vto_documento,
               v_telefono,
               p_email,
               p_direccion,
               p_cod_profesion,
               p_desc_prof,
               p_desc_prof_ing
          from ba_personas        p,
               ba_per_fisicas     f,
               ba_telefonos       t,
               ba_direcciones     d,
               ba_ser_profesiones m,
               ba_ser_profesiones n
         where p.cod_persona = f.cod_persona
           and p.cod_persona = t.cod_persona(+)
           and p.cod_persona = d.cod_persona(+)
           and t.principal(+) = 'S'
           and d.principal(+) = 'S'
           and f.cod_profesion = m.cod_profesion(+)
           and m.cod_map = n.cod_profesion(+)
           and p.cod_tip_documento = p_tip_documento
           and p.nro_documento = p_nro_documento
           and p.cod_pais = nvl(v_cod_pais,p_cod_pais);
      
        p_cod_error := 0;
      exception
      
        when too_many_rows then
          p_cod_error := 2;
          p_msj_error := 'Error al recuperar datos de la persona. Existe mas de un registro';
        when others then
          p_cod_error := 3;
          p_msj_error := 'Error al recuperar datos de la persona';
      end;
      --Valida que la fecha de nacimiento corresponda a la persona
      if p_tip_operacion = 'E' then
        if p_fec_nacimiento != v_fec_nacimiento then
          p_cod_error := 8;
          p_msj_error := 'Fecha de nacimiento : ' || p_fec_nacimiento ||
                         ' no corresponde a la persona';
          return;
        end if;
        --Valida numero de celular
        if p_telefono != v_telefono then
          p_cod_error := 9;
          p_msj_error := 'El numero ' || p_telefono ||
                         ' no corresponde a la persona';
          return;
        end if;
        if nvl(p_cod_error, 0) = 0 then
          p_cod_error := 0;
          p_msj_error := 'Los datos son correctos';
        end if;
      else
        p_fec_nacimiento := v_fec_nacimiento;
        p_telefono       := v_telefono;
      end if;
    
    elsif v_tip_persona = 'J' then
      if nvl(p_tip_operacion, 'x') = 'E' then
        -- Persona Juridica
        p_cod_error := 4;
        p_msj_error := 'Persona es del tipo Juridica';
      else
        begin
          select f.raz_social,
                 null seg_nombre,
                 null pri_apellido,
                 null seg_apellido,
                 null cod_sexo,
                 p.cod_pais,
                 f.fec_apertura,
                 null fec_vto_documento,
                 t.area || t.telefono telefono_principal,
                 p.dir_correo email,
                 d.direccion,
                 null cod_profesion,
                 null descripcion,
                 null deseng
            INTO p_pri_nombre,
                 p_seg_nombre,
                 p_pri_apellido,
                 p_seg_apellido,
                 p_cod_sexo,
                 p_cod_pai_nacionalidad,
                 v_fec_nacimiento,
                 p_fec_vto_documento,
                 v_telefono,
                 p_email,
                 p_direccion,
                 p_cod_profesion,
                 p_desc_prof,
                 p_desc_prof_ing
            from ba_personas      p,
                 ba_per_juridicas f,
                 ba_telefonos     t,
                 ba_direcciones   d
           where p.cod_persona = f.cod_persona
             and p.cod_persona = t.cod_persona(+)
             and p.cod_persona = d.cod_persona(+)
             and t.principal(+) = 'S'
             and d.principal(+) = 'S'
             and p.cod_tip_documento = p_tip_documento
             and p.nro_documento = p_nro_documento
             and p.cod_pais = nvl(v_cod_pais,p_cod_pais);
        exception
          when no_data_found then
            p_cod_error := 5;
            p_msj_error := 'No se encontraron datos';
          when others then
            p_cod_error := 6;
            p_msj_error := 'Error al consultar datos' || sqlerrm;
        end;
      end if;
    end if;
    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Documento : ' || p_nro_documento || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_DAT_PERSONA',
                            v_det_error,
                            p_cod_persona,
                            null);
    end if;
  exception
    when others then
      p_cod_error := 5;
      p_msj_error := sqlerrm;
      v_det_error := 'Documento : ' || p_nro_documento || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_DAT_PERSONA',
                            v_det_error,
                            p_cod_persona,
                            null);
  end pr_obt_dat_persona;

  procedure pr_gen_pag_tarjetas(p_cod_ente    in varchar2,
                                p_monto       in number,
                                p_mon_bcp     in varchar2,
                                p_mov_id      in varchar2,
                                p_cuenta_tarj in varchar2,
                                p_error       out number,
                                p_respuesta   out varchar2) is

    v_cod_ente_vision ge_entes.cod_ente%type;
    v_mon_pag_min     ta_cta_tarjetas.mto_pag_minimo%type;
    v_nro_cuenta      ge_cuentas.nro_cuenta%type; -- Numero de la cuenta
    v_denominacion    ta_tarjetas.nom_embozar%type; -- Nombre de la cuenta
    v_cod_moneda      ba_monedas.cod_moneda%type; -- moneda de la cuenta
    v_est_cuenta      ge_cuentas.estado%type; -- estado de la cuenta
    v_tip_cuenta      ge_modalidades.cod_modalidad%type; -- tipo de cuenta(modalidad)
    v_cod_oficina     ta_cta_tarjetas.cod_oficina%type;
    v_cod_tra_padre   ge_transacciones.cod_transaccion%type := 250;
    v_mod_padre       ta_cta_tarjetas.cod_modulo%type;
    v_mad_padre       ta_cta_tarjetas.cod_modalidad%type;
    v_cod_modulo      ta_cta_tarjetas.cod_modulo%type;
    v_cod_modalidad   ta_cta_tarjetas.cod_modalidad%type;
    v_nvo_estado      ta_cta_tarjetas.estado%type;
    v_sal_disponible  number(18, 2);
    v_procesa         varchar2(1);
    v_es_ope_vencida  varchar2(1);
    v_cod_transaccion ge_transacciones.cod_transaccion%type;
    v_hor_actual      VARCHAR2(08); -- := to_char(SYSDATE, 'HH24:MI:SS');
    v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(5);
    v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
    v_dia_mora        ta_cobros.dia_mora%type;
    v_cta_deb_ente    ge_par_entes.val_parametro%type;
    v_par_ente        ge_par_entes.val_parametro%type;
    v_par_moneda      ba_monedas.cod_moneda%type;
    v_nro_tarjeta     ta_tarjetas.nro_tarjeta%type;
    v_det_error       ge_log_errores.det_error%type;
    v_cod_procesadora ta_tipos.cod_ent_procesadora%TYPE;

  begin
    /*Validaciones*/
    if nvl(p_cod_ente, 'x') = 'x' then
      p_error     := 1;
      p_respuesta := 'Debe ingresar ente: ' || p_cod_ente;
      return;
    end if;
    if nvl(p_monto, 0) = 0 then
      p_error     := 2;
      p_respuesta := 'Debe ingresar el monto de la operacion: ' || p_monto;
      return;
    end if;
    if nvl(p_mon_bcp, 'x') = 'x' then
      p_error     := 3;
      p_respuesta := 'Debe ingresar la moneda: ' || p_mon_bcp;
      return;
    end if;
    if nvl(p_mov_id, 'x') = 'x' then
      p_error     := 4;
      p_respuesta := 'Debe ingresar el Id del movimiento - ' || p_mov_id;
      return;
    end if;
    if nvl(p_cuenta_tarj, 'x') = 'x' then
      p_error     := 5;
      p_respuesta := 'Debe ingresar la cuenta - ' || p_cuenta_tarj;
      return;
    end if;
    if pae_cnf.fu_obt_est_modulo(1) != 2 then
      p_error     := 99;
      p_respuesta := 'Modulo Cerrado. No se puede operar';
    else
      if nvl(p_error, 0) = 0 then
        v_par_moneda := it.fue_obt_mon_bcp(p_mon_bcp);
        /*Valida si la cuenta existe*/
        begin
          select a.nom_embozar,
                 c.cod_moneda,
                 c.estado,
                 c.cod_modalidad,
                 c.nro_cuenta,
                 c.cod_oficina,
                 c.mto_pag_minimo,
                 c.cod_modulo,
                 c.cod_modalidad,
                 c.dia_mora,
                 a.nro_tarjeta
            into v_denominacion,
                 v_cod_moneda,
                 v_est_cuenta,
                 v_tip_cuenta,
                 v_nro_cuenta,
                 v_cod_oficina,
                 v_mon_pag_min,
                 v_mod_padre,
                 v_mad_padre,
                 v_dia_mora,
                 v_nro_tarjeta
            from ta_cta_tarjetas c, ta_tarjetas a
           where c.nro_cuenta = a.nro_cuenta
             and a.nro_cuenta = p_cuenta_tarj
             and a.rel_tarjeta = 0 --principal
             and a.vigente = 'S';

        exception
          when no_data_found then
            p_error     := 7;
            p_respuesta := 'Nro de cuenta ' || p_cuenta_tarj ||
                           ' no existe!';
            return;
          when others then
            p_error     := 8;
            p_respuesta := 'ERROR: ' || sqlerrm;
            return;
        end;
        /*Valida monto*/
        if nvl(p_monto, 0) > 0 then
          if p_monto < v_mon_pag_min then
            p_error     := 10;
            p_respuesta := 'Monto ingresado debe ser mayor o igual al pago minimo : ' ||
                           v_mon_pag_min;
            return;
          end if;
        else
          p_error     := 9;
          p_respuesta := 'Monto ingresado debe ser mayor a cero ';
          return;
        end if;
        if v_cod_moneda <> v_par_moneda then
          p_error     := 11;
          p_respuesta := 'La moneda ingresada ' || p_mon_bcp ||
                         ' no corresponde a la cuenta';
          return;
        end if;

        p_respuesta := fuj_ver_impedimentos(p_cuenta_tarj,
                                            v_tip_cuenta,
                                            v_cod_transaccion,
                                            v_est_cuenta,
                                            'C'); -- 'C'== CREDITO
        if p_respuesta is not null then
          p_error     := 12;
          p_respuesta := 'No se puede procesar el pago: ' || p_respuesta;
          return;
        end if;
        -- Controla que la Cuenta no haya pasado a vencida
        BEGIN
          SELECT 'S'
            INTO v_es_ope_vencida
            FROM ov_cta_vencidas b
           WHERE b.nro_cta_origen = p_cuenta_tarj;
          IF nvl(v_es_ope_vencida, 'N') = 'S' THEN
            p_error     := 13;
            p_respuesta := 'La cuenta ' || p_cuenta_tarj ||
                           ' se encuentra vencida';
            return;
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            v_es_ope_vencida := NULL;
          WHEN OTHERS THEN
            NULL;
        END;
        /*Recupera los datos del ente*/
        if v_par_moneda = pag_gen.FU_OBT_MON_LOCAL then
          v_par_ente := 'CTA_OP_CNB_GS';
        elsif v_par_moneda = pag_gen.FU_OBT_MON_FUERTE then
          v_par_ente := 'CTA_OP_CNB_USD';
        end if;

        -- Si el ente recibido como parametro corresponde a WEPA (RED DIFGITAL S.A)
        If p_cod_ente = nvl(fug_obt_pardinamico('COD_ENT_WEPA'), 9733) then
          --Obtenemos el ente de wepa donde la cta operativa configurada es la cta de vision
          v_cod_ente_vision := fug_obt_pardinamico('COD_ENT_WEPA_VISION');
          -- Obtenemos la cuenta
          v_cta_deb_ente := fug_obt_parentes(v_cod_ente_vision, v_par_ente);
        Else
          v_cta_deb_ente := fug_obt_parentes(p_cod_ente, v_par_ente);
        End if;

        if v_cta_deb_ente is null then
          p_error     := 14;
          p_respuesta := 'La cuenta Operativa del ente ' || p_cod_ente ||
                         ' no se encuentra configurada';
          return;
        end if;

        /*Si pasa todas las validaciones realiza operacion de debito y credito*/
        begin
          pre_ini_aplicacion;
          pae_cnf.g_cod_modulo := 1;
        end;
        if pae_cnf.fu_obt_est_modulo(3) != 2 then
          p_error     := 18;
          p_respuesta := 'En proceso de cierre';
          return;
        end if;

        begin

          savepoint pago;

          v_hor_actual := fug_obt_mov_hora; /*fug_obt_hor_disponible(v_fec_actual,
                                                                                v_hor_actual,
                                                                                user,
                                                                                'N');*/

          pag_cta.pr_set_referencia(p_mov_id);
          pag_cta.pr_set_nro_documento3(p_cod_ente);
          pag_cta.PR_NRO_CAJA(p_nro_caja => null);
          pag_cta.pr_act_operacion(v_cta_deb_ente,
                                   v_hor_actual,
                                   'D', -- Debito
                                   v_par_moneda,
                                   p_monto,
                                   v_cod_tra_padre,
                                   8522, -- trans. hijo de efectivo
                                   p_mov_id,
                                   null, -- cotizacion
                                   v_cod_oficina,
                                   v_mod_padre,
                                   v_mad_padre,
                                   null, -- tasa
                                   null, -- valor de tasa
                                   'Debito pago de tarjeta', --concepto
                                   'N', -- emitir aviso
                                   v_nro_secuencia, -- nro de secuencia
                                   v_fec_actual);
          if nvl(pag_cta.g_cod_error, 0) != 0 then
            p_error     := 18;
            p_respuesta := pag_cta.G_MSJ_ERROR;
            rollback to pago;
          else
            pag_cta.pr_set_referencia(p_mov_id);
            pag_cta.pr_set_nro_documento3(p_cod_ente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            pag_cta.pr_act_operacion(p_cuenta_tarj,
                                     v_hor_actual,
                                     'C', -- Credito
                                     v_par_moneda,
                                     p_monto,
                                     v_cod_tra_padre,
                                     978, -- trans. hijo de efectivo
                                     p_mov_id,
                                     null, -- cotizacion
                                     v_cod_oficina,
                                     v_mod_padre,
                                     v_mad_padre,
                                     null, -- tasa
                                     null, -- valor de tasa
                                     'Pago Efectivo Tarj:' || v_nro_tarjeta, --concepto
                                     'N', -- emitir aviso
                                     v_nro_secuencia, -- nro de secuencia
                                     v_fec_actual);
          end if;
          if nvl(pag_cta.g_cod_error, 0) = 0 THEN
            --Verifico la procesadora para insertar el cobro en la tabla correspondiente
            v_cod_procesadora := fut_obt_procesadora(v_nro_cuenta);
            IF v_cod_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD') THEN
              insert into ta_cobros
                (nro_cuenta,
                 nro_tarjeta,
                 nro_cta_debito,
                 fec_proceso,
                 monto,
                 estado,
                 fec_valor,
                 observacion,
                 hora,
                 cod_usuario,
                 dia_mora,
                 tipo)
              values
                (v_nro_cuenta,
                 v_nro_tarjeta,
                 null,
                 v_fec_actual,
                 p_monto,
                 'P',
                 v_fec_actual,
                 'Pago Tarjeta por FielCorrsponsal',
                 v_hor_actual,
                 user,
                 v_dia_mora,
                 'P');
            ELSIF v_cod_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL') THEN
              insert into ta_cobros_gp
                (nro_cuenta,
                 nro_tarjeta,
                 nro_cta_debito,
                 fec_proceso,
                 monto,
                 estado,
                 fec_valor,
                 observacion,
                 hora,
                 cod_usuario,
                 dia_mora,
                 tipo,
                 canal)
              values
                (v_nro_cuenta,
                 v_nro_tarjeta,
                 null,
                 v_fec_actual,
                 p_monto,
                 'P',
                 v_fec_actual,
                 'Pago Tarjeta por FielCorrsponsal',
                 v_hor_actual,
                 user,
                 v_dia_mora,
                 'P',
                 'B'); --Boca cobranzas
            END IF;
          else
            p_error     := 15;
            p_respuesta := pag_cta.G_MSJ_ERROR;
            rollback to pago;
          end if;
          /*Si esta todo ok responde 0*/
          if nvl(p_error, 0) = 0 then
            p_error     := 0;
            p_respuesta := 'Pago realizado correctamente';
          end if;
        exception
          when others then
            p_error := 16;
            if pag_cta.g_cod_error != '00' then
              p_respuesta := pag_cta.G_MSJ_ERROR;
            else
              p_respuesta := sqlerrm;
            end if;
            rollback to pago;
        end;
      end if;
    end if;
    if nvl(p_error, 0) != 0 then
      v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Monto: ' || p_monto || ' ' || p_mon_bcp ||
                     ' Error: Cod. ' || p_error || '-' || p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_PAG_TARJETAS',
                            v_det_error,
                            null,
                            p_cuenta_tarj);
    end if;

  exception
    when others then
      p_error     := 17;
      p_respuesta := 'Error al procesar pago de Tarjeta cta ' ||
                     p_cuenta_tarj || ' - ' || sqlerrm;
      v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Monto: ' || p_monto || ' ' || p_mon_bcp ||
                     ' Error: Cod. ' || p_error || ' ' || p_respuesta;

      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_PAG_TARJETAS',
                            v_det_error,
                            null,
                            p_cuenta_tarj);
  end pr_gen_pag_tarjetas;

  procedure pr_ver_mov_cnb_diario(p_cod_persona   in varchar2,
                                  p_nro_cuenta    in varchar2,
                                  p_cod_ente      in ge_entes.cod_ente%type,
                                  p_mon_bcp       in number,
                                  p_monto         in number,
                                  p_tip_operacion in varchar2,
                                  p_mto_total_gs  out number, --Total GS
                                  p_mto_total_ext out number, --Total moneda extranjera
                                  p_mto_total     out number, --Total GS + Total moneda extranjera guaranizado
                                  p_mto_limite    out number,
                                  p_error         out number,
                                  p_respuesta     out varchar2) is

    v_mto_limite         ge_movimientos.monto%type;
    v_mto_lim_especial   ge_movimientos.monto%type;
    v_mon_lim_especial   ba_monedas.cod_moneda%type;
    v_cod_moneda         ba_monedas.cod_moneda%type;
    v_cod_mon_limite     ba_monedas.cod_moneda%type;
    v_mon_fuerte         ba_monedas.cod_moneda%type;
    v_mon_cta            ba_monedas.cod_moneda%type;
    v_mto_tot_gs_diario  ge_movimientos.monto%type := 0;
    v_mto_tot_ext_diario ge_movimientos.monto%type := 0;
    v_mto_tot_equ_diario ge_movimientos.monto%type := 0;
    v_cod_tra_padre      ge_transacciones.cod_transaccion%type;
    v_cod_transaccion    ge_transacciones.cod_transaccion%type;
    v_ope_monto          ge_movimientos.monto%type;
    v_nom_par_gral       ge_parametros.parametro%type;
    v_nom_parametro      ge_parametros.parametro%type;
    v_det_error          ge_log_errores.det_error%type;
    v_monto_limite_ente  ge_movimientos.monto%type;

    cursor c_movimientos is
      select m.monto, m.cod_moneda
        from ge_movimientos m
       where m.cod_tra_padre = v_cod_tra_padre
         and m.cod_transaccion = v_cod_transaccion
         and m.nro_cuenta = p_nro_cuenta
         and m.reversado = 'N';

  begin
    /*Proceso para el control de exceso de movimientos por cuenta*/

    /*Validaciones*/
    if nvl(p_monto, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Debe ingresar el monto de la operacion: ';
      return;
    end if;
    if nvl(p_mon_bcp, 0) = 0 then
      p_error     := 2;
      p_respuesta := 'Debe ingresar la moneda';
      return;
    end if;
    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_error     := 3;
      p_respuesta := 'El numero de cuenta no puede ser nulo';
      return;
    end if;
    if nvl(p_tip_operacion, 'x') = 'x' then
      p_error     := 4;
      p_respuesta := 'Tipo de operacion no puede ser nulo';
      return;
    end if;
    v_cod_moneda := fue_obt_mon_bcp(p_mon_bcp);
    v_mon_fuerte := pag_gen.FU_OBT_MON_FUERTE;
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    v_mon_cta := pag_cta.G_CTAS.cod_moneda;
    if v_mon_cta != v_cod_moneda then
      p_error     := 5;
      p_respuesta := 'La moneda de la operacion no corresponde a la moneda de la cuenta';
      return;
    end if;
    /*Verifica si el cliente cuenta con limite personalizado*/
    /*Extracciones*/
    if p_tip_operacion = 'E' then
      v_nom_par_gral    := 'LIM_MTO_DIA_EXT_GRAL';
      v_cod_transaccion := 8514;
      v_cod_tra_padre   := 8536;
      if v_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
        v_nom_parametro  := 'LIM_DIA_EXT_CNB_GS';
        v_cod_mon_limite := pag_gen.FU_OBT_MON_LOCAL;
      elsif v_cod_moneda = pag_gen.FU_OBT_MON_FUERTE then
        v_nom_parametro  := 'LIM_DIA_EXT_CNB_USD';
        v_cod_mon_limite := pag_gen.FU_OBT_MON_FUERTE;
      end if;
      /*Depositos*/
    elsif p_tip_operacion = 'D' then
      v_nom_par_gral    := 'LIM_MTO_DIA_DEP_GRAL';
      v_cod_transaccion := 8515;
      v_cod_tra_padre   := 8535;
      if v_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
        v_nom_parametro  := 'LIM_DIA_DEP_CNB_GS';
        v_cod_mon_limite := pag_gen.FU_OBT_MON_LOCAL;
      elsif v_cod_moneda = pag_gen.FU_OBT_MON_FUERTE then
        v_nom_parametro  := 'LIM_DIA_DEP_CNB_USD';
        v_cod_mon_limite := pag_gen.FU_OBT_MON_FUERTE;
      end if;
    else
      p_error     := 6;
      p_respuesta := 'Tipo operacion incorrecto - ' || p_tip_operacion;
      return;
    end if;

    --buscamos si el ente se encuentra en la tabla de limites
    begin
      v_monto_limite_ente := fu_obt_lim_ente(p_cod_ente,
                                             v_cod_moneda,
                                             p_tip_operacion);
    exception
      when no_data_found then
        v_monto_limite_ente := null;
      when others then
        p_error     := 7;
        p_respuesta := 'Error al recuperar monto limite para el ente' ||
                       p_cod_ente;
    end;
    --

    begin
      /*Busca si la cuenta tiene monto limite personalizado*/
      v_mto_lim_especial := to_number(FUG_OBT_PARADICIONAL(p_nro_cuenta,
                                                           v_nom_parametro));

    exception
      when no_data_found then
        null;
      when others then
        p_error     := 8;
        p_respuesta := 'Error al recuperar monto limite para la cuenta' ||
                       p_nro_cuenta;
        return;
    end;
    if v_mto_lim_especial is not null then
      v_mto_limite := v_mto_lim_especial;

    else
      /*Si no encuentra monto limite personalizado busca el monto limite general por tipo de operacion y moneda*/
      v_mto_limite     := to_number(fug_obt_pardinamico(v_nom_par_gral,
                                                        null,
                                                        null,
                                                        v_cod_moneda));
      v_cod_mon_limite := v_cod_moneda;

      if v_mto_limite is null then
        if v_cod_moneda != pag_gen.FU_OBT_MON_LOCAL then
          /*Si no tiene parametrizado en usd busca si tiene en GS*/
          v_mto_limite     := to_number(fug_obt_pardinamico(v_nom_par_gral,
                                                            null,
                                                            null,
                                                            pag_gen.FU_OBT_MON_LOCAL));
          v_cod_mon_limite := pag_gen.FU_OBT_MON_LOCAL;
        else
          p_error     := 9;
          p_respuesta := 'No se encuentra configurado el monto limite gral en guaranies';
          return;
        end if;
      end if;
    end if;
    for reg in c_movimientos loop
      if reg.cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
        v_mto_tot_gs_diario := v_mto_tot_gs_diario + reg.monto;
      else
        v_mto_tot_ext_diario := v_mto_tot_ext_diario + reg.monto;
        v_mto_tot_equ_diario := v_mto_tot_equ_diario +
                                pag_gen.FU_CON_MON_A_MONEDA(reg.cod_moneda,
                                                            pag_gen.FU_OBT_MON_LOCAL,
                                                            reg.monto);
      end if;
    end loop;

    if v_monto_limite_ente <> 0 then
      if v_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then

        if nvl(v_mto_tot_gs_diario, 0) + p_monto > v_monto_limite_ente then
          p_error     := 10;
          p_respuesta := 'NOK-Monto supera el limite diario del Ente';
        else
          p_error     := 0;
          p_respuesta := 'OK';
        end if;
      else
        if nvl(v_mto_tot_ext_diario, 0) + p_monto > v_monto_limite_ente then
          p_error     := 11;
          p_respuesta := 'NOK-Monto supera el limite diario del Ente';
        else
          p_error     := 0;
          p_respuesta := 'OK';
        end if;
      end if;
    else

      if v_mto_limite is not null then
        if v_cod_mon_limite = v_cod_moneda then
          if v_cod_mon_limite = pag_gen.FU_OBT_MON_LOCAL then

            if nvl(v_mto_tot_gs_diario, 0) + p_monto > v_mto_limite then
              p_error     := 12;
              p_respuesta := 'NOK-Monto supera el limite diario';
            else
              p_error     := 0;
              p_respuesta := 'OK';
            end if;
          else
            if nvl(v_mto_tot_ext_diario, 0) + p_monto > v_mto_limite then
              p_error     := 13;
              p_respuesta := 'NOK-Monto supera el limite diario';
            else
              p_error     := 0;
              p_respuesta := 'OK';
            end if;
          end if;
        else
          if v_cod_mon_limite = pag_gen.FU_OBT_MON_LOCAL then
            v_ope_monto := pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda,
                                                       pag_gen.FU_OBT_MON_LOCAL,
                                                       p_monto);
            if nvl(v_mto_tot_gs_diario, 0) + nvl(v_mto_tot_equ_diario, 0) +
               v_ope_monto > v_mto_limite then
              p_error     := 14;
              p_respuesta := 'NOK-Monto supera el limite diario';
            else
              p_error     := 0;
              p_respuesta := 'OK';
            end if;
          end if;
        end if;
      end if;
    end if;
    p_mto_total_gs  := nvl(v_mto_tot_gs_diario, 0);
    p_mto_total_ext := nvl(v_mto_tot_ext_diario, 0);
    p_mto_total     := nvl(v_mto_tot_equ_diario, 0) +
                       nvl(v_mto_tot_gs_diario, 0);
    p_mto_limite    := nvl(v_mto_limite, 0);
    if nvl(p_error, 0) != 0 then
      v_det_error := ' Monto: ' || p_monto || ' ' || p_mon_bcp ||
                     ' Tip.Persona ' || p_tip_operacion || ' Error: ' ||
                     p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_VER_MOV_CNB_DIARIO',
                            v_det_error,
                            p_cod_persona,
                            p_nro_cuenta);
    end if;
  exception
    when others then
      p_error     := 15;
      p_respuesta := 'NOK - ' || SQLERRM;
      v_det_error := ' Monto: ' || p_monto || ' ' || p_mon_bcp ||
                     ' Tip.Persona ' || p_tip_operacion || ' Error: ' ||
                     p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_VER_MOV_CNB_DIARIO',
                            v_det_error,
                            p_cod_persona,
                            p_nro_cuenta);
  end pr_ver_mov_cnb_diario;

  function fu_obt_lim_ente(p_cod_ente      in number,
                           p_cod_moneda    in varchar2,
                           p_tipo_servicio in varchar2) return number is
    v_monto_dep ge_entes_limites.mto_dep_max%type;
    v_monto_ext ge_entes_limites.mto_ext_max%type;
    v_result    number;
  begin
    begin
      select s.mto_dep_max, s.mto_ext_max
        into v_monto_dep, v_monto_ext
        from ge_entes_limites s
       where s.cod_ente = p_cod_ente
         and s.cod_moneda = p_cod_moneda
         and s.estado = 'A';
    exception
      when others then
        v_monto_dep := 0;
        v_monto_ext := 0;
    end;
    --enviamos el monto segun el tipo de servicio// D:deposito , E:Extraccion
    if p_tipo_servicio = 'D' then
      v_result := v_monto_dep;
    elsif p_tipo_servicio = 'E' then
      v_result := v_monto_ext;
    end if;
    return(v_result);
  end fu_obt_lim_ente;

  procedure pr_val_per_excepcion(p_nro_documento     in VARCHAR2,
                                 p_cod_pais          in NUMBER,
                                 p_cod_tip_documento in NUMBER,
                                 p_primer_nombre     in VARCHAR2,
                                 p_segundo_nombre    in VARCHAR2,
                                 p_primer_apellido   in VARCHAR2,
                                 p_segundo_apellido  in VARCHAR2,
                                 p_tipo_cliente      in VARCHAR2, -- R remitente , B beneficiario
                                 p_cod_error         out number,
                                 p_msj_error         out varchar2,
                                 p_retorno_persona   out varchar2) -- N = HABILITADO , S INHABLITADO
   is
    v_det_error       ge_log_errores.det_error%type;
    v_existe_ex       varchar2(1);
    v_existe_ln       varchar2(1);
    v_existe_of       varchar2(1);
    v_nombre_completo varchar2(70) := (p_primer_nombre || ' ' ||
                                      p_segundo_nombre || ' ' ||
                                      p_primer_apellido || ' ' ||
                                      p_segundo_apellido);

  begin
    --buscamos el cliente en la lista blanca

    begin
      --1er nivel de busqueda-- busca por doucmento, tipoDocumento, pais
      select 'S'
        into v_existe_ex
        from it.ge_cli_lis_excepciones s
       where s.nro_documento = p_nro_documento
         and s.cod_pais = p_cod_pais
         and s.cod_tip_documento = p_cod_tip_documento
         and sysdate between s.fec_vigencia and s.fec_vencimiento;
    exception
      when no_data_found then
        begin
          --2do nivel de busqueda-- busca solo por documento
          select 'S'
            into v_existe_ex
            from it.ge_cli_lis_excepciones s
           where s.nro_documento = p_nro_documento
             and sysdate between s.fec_vigencia and s.fec_vencimiento;
        exception
          when no_data_found then
            v_existe_ex := 'N';
        end;
    end;

    --buscamos al cliente en las tablas temporales--
    begin
      select 'S'
        into v_existe_ln
        from tm_per_lis_negras s
       where s.nro_documento = P_NRO_DOCUMENTO
         and s.cod_pais = P_COD_PAIS;
    exception
      when no_data_found then
        begin
          select 'S'
            into v_existe_ln
            from tm_per_lis_negras s
           where s.nro_documento = P_NRO_DOCUMENTO;
        exception
          when no_data_found then
            begin
              select 'S'
                into v_existe_ln
                from tm_per_lis_negras s
               where s.nom_completo = UPPER(v_nombre_completo);
            exception
              when no_data_found then
                v_existe_ln := 'N';
            end;
        end;
    end;
    --buscamos el ciente en el temporal per_ofac
    begin
      select 'S'
        into v_existe_of
        from tm_per_ofac s
       where s.nro_documento = P_NRO_DOCUMENTO
         and s.pais = P_COD_PAIS;
    exception
      when no_data_found then
        begin
          select 'S'
            into v_existe_of
            from tm_per_ofac s
           where s.nro_documento = P_NRO_DOCUMENTO;
        exception
          when no_data_found then
            begin
              select 'S'
                into v_existe_of
                from tm_per_ofac s
               where s.nom_completo = UPPER(v_nombre_completo);
            exception
              when no_data_found then
                v_existe_of := 'N';
            end;
        end;
    end;
    -------
    --Validamos el cliente --
    --1) Se bloqueara al usuario solo SI encuentra en las tablas tm_per_lis_negras y tm_per_ofac y NO en la tabla lista blanca.
    --2) Se bloqueara al usuario solo SI encuentra en la tabla tm_per_lis_negras y NO tm_per_ofac NI TAMPOCO en la tabla lista blanca.
    --3) Se bloqueara al usuario solo SI encuentra en la tabla tm_per_ofac y NO tm_per_lis_negras , NI TAMPOCO en la tabla li.sta blanca.
    -------
    IF v_existe_ex = 'N' THEN
      --se  verifica los tipos de opciones de la busqueda del cliente
      IF ((v_existe_ln = 'S' and v_existe_of = 'S') OR
         (v_existe_ln = 'S' and v_existe_of = 'N') OR
         (v_existe_ln = 'N' and v_existe_of = 'S')) THEN
        p_cod_error       := 1;
        p_retorno_persona := 'S';
        --se carga el mensaje de retorno segun el tipo de cliente
        IF p_tipo_cliente = 'R' then
          p_msj_error := 'El Remitente no se encuentra habilitado para operar en la Red de Financiera El Comercio';
        ELSIF p_tipo_cliente = 'B' then
          p_msj_error := 'El Beneficiario no se encuentra habilitado para operar en la Red de Financiera El Comercio';
        END IF;
      ELSE
        p_cod_error       := 0;
        p_retorno_persona := 'N';
      END IF;
    ELSE
      p_cod_error       := 0;
      p_retorno_persona := 'N';
    END IF;
    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Documento : ' || p_nro_documento || ' Tipo cliente: ' ||
                     p_tipo_cliente || ' Cod. pais ' || p_cod_pais ||
                     ' Error: Cod ' || p_cod_error || ' - ' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_VAL_PER_EXCEPCION',
                            v_det_error,
                            null,
                            null);
    end if;
  exception
    when others then
      p_msj_error := sqlerrm;
      v_det_error := 'Documento : ' || p_nro_documento || ' Tipo cliente: ' ||
                     p_tipo_cliente || ' Cod. pais ' || p_cod_pais ||
                     ' Error: Cod ' || p_cod_error || ' - ' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_VAL_PER_EXCEPCION',
                            v_det_error,
                            null,
                            null);
  end pr_val_per_excepcion;

  procedure pr_ver_sal_extracciones(p_nro_cuenta     in varchar2,
                                    p_monto          in number,
                                    p_mon_bcp        in number,
                                    p_respuesta      out varchar2,
                                    p_error          out number,
                                    p_mon_operacion  out number,
                                    p_sal_disponible out number) is

    /*Procedo que verifica si la cuenta tiene saldo suficiente para la extraccion*/

    v_est_cuenta        ge_cuentas.estado%type;
    v_sal_disponible    ge_movimientos.monto%type;
    v_procesa           varchar2(1) := 'N';
    v_cod_modulo        ge_movimientos.cod_modulo%type := NULL;
    v_cod_modalidad     ge_movimientos.cod_modalidad%type := NULL;
    v_cod_tas_iva       ge_tasas.cod_tasa%TYPE := NULL;
    v_cod_tasa          ge_tasas.cod_tasa%TYPE := NULL;
    v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
    v_val_tas_iva       ge_tas_fechas.val_tasa%TYPE;
    v_fec_vigencia      ge_tas_fechas.fec_vigencia%TYPE;
    v_tip_valor         ge_tasas.tip_valor%TYPE;
    v_tipo              ge_tasas.tipo%TYPE;
    v_par_tasa          ge_par_entes.val_parametro%type;
    v_tra_comsion       ge_transacciones.cod_transaccion%type;
    v_redondeo          NUMBER(1);
    v_cargo_iva         ge_movimientos.monto%type;
    v_tas_personalizada varchar2(1) := 'N';
    v_cod_moneda        ba_monedas.cod_moneda%type;
    v_mon_final         ge_movimientos.monto%type;
    v_det_error         ge_log_errores.det_error%type;

  begin
    p_error              := 0;
    pae_cnf.g_cod_modulo := 1;
    v_cod_moneda         := fue_obt_mon_bcp(p_mon_bcp);
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    if fu_es_conjunta(p_nro_cuenta) = 'S' then
      p_error     := 1;
      p_respuesta := 'La cuenta es conjunta ';
      return;
    end if;
    if v_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        3,
                                        NULL,
                                        pag_gen.fu_obt_mon_local);
    elsif v_cod_moneda = pag_gen.FU_OBT_MON_FUERTE then
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        3,
                                        NULL,
                                        pag_gen.FU_OBT_MON_FUERTE);
    else
      p_respuesta := 'Moneda ' || v_cod_moneda || ' no corresponde ';
      return;
    end if;

    begin
      select tas_personalizada
        into v_tas_personalizada
        from ge_cuentas
       where nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        p_error     := 1;
        p_respuesta := 'La cuenta ' || p_nro_cuenta || 'no existe';
        return;
    end;

    /*Obtiene valor del cargo*/
    pag_gen.pr_obt_val_tasa(pag_cta.G_CTAS.cod_modulo,
                            pag_cta.G_CTAS.cod_modalidad,
                            pag_cta.G_CTAS.cod_oficina,
                            p_nro_cuenta,
                            v_cod_moneda,
                            NULL,
                            v_tas_personalizada,
                            v_cod_tasa,
                            8512, --Transaccion comision por extraccion
                            NULL,
                            v_val_tasa,
                            v_fec_vigencia,
                            v_tip_valor,
                            v_tipo);
    /*iva*/
    v_cod_tas_iva := 323;
    pag_gen.pr_obt_val_tasa(pag_cta.G_CTAS.cod_modulo,
                            pag_cta.G_CTAS.cod_modalidad,
                            NULL,
                            NULL,
                            v_cod_moneda,
                            NULL,
                            NULL,
                            v_cod_tas_iva,
                            NULL,
                            NULL,
                            v_val_tas_iva,
                            v_fec_vigencia,
                            v_tip_valor,
                            v_tipo);
    v_cargo_iva := nvl(round((v_val_tasa * v_val_tas_iva / 100), v_redondeo),
                       0);

    /*Se suma el cargo al monto para verificar el saldo*/

    v_mon_final := nvl(p_monto, 0) + nvl(v_val_tasa, 0) + v_cargo_iva;

    pag_cta.PR_VER_OPERACION(p_nro_cuenta,
                             8516,
                             pag_cta.G_CTAS.COD_MODULO,
                             pag_cta.G_CTAS.COD_MODALIDAD,
                             'D',
                             v_cod_moneda,
                             v_mon_final,
                             pag_cta.G_CTAS.COD_OFICINA,
                             v_cod_modulo,
                             v_cod_modalidad,
                             v_est_cuenta,
                             v_sal_disponible,
                             v_procesa,
                             8514);

    if v_procesa = 'N' then
      p_error          := 2;
      p_respuesta      := pag_cta.G_MSJ_ERROR;
      p_sal_disponible := v_sal_disponible;
      p_mon_operacion  := v_mon_final;
    elsif v_procesa = 'S' then
      p_respuesta      := 'OK';
      p_sal_disponible := v_sal_disponible;
      p_mon_operacion  := v_mon_final;
    end if;
  exception
    when others then
      p_respuesta := 'NOK- ' || SQLERRM;
      p_error     := 3;
      v_det_error := ' Monto: ' || p_monto || ' ' || p_mon_bcp ||
                     ' Error: ' || p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_VER_SAL_EXTRACCIONES',
                            v_det_error,
                            null,
                            p_nro_cuenta);
  end pr_ver_sal_extracciones;

  procedure pr_obt_mto_comision(p_cta_credito  in varchar2,
                                p_cod_moneda   in number,
                                p_mto_comision out number,
                                p_cod_error    out number,
                                p_msj_error    out varchar2) is
    v_moneda   ba_monedas.cod_moneda%type := it.fue_obt_mon_bcp(p_cod_moneda);
    v_existe   varchar2(1);
    v_comision ge_tas_fechas.val_tasa%type;
    v_tasa     ge_tas_fechas.cod_tasa%type := 516;
  begin
    --buscamos si la cuenta tiene configurado tasa personalizada
    begin
      select 'S'
        into v_existe
        from ge_cuentas s
       where s.nro_cuenta = p_cta_credito
         and s.cod_moneda = v_moneda
         and s.tas_personalizada = 'S';
    exception
      when no_data_found then
        v_existe    := null;
        p_cod_error := 1;
        p_msj_error := 'La cuenta no posee tasa personalizada: ' ||
                       p_cta_credito;
    end;
    --si la cuenta tiene tasa personalizada buscamos el cargo --
    if v_existe = 'S' then
      begin
        select s.val_tasa
          into v_comision
          from ge_tas_fechas s
         where s.cod_tasa = v_tasa
           and s.nro_cuenta = p_cta_credito
           and s.cod_moneda = v_moneda
           and sysdate between s.fec_vigencia and s.fec_vencimiento;
      exception
        when no_data_found then
          v_comision  := 0;
          p_cod_error := 2;
          p_msj_error := 'No se encontro el cargo configurado para la cuenta' ||
                         p_cta_credito;
      end;
      p_mto_comision := v_comision;
      p_cod_error    := 0;
      p_msj_error    := 'Proceso Finalizado correctamente';
    end if;
  end pr_obt_mto_comision;

   procedure pr_gen_mov_deposito(p_cod_ente       in number,
                                p_monto          in number,
                                p_nro_cuenta     in varchar2,
                                p_cod_moneda_bcp in ba_monedas.cod_mon_bco_central%type,
                                p_mov_id         in varchar2,
                                p_cod_error      out number,
                                p_msj_error      out varchar2) is
    --VARIABLE
    v_par_ente         ge_par_entes.val_parametro%type;
    v_cuenta           ge_movimientos.nro_cuenta%type := p_nro_cuenta;
    v_cuenta_cnb       ge_movimientos.nro_cuenta%type;
    v_cod_ente_vision  ge_entes.cod_ente%type;
    v_moneda           ba_monedas.cod_moneda%type;
    v_mto              ge_movimientos.monto%type := p_monto;
    v_mto_comis        ge_movimientos.monto%type;
    v_fecha_actual     DATE := it.pag_cal.fu_obt_fec_actual(1);
    v_p_fe_vigencia    DATE;
    v_hora             ge_movimientos.hora%TYPE; /* := to_char(sysdate,
                                                                 'HH24:MI:SS');*/
    v_cotizacion       ge_cotizaciones.val_conversion%type := null;
    v_nro_documento    ge_movimientos.nro_documento%type := p_mov_id;
    v_existe           varchar2(1) default 'S';
    v_referencia       ge_movimientos.referencia%type := p_mov_id;
    v_cod_persona      ba_personas.cod_persona%type := fug_obt_cli_principal(v_cuenta);
    v_tip_ente         number(1) := 0;
    v_cod_mod_padre    number;
    v_cod_mad_padre    number;
    v_cod_tra_padre    number;
    v_factura          cb_lib_ventas.nro_factura%type;
    v_tas_personal     ge_cuentas.tas_personalizada%type default 'N';
    v_val_tasa         ge_tas_fechas.val_tasa%type;
    v_tip_valor        ge_tasas.tip_valor%type;
    v_tipo             ge_tasas.tipo%type;
    v_cod_tasa         ge_transacciones.cod_tasa%type;
    v_mto_iva          ge_movimientos.monto%type;
    v_cod_tas_comision ge_transacciones.cod_tasa%type := 516;
    v_redondeo         NUMBER(1);
    v_val_tas_comision ge_tas_fechas.val_tasa%type;
    v_cod_mod_persona  ge_transacciones.cod_modulo%TYPE;
    v_cod_mad_persona  ge_transacciones.cod_modalidad%TYPE;
    v_est_cuenta       ah_cta_vistas.estado%TYPE;
    v_sal_disponible   NUMBER;
    v_procesa          VARCHAR2(1);
    v_cod_transaccion  ge_movimientos.cod_transaccion%TYPE DEFAULT NULL;
    v_det_error        ge_log_errores.det_error%type;
    r_gmovi            ge_movimientos%ROWTYPE;
    v_ofi_cta_ahorro   ba_oficinas.cod_oficina%type;
    v_ofi_usuario      ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(user);
    v_mto_equ_local    ge_movimientos.mto_equ_local%type := null;
    v_cod_tas_personal ge_tas_fechas.cod_tasa%TYPE DEFAULT NULL;
    v_usuario          varchar2(15);
    v_hora_c           ge_movimientos.hora%TYPE;
    v_numero_secuencia NUMBER(3) := 0;
    v_codigo_modulo    NUMBER(3) := 4;
    v_codigo_modalidad NUMBER(3) := 43;
    v_mto_tot_wp       number(18);
    v_mto_lim_wp       number(18);
    v_horario             varchar2(1);
    v_es_mov_noc          varchar2(1);
    v_es_cta_noc          varchar2(1);
    v_fec_valor           ge_calendarios.fec_actual%type;
    v_error               number;
    v_respuesta           varchar(4000);

  begin

    v_moneda := fue_obt_mon_bcp(p_cod_moneda_bcp);
    -- obtenemos la cuenta rubro
    if v_moneda = it.pag_gen.fu_obt_mon_local then
      --v_cuenta_cnb := it.fug_obt_parentes(p_cod_ente, 'CTA_OP_CNB_GS');
      v_par_ente := 'CTA_OP_CNB_GS';
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        3,
                                        NULL,
                                        pag_gen.fu_obt_mon_local);
    elsif v_moneda = it.pag_gen.fu_obt_mon_fuerte then
      v_cotizacion := fug_obt_cotizacion(v_moneda, v_fecha_actual);
      --v_cuenta_cnb := it.fug_obt_parentes(p_cod_ente, 'CTA_OP_CNB_USD');
      v_par_ente := 'CTA_OP_CNB_USD';
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        3,
                                        NULL,
                                        pag_gen.FU_OBT_MON_FUERTE);
    end if;
    -- Si el ente recibido como parametro corresponde a WEPA (RED DIFGITAL S.A)
    If p_cod_ente = nvl(fug_obt_pardinamico('COD_ENT_WEPA'), 9733) then
      --Obtenemos el ente de wepa donde la cta operativa configurada es la cta de vision
      v_cod_ente_vision := fug_obt_pardinamico('COD_ENT_WEPA_VISION');
      -- Obtenemos la cuenta
      v_cuenta_cnb := it.fug_obt_parentes(v_cod_ente_vision, v_par_ente);
    Else
      -- Sino sigue su curso normal
      v_cuenta_cnb := it.fug_obt_parentes(p_cod_ente, v_par_ente);
    End if;

    if p_cod_ente is null then
      p_cod_error := 1;
      p_msj_error := 'Codigo de Ente no puede ser nulo.';
      return;
    end if;

    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
              it.paa_dex.pr_val_sal_mov_cliente_wp( v_cuenta,--cuenta
                                                    v_mto,--monto operacion
                                                    v_moneda, --moneda
                                                    'D',      -- D=Deposito / E=Extraccion
                                                    v_mto_tot_wp,--Total GS(monto operacion+monto movimiento)
                                                    v_mto_lim_wp, --Mto limite establecido en parametro gral
                                                    p_cod_error,
                                                    p_msj_error);
    savepoint deposito;
    if NVL(p_cod_error, 0) = 0 then
            --Verifica estado del modulo
       lp_ver_hor_cnb(v_ofi_cta_ahorro,
                     '3',
                     v_horario,
                     v_es_mov_noc,
                     v_es_cta_noc,
                     v_fecha_actual,
                     v_fec_valor,
                     v_error,
                     v_respuesta);
      if nvl(v_error, 0) = 0 then
      pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
      v_ofi_cta_ahorro := pag_cta.g_ctas.cod_oficina;

      --Verifica operacion de la cuenta
      pag_cta.PR_VER_OPERACION(v_cuenta,
                               8515,
                               3,
                               31,
                               'C',
                               v_moneda,
                               v_mto,
                               v_ofi_cta_ahorro,
                               v_cod_mod_persona,
                               v_cod_mad_persona,
                               v_est_cuenta,
                               v_sal_disponible,
                               v_procesa,
                               v_cod_transaccion);
      --generar credito en cta. cliente
      IF nvl(v_procesa, 'S') = 'N' THEN
        --no puede procesar
        p_cod_error := 15;
        p_msj_error := pag_cta.G_MSJ_ERROR;
      else

        begin
          v_hora             := fug_obt_mov_hora; /*fug_obt_hor_disponible(v_fecha_actual,
                                                                            v_hora,
                                                                            user,
                                                                            'N');*/
          v_numero_secuencia := v_numero_secuencia;
          PAG_CTA.PR_SET_REFERENCIA(v_referencia);
          pag_cta.pr_set_nro_documento3(p_cod_ente);
          pag_cta.PR_NRO_CAJA(p_nro_caja => null);
          if v_moneda = pag_gen.fu_obt_mon_fuerte then
            v_mto_equ_local := round(v_mto * v_cotizacion, 0);
          end if;
          ----------------------------------------------------------
          v_usuario := fu_obt_mov_user('FIELCOCNB');
          v_hora_c  := fu_obt_hora(v_usuario);
          pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_numero_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_codigo_modulo,
                                   p_cod_mad_padre  => v_codigo_modalidad);
          ------------------------------------------------------------

          pag_cta.pr_act_operacion(v_cuenta,
                                   v_hora_c,
                                   'C',
                                   v_moneda,
                                   v_mto,
                                   8535,
                                   8515,
                                   v_nro_documento,
                                   null,
                                   v_ofi_cta_ahorro, --oficina cuenta
                                   3,
                                   31,
                                   null,
                                   null,
                                   'DEPOSITO-CNB ' || v_cuenta,
                                   'N',
                                   v_numero_secuencia,
                                   v_fecha_actual,
                                   null,
                                   null,
                                   v_mto_equ_local);
          if pag_cta.G_COD_ERROR != 0 then
            p_cod_error := 10;
            p_msj_error := pag_cta.G_MSJ_ERROR;
            rollback to deposito;
          end if;
        end;
        if nvl(p_cod_error, 0) = 0 then
          --obtener tasa personalizada de la cuenta
          begin
            select tas_personalizada
              into v_tas_personal
              from ge_cuentas
             where nro_cuenta = v_cuenta;
          exception
            when no_data_found then
              p_cod_error := 2;
              p_msj_error := 'La cuenta ' || v_cuenta || 'no existe';
          end;
          if v_tas_personal = 'S' then
            begin
              select cod_tasa
                into v_cod_tas_personal
                from ge_tas_fechas
               where nro_cuenta = v_cuenta;
            exception
              when no_data_found then
                p_cod_error := 2;
                p_msj_error := 'La tasa personalizada de la cuenta ' ||
                               v_cuenta || 'no existe';
            end;
          end if;

          begin
            --obtengo el val_tasa
            PAG_GEN.PR_OBT_VAL_TASA(3,
                                    31,
                                    v_ofi_cta_ahorro, --oficina cuenta
                                    v_cuenta,
                                    v_moneda,
                                    v_mto,
                                    v_tas_personal,
                                    v_cod_tas_personal,
                                    8512,
                                    null,
                                    v_val_tas_comision,
                                    v_p_fe_vigencia,
                                    v_tip_valor,
                                    v_tipo,
                                    v_cod_persona);
            if pag_cta.G_COD_ERROR != 0 then
              p_cod_error := 10;
              p_msj_error := pag_cta.G_MSJ_ERROR;
              rollback to deposito;
            end if;
          end;

          v_mto_comis := v_val_tas_comision;
          --generar movimiento de la comision
          --begin
          --obtengo el val_tasa para iva
          PAG_GEN.PR_OBT_VAL_TASA(3,
                                  31,
                                  v_ofi_cta_ahorro, --oficina cta
                                  v_cuenta,
                                  v_moneda,
                                  v_mto,
                                  v_tas_personal,
                                  v_cod_tasa, --v_cod_tasa,
                                  518,
                                  null,
                                  v_val_tasa,
                                  v_p_fe_vigencia,
                                  v_tip_valor,
                                  v_tipo,
                                  v_cod_persona);
          --calcular monto iva
          begin
            v_mto_iva := fu_obt_impuesto(v_mto_comis, p_cod_moneda_bcp);
          exception
            when others then
              v_mto_iva := 0;
          end;
          if v_mto_comis > 0  then
            --Verifica operacion de la cuenta
            pag_cta.PR_VER_OPERACION(v_cuenta,
                                     8512,
                                     3,
                                     31,
                                     'D',
                                     v_moneda,
                                     v_mto_comis + v_mto_iva,
                                     v_ofi_cta_ahorro, --oficina cta
                                     v_cod_mod_persona,
                                     v_cod_mad_persona,
                                     v_est_cuenta,
                                     v_sal_disponible,
                                     v_procesa,
                                     v_cod_transaccion);
            if nvl(v_procesa, 'S') = 'N' then
              --no puede procesar
              p_cod_error := 15;
              p_msj_error := pag_cta.G_MSJ_ERROR;
              rollback to deposito;
            end if;
          end if;
          if nvl(p_cod_error, 0) = 0 then
            if nvl(v_mto_comis, 0) > 0 then
              if v_moneda = pag_gen.fu_obt_mon_fuerte then
                v_mto_equ_local := round(v_mto * v_cotizacion, 0);
              end if;
              pag_cta.pr_set_nro_documento3(p_cod_ente);
              pag_cta.PR_NRO_CAJA(p_nro_caja => null);
              pag_cta.pr_act_operacion(v_cuenta,
                                       v_hora_c,
                                       'D',
                                       v_moneda,
                                       v_mto_comis,
                                       8535,
                                       8512,
                                       v_nro_documento,
                                       null,
                                       v_ofi_cta_ahorro, --oficina cta
                                       3,
                                       31,
                                       v_cod_tas_comision,
                                       v_val_tas_comision,
                                       'COMISION EXT/DEP CNB',
                                       'N',
                                       v_numero_secuencia,
                                       v_fecha_actual,
                                       null,
                                       null,
                                       v_mto_equ_local);
              if pag_cta.G_COD_ERROR != 0 then
                p_cod_error := 10;
                p_msj_error := pag_cta.G_MSJ_ERROR;
                rollback to deposito;
              end if;
            end if;
            -- end;
            --generar movimiento de iva, obtener tasa para la transaccion
            begin
              select t.cod_tasa
                into v_cod_tasa
                from ge_transacciones t
               where t.cod_modulo = 3
                 and t.cod_modalidad = 31
                 and t.cod_transaccion = 518;
            exception
              when no_data_found then
                p_cod_error := 3;
                p_msj_error := 'Codigo de tasa no encontrada';
                rollback to deposito;
            end;
            -- begin
            if nvl(p_cod_error, 0) = 0 then
              if nvl(v_mto_iva, 0) > 0 then
                --generar movimiento de iva
                begin
                  v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
                  r_gmovi.cod_usuario     := v_usuario;
                  r_gmovi.hora            := v_hora_c;
                  r_gmovi.fecha           := v_fecha_actual;
                  r_gmovi.cod_persona     := v_cod_persona;
                  r_gmovi.nro_secuencia   := v_numero_secuencia;
                  r_gmovi.cod_modulo      := v_cod_mod_persona;
                  r_gmovi.cod_modalidad   := v_cod_mad_persona;
                  r_gmovi.cod_oficina     := v_ofi_cta_ahorro; --ofi cliente
                  r_gmovi.cod_moneda      := v_moneda;
                  r_gmovi.fec_valor       := trunc(sysdate);
                  r_gmovi.cod_tra_padre   := 8535;
                  r_gmovi.cod_mod_padre   := 3;
                  r_gmovi.cod_mad_padre   := 31;
                  r_gmovi.cod_transaccion := 518;
                  r_gmovi.monto           := v_mto_iva;
                  r_gmovi.nro_documento   := p_mov_id;
                  r_gmovi.nro_documento3  := p_cod_ente;
                  r_gmovi.referencia      := p_mov_id;
                  r_gmovi.cod_ofi_origen  := v_ofi_usuario; --oficina usuario
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := upper('Credito IVA comision');
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_rubro       := null;
                  r_gmovi.cod_tasa        := v_cod_tasa;
                  r_gmovi.val_tasa        := v_val_tasa;
                  r_gmovi.tip_mov_rubro   := 'C';
                  r_gmovi.nro_caja        := null;
                  r_gmovi.nro_cuenta      := v_cuenta; --null;
                  if v_moneda = pag_gen.fu_obt_mon_fuerte then
                    r_gmovi.cotizacion    := v_cotizacion;
                    r_gmovi.mto_equ_local := round(v_mto_iva * v_cotizacion,
                                                   0);
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                exception
                  when others then
                    p_cod_error := 14;
                    p_msj_error := sqlerrm;
                    rollback to deposito;
                end;
              end if;
              if nvl(p_cod_error, 0) = 0 then
                ------
                if nvl(v_mto_iva, 0) > 0 then
                  if v_moneda = pag_gen.fu_obt_mon_fuerte then
                    v_mto_equ_local := round(v_mto_iva * v_cotizacion, 0);
                  end if;
                  pag_cta.pr_set_nro_documento3(p_cod_ente);
                  pag_cta.PR_NRO_CAJA(p_nro_caja => null);
                  pag_cta.pr_act_operacion(v_cuenta,
                                           v_hora_c,
                                           'D',
                                           v_moneda,
                                           v_mto_iva,
                                           8535,
                                           503,
                                           v_nro_documento,
                                           null,
                                           v_ofi_cta_ahorro, --oficina cta
                                           3,
                                           31,
                                           v_cod_tasa,
                                           v_val_tasa,
                                           'IVA EXT/DEP CNB',
                                           'N',
                                           v_numero_secuencia,
                                           v_fecha_actual,
                                           null,
                                           null,
                                           v_mto_equ_local);
                  if pag_cta.G_COD_ERROR != 0 then
                    p_cod_error := 10;
                    p_msj_error := pag_cta.G_MSJ_ERROR;
                    rollback to deposito;
                  end if;
                end if;
                --end;
                --Verifica operacion de la cuenta
                pag_cta.PR_VER_OPERACION(v_cuenta_cnb,
                                         8513,
                                         4,
                                         43,
                                         'D',
                                         v_moneda,
                                         v_mto,
                                         v_ofi_cta_ahorro, --61,
                                         v_cod_mod_persona,
                                         v_cod_mad_persona,
                                         v_est_cuenta,
                                         v_sal_disponible,
                                         v_procesa,
                                         v_cod_transaccion);
                if nvl(p_cod_error, 0) = 0 then
                  begin
                    --generar, debito cuenta operativa
                    if v_moneda = pag_gen.fu_obt_mon_fuerte then
                      v_mto_equ_local := round(v_mto * v_cotizacion, 0);
                    end if;
                    --v_numero_secuencia := v_numero_secuencia + 1;
                    pag_cta.pr_set_nro_documento3(p_cod_ente);
                    pag_cta.PR_NRO_CAJA(p_nro_caja => null);
          ----------------------------------------------------------
          pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_numero_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_codigo_modulo,
                                   p_cod_mad_padre  => v_codigo_modalidad);
          ------------------------------------------------------------
                    pag_cta.pr_act_operacion(v_cuenta_cnb,
                                             v_hora_c,
                                             'D',
                                             v_moneda,
                                             v_mto,
                                             8535,
                                             8513,
                                             v_nro_documento,
                                             null,
                                             v_ofi_cta_ahorro, --61, --oficina cta
                                             3, --4,
                                             31, --43,
                                             null,
                                             null,
                                             'DEPOSITOS EN CNB ' ||
                                             v_cuenta_cnb,
                                             'N',
                                             v_numero_secuencia,
                                             v_fecha_actual,
                                             null,
                                             null,
                                             v_mto_equ_local);
                    if pag_cta.G_COD_ERROR != 0 then
                      p_cod_error := 10;
                      p_msj_error := pag_cta.G_MSJ_ERROR;
                      rollback to deposito;
                    end if;
                    if nvl(p_cod_error, 0) = 0 then
                      --actualizacion de cod_persona en los movimientos
                      update ge_movimientos t
                         set t.cod_persona = v_cod_persona
                       where t.fecha = v_fecha_actual
                         and t.hora = v_hora_c
                         and t.cod_usuario = v_usuario
                         and t.referencia = v_referencia
                         and t.cod_persona is null;

                      p_cod_error := 0;
                      p_msj_error := 'Se han generado los movimientos';
                    end if;

                  exception
                    when others then
                      p_cod_error := 4;
                      p_msj_error := 'Error el proceso de cobro ' ||
                                     sqlerrm;
                      rollback to deposito;
                  end;
                end if;
              end if; --
            end if;
          end if;
        end if; --
      end if;
      if pag_cta.G_COD_ERROR != 0 or nvl(p_cod_error, 0) != 0 then
        p_cod_error := 5;
        p_msj_error := nvl(p_msj_error, pag_cta.G_MSJ_ERROR);
        rollback to deposito;
      end if;
    else 
         p_cod_error := v_error;
         p_msj_error :=v_respuesta;
    end if;
    end if;
    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Monto: ' || p_monto || ' ' || p_cod_moneda_bcp ||
                     ' Error: Cod. ' || p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_MOV_DEPOSITO',
                            v_det_error,
                            null,
                            p_nro_cuenta);
    end if;
  exception
    when others then
      p_cod_error := 5;
      p_msj_error := sqlerrm;
      v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Monto: ' || p_monto || ' ' || p_cod_moneda_bcp ||
                     ' Error: Cod. ' || p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_MOV_DEPOSITO',
                            v_det_error,
                            null,
                            p_nro_cuenta);
       rollback to deposito;
  end pr_gen_mov_deposito;

  procedure pr_gen_pin_extracciones(p_cod_persona in varchar2,
                                    p_nro_celular in varchar2,
                                    p_pin         out number,
                                    p_respuesta   out varchar2) is

    /*Verifica si el nro.celular corresponde a la persona y genera un numero aleatorio de 4 digitos*/

    v_existe    varchar2(1) := 'N';
    v_det_error ge_log_errores.det_error%type;

  begin

    v_existe := 'N';
    begin
      select 'S'
        into v_existe
        from ba_telefonos t
       where t.cod_persona = p_cod_persona
         and t.tip_linea = 'C'
         and (t.telefono = p_nro_celular OR
             t.area || t.telefono = p_nro_celular)
         and t.tipo = 'P';
    exception
      when NO_DATA_FOUND then
        p_respuesta := 'El numero ' || p_nro_celular ||
                       ' no corresponde a la persona';
        return;
    end;
    if v_existe = 'S' then
      p_pin       := round(dbms_random.value(1000, 9999), 0);
      p_respuesta := 'OK';
    end if;
  exception
    when others then
      p_respuesta := 'NOK- ' || sqlerrm;
      v_det_error := 'Celular : ' || p_nro_celular || ' Error: ' ||
                     p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_PIN_EXTRACCIONES',
                            v_det_error,
                            p_cod_persona,
                            null);
  end pr_gen_pin_extracciones;

  FUNCTION fu_cal_deu_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                               p_cuota      IN pr_cuotas.nro_cuota%TYPE)
    RETURN varchar2 IS
    --Datos de la cabecera.
    v_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE := 360;
    v_nom_titular   BA_PERSONAS.NOM_COMPLETO%TYPE;
    v_can_cuotas    NUMBER(3);
    v_cadena        VARCHAR2(32767);
    -- variables
    v_mto_cobrado        NUMBER(18, 2); -- Mto cobrado (no se despliega)
    v_tot_capital        NUMBER(18, 2); -- Capital (no se despliega )
    v_tot_interes        NUMBER(18, 2); -- Interes (no se despliega )
    v_tot_int_adelantado NUMBER(18, 2); -- Interes adelantado (no despliega)
    v_tot_mora           NUMBER(18, 2); -- Mora s/capital (no despliega)
    v_tot_mora_interes   NUMBER(18, 2); -- Mora s/Interes (DESPLIEGA : Mora s/interes )
    v_tot_mora_int_adel  NUMBER(18, 2); -- Mora interes adelantado (no desp)
    v_tot_impuesto       NUMBER(18, 2); -- Total impuesto (DESPLIEGA : ley 125/91)
    v_tot_cargo          NUMBER(18, 2); -- Total cargo (DESPLIEGA : Cargo + IVA )
    v_tot_cargo_iva      NUMBER(18, 2); -- Total cargo IVA  (no desp)
    v_tot_int_descontado NUMBER(18, 2); -- Total interes descontado (no desp)
    v_tot_a_cobrar       NUMBER(18, 2); -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
    v_tot_punitorio      NUMBER(18, 2); -- Total monto punitorio (DESPLIEGA : Punitorio)
    v_moneda             ba_monedas.cod_moneda%type; --nr
    v_cod_moneda         VARCHAR2(1);
    v_cod_ofi_origen     pr_movimientos_his.cod_ofi_origen%TYPE;
    v_dia_mora           pr_cta_prestamos.dia_atraso%TYPE;
    v_nro_cuenta         pr_cta_prestamos.nro_cuenta%TYPE;
    v_iva_devuelto       NUMBER(18, 2) := 0; -- Iva devuelto
    v_cantidad           NUMBER(3) := 0;
    v_fec_actual         Date;
    v_cod_retorno        VARCHAR2(3) := '000';
    r_ctapre             pr_cta_prestamos%ROWTYPE;
    v_des_retorno        VARCHAR2(30) := 'OK';
    v_cod_error          NUMBER(3) := 0;

    CURSOR cta IS
      SELECT c.nro_cuenta
        FROM ba_personas a, ge_cta_clientes c, pr_cta_prestamos s
       WHERE a.cod_persona = c.cod_persona
         AND c.nro_cuenta = s.nro_cuenta
         AND (c.nro_cuenta = p_nro_cuenta) --OR replace(a.nro_documento,'-','') = p_nro_cuenta)
         AND c.relacion = 'P'
         AND s.estado <> 'N'
         AND nvl(instr(',' || fug_obt_pardinamico('PRE_MOD_NEGADAS') || ',',
                       ',' || s.cod_modalidad || ','),
                 0) = 0;

    --Cursor para recuperar los detalles: la cuota mas vencida de cada cuenta.
    CURSOR cuotas(v_nro_cuenta IN VARCHAR2) IS
      SELECT to_char((c.fec_vencimiento), 'ddmmyyyy') fec_vto,
             c.nro_cuota nro_cuota
        FROM pr_cuotas c
       WHERE c.nro_cuenta = v_nro_cuenta
         and c.nro_cuota = p_cuota
         AND c.nro_cuota > 0
         AND c.estado <> 'N'
       ORDER BY c.nro_cuota;

  BEGIN
    v_fec_actual := pag_cal.fu_obt_fec_actual(3);
    lp_ver_horario;
    v_cod_ofi_origen := fug_obt_ofi_usuario(USER);
    v_can_cuotas     := 0;
    IF v_cod_retorno = pag_ser.v_cod_aprobado THEN

      FOR r IN cta LOOP
        v_cantidad     := v_cantidad + 1;
        v_iva_devuelto := 0;
        v_nro_cuenta   := r.nro_cuenta;
        v_nom_titular  := fue_obt_nom_persona(fug_obt_cli_principal(v_nro_cuenta));
        pap_pre.pr_obt_dat_prestamo(v_nro_cuenta, r_ctapre);
        --
        IF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_local THEN
          v_cod_moneda := '1';
        ELSIF r_ctapre.cod_moneda = pag_gen.fu_obt_mon_fuerte THEN
          v_cod_moneda := '2';
        ELSE
          v_cod_retorno := pag_ser.v_mon_incorrecta;
          v_des_retorno := 'Moneda incorrecta.';
        END IF;
        -- Se verifica si no tiene cobros pendientes de ser aplicados...
        DECLARE
          v_can_pag_pend NUMBER(5) := 0;
        BEGIN
          SELECT COUNT(*)
            INTO v_can_pag_pend
            FROM pr_cobros_noc
           WHERE nro_cuenta = v_nro_cuenta
             AND estado = 'I';
          IF v_can_pag_pend > 0 THEN
            v_cod_retorno := pag_ser.v_cuo_cancelada;
            v_des_retorno := 'Cuota ya pagada';
          END IF;
        END;
        --Moneda de la cuenta es la misma que eligio el usuario.
        IF v_cod_retorno = pag_ser.v_cod_aprobado THEN
          FOR d IN cuotas(v_nro_cuenta) LOOP
            v_can_cuotas := nvl(v_can_cuotas, 0) + 1;

            pap_pre.pr_ini_autorizacion;
            pap_pre.pr_obt_deu_prestamo(v_nro_cuenta,
                                        v_fec_actual,
                                        p_cuota,
                                        p_cuota,
                                        v_cod_ofi_origen,
                                        v_mto_cobrado,
                                        v_cod_error,
                                        v_des_retorno,
                                        v_tot_capital,
                                        v_tot_interes,
                                        v_tot_int_adelantado,
                                        v_tot_mora,
                                        v_tot_mora_interes,
                                        v_tot_mora_int_adel,
                                        v_tot_punitorio,
                                        v_tot_impuesto,
                                        v_tot_cargo,
                                        v_tot_cargo_iva,
                                        v_tot_int_descontado,
                                        v_dia_mora,
                                        v_cod_tra_padre,
                                        'N'); --- cancela

            IF v_cod_error <> 0 THEN
              v_cod_retorno := pag_ser.v_err_proceso;
              v_des_retorno := 'Error en la cuenta de prestamo';
            ELSE
              v_tot_mora     := nvl(v_tot_mora, 0) +
                                nvl(v_tot_mora_int_adel, 0) +
                                nvl(v_tot_mora_interes, 0);
              v_tot_cargo    := nvl(v_tot_cargo, 0);
              v_tot_a_cobrar := nvl(v_tot_capital, 0) +
                                nvl(v_tot_interes, 0) + nvl(v_tot_mora, 0) +
                                nvl(v_tot_impuesto, 0) +
                                nvl(v_tot_int_adelantado, 0) +
                                nvl(v_tot_cargo, 0) +
                                nvl(v_tot_punitorio, 0);
              v_cadena       := to_char(v_nro_cuenta) || ';' ||
                                to_char(p_cuota) || ';' || d.fec_vto || ';' ||
                                v_tot_a_cobrar;
            END IF;
          END LOOP;
        END IF;
        EXIT WHEN v_cantidad = 10;
      END LOOP;
      IF v_nro_cuenta IS NULL THEN
        --No encontro la cuenta, emite mensaje de error.
        v_cod_retorno := pag_ser.v_cta_incorrecta;
        v_des_retorno := 'Cuenta o doc. inexistente';
      END IF;
    ELSE
      v_cadena := rpad(v_cod_retorno, 3, ' ') ||
                  rpad(v_des_retorno, 30, ' ') ||
                  rpad(v_nom_titular, 60, ' ') ||
                  lpad(to_char(v_can_cuotas), 3, '0');
    END IF;
    IF v_cod_retorno != pag_ser.v_cod_aprobado then
      v_cadena := rpad(v_cod_retorno, 3, ' ') ||
                  rpad(v_des_retorno, 30, ' ');

    END IF;

    commit;
    RETURN v_cadena;
  END fu_cal_deu_prestamo;

  procedure pr_obt_saldo_cuenta(p_cod_ente       in ge_entes.cod_ente%type,
                                p_cod_moneda_bcp in ba_monedas.cod_mon_bco_central%type,
                                p_sal_disponible out ah_cta_vistas.sal_total%type,
                                p_cod_error      out number,
                                p_msj_error      out varchar2) is

    v_nro_cuenta ge_cuentas.nro_cuenta%type;
    v_cod_moneda ba_monedas.cod_moneda%type;
    v_parametro  ge_par_entes.parametro%type;
    v_cod_mon_local  ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_det_error      ge_log_errores.det_error%type;

  begin

    if p_cod_ente is null then
      p_cod_error := 1;
      p_msj_error := 'Codigo de Ente no puede ser nulo.';
    elsif p_cod_moneda_bcp is null then
      p_cod_error := 1;
      p_msj_error := 'Moneda no puede ser nula,';
    else
      v_cod_moneda := it.fue_obt_mon_bcp(p_cod_moneda_bcp);
      if v_cod_moneda = v_cod_mon_local then
        v_parametro := 'CTA_AH_CNB_GS';
      else
        v_parametro := 'CTA_AH_CNB_USD';
      end if;
      --recuperar la cuenta de ahorro del ente
      v_nro_cuenta := fug_obt_parentes(p_cod_ente, v_parametro);
      if v_nro_cuenta is not null then
        pag_cta.pr_obt_cuenta(v_nro_cuenta);
        if pag_cta.fu_obt_cod_error() <> 0 then
          p_cod_error := pag_cta.g_cod_error;
          p_msj_error := 'Cta.' || v_nro_cuenta || '-' ||
                         pag_cta.g_msj_error;
        end if;
        if nvl(p_cod_error, 0) = 0 then
          /* calcular saldo dispobible */
          p_sal_disponible := nvl(pag_cta.g_ctas.sal_disponible, 0);
        end if;
      else
        p_cod_error := 2;
        p_msj_error := 'Ente no tiene cuenta de ahorro asociada.';
      end if;
    end if;
    if nvl(p_cod_error,0) != 0 then
      v_det_error := 'Ente : ' || p_cod_ente || 'Mov ID: ' ||
                     ' Moneda: ' || p_cod_moneda_bcp ||
                     ' Error: Cod ' ||p_cod_error||' - '||p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_SALDO_CUENTA',
                            v_det_error,
                            null,
                            null);
    end if;
  exception
    when others then
      p_cod_error:=3;
      p_msj_error := sqlerrm;
      v_det_error := 'Ente : ' || p_cod_ente || 'Mov ID: ' ||
                     ' Moneda: ' || p_cod_moneda_bcp ||
                     ' Error: Cod ' ||p_cod_error||' - '||p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_SALDO_CUENTA',
                            v_det_error,
                            null,
                            null);
  end;

  procedure pr_gen_extraccion(p_cod_ente    in number,
                              p_cod_persona in varchar2,
                              p_mon_bcp     in number,
                              p_monto       in number,
                              p_nro_cuenta  in varchar2,
                              p_mov_id      in varchar2,
                              p_error       out number,
                              p_respuesta   out varchar2) is

    /*Proceso de generacion de operaciones de extracciones por fielcorresponsal*/
    v_cod_ente_vision   ge_entes.cod_ente%type;
    v_cod_tra_padre     ge_transacciones.cod_transaccion%type := 8536;
    v_cod_transaccion   ge_transacciones.cod_transaccion%type;
    v_est_cuenta        ge_cuentas.estado%type;
    v_sal_disponible    ge_movimientos.monto%type;
    v_procesa           varchar2(1) := 'N';
    v_cod_modulo        ge_movimientos.cod_modulo%type := NULL;
    v_cod_modalidad     ge_movimientos.cod_modalidad%type := NULL;
    v_cod_moneda        ba_monedas.cod_moneda%type;
    v_hor_actual        VARCHAR2(08);-- := to_char(SYSDATE, 'HH24:MI:SS');
    v_fec_actual        DATE := pag_cal.fu_obt_fec_actual(5);
    v_nro_secuencia     ge_movimientos.nro_secuencia%type := 0;
    v_cta_cre_ente      ge_par_entes.val_parametro%type;
    v_par_ente          ge_par_entes.val_parametro%type;
    v_cod_ofi_ente      ge_cta_clientes.cod_oficina%type;
    v_cod_mod_ente      ge_cta_clientes.cod_modulo%type;
    v_cod_mad_ente      ge_cta_clientes.cod_modalidad%type;
    v_cod_ofi_persona   ge_cta_clientes.cod_oficina%type;
    v_cod_mod_persona   ge_cta_clientes.cod_modulo%type;
    v_cod_mad_persona   ge_cta_clientes.cod_modalidad%type;
    v_cod_mon_cta       ba_monedas.cod_moneda%type;
    v_cod_tas_iva       ge_tasas.cod_tasa%TYPE := NULL;
    v_cod_tasa          ge_tasas.cod_tasa%TYPE := 516;
    v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
    v_val_tas_iva       ge_tas_fechas.val_tasa%TYPE;
    v_fec_vigencia      ge_tas_fechas.fec_vigencia%TYPE;
    v_tip_valor         ge_tasas.tip_valor%TYPE;
    v_tipo              ge_tasas.tipo%TYPE;
    v_par_tasa          ge_par_entes.val_parametro%type;
    v_tra_comsion       ge_transacciones.cod_transaccion%type;
    v_redondeo          NUMBER(1);
    v_cargo_iva         ge_movimientos.monto%type;
    r_gmovi             ge_movimientos%ROWTYPE;
    v_tas_personalizada varchar2(1) := 'N';
    v_det_error         ge_log_errores.det_error%type;
    V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
    V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
    V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
    V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
    V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
    V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
    V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
    v_cod_ofi_origen    ge_movimientos.cod_ofi_origen%type;
    v_cotizacion        ge_movimientos.cotizacion%type:=null;
    v_mto_equ_local     ge_movimientos.mto_equ_local%type;
    v_usuario             varchar2(15);
    v_hora_c              ge_movimientos.hora%TYPE;
    v_numero_secuencia    NUMBER(3) := 0;
    v_codigo_modulo       NUMBER(3) := 4;
    v_codigo_modalidad    NUMBER(3) := 43;
    v_mto_tot_wp          NUMBER(18);
    v_mto_lim_wp          NUMBER(18);
    v_horario             varchar2(1);
    v_es_mov_noc          varchar2(1);
    v_es_cta_noc          varchar2(1);
    v_fec_valor           ge_calendarios.fec_actual%type;
    v_error               number;
    v_respuesta           varchar(4000);
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    savepoint extraccion; --UCTAS-1151
    /*Validaciones*/
    if nvl(p_cod_ente, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Debe ingresar ente ';
      return;
    end if;
    if nvl(p_monto, 0) = 0 then
      p_error     := 2;
      p_respuesta := 'Debe ingresar el monto de la operacion ';
      return;
    end if;
    if nvl(p_mon_bcp, 0) = 0 then
      p_error     := 3;
      p_respuesta := 'Debe ingresar la moneda ';
      return;
    end if;
    if nvl(p_mov_id, 'x') = 'x' then
      p_error     := 4;
      p_respuesta := 'Debe ingresar el Id de la operacion ';
      return;
    end if;
    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_error     := 5;
      p_respuesta := 'Debe ingresar la cuenta ';
      return;
    end if;
    v_cod_ofi_origen  := fug_obt_ofi_usuario(USER);
    v_cod_transaccion := 8514; --Transaccion para extraccion
    v_tra_comsion     := 8512; --Transaccion para comision de extraccion
    v_cod_moneda      := fue_obt_mon_bcp(p_mon_bcp);
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    v_cod_ofi_persona := pag_cta.G_CTAS.cod_oficina;
    v_cod_mod_persona := pag_cta.G_CTAS.cod_modulo;
    v_cod_mad_persona := pag_cta.G_CTAS.cod_modalidad;
    v_cod_mon_cta     := pag_cta.G_CTAS.cod_moneda;
    /*La moneda de la extraccion debe ser igual a la moneda de la cuenta*/
    if v_cod_mon_cta != v_cod_moneda then
      p_error     := 6;
      p_respuesta := 'La moneda de la operacion no corresponde a la moneda de la cuenta';
      return;
    end if;
    if fu_es_conjunta(p_nro_cuenta) = 'S' then
      p_error     := 7;
      p_respuesta := 'La cuenta es conjunta ';
      return;
    end if;
    /*Recupera los datos del ente*/
    if v_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
      v_par_ente := 'CTA_OP_CNB_GS';
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        3,
                                        NULL,
                                        pag_gen.fu_obt_mon_local);
    elsif v_cod_moneda = pag_gen.FU_OBT_MON_FUERTE then
      v_cotizacion := fug_obt_cotizacion(v_cod_moneda,v_fec_actual);
      v_par_ente   := 'CTA_OP_CNB_USD';
      v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                        3,
                                        NULL,
                                        pag_gen.FU_OBT_MON_FUERTE);
    else
      p_error     := 7;
      p_respuesta := 'Moneda ' || v_cod_moneda || ' no corresponde ';
      return;
    end if;
        -- Si el ente recibido como parametro corresponde a WEPA (RED DIFGITAL S.A)
    If p_cod_ente = nvl( fug_obt_pardinamico('COD_ENT_WEPA'), 9733 ) then
      --Obtenemos el ente de wepa donde la cta operativa configurada es la cta de vision
      v_cod_ente_vision := fug_obt_pardinamico('COD_ENT_WEPA_VISION');
      -- Obtenemos la cuenta
      v_cta_cre_ente      := fug_obt_parentes(v_cod_ente_vision, v_par_ente);
    Else
    v_cta_cre_ente := fug_obt_parentes(p_cod_ente, v_par_ente);
    End if;

    if v_cta_cre_ente is null then
      p_error     := 8;
      p_respuesta := 'La cuenta en la moneda ' || v_cod_moneda ||
                     ' del ente ' || p_cod_ente ||
                     ' no se encuentra configurada';
      return;
    end if;
                    
    it.paa_dex.pr_val_sal_mov_cliente_wp( p_nro_cuenta,--cuenta
                                          p_monto,   --monto operacion
                                          v_cod_moneda,--moneda
                                          'E',     -- D=Deposito / E=Extraccion
                                          v_mto_tot_wp,--Total GS(monto operacion+monto movimiento)
                                          v_mto_lim_wp, --Mto limite establecido en parametro gral
                                          p_error,
                                          p_respuesta);
  if nvl(p_error,0) = 0 then --- para control de movimientos diarios
    --Verifica estado del modulo
       lp_ver_hor_cnb(v_cod_ofi_origen,
                     '3',
                     v_horario,
                     v_es_mov_noc,
                     v_es_cta_noc,
                     v_fec_actual,
                     v_fec_valor,
                     v_error,
                     v_respuesta);
    if nvl(v_error, 0) = 0 then
    pag_cta.PR_OBT_CUENTA(v_cta_cre_ente);
    if pag_cta.G_COD_ERROR = 0 then
      v_cod_ofi_ente := pag_cta.G_CTAS.cod_oficina;
      v_cod_mod_ente := pag_cta.G_CTAS.cod_modulo;
      v_cod_mad_ente := pag_cta.G_CTAS.cod_modalidad;
    else
      p_error     := 9;
      p_respuesta := pag_cta.G_MSJ_ERROR;
      return;
    end if;

    /*Verifica operacion de la cuenta*/
    pag_cta.PR_VER_OPERACION(p_nro_cuenta,
                             v_cod_tra_padre,
                             3,
                             31,
                             'D',
                             v_cod_moneda,
                             p_monto,
                             v_cod_ofi_origen,
                             v_cod_mod_persona,
                             v_cod_mad_persona,
                             v_est_cuenta,
                             v_sal_disponible,
                             v_procesa,
                             v_cod_transaccion);
   
   if v_procesa = 'S' then
     /* if pae_cnf.fu_obt_est_modulo(3) != 2 then --UCTAS-1151
        -- periodo de cierre, no debe poder procesar operacion
        p_error     := 99;
        p_respuesta := 'Modulo Cerrado. No se puede operar';
      else*/
        begin
          select tas_personalizada
            into v_tas_personalizada
            from ge_cuentas
           where nro_cuenta = p_nro_cuenta;
        exception
          when no_data_found then
            p_error     := 10;
            p_respuesta := 'La cuenta ' || p_nro_cuenta || 'no existe';
            return;
        end;

        /*Obtiene valor del cargo*/
        pag_gen.pr_obt_val_tasa(v_cod_mod_persona,
                                v_cod_mad_persona,
                                NULL,
                                p_nro_cuenta,
                                v_cod_moneda,
                                NULL,
                                v_tas_personalizada,
                                v_cod_tasa,
                                v_tra_comsion,
                                NULL,
                                v_val_tasa,
                                v_fec_vigencia,
                                v_tip_valor,
                                v_tipo);
        /*iva*/
        v_cod_tas_iva := 323;
        pag_gen.pr_obt_val_tasa(v_cod_mod_persona,
                                v_cod_mad_persona,
                                NULL,
                                NULL,
                                v_cod_moneda,
                                NULL,
                                NULL,
                                v_cod_tas_iva,
                                NULL,
                                NULL,
                                v_val_tas_iva,
                                v_fec_vigencia,
                                v_tip_valor,
                                v_tipo);

        v_cargo_iva := round((v_val_tasa * v_val_tas_iva / 100), v_redondeo);

        if pae_cnf.fu_obt_est_modulo(3) != 2 then
          p_error     := 11;
          p_respuesta := 'En proceso de cierre';
          return;
        end if;

        begin
          --savepoint extraccion; --UCTAS-1151

          v_hor_actual := fug_obt_mov_hora;/*fug_obt_hor_disponible(v_fec_actual,
                                                 v_hor_actual,
                                                 user,
                                                 'N');*/

          /*Debito al cliente*/
          pag_cta.pr_set_referencia(p_mov_id);
          pag_cta.pr_set_nro_documento3(p_cod_ente);
          pag_cta.PR_NRO_CAJA(p_nro_caja => null);
          if v_cod_moneda = pag_gen.fu_obt_mon_fuerte then
            v_mto_equ_local := round(p_monto * v_cotizacion,0);
          end if;

           v_usuario := fu_obt_mov_user('FIELCOCNB');
           v_hora_c  := fu_obt_hora(v_usuario);

           pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => 61,
                                 p_cod_mod_padre => v_codigo_modulo,
                                 p_cod_mad_padre => v_codigo_modalidad);


          pag_cta.PR_ACT_OPERACION(p_nro_cuenta,
                                   v_hora_c,
                                   'D',
                                   v_cod_moneda,
                                   p_monto,
                                   v_cod_tra_padre,
                                   v_cod_transaccion,
                                   p_mov_id,
                                   v_cotizacion,
                                   v_cod_ofi_origen,
                                   v_cod_mod_ente,
                                   v_cod_mad_ente,
                                   null,
                                   null,
                                   'Extraccion por CNB',
                                   'N',
                                   v_numero_secuencia,
                                   v_fec_actual,
                                   null,
                                   null,
                                   v_mto_equ_local);
          if pag_cta.G_COD_ERROR != 00 then
            p_error     := 12;
            p_respuesta := pag_cta.G_MSJ_ERROR;
            rollback to extraccion;
          else
            /*Credito a la cuenta CNB*/

            pag_cta.pr_set_referencia(p_mov_id);
            pag_cta.pr_set_nro_documento3(p_cod_ente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            if v_cod_moneda = pag_gen.fu_obt_mon_fuerte then
              v_mto_equ_local := round(p_monto * v_cotizacion,0);
            end if;

            pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                     p_fec_valor => trunc(sysdate),
                                     p_cod_tra_padre => v_cod_tra_padre,
                                     p_estado => 'N',
                                     p_reversado => 'N',
                                     p_nro_secuencia => v_numero_secuencia,
                                     p_est_cuenta => null,
                                     p_cod_ofi_origen => 61,
                                     p_cod_mod_padre => v_codigo_modulo,
                                     p_cod_mad_padre => v_codigo_modalidad);

            pag_cta.pr_act_operacion(v_cta_cre_ente,
                                     v_hora_c,
                                     'C', --credito
                                     v_cod_moneda,
                                     p_monto,
                                     v_cod_tra_padre,
                                     8505, --debito CNB
                                     p_mov_id,
                                     v_cotizacion, -- cotizacion
                                     v_cod_ofi_origen,
                                     v_cod_mod_ente,
                                     v_cod_mad_ente,
                                     null, -- tasa
                                     null, -- valor de tasa
                                     'Extraccion CNB', --concepto
                                     'N', -- emitir aviso
                                     v_numero_secuencia, -- nro de secuencia
                                     v_fec_actual,
                                     null,
                                     null,
                                     v_mto_equ_local);
            if pag_cta.G_COD_ERROR != 00 then
              p_error     := 12;
              p_respuesta := pag_cta.G_MSJ_ERROR;
              rollback to extraccion;
            else
              if nvl(v_val_tasa,0) > 0 then
                pag_cta.pr_set_referencia(p_mov_id);
                pag_cta.pr_set_nro_documento3(p_cod_ente);
                if v_cod_moneda = pag_gen.fu_obt_mon_fuerte then
                   v_mto_equ_local := round(v_val_tasa * v_cotizacion,0);
                end if;
                pag_cta.pr_act_operacion(p_nro_cuenta,
                                       v_hora_c,
                                       'D',
                                       v_cod_moneda,
                                       v_val_tasa,
                                       v_cod_tra_padre,
                                       v_tra_comsion, --debito comision extraccion CNB
                                       p_mov_id,
                                       v_cotizacion, -- cotizacion
                                       v_cod_ofi_origen,
                                       v_cod_mod_ente,
                                       v_cod_mad_ente,
                                       v_cod_tasa, -- tasa
                                       v_val_tasa, -- valor de tasa
                                       'Comision Extraccion CNB', --concepto
                                       'N', -- emitir aviso
                                       v_numero_secuencia, -- nro de secuencia
                                       v_fec_actual,
                                       null,
                                       null,
                                       v_mto_equ_local);
              end if;
            end if;
            if pag_cta.g_cod_error = 00 then
              if nvl(v_cargo_iva,0) > 0 then
                --- inserta cargo por la transaccion correspondiente al iva
                -- Aumento la secuencia
                begin
                  v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
                  r_gmovi.cod_usuario     := v_usuario;
                  r_gmovi.hora            := v_hora_c;
                  r_gmovi.fecha           := v_fec_actual;
                  r_gmovi.cod_persona     := p_cod_persona;
                  r_gmovi.nro_secuencia   := v_numero_secuencia;
                  r_gmovi.cod_modulo      := v_cod_mod_persona;
                  r_gmovi.cod_modalidad   := v_cod_mad_persona;
                  r_gmovi.cod_oficina     := v_cod_ofi_persona;
                  r_gmovi.cod_moneda      := v_cod_moneda;
                  r_gmovi.fec_valor       := v_fec_actual;
                  r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                  r_gmovi.cod_mod_padre   := v_cod_mod_ente;
                  r_gmovi.cod_mad_padre   := v_cod_mad_ente;
                  r_gmovi.cod_transaccion := 518;
                  r_gmovi.monto           := v_cargo_iva;
                  r_gmovi.nro_documento   := p_mov_id;
                  r_gmovi.nro_documento3  := p_cod_ente;
                  r_gmovi.referencia      := p_mov_id;
                  r_gmovi.cod_ofi_origen  := v_cod_ofi_origen; --oficina usuario
                  r_gmovi.emi_aviso       := 'N';
                  r_gmovi.concepto        := 'Debito iva comision';
                  r_gmovi.estado          := 'N';
                  r_gmovi.reversado       := 'N';
                  r_gmovi.cod_rubro       := null;
                  r_gmovi.cod_tasa        := v_cod_tas_iva;
                  r_gmovi.val_tasa        := v_val_tas_iva;
                  r_gmovi.tip_mov_rubro   := 'D';
                  r_gmovi.nro_caja        := null;
                  r_gmovi.nro_cuenta      := null;
                  if v_cod_moneda = pag_gen.fu_obt_mon_fuerte then
                    r_gmovi.mto_equ_local    := round(v_cargo_iva * v_cotizacion, 0);
                    r_gmovi.cotizacion       := v_cotizacion;
                  else
                    r_gmovi.mto_equ_local    := null;
                    r_gmovi.cotizacion       := null;
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi);
                exception
                  when others then
                    p_error     := 14;
                    p_respuesta := sqlerrm;
                    rollback to extraccion;
                end;
              end if;
            else
              p_error     := 15;
              p_respuesta := pag_cta.g_msj_error;
              rollback to extraccion;
            end if;
            if pag_cta.G_COD_ERROR != 00 then
              p_error     := 12;
              p_respuesta := pag_cta.G_MSJ_ERROR;
              rollback to extraccion;
            else
              if nvl(v_cargo_iva,0) > 0 then
                pag_cta.pr_set_referencia(p_mov_id);
                pag_cta.pr_set_nro_documento3(p_cod_ente);
                pag_cta.PR_NRO_CAJA(p_nro_caja => null);
                if v_cod_moneda = pag_gen.fu_obt_mon_fuerte then
                  v_mto_equ_local := round(v_cargo_iva * v_cotizacion,0);
                end if;
                pag_cta.pr_act_operacion(p_nro_cuenta,
                                         v_hora_c,
                                         'D',
                                         v_cod_moneda,
                                         v_cargo_iva,
                                         v_cod_tra_padre,
                                         503,
                                         p_mov_id,
                                         v_cotizacion,
                                         v_cod_ofi_origen, --oficina cta
                                         3,
                                         31,
                                         v_cod_tasa,
                                         v_val_tasa,
                                         'IVA EXT/DEP CNB',
                                         'N',
                                         v_numero_secuencia,
                                         v_fec_actual,
                                         null,
                                         null,
                                         v_mto_equ_local);
                if pag_cta.G_COD_ERROR != 0 then
                  p_respuesta := 13;
                  p_respuesta := pag_cta.G_MSJ_ERROR;
                  rollback to extraccion;
                end if;
              end if;
            end if;


          end if;
        exception
          when others then
            p_error     := 16;
            p_respuesta := sqlerrm;
            rollback to extraccion;
        end;
    --  end if; --UCTAS-1151
    else
      p_error     := 17;
      p_respuesta := pag_cta.G_MSJ_ERROR;
    end if;
  else 
         p_error := v_error;
         p_respuesta :=v_respuesta;
  end if;
  end if;
    if nvl(p_error, 0) = 0 then
      p_error     := 0;
      p_respuesta := 'OK';
    else
      v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Monto: ' || p_monto || ' ' || p_mon_bcp ||
                     ' Error: Cod. ' || p_error || '-' || p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_EXTRACCIONES',
                            v_det_error,
                            p_cod_persona,
                            p_nro_cuenta);
      rollback to extraccion;                      
    end if;

  exception
    when others then
      p_error     := 18;
      p_respuesta := 'NOK - ' || SQLERRM;
      v_det_error := 'Ente: ' || p_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Monto: ' || p_monto || ' ' || p_mon_bcp ||
                     ' Error: Cod. ' || p_error || '-' || p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_EXTRACCIONES',
                            v_det_error,
                            p_cod_persona,
                            p_nro_cuenta);
             rollback to extraccion;
  end pr_gen_extraccion;
  ---------------------------------------------------------------------------------------------
/*DA-1962  - Registro de datos de APN*/
/*nrecalde - Junio2021*/
procedure pr_ins_dat_apn(p_cod_mtcn             in varchar2,
                         p_referencia           in number,
                         p_fec_operacion        in date,
                         p_est_notificado       in varchar2,
                         p_fec_notificado       in date,
                         p_cod_err_not          in varchar2,
                         p_sub_cod_err_not      in varchar2,
                         p_desc_err_not         in varchar2,
                         p_est_transf           in varchar2,
                         p_cod_err_ope          in number,
                         p_nom_solicitante      in varchar2,
                         p_ape_solicitante      in varchar2,
                         p_pri_nom_beneficiario in varchar2,
                         p_ape_beneficiario     in varchar2,
                         p_ciu_beneficiario     in varchar2,
                         p_est_beneficiario     in varchar2,
                         p_doc_beneficiario     in varchar2,
                         p_cta_beneficiario     in varchar2,
                         p_mto_transf           in number,
                         p_cod_moneda           in varchar2,
                         p_cod_mot_transf       in varchar2,
                         p_swf_bco_destino      in varchar2,
                         p_des_mot_tranf        in varchar2,
                         p_msgid                in varchar2,
                         p_pai_sol              in varchar2,
                         p_cod_err              out number,
                         p_msj_error            out varchar2) is
  v_det_error      ge_log_errores.det_error%type;

begin
  begin
    insert into ge_apn_datos
      (cod_mtcn,
       referencia,
       fec_operacion,
       est_notificado,
       fec_notificado,
       cod_err_not,
       sub_cod_err_not,
       desc_err_not,
       est_transf,
       cod_err_ope,
       nom_solicitante,
       ape_solicitante,
       pri_nom_beneficiario,
       ape_beneficiario,
       ciu_beneficiario,
       est_beneficiario,
       doc_beneficiario,
       cta_beneficiario,
       mto_transf,
       cod_moneda,
       cod_mot_transf,
       swf_bco_destino,
       des_mot_tranf,
       msgid,
       cod_pais_iso)
    values
      (p_cod_mtcn,
       p_referencia,
       p_fec_operacion,
       p_est_notificado,
       p_fec_notificado,
       p_cod_err_not,
       p_sub_cod_err_not,
       p_desc_err_not,
       p_est_transf,
       p_cod_err_ope,
       p_nom_solicitante,
       p_ape_solicitante,
       p_pri_nom_beneficiario,
       p_ape_beneficiario,
       p_ciu_beneficiario,
       p_est_beneficiario,
       p_doc_beneficiario,
       p_cta_beneficiario,
       p_mto_transf,
       p_cod_moneda,
       p_cod_mot_transf,
       p_swf_bco_destino,
       p_des_mot_tranf,
       p_msgid,
       p_pai_sol);
    p_cod_err   := 0;
    p_msj_error := 'Ejecucion Exitosa';
  exception
    when others then
      p_cod_err   := 1;
      p_msj_error := 'Error al insertar el registro' || sqlerrm;
  end;

  if nvl(p_cod_err, 0) = 0 then
    p_cod_err   := 0;
    p_msj_error := 'Actualizacion exitosa';
  else
    v_det_error :=   'Monto Transf.' || p_mto_transf || 'Cod.Moneda' || p_cod_moneda ||
                     'Motivo transf.'|| p_cod_moneda || 'Mot.Transf' || p_swf_bco_destino||
                     'Nombre Benef. '|| p_pri_nom_beneficiario || 'Apellido Benef.' || p_ape_beneficiario ||
                     'Ciudad Benef.' || p_ciu_beneficiario || 'Estado Benef.' || p_est_beneficiario ||
                     'Doc. Benef'    || p_doc_beneficiario || 'Cuenta Benef.' || p_cta_beneficiario ||
                     ' Error: ' || sqlerrm;
    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_INS_DAT_APN',
                          v_det_error,
                          null,
                          null);
  end if;
exception
  when others then
    p_cod_err   := 6;
    v_det_error :=  'Monto Transf.' || p_mto_transf || 'Cod.Moneda' || p_cod_moneda ||
                     'Motivo transf.'|| p_cod_moneda || 'Mot.Transf' || p_swf_bco_destino||
                     'Nombre Benef. '|| p_pri_nom_beneficiario || 'Apellido Benef.' || p_ape_beneficiario ||
                     'Ciudad Benef.' || p_ciu_beneficiario || 'Estado Benef.' || p_est_beneficiario ||
                     'Doc. Benef'    || p_doc_beneficiario || 'Cuenta Benef.' || p_cta_beneficiario ||
                     ' Error: ' || sqlerrm;
    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_INS_DAT_APN',
                          v_det_error,
                          null,
                          null);

end pr_ins_dat_apn;
  ---------------------------------------------------------------------------------------------------
  /*DA-1962 / DA-2216 - Actualizacion de datos de APN para notificacion a WU*/
  /* Julio2021*/
  procedure pr_act_dat_apn(p_mtcn           in varchar2,
                         p_referencia     in varchar2,
                         p_cod_err_ope    in number, --workflow 1000
                         p_est_transf     in varchar2, --estado de la transferencia ge_snp_transferencia
                         p_est_notificado in varchar2, -- Notificado
                         p_cod_err_not    in varchar2, -- respuesta del servicio ej 200 entonces update Confriamdp
                         p_sub_cod_error  in varchar2, --0000
                         p_desc_error     in varchar2, -- OK
                         p_cod_err        out number,
                         p_msj_error      out varchar2) is
  v_existe_reg     varchar2(1);
  v_est_notificado ge_apn_datos.est_notificado%type;
  v_est_tra        ge_apn_datos.est_transf%type;
  v_err_ope        ge_apn_datos.cod_err_ope%type;
  v_fec_notificado ge_apn_datos.fec_notificado%type;
  v_det_error      ge_log_errores.det_error%type;

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  begin
    --buscamos que exista el registro para la actualizacion--
    select 'S', s.est_transf, s.cod_err_ope
      into v_existe_reg, v_est_tra, v_err_ope
      from it.ge_apn_datos s
     where s.cod_mtcn = p_mtcn
       and s.referencia = p_referencia;
  exception
    when others then
      v_existe_reg := 'N';
  end;
  if v_existe_reg = 'S' then
    if p_cod_err_not is not null then
      --respuesta del servicio de WU--
        v_est_notificado := 'C';
        v_fec_notificado := sysdate;
      begin
        update it.ge_apn_datos s
           set s.est_notificado  = v_est_notificado,
               s.fec_notificado  = v_fec_notificado,
               s.cod_err_not     = p_cod_err_not,
               s.sub_cod_err_not = p_sub_cod_error,
               s.desc_err_not    = p_desc_error
         where s.cod_mtcn = p_mtcn
           and s.referencia = p_referencia;
        if sql%rowcount = 0 then
          p_cod_err   := 1;
          p_msj_error := 'No actualizo el Estado a Confirmado de ge_dat_apn Mtcn ' ||
                         p_mtcn;
        end if;
      exception
        when others then
          p_cod_err   := 2;
          p_msj_error := 'No actualizo Mtcn ' || p_mtcn || ' - ' || sqlerrm;
      end;

    else
      if nvl(v_est_tra, 'x') != nvl(p_est_transf, 'x') then
        begin
          update it.ge_apn_datos s
             set s.est_notificado  = 'N',
                 s.est_transf      = p_est_transf,
                 s.cod_err_ope     = p_cod_err_ope,
                 s.fec_notificado  = null,
                 s.cod_err_not     = null,
                 s.sub_cod_err_not = null,
                 s.desc_err_not    = null
           where s.cod_mtcn = p_mtcn
             and s.referencia = p_referencia;
          if sql%rowcount = 0 then
            p_cod_err   := 3;
            p_msj_error := 'No actualizo el Estado a Notificar de ge_dat_apn Mtcn ' ||
                           p_mtcn;
          end if;
        exception
          when others then
            p_cod_err   := 4;
            p_msj_error := 'No actualizo Mtcn ' || p_mtcn || ' - ' ||
                           sqlerrm;
        end;
      end if;
    end if;
  else
    p_cod_err   := 5;
    p_msj_error := 'No existe registro en ge_dat_apn Mtcn ' || p_mtcn;
  end if;
  if nvl(p_cod_err, 0) = 0 then
    p_cod_err   := 0;
    p_msj_error := 'Actualizacion exitosa';
  else
    v_det_error := 'MTCN: ' || p_mtcn || ' Est.Tranf: ' || p_est_transf ||
                   ' Cod.Error ope: ' || p_cod_err_ope || ' Est.Not: ' ||
                   p_est_notificado || ' Error not: ' || p_cod_err_not ||
                   'Sub err not' || p_sub_cod_error || ' Desc.error ' ||
                   p_desc_error || ' Error : ' || p_cod_err || ' - ' ||
                   sqlerrm;
    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_ACT_DAT_APN',
                          v_det_error,
                          null,
                          null);
  end if;
exception
  when others then
    p_cod_err   := 6;
    v_det_error := 'MTCN: ' || p_mtcn || ' Est.Tranf: ' || p_est_transf ||
                   ' Cod.Error ope: ' || p_cod_err_ope || ' Est.Not: ' ||
                   p_est_notificado || ' Error not: ' || p_cod_err_not ||
                   'Sub err not' || p_sub_cod_error || ' Desc.error ' ||
                   p_desc_error || ' Error : ' || p_cod_err || ' - ' ||
                   sqlerrm;
    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_ACT_DAT_APN',
                          v_det_error,
                          null,
                          null);

end pr_act_dat_apn;

---------------------------------------------------------------------------------------------------
function fu_ver_mov_es_tra_apn(p_mtcn              in varchar2,
                               p_referencia        in varchar2,
                               p_tip_transferencia in varchar2)
  return varchar2 is
  --Tip_transferencia SIPAP o FIELCO
  v_es_apn    varchar2(1);
  v_det_error ge_log_errores.det_error%type;

begin
  if p_tip_transferencia = 'FIELCO' then
    begin
      select 'S'
        into v_es_apn
        from ge_apn_datos d
       where d.cod_mtcn = p_mtcn
         and d.referencia = p_referencia
         and d.swf_bco_destino = 'COMAPYPA';
    exception
      when no_data_found then
        v_es_apn := 'N';
      when too_many_rows then
        v_es_apn := 'S';
      when others then
        v_es_apn := 'N';
    end;
  else
    begin
      select 'S'
        into v_es_apn
        from ge_apn_datos d
       where d.cod_mtcn = p_mtcn
         and d.referencia = p_referencia
         and d.swf_bco_destino != 'COMAPYPA';
    exception
      when no_data_found then
        v_es_apn := 'N';
      when too_many_rows then
        v_es_apn := 'S';
      when others then
        v_es_apn := 'N';
    end;
  end if;

  return v_es_apn;
exception
  when others then
    v_det_error := 'MTCN: ' || p_mtcn || ' Referencia: ' || p_referencia ||
                   ' Tip.Transf: ' || p_tip_transferencia || ' Error: ' ||
                   sqlerrm;
    PRG_INS_LOG_PROGRAMAS('PAP_SER.FU_VER_MOV_ES_TRA_APN',
                          v_det_error,
                          null,
                          null);
end fu_ver_mov_es_tra_apn;
---------------------------------------------------------------------------------------------------
  procedure pr_obt_datos_dec_jur(p_cod_persona     in varchar2,
                               p_moneda_bcp      in number,
                               p_monto           in number,
                               p_fecha_mov       in date,
                               p_nombre          out varchar2,
                               p_nro_doc_cliente out varchar2,
                               p_nacionalidad    out varchar2,
                               p_direccion       out varchar2,
                               p_ciudad          out varchar2,
                               p_ingreso         out number,
                               p_egreso          out number,
                               v_respuesta       out varchar2,
                               v_importe_usd     out number) is

  v_cod_moneda    ba_monedas.cod_moneda%type;
  v_cod_error     varchar2(3) := '000';
  v_msj_error     varchar2(100);
  p_respuesta     varchar2(500);
  v_mto_fuerte    ge_mov_cli_declaraciones.mto_mon_fuerte%type;
  v_mon_local     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_mon_fuerte    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  v_total_cliente ge_mov_cli_declaraciones.mto_mon_fuerte%type := 0;
  v_mto_sup       number := fug_obt_pardinamico('OPE_SUP_MON_FUERTE');
  v_hora_mov      ge_movimientos.hora%type;
  v_det_error     ge_log_errores.det_error%type;

begin

  p_ingreso   := 0;
  p_egreso    := 0;
  v_respuesta := 'N';
  if p_cod_persona is null then
    v_cod_error := '001';
    v_msj_error := 'Codigo de persona es dato requerido. No puede ser nulo';
    v_respuesta := 'N';
  end if;
  v_cod_moneda := it.fue_obt_mon_bcp(p_moneda_bcp);

  if v_cod_error = '000' and v_cod_moneda in (v_mon_fuerte, v_mon_local) then
    --convierto el monto a la moneda fuerte del sistema, en caso de que este en moneda local
    if v_cod_moneda = v_mon_fuerte then
      v_mto_fuerte := p_monto;
    else
      v_mto_fuerte := pal_cam.fu_con_mon_a_moneda(v_cod_moneda,
                                                  v_mon_fuerte,
                                                  p_monto);
    end if;
  end if;

  begin
    select b.nom_completo,
           b.nro_documento,
           p.nacionalidad,
           d.direccion,
           c.descripcion
      into p_nombre,
           p_nro_doc_cliente,
           p_nacionalidad,
           p_direccion,
           p_ciudad
      from ba_personas b, ba_direcciones d, ba_ciudades c, ba_paises p
     where b.cod_pais = p.cod_pais
       and d.cod_ciudad = c.cod_ciudad(+)
       and d.cod_pais = c.cod_pais(+)
       and d.principal(+) = 'S'
       and b.cod_persona = d.cod_persona(+)
       and b.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      p_nombre          := null;
      p_nro_doc_cliente := null;
      p_nacionalidad    := null;
      p_direccion       := null;
      p_ciudad          := null;
      v_respuesta       := 'N';
  end;

  if v_cod_error = '000' then
    --controlo las operaciones en el lapso establecido
    --ajustado 05/08/2021 nrecalde--
    begin
      select nvl(sum(pal_cam.fu_con_mon_a_moneda(cod_moneda,
                                                 v_mon_fuerte,
                                                 monto)),
                 0) total
        into v_total_cliente
        from ge_mov_res_clientes
       where cod_persona = p_cod_persona
         and nro_dec_jurada is null
         and fecha between add_months(p_fecha_mov, -12) and p_fecha_mov;
    exception
      when no_data_found then
        v_total_cliente := 0;
    end;
    --se agrega control para saber si es la primera vez que el cliente deposita un monto alto--
    if v_total_cliente = 0 and v_mto_fuerte >= v_mto_sup then
      v_importe_usd := pal_cam.fu_con_mon_a_moneda(v_cod_moneda,
                                                   v_mon_fuerte,
                                                   v_total_cliente);
      v_respuesta   := 'S';
    elsif v_total_cliente > 0 then
      v_total_cliente := nvl(v_total_cliente, 0) + nvl(v_mto_fuerte, 0); --le sumo el total a la operacion actual
      if v_total_cliente >= v_mto_sup then
        v_importe_usd := pal_cam.fu_con_mon_a_moneda(v_cod_moneda,
                                                     v_mon_fuerte,
                                                     v_total_cliente);
        v_respuesta   := 'S';
      else
        p_respuesta := 'Cliente no supera limite';
        v_respuesta := 'N';
      end if;
    elsif v_total_cliente = 0 and v_mto_fuerte < v_mto_sup then
      p_respuesta := 'Cliente no supera limite';
      v_respuesta := 'N';
    end if;
  end if;
  if v_msj_error is not null then
    p_respuesta := v_msj_error;
    v_det_error := ' Monto: ' || p_monto || ' Moneda: ' || p_moneda_bcp ||
                   ' Error: Cod. ' || v_cod_error || '-' || p_respuesta;

    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_DATOS_DEC_JUR',
                          v_det_error,
                          p_cod_persona,
                          null);
  end if;
exception
  when others then
    p_respuesta := sqlerrm;
    v_det_error := ' Monto: ' || p_monto || ' Moneda: ' || p_moneda_bcp ||
                   ' Error: ' || p_respuesta;

    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_DATOS_DEC_JUR',
                          v_det_error,
                          p_cod_persona,
                          null);

end pr_obt_datos_dec_jur;
  ---------------------------------------------------------------------------------------------------
  /*DA-1922  - Control de Cuenta FIELCO- WU*/
  /*nrecalde - Junio2021*/
  function fu_bus_men_error(p_codigo in number) return varchar2 is
    v_mensaje it.ge_lis_error.desc_es%type;
  begin
    begin
      select s.desc_es
        into v_mensaje
        from it.ge_lis_error s
       where s.cod_error = p_codigo;
    exception
      when no_data_found then
        v_mensaje := null;
    end;
    return(v_mensaje);
  end fu_bus_men_error;
   ---------------------------------------------------------------------------------------------------
  /*DA-1922  - Control de Cuenta FIELCO- WU*/
  /*nrecalde - Junio2021*/
 procedure pr_cta_control(p_nro_cuenta    in ge_cuentas.nro_cuenta%type,
                          p_nro_documento in ba_personas.nro_documento%type,
                          p_monto         in number,
                          p_moneda        in number,
                          p_nombre        in varchar2,
                          p_apellido      in varchar2,
                          p_cod_swf       in varchar2,
                          p_cod_error     out number,
                          p_msj_error     out varchar2) is

   v_nombre_rec    ba_personas.nom_completo%type;
   v_nombre_cuenta ge_cuentas.denominacion%type;
   v_moneda        ba_monedas.cod_moneda%type;
   v_modulo        ge_cuentas.cod_modulo%type;
   v_modalidad     ge_cuentas.cod_modalidad%type;
   --v_cod_tra_padre   ge_transacciones.cod_transaccion%type;
   v_oficina         ge_cuentas.cod_oficina%type;
   v_existe_cuenta   varchar2(1);
   v_existe_doc      varchar2(1);
   v_coincide        varchar2(1);
   v_existe_cd       varchar2(1);
   v_existe          varchar2(1);
   v_nvo_estado      ah_cta_vistas.estado%type;
   v_sal_disponible  NUMBER;
   v_procesa         VARCHAR2(10);
   v_cod_transaccion ge_movimientos.cod_transaccion%type default null;
   v_cod_persona     ge_cta_clientes.cod_persona%type;
   v_nro_doc         ba_personas.nro_documento%type;
   v_result          varchar2(1000);
   v_resul           varchar2(1000);
   v_res             varchar2(1);
   v_fecha_actual    DATE := it.pag_cal.fu_obt_fec_actual(1);
   v_nac             varchar2(1000);
   v_dir             varchar2(1000);
   v_ciu             varchar2(1000);
   v_in              number;
   v_eg              number;
   v_importe_usd     number;
   v_pais            number;
   v_tipo_doc        number;
   v_cod             number;
   v_msj             varchar2(70);
   v_retorno         varchar2(10);
 begin
   if p_cod_swf <> 'COMAPYPA' then
     null;
   else
     v_nombre_rec := UPPER(p_nombre || ' ' || p_apellido);
     v_moneda     := fue_obt_mon_bcp(p_moneda);

     if p_nro_cuenta is not null and p_nro_documento is not null then
       --1era busqueda : que exista la cuenta--
       begin
         select 'S', ct.cod_persona
           into v_existe_cuenta, v_cod_persona
           from ge_cuentas c, ge_cta_clientes ct
          where c.nro_cuenta = ct.nro_cuenta
            and c.cod_modulo = ct.cod_modulo
            and c.cod_modalidad = ct.cod_modalidad
            and c.nro_cuenta = p_nro_cuenta
            and ct.relacion = 'P';
       exception
         when no_data_found then
           v_existe_cuenta := 'N';
           p_cod_error     := 1005;
           p_msj_error     := fu_bus_men_error(p_cod_error);
       end;

       --------------------------------------------------------------
       --2da busqueda : que exista el documento
       if v_existe_cuenta = 'S' then
         begin
           select 'S', s.nro_documento
             into v_existe_doc, v_nro_doc
             from ba_personas s
            where s.nro_documento = p_nro_documento;
         exception
           when no_data_found then
             v_existe_doc := 'N';
             p_cod_error  := 1007;
             p_msj_error  := fu_bus_men_error(p_cod_error);
         end;
       end if;
       --3era busqueda : si coincide nro de cuenta y nro documento
       if v_existe_cuenta = 'S' and v_existe_doc = 'S' then
         begin
           select 'S'
             into v_existe_cd
             from ge_cuentas      c,
                  ge_cta_clientes ct,
                  ge_clientes     cl,
                  ba_personas     p
            where c.nro_cuenta = ct.nro_cuenta
              and ct.cod_persona = cl.cod_persona
              and cl.cod_persona = p.cod_persona
              and c.nro_cuenta = p_nro_cuenta
              and p.nro_documento = p_nro_documento;
         exception
           when no_data_found then
             v_existe_cd := 'N';
             p_cod_error := 1006;
             p_msj_error := fu_bus_men_error(p_cod_error);
         end;
       end if;
       --4ta busqueda : moneda coincida con la cuenta y el documento
       if v_existe_cuenta = 'S' and v_existe_doc = 'S' and
          v_existe_cd = 'S' then
         begin
           select 'S',
                  UPPER(c.denominacion),
                  c.cod_modulo,
                  c.cod_modalidad,
                  c.cod_oficina,
                  p.cod_pais,
                  p.cod_tip_documento
             into v_existe,
                  v_nombre_cuenta,
                  v_modulo,
                  v_modalidad,
                  v_oficina,
                  v_pais,
                  v_tipo_doc
             from ge_cuentas      c,
                  ge_cta_clientes ct,
                  ge_clientes     cl,
                  ba_personas     p
            where c.nro_cuenta = ct.nro_cuenta
              and ct.cod_persona = cl.cod_persona
              and cl.cod_persona = p.cod_persona
              and c.nro_cuenta = p_nro_cuenta
              and p.nro_documento = p_nro_documento
              and c.cod_moneda = v_moneda;
         exception
           when no_data_found then
             v_existe    := 'N';
             p_cod_error := 1010;
             p_msj_error := fu_bus_men_error(p_cod_error);
         end;
       end if;
     end if;
     --como control extra buscamos que coincidan los nombres--
     --  pr_con_nom_coincidencia(v_nombre_cuenta, v_nombre_rec, v_coincide);
     if v_existe = 'S' THEN
       ---ley 1015------------------------------------------------
       pr_obt_datos_dec_jur(v_cod_persona,
                            p_moneda,
                            p_monto,
                            v_fecha_actual,
                            v_nombre_rec,
                            v_nro_doc,
                            v_nac,
                            v_dir,
                            v_ciu,
                            v_in,
                            v_eg,
                            v_res,
                            v_importe_usd);
       if v_res = 'S' then
         p_cod_error := 1002;
         p_msj_error := fu_bus_men_error(p_cod_error);
       end if;

       --limite por monto----------------------------------------
       if v_res <> 'S' then
         begin
           v_result := fu_control_limite(v_cod_persona, p_moneda, p_monto);
           if v_result <> 'OK' then
             p_cod_error := 1009;
             p_msj_error := fu_bus_men_error(p_cod_error);
           end if;
         end;
       end if;
       ---lista negra-------------------------------------------------
       if v_result = 'OK' and v_res = 'N' then
         pr_val_per_excepcion(p_nro_documento,
                              v_pais,
                              v_tipo_doc,
                              p_nombre,
                              null,
                              p_apellido,
                              null,
                              null,
                              v_cod,
                              v_msj,
                              v_retorno);
         if v_retorno = 'S' then
           p_cod_error := 1003;
           p_msj_error := fu_bus_men_error(p_cod_error);
         end if;
       end if;
       if v_result = 'OK' and v_res = 'N' and v_retorno = 'N' then
         begin
           it.pag_cta.pr_ver_operacion(P_NRO_CUENTA      => p_nro_cuenta,
                                       P_COD_TRA_PADRE   => 8506, --v_cod_tra_padre,
                                       P_COD_MOD_PADRE   => 4, --v_modulo,
                                       P_COD_MAD_PADRE   => 43, --v_modalidad,
                                       P_TIP_MOVIMIENTO  => 'C', --tipo credito
                                       P_COD_MONEDA      => v_moneda,
                                       P_MONTO           => p_monto,
                                       P_COD_OFI_ORIGEN  => v_oficina,
                                       P_COD_MODULO      => v_modulo,
                                       P_COD_MODALIDAD   => v_modalidad,
                                       P_NVO_ESTADO      => v_nvo_estado,
                                       P_SAL_DISPONIBLE  => v_sal_disponible,
                                       P_PROCESA         => v_procesa,
                                       P_COD_TRANSACCION => v_cod_transaccion);
         exception
           when others then
             p_cod_error := 1;
             p_msj_error := 'Error al ejecutar pag_cta.pr_ver_operacion';
         end;
         -- verificamos del porque no puede operar la cuenta--
         --para modalidad in (31, 41, 42, 43, 44, 45, 46, 47, 48, 455)
         --cod.33 error por estado de la cuenta, No se podra acreditar si la cta esta en :(C)ancelada, Bloqueo (T)otal, (P)endiente de Cancelacion
         --cod.34 error al acreditar por estado de cuenta incorrecto
         --cod.35 error por tipo operacion debe ser (D)ebito o (C)redito
         --para modalidad in (32, 33, 34, 35)
         --cod.40 error Monto a acreditar supera al Capital
         --cod.41 error estado de la cuenta no permite creditos
         --cod.42 error por tipo operacion debe ser (D)ebito o (C)redito
         if v_procesa = 'N' then
           if it.pag_cta.G_COD_ERROR in (33, 34, 35, 40, 41, 42) then
             p_cod_error := 1005; --se cambia por pedido del analista
             p_msj_error := fu_bus_men_error(p_cod_error) ||
                            it.pag_cta.G_MSJ_ERROR;
           else
             p_cod_error := 0;
             p_msj_error := 'Ejecuci?n Exitosa';
           end if;
         elsif v_procesa = 'S' then
           p_cod_error := 0;
           p_msj_error := 'Ejecuci?n Exitosa';
         end if;
         /*else
         p_cod_error := 2;
         p_msj_error := 'No coincide los datos de la cuenta. Nombre/Apellido';*/
       end if;
     end if;
   end if;
 end pr_cta_control;
   ---------------------------------------------------------------------------------------------------
  procedure pr_gen_apn_tra_fielco(p_nom_beneficiario      in varchar2,
                                  p_ape_beneficiario      in varchar2,
                                  p_ciu_beneficiario      in VARCHAR2,
                                  p_est_beneficiario      in VARCHAR,
                                  p_nro_doc_beneficiario  in VARCHAR2,
                                  p_cta_beneficiario      in VARCHAR2,
                                  p_cod_swift             in varchar2,
                                  p_nom_remitente         in VARCHAR,
                                  p_ape_remitente         in VARCHAR,
                                  p_tra_monto             in number,
                                  p_tra_moneda            in VARCHAR2, --formato iso
                                  p_cod_motivo            in VARCHAR2,
                                  p_des_motivo            in varchar2,
                                  p_cod_mtcn              in varchar2,
                                  p_msgid                 in varchar2,
                                  p_pai_sol               in varchar2,
                                  p_cod_error             out number,
                                  p_respuesta             out varchar2,
                                  p_est_transferencia     out varchar2,
                                  p_des_est_transferencia out varchar2) is

    v_cod_tra_padre        ge_transacciones.cod_transaccion%type := 8506;
    v_cod_ofi_ente         ge_cta_clientes.cod_oficina%type;
    v_cod_mod_ente         ge_cta_clientes.cod_modulo%type;
    v_cod_mad_ente         ge_cta_clientes.cod_modalidad%type;
    v_cod_ofi_persona      ge_cta_clientes.cod_oficina%type;
    v_cod_mod_persona      ge_cta_clientes.cod_modulo%type;
    v_cod_mad_persona      ge_cta_clientes.cod_modalidad%type;
    v_est_cuenta           ge_cuentas.estado%type;
    v_sal_disponible       ge_movimientos.monto%type;
    v_procesa              varchar2(1) := 'N';
    v_cod_transaccion      ge_transacciones.cod_transaccion%type;
    v_cod_moneda           ba_monedas.cod_moneda%type;
    v_cta_wu               ge_cuentas.nro_cuenta%type;
    v_cta_wepa             ge_cuentas.nro_cuenta%type;
    v_hor_actual           VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS');
    v_fec_actual           DATE := pag_cal.fu_obt_fec_actual(5);
    v_fec_valor          DATE := v_fec_actual;--TRFS-1331
    v_nro_secuencia        ge_movimientos.nro_secuencia%type := 0;
    v_est_transferencia    ge_lis_estados.cod_est%type;
    v_tip_doc_beneficiario ba_tip_documentos.cod_tip_documento%type;
    v_error                number;
    v_respuesta            varchar2(2000);
    v_monto                ge_movimientos.monto%type;
    v_redondeo             NUMBER(1);
    v_existe               varchar2(1);
    v_det_error            ge_log_errores.det_error%type;
    v_ok_control           varchar2(1) := 'S';
    v_mon_bcp              ba_monedas.cod_mon_bco_central%type;
    v_id                   ge_apn_datos.referencia%type;
    v_cod_persona          ba_personas.cod_persona%type;
    v_nom                  ba_personas.nom_completo%type;
    v_doc                  ba_personas.nro_documento%type;
    v_nac                  varchar2(70);
    v_dir                  varchar2(70);
    v_ciu                  varchar2(70);
    v_ing                  number;
    v_egr                  number;
    v_res                  varchar2(2000);
    v_msj_error            varchar(4000);
    --TRFS-1235
    v_usu_mov            ba_usuarios.cod_usuario%type;
    v_hor_mov            ge_snp_transferencias.hora%type;  
    --TRFS-1331
    v_horario         VARCHAR2(1) := 'D'; -- Dia normal
    v_es_mov_noc      VARCHAR2(1) := 'N';
    v_es_cta_noc      VARCHAR2(1) := 'N'; -- Graba S/N ctas noctunas
    retError           typ_mensajerespuesta := typ_mensajerespuesta;
  begin
    savepoint transferencia;
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

    /*Validaciones*/
    /*Verifica parametros obligatorios para la transaccion*/
    if nvl(p_cod_mtcn, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' endToEndId';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' endToEndId';
    end if;
    if nvl(p_tra_monto, 0) = 0 then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' paymentAmount';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' paymentAmount';
    end if;

    if nvl(p_cta_beneficiario, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' accountNumber';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' accountNumber';
    end if;

    if nvl(p_nro_doc_beneficiario, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' id value';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' id value';
    end if;

    if nvl(p_est_beneficiario, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' state';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' state';
    end if;

    if nvl(p_ciu_beneficiario, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' city';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' city';
    end if;

    if nvl(p_nom_beneficiario, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' creditor firstName';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' creditor firstName';
    end if;

    if nvl(p_ape_beneficiario, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' creditor lastName';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' creditor lastName';
    end if;

    if nvl(p_tra_moneda, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
    end if;

    if nvl(p_cod_swift, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' bankCode';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' bankCode';
    end if;

    if nvl(p_cod_motivo, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' purpose code';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' purpose code';
    end if;

    if nvl(p_nom_remitente, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' debitor firstName';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' debitor firstName';
    end if;

    if nvl(p_ape_remitente, 'x') = 'x' then
      p_cod_error := 1001;
      p_respuesta := fu_bus_men_error(p_cod_error) || ' debitor lastName';
      v_msj_error := fu_bus_men_error(p_cod_error) || ' debitor lastName';
    end if;

    begin
      select 'S'
        into v_existe
        from ge_apn_datos a
       where a.cod_mtcn = p_cod_mtcn;
    exception
      when no_data_found then
        v_existe := 'N';
    end;

    if nvl(v_existe, 'N') = 'S' then
      p_cod_error := 1012;
      p_respuesta := fu_bus_men_error(p_cod_error);
      v_msj_error := fu_bus_men_error(p_cod_error);
    end if;

    if nvl(p_cod_error, 0) = 0 then
      v_existe := 'N';
      begin
        select 'S', p.cod_persona
          into v_existe, v_cod_persona
          from ge_cta_clientes c, ba_personas p
         where c.cod_persona = p.cod_persona
           and c.nro_cuenta = p_cta_beneficiario
           and p.nro_documento = p_nro_doc_beneficiario;
      exception
        when no_data_found then
          p_cod_error := 1006;
          p_respuesta := fu_bus_men_error(p_cod_error);
          v_msj_error := fu_bus_men_error(p_cod_error);
      end;

      v_cod_moneda := fue_obt_iso_moneda(p_tra_moneda);

      if nvl(v_cod_moneda, 'x') not in
         (pag_gen.FU_OBT_MON_LOCAL, pag_gen.FU_OBT_MON_FUERTE) then
        p_cod_error := 1013;
        p_respuesta := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
      end if;

/*      v_cta_wu := fug_obt_pardinamico('CTA_OP_WESTERN',
                                      null,
                                      null,
                                      v_cod_moneda);*/

      v_cta_wepa := fug_obt_pardinamico('NRO_CTA_OPE_WEPA',
                                        null,
                                        null,
                                        v_cod_moneda);

      if nvl(v_cta_wepa, 'x') = 'x' then
        p_cod_error := 1011;
        p_respuesta := fu_bus_men_error(p_cod_error);
        v_msj_error := fu_bus_men_error(p_cod_error);
      end if;
      /*Obtiene cuenta del cliente*/
      pag_cta.PR_OBT_CUENTA(p_cta_beneficiario);
      v_cod_ofi_persona := pag_cta.G_CTAS.cod_oficina;
      v_cod_mod_persona := pag_cta.G_CTAS.cod_modulo;
      v_cod_mad_persona := pag_cta.G_CTAS.cod_modalidad;

      if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
        p_cod_error := 1011;
        p_respuesta := fu_bus_men_error(p_cod_error);
        v_msj_error := '1- '||pag_cta.G_COD_ERROR || ' - ' || pag_cta.G_MSJ_ERROR;
      end if;

      if v_cod_moneda != pag_cta.G_CTAS.cod_moneda then
        p_cod_error := 1010;
        p_respuesta := fu_bus_men_error(p_cod_error);
        v_msj_error := fu_bus_men_error(p_cod_error);
      end if;
      /*Obtiene datos de la cuenta de la cuenta operativa wu*/
      pag_cta.PR_OBT_CUENTA(v_cta_wepa);
      if pag_cta.G_COD_ERROR = 0 then
        v_cod_ofi_ente := pag_cta.G_CTAS.cod_oficina;
        v_cod_mod_ente := pag_cta.G_CTAS.cod_modulo;
        v_cod_mad_ente := pag_cta.G_CTAS.cod_modalidad;
      end if;
      if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
        p_cod_error := 1011;
        p_respuesta := fu_bus_men_error(p_cod_error);
        v_msj_error := '2- '||pag_cta.G_COD_ERROR || ' - ' || pag_cta.G_MSJ_ERROR;
      end if;
      if pae_cnf.fu_obt_est_modulo(3) != 2 then
        p_cod_error := 1011;
        p_respuesta := fu_bus_men_error(p_cod_error);
        v_msj_error := 'Error cierre operativo';
      end if;
      begin
        select b.cod_mon_bco_central
          into v_mon_bcp
          from ba_monedas b
         where b.cod_moneda = v_cod_moneda;
      exception
        when others then
          p_cod_error := 1011;
          p_respuesta := fu_bus_men_error(p_cod_error);
          v_msj_error := 'Error al obtener moneda BCP';
      end;
      --llamamos a pr_cta_control--
      pr_cta_control(p_cta_beneficiario,
                     p_nro_doc_beneficiario,
                     p_tra_monto,
                     v_mon_bcp,
                     p_nom_beneficiario,
                     p_ape_beneficiario,
                     'COMAPYPA',
                     p_cod_error,
                     p_respuesta);
      if nvl(p_cod_error, 0) <> 0 then
        v_ok_control := 'N'; --marca como control fallido
        v_msj_error  := 'Error al llamar pr_cta_control ' || p_cod_error ||
                        ' - ' || p_respuesta;
      end if;

      if nvl(p_cod_error, 0) = 0 then
        --si pasa las validaciones

        /*verifica operacion cuenta del beneficiario*/
        begin
          pag_cta.PR_VER_OPERACION(p_cta_beneficiario,
                                   v_cod_tra_padre,
                                   v_cod_mod_ente,
                                   v_cod_mad_ente,
                                   'C',
                                   v_cod_moneda,
                                   v_monto,
                                   v_cod_ofi_persona,
                                   v_cod_mod_persona,
                                   v_cod_mad_persona,
                                   v_est_cuenta,
                                   v_sal_disponible,
                                   v_procesa,
                                   v_cod_transaccion);
        exception
          when others then
            v_procesa := 'N';
        end;
        if nvl(v_procesa, 'N') = 'S' then
          begin

            --TRFS-1235
            prs_snp_obt_usu_hor_mov_apn('APNWEPA',
                                           v_usu_mov,
                                           v_hor_mov);
            v_hor_actual :=  v_hor_mov;
            v_id         := to_number(to_char(v_fec_actual, 'yymmdd') ||
                                      it.s_apn.nextval);
             
             v_tra_spi := 'S';--TRFS-1331
             reterror := lp_ver_hor_transferencia(v_horario, v_es_mov_noc, v_es_cta_noc,
                                            null,
                                            v_cod_ofi_ente,
                                            v_fec_actual, null, v_fec_valor);
              v_tra_spi := 'N';--TRFS-1331
             --TRFS-1235
             pag_cta.PR_SET_VARIABLES(p_cod_usuario    => v_usu_mov,
                                      p_fec_valor      => v_fec_actual,
                                      p_cod_tra_padre  => v_cod_tra_padre,
                                      p_estado         => 'N',
                                      p_reversado      => 'N',
                                      p_nro_secuencia  => v_nro_secuencia,
                                      p_est_cuenta     => NULL,
                                      p_cod_ofi_origen => v_cod_ofi_ente,
                                      p_cod_mod_padre  => v_cod_mod_ente,
                                      p_cod_mad_padre  => v_cod_mad_ente);
            /*Debito a la cuenta operativa Western*/
            pag_cta.pr_set_referencia(p_cod_mtcn);
            pag_cta.PR_ACT_OPERACION(v_cta_wepa,
                                     v_hor_actual,
                                     'D',
                                     v_cod_moneda,
                                     p_tra_monto,
                                     v_cod_tra_padre,
                                     503,
                                     v_id, --nro_doc
                                     null,
                                     v_cod_ofi_ente,
                                     v_cod_mod_ente,
                                     v_cod_mad_ente,
                                     null,
                                     null,
                                     'Transferencia APN',
                                     'N',
                                     v_nro_secuencia,
                                     v_fec_valor);--TRFS-1331

            if pag_cta.G_COD_ERROR != 00 then
              p_cod_error := 1011;
              p_respuesta := fu_bus_men_error(p_cod_error);
              v_msj_error :='3- '||pag_cta.G_COD_ERROR || ' - ' ||
                             pag_cta.G_MSJ_ERROR;
              rollback to transferencia;
            else
              /*Credito al cliente*/
              --TRFS-1235
             pag_cta.PR_SET_VARIABLES(p_cod_usuario    => v_usu_mov,
                                      p_fec_valor      => v_fec_actual,
                                      p_cod_tra_padre  => v_cod_tra_padre,
                                      p_estado         => 'N',
                                      p_reversado      => 'N',
                                      p_nro_secuencia  => v_nro_secuencia,
                                      p_est_cuenta     => NULL,
                                      p_cod_ofi_origen => v_cod_ofi_ente,
                                      p_cod_mod_padre  => v_cod_mod_ente,
                                      p_cod_mad_padre  => v_cod_mad_ente);
              pag_cta.pr_set_referencia(p_cod_mtcn);
              pag_cta.PR_ACT_OPERACION(p_cta_beneficiario,
                                       v_hor_actual,
                                       'C',
                                       v_cod_moneda,
                                       p_tra_monto,
                                       v_cod_tra_padre,
                                       602,
                                       v_id, --nro_doc
                                       null,
                                       v_cod_ofi_ente,
                                       v_cod_mod_ente,
                                       v_cod_mad_ente,
                                       null,
                                       null,
                                       'Credito por Transferencia APN',
                                       'N',
                                       v_nro_secuencia,
                                      v_fec_valor);--TRFS-1331
              if pag_cta.G_COD_ERROR != 00 then
                p_cod_error := 1011;
                p_respuesta := fu_bus_men_error(p_cod_error);
                v_msj_error := '4- '||pag_cta.G_COD_ERROR || ' - ' ||
                               pag_cta.G_MSJ_ERROR;
                rollback to transferencia;
              end if;
            end if;
          exception
            when others then
              p_cod_error := 1011;
              p_respuesta := fu_bus_men_error(p_cod_error);
              v_msj_error := 'Error al generar movimientos ' || sqlerrm;
              rollback to transferencia;
          end;
        else
          p_cod_error := 1011;
          p_respuesta := fu_bus_men_error(p_cod_error);
          v_msj_error := 'Error en la verificacion de la operacion ' ||
                         pag_cta.G_COD_ERROR || ' ' || pag_cta.G_MSJ_ERROR;
        end if;
      end if;
    end if;
    if nvl(p_cod_error, 0) = 0 and nvl(v_ok_control, 'S') = 'S' then
      p_est_transferencia     := 'ACTC';
      p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
      p_cod_error             := 0;
      p_respuesta             := fu_bus_men_error(p_cod_error);
      --se registra ley 1015--
      Begin
        pr_obt_datos_dec_jurada(v_cod_persona,
                                v_mon_bcp,
                                p_tra_monto,
                                v_fec_actual,
                                v_id,
                                v_nom,
                                v_doc,
                                v_nac,
                                v_dir,
                                v_ciu,
                                v_ing,
                                v_egr,
                                v_res);
      exception
        when others then
          p_est_transferencia     := 'RJCT';
          p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
          v_msj_error             := 'Error al obtener datos declaracion jurada';
          rollback to transferencia;
      end;
    elsif nvl(p_cod_error, 0) != 0 and nvl(v_ok_control, 'S') = 'S' then
      p_est_transferencia     := 'RJCT';
      p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
    elsif nvl(v_ok_control, 'S') = 'N' then
      p_est_transferencia     := 'FAIL';
      p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
    end if;

    if nvl(p_cod_error, 0) != 0 then

      rollback to transferencia;

    end if;
    /*Inserta en la tabla de operaciones APN*/
    pr_ins_dat_apn(p_cod_mtcn, --mtcn
                   v_id, --referencia
                   sysdate, --fecha operacion
                   null, --estado notificado
                   null, --fecha notificado
                   null, --cod. error notificacion
                   null, --sub cod. error notificacion
                   null, --descripcion error notificacion
                   p_est_transferencia, --estado transferencia
                   p_cod_error, --error operacion
                   p_nom_remitente,
                   p_ape_remitente,
                   p_nom_beneficiario,
                   p_ape_beneficiario,
                   p_ciu_beneficiario,
                   p_est_beneficiario,
                   p_nro_doc_beneficiario,
                   p_cta_beneficiario,
                   p_tra_monto,
                   p_tra_moneda, --formato iso
                   p_cod_motivo,
                   p_cod_swift,
                   p_des_motivo,
                   p_msgid,
                   p_pai_sol,
                   v_error,
                   v_respuesta);

    if nvl(v_error, 0) != 0 and nvl(p_cod_error, 0) = 0 then
      p_est_transferencia     := 'RJCT';
      p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
      p_cod_error             := 1011;
      p_respuesta             := fu_bus_men_error(p_cod_error);
      v_msj_error             := v_error || ' - ' || v_respuesta;
      /*Si no pudo insertar en ge_apn_datos hacemos rollback*/
      rollback to transferencia;
    end if;
    if nvl(v_error, 0) != 0 or nvl(p_cod_error, 0) != 0 then
      /*Si existe un error en la insercion en la tabla de operaciones APN deshace la operacion*/
      v_det_error := substr('MTCN: ' || p_cod_mtcn || ' Monto: ' ||
                            p_tra_monto || ' Moneda: ' || p_tra_moneda ||
                            ' Nro.Documento: ' || p_nro_doc_beneficiario ||
                            ' Nro. cuenta ' || p_cta_beneficiario ||
                            ' Error: ' || v_msj_error,
                            1,
                            4000);
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_APN_TRA_FIELCO',
                            v_det_error,
                            null,
                            p_cta_beneficiario);

    end if;

  exception
    when others then
      p_est_transferencia     := 'RJCT';
      p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
      p_cod_error             := 1011;
      p_respuesta             := fu_bus_men_error(p_cod_error);
      v_msj_error             := '5- '||DBMS_UTILITY.format_error_backtrace || ' ' ||
                                 DBMS_UTILITY.format_error_stack;
      pr_ins_dat_apn(p_cod_mtcn, --mtcn
                     v_id, --referencia
                     sysdate, --fecha operacion
                     null, --estado notificado
                     null, --fecha notificado
                     null, --cod. error notificacion
                     null, --sub cod. error notificacion
                     null, --descripcion error notificacion
                     p_est_transferencia, --estado transferencia
                     p_cod_error, --error operacion
                     p_nom_remitente,
                     p_ape_remitente,
                     p_nom_beneficiario,
                     p_ape_beneficiario,
                     p_ciu_beneficiario,
                     p_est_beneficiario,
                     p_nro_doc_beneficiario,
                     p_cta_beneficiario,
                     p_tra_monto,
                     p_tra_moneda, --formato iso
                     p_cod_motivo,
                     p_cod_swift,
                     p_des_motivo,
                     p_msgid,
                     p_pai_sol,
                     v_error,
                     v_respuesta);

      if nvl(v_error, 0) != 0 or nvl(p_cod_error, 0) != 0 then
        /*Si existe un error en la insercion en la tabla de operaciones APN deshace la operacion*/
        v_det_error := substr('MTCN: ' || p_cod_mtcn || ' Monto: ' ||
                              p_tra_monto || ' Moneda: ' || p_tra_moneda ||
                              ' Nro.Documento: ' || ' Nro. cuenta ' ||
                              p_cta_beneficiario || p_nro_doc_beneficiario ||
                              ' Error: ' || v_msj_error || ' ' ||
                              v_respuesta,
                              1,
                              4000);

        PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_APN_TRA_FIELCO',
                              v_det_error,
                              null,
                              p_cta_beneficiario);
      end if;
  end pr_gen_apn_tra_fielco;
------------------------------------------------------------------------------------------------
  /*larce - Junio2021*/
  function fu_obt_men_estado(p_cod in varchar2) return varchar2 is
    v_mensaje ge_lis_estados.desc_es%type;
  begin
    begin
      select s.desc_es
        into v_mensaje
        from ge_lis_estados s
       where s.cod_est = p_cod;
    exception
      when no_data_found then
        v_mensaje := null;
    end;
    return(v_mensaje);
 end fu_obt_men_estado;
 ------------------------------------------------------------------------------------------

  --inserta datos en resumen del cliente
  procedure pr_ins_res_cliente(p_cod_persona    in ba_personas.cod_persona%type,
                               p_fecha_mov      in date,
                               p_hora_mov       in ge_movimientos.hora%type,
                               p_cod_usuario    in ba_usuarios.cod_usuario%type,
                               p_cod_mon_fuerte in ba_monedas.cod_moneda%type) is

    rg_gmrcl    ge_mov_res_clientes%rowtype;
    v_det_error ge_log_errores.det_error%type;
    cursor c_movimientos is
      select m.fecha,
             m.hora,
             m.cod_usuario,
             m.fec_valor,
             m.nro_cuenta,
             m.cod_moneda,
             m.cod_ofi_origen,
             m.cod_tra_padre,
             m.cod_mod_padre,
             m.cod_mad_padre,
             m.cotizacion,
             m.nro_documento,
             m.nro_documento3, --codigo de la persona si es desde un cnb
             m.cod_persona,
             t.tipo tip_movimiento,
             protegido,
             m.cod_modulo,
             m.cod_modalidad,
             sum(m.monto) monto,
             sum(m.mto_equ_local) mto_equ_local
        from ge_movimientos m, ge_transacciones t
       where m.cod_mod_padre = 4
         and t.cod_modulo = m.cod_modulo
         and t.cod_modalidad = m.cod_modalidad
         and t.cod_transaccion = m.cod_transaccion
         and m.reversado = 'N'
         and m.monto > 0
         and m.fecha = nvl(p_fecha_mov, m.fecha)
         and m.hora = nvl(p_hora_mov, m.hora)
         and m.cod_usuario = nvl(p_cod_usuario, m.cod_usuario)
         and (m.cod_transaccion in (8509,8523) or (m.cod_tra_padre = 8506 and m.cod_transaccion = 602)) --tansaccion wu
       group by m.fecha,
                m.hora,
                m.cod_usuario,
                m.fec_valor,
                m.nro_cuenta,
                m.cod_moneda,
                m.cod_ofi_origen,
                m.cod_tra_padre,
                m.cod_mod_padre,
                m.cod_mad_padre,
                m.cotizacion,
                m.nro_documento,
                m.nro_documento3,
                m.cod_persona,
                t.tipo,
                protegido,
                m.cod_modulo,
                m.cod_modalidad;
  begin

    for reg in c_movimientos loop
      rg_gmrcl.cod_persona := p_cod_persona;
      if reg.cod_moneda != p_cod_mon_fuerte then
        rg_gmrcl.mto_equ_mon_fuerte := pag_gen.FU_CON_MON_A_MONEDA(reg.cod_moneda,
                                                                   p_cod_mon_fuerte,
                                                                   reg.monto,
                                                                   reg.cotizacion);
      end if;
      --insertar movimiento
      BEGIN
        insert into ge_mov_res_clientes
          (fecha,
           hora,
           cod_usuario,
           cod_persona,
           fec_valor,
           monto,
           nro_cuenta,
           cod_moneda,
           cod_ofi_origen,
           cod_tra_padre,
           cod_mod_padre,
           cod_mad_padre,
           mto_equ_local,
           mto_equ_mon_fuerte,
           cotizacion,
           nro_documento,
           informado,
           cod_modulo,
           cod_modalidad,
           tip_mov_rubro,
           ano,
           mes)
        values
          (reg.fecha,
           reg.hora,
           reg.cod_usuario,
           p_cod_persona,
           reg.fec_valor,
           reg.monto,
           reg.nro_cuenta,
           reg.cod_moneda,
           reg.cod_ofi_origen,
           reg.cod_tra_padre,
           reg.cod_mod_padre,
           reg.cod_mad_padre,
           reg.mto_equ_local,
           reg.monto,
           reg.cotizacion,
           reg.nro_documento,
           null,
           reg.cod_modulo,
           reg.cod_modalidad,
           reg.tip_movimiento,
           to_char(reg.fecha,'YYYY'),
           to_number(to_char(SYSDATE,'MM')));
      exception
        when others  then
          v_det_error:= sqlerrm;
      END;
    end loop;
  exception
    when others then
      v_det_error := 'Fecha mov : ' || p_fecha_mov || ' Hora mov : ' ||
                     p_hora_mov || ' Usuario mov: ' || p_cod_usuario ||
                     ' Error: ' || sqlerrm;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_INS_RES_CLIENTE',
                            v_det_error,
                            p_cod_persona,
                            null);
  end pr_ins_res_cliente;
------------------------------------------------------------------------------------------------
   --obtener datos para ddjj
  procedure pr_obt_datos_dec_jurada(p_cod_persona in varchar2,
                                    p_moneda_bcp  in number,
                                    p_monto       in number,
                                    p_fecha_mov   in date,
                                    --p_hora_mov        in ge_movimientos.hora%type,
                                    p_movimiento_id   in number,
                                    p_nombre          out varchar2,
                                    p_nro_doc_cliente out varchar2,
                                    p_nacionalidad    out varchar2,
                                    p_direccion       out varchar2,
                                    p_ciudad          out varchar2,
                                    p_ingreso         out number,
                                    p_egreso          out number,
                                    p_respuesta       out varchar2) is

    v_cod_moneda     ba_monedas.cod_moneda%type;
    v_cod_error      varchar2(3) := '000';
    v_msj_error      varchar2(100);
    v_mto_fuerte     ge_mov_cli_declaraciones.mto_mon_fuerte%type; /*monto de la operacion*/
    v_mon_local      ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_mon_fuerte     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
    v_total_cliente  ge_mov_cli_declaraciones.mto_mon_fuerte%type;
    v_mto_sup        number := fug_obt_pardinamico('OPE_SUP_MON_FUERTE');
    v_nro_dec_jurada ge_dec_juradas.nro_dec_jurada%type;
    v_hora_mov       ge_movimientos.hora%type;
    v_det_error      ge_log_errores.det_error%type;
    v_cod_usuario    ba_usuarios.cod_usuario%type;
  begin

    p_ingreso := 0;
    p_egreso  := 0;
    if p_cod_persona is null then
      v_cod_error := '001';
      v_msj_error := 'Codigo de persona es dato requerido. No puede ser nulo';
    end if;
    v_cod_moneda := it.fue_obt_mon_bcp(p_moneda_bcp);

    if v_cod_error is null and v_cod_moneda in (v_mon_fuerte, v_mon_local) then
      --convierto el monto a la moneda fuerte del sistema, en caso de que este en moneda local
      if v_cod_moneda = v_mon_fuerte then
        v_mto_fuerte := p_monto;
      else
        v_mto_fuerte := pal_cam.fu_con_mon_a_moneda(v_cod_moneda,
                                                    v_mon_fuerte,
                                                    p_monto);
      end if;

      if nvl(v_mto_fuerte, 0) > 0 then

        update ge_mov_cli_declaraciones
           set mto_mon_fuerte = nvl(mto_mon_fuerte, 0) +
                                nvl(v_mto_fuerte, 0)
         where cod_persona = p_cod_persona;
        if sql%notfound then
          insert into ge_mov_cli_declaraciones
            (cod_persona, mto_mon_fuerte)
          values
            (p_cod_persona, v_mto_fuerte);
        end if;
      end if;
    end if;
    --recuperar hora del movimiento
    begin
      select hora, cod_usuario
        into v_hora_mov, v_cod_usuario
        from ge_movimientos
       where cod_tra_padre in (8506,8516) /*tra_padre wu*/
         and nro_documento = p_movimiento_id
         and rownum = 1;
    exception
      when no_data_found then
        v_cod_error := '002';
        v_msj_error := 'Movimiento no encontrado';
    end;
    if v_cod_error = '000' then
      --registrar el movimiento en el resumen del cliente
      pr_ins_res_cliente(p_cod_persona,
                         p_fecha_mov,
                         v_hora_mov,
                         v_cod_usuario,
                         v_mon_fuerte);

      --controlo las operaciones en el lapso establecido
      select sum(pal_cam.fu_con_mon_a_moneda(cod_moneda,
                                             v_mon_fuerte,
                                             monto)) total
        into v_total_cliente
        from ge_mov_res_clientes
       where cod_persona = p_cod_persona
         and nro_dec_jurada is null
         and fecha between add_months(p_fecha_mov, -12) and p_fecha_mov;

      --le sumo el total a la operacion actual
      v_total_cliente := v_total_cliente + v_mto_fuerte;

      if v_total_cliente >= v_mto_sup then
        begin
          select b.nom_completo,
                 b.nro_documento,
                 p.nacionalidad,
                 d.direccion,
                 c.descripcion
            into p_nombre,
                 p_nro_doc_cliente,
                 p_nacionalidad,
                 p_direccion,
                 p_ciudad
            from ba_personas    b,
                 ba_direcciones d,
                 ba_ciudades    c,
                 ba_paises      p
           where b.cod_pais = p.cod_pais
             and d.cod_ciudad = c.cod_ciudad(+)
             and d.cod_pais = c.cod_pais(+)
             and d.principal(+) = 'S'
             and b.cod_persona = d.cod_persona(+)
             and b.cod_persona = p_cod_persona;
        exception
          when no_data_found then
            p_nombre          := null;
            p_nro_doc_cliente := null;
            p_nacionalidad    := null;
            p_direccion       := null;
            p_ciudad          := null;
        end;

        begin
          v_nro_dec_jurada := fue_obt_sig_secuencia('s_nro_dec_jurada');
          insert into ge_dec_juradas
            (fecha,
             hora,
             cod_mod_padre,
             cod_persona,
             nro_documento,
             monto,
             impresion,
             nro_dec_jurada)
          values
            (p_fecha_mov,
             v_hora_mov,
             4,
             p_cod_persona,
             p_nro_doc_cliente,
             v_total_cliente,
             null,
             v_nro_dec_jurada);

          --Actualiar los movimientos que corresponden a la declaracion jurada del cliente
          update ge_mov_res_clientes
             set nro_dec_jurada = v_nro_dec_jurada
           where cod_persona = p_cod_persona
             and nro_dec_jurada is null;

          --actualizar el total por cliente para cerar el mismo
          update ge_mov_cli_declaraciones
             set mto_mon_fuerte_ant = nvl(mto_mon_fuerte_ant, 0) +
                                      mto_mon_fuerte,
                 mto_mon_fuerte     = 0
           where cod_persona = p_cod_persona;

          p_respuesta := 'Declaracion Genedada';
        end;

      else
        p_respuesta := 'Cliente no supera limite';
      end if;
    end if;
    if v_msj_error is not null then
      p_respuesta := v_msj_error;
      v_det_error := 'Mov ID: ' ||p_movimiento_id || ' Monto: ' || p_monto ||
                     ' Moneda: ' || p_moneda_bcp || ' Error: Cod. ' ||
                     v_cod_error || '-' || p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_DATOS_DEC_JURADA',
                            v_det_error,
                            p_cod_persona,
                            null);
    end if;
  exception
    when others then
      p_respuesta := sqlerrm;
      v_det_error := 'Mov ID: ' ||p_movimiento_id || ' Monto: ' || p_monto ||
                     ' Moneda: ' || p_moneda_bcp || ' Error: ' ||p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_OBT_DATOS_DEC_JURADA',
                            v_det_error,
                            p_cod_persona,
                            null);

  end pr_obt_datos_dec_jurada;

  ----------------------------------------------------------------------------------------------------------------------------------------
 /*DA-1927  - Generacion de trasferencias SIPAP y movimientos - APN WU*/
  /*nrecalde - Julio2021*/
    procedure pr_gen_apn_tra_sipap( --datos solicitante
                                 p_nom_sol in varchar2, --MARCOS ARIEL
                                 p_ape_sol in varchar2, --YUBERO GARRIDO
                                 --datos beneficiario
                                 p_nom_ben     in varchar2, --RUSTINA
                                 p_ape_ben     in varchar2, --RODRIGUEZ DE GARRIDO
                                 p_nro_doc_ben in varchar2, -- 613869
                                 p_ciu_ben     in varchar2, -- 138
                                 p_est_ben     in varchar2, -- 3
                                 p_cta_ben     in varchar2, --09834449368
                                 p_cod_swf_ben in varchar2, --FAMIPYPA
                                 --datos transf
                                 p_monto                 in ge_snp_transferencias.monto%type,
                                 p_moneda                in ba_monedas.cod_mon_iso%type,
                                 p_cod_mot               in it.ge_apn_datos.cod_mot_transf%type,
                                 p_fec                   in date,
                                 p_mtcn                  in it.ge_apn_datos.cod_mtcn%type,
                                 p_des_motivo            in varchar2,
                                 p_hora                  in varchar2,
                                 p_msgid                 in varchar2,
                                 p_pai_sol               in varchar2,
                                 p_est_transferencia     out varchar2,
                                 p_des_est_transferencia out varchar2,
                                 p_cod_error             out number,
                                 p_msj_error             out varchar2) is

    r_gtran         pas_snp.rg_msj;
    v_cod_mod_padre ge_transacciones.cod_modulo%type := 4;
    v_cod_mad_padre ge_modalidades.cod_modalidad%type := 455;
    v_hora          ge_movimientos.hora%TYPE := p_hora;
    -- v_hora            ge_movimientos.hora%TYPE := to_char(SYSDATE,'hh24:mi:ss');
    v_cod_moneda        ba_monedas.cod_moneda%type;
    v_nro_cuenta_w      ge_cuentas.nro_cuenta%type;
    v_cta_wepa          ge_cuentas.nro_cuenta%type;
    v_tip_cargo         ge_snp_transferencias.tip_cargo%type;
    v_prioridad         ge_snp_transferencias.prioridad%type;
    v_ind_valor         ge_snp_transferencias.ind_valor%type := 'S';
    v_origen            ge_snp_transferencias.origen%type default 'I'; --I = ITGF
    v_plataforma        ge_snp_transferencias.plataforma%type; /*default 'X';*/ -- X = Xadapter
    v_cod_tra_padre     ge_transacciones.cod_transaccion%type := 8506;
    v_mtcn              ge_apn_datos.cod_mtcn%type;
    v_det_error         ge_log_errores.det_error%type;
    v_tip_transf        ge_snp_transferencias.cod_msj_swift%type;/* := 103*/
    v_cod_tip_ope       ge_snp_transferencias.cod_tip_operacion%type := '001';
    v_cod_sub_tip_ope   ge_snp_transferencias.cod_sub_tip_operacion%type := '002';
    v_fec_operacion     date := trunc(sysdate);
    v_fec_actual        date := pag_cal.fu_obt_fec_actual(9); --ge_snp_transferencias.fecha%type := trunc(sysdate);
    v_nro_secuencia     ge_movimientos.nro_secuencia%type := 0;
    v_cod_ofi_ente      ge_cta_clientes.cod_oficina%type;
    v_cod_mod_ente      ge_cta_clientes.cod_modulo%type;
    v_cod_mad_ente      ge_cta_clientes.cod_modalidad%type;
    v_fec_sugerida      date;
    v_existe            varchar2(1);
    v_existe_apn        varchar2(1);
    v_estado            varchar2(1);
    v_error             number;
    v_cod_error         number;
    v_mensaje           varchar2(50);
    v_circuito          varchar2(1);
    v_respuesta         varchar2(2000);
    v_cta_interb        varchar2(50);
    v_hora_existe       varchar2(1);
    v_ok_control        varchar2(1) := 'S';
    moneda              number;
    v_mto_sup           number := fug_obt_pardinamico('OPE_SUP_MON_FUERTE');
    v_monto_GS          number(18, 2);
    v_mon_local         ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_mon_fuerte        ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
    v_mon_bcp           ba_monedas.cod_mon_bco_central%type;
    v_ben_tip_documento ba_personas.cod_tip_documento%type;
    v_msj_error         varchar2(4000);
    v_est_transferencia ge_lis_estados.cod_est%type;
    v_tra_situacion     ge_snp_transferencias.situacion%type;
    v_documento         number;
    --DA-7984
    v_tra_spi           varchar2(1):='N';
    v_tra_spi_ind      varchar2(1) :='N';
    --/*
    v_cta_pte_sol_bcp   varchar2(20);
    v_nro_cta_pte_beneficiario ge_snp_transferencias.nro_cta_pte_beneficiario%type;
    v_mes_sugerida       number(2);
    v_mes_fec_cal        number(2);
    v_cantidad           number(10):=0;
    --TRFS-203
    v_usu_mov            ba_usuarios.cod_usuario%type;
    v_hor_mov            ge_snp_transferencias.hora%type;
    v_aler               varchar2(1) := 'N'; --patrocinador
    v_cod_swift_sub      ge_snp_transferencias.cod_swi_suc_beneficiario%type;
    v_cta_sub            ge_snp_transferencias.nro_cta_suc_pte_beneficiario%type;
    v_cod_swift            ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  begin
    savepoint transferencia;

    if pae_cnf.fu_obt_est_modulo(1) != 2 then
      -- periodo de cierre, no debe poder procesar operacion
         p_cod_error := 1011;
         p_msj_error := fu_bus_men_error(p_cod_error);
         v_msj_error := 'Modulo Cerrado. No se puede operar';
    else
      begin
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 1;
      end;

      --validaciones iniciales para registrar la operacion en ge_snp_transferencias
      --1001 Parametros enviados vacios
      --control del codigo mtcn no venga nulo
      if nvl(p_mtcn, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' endToEndId';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' endToEndId';
      end if;
      --control del monto no venga nulo
      if nvl(p_monto, 0) = 0 then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' paymentAmount';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' paymentAmount';
      end if;
      --control de la cuenta del beneficiario no venga nulo
      if nvl(p_cta_ben, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' accountNumber';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' accountNumber';
      end if;
      --control del nro documento del beneficiario no venga nulo
      if nvl(p_nro_doc_ben, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' id value';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' id value';
      else
        begin
          select to_number(trim(REGEXP_REPLACE(REPLACE(REPLACE(p_nro_doc_ben,
                                                               '-',
                                                               ''),
                                                       '/',
                                                       ''),
                                               '[A-Za-z]*')))
            into v_documento
            from dual;
            if v_documento is null then
                p_cod_error := 1001;
                p_msj_error := fu_bus_men_error(p_cod_error) || ' id value';
                v_msj_error := fu_bus_men_error(p_cod_error) || ' id value';
            end if;
        exception
          WHEN VALUE_ERROR THEN
            p_cod_error := 1001;
            p_msj_error := fu_bus_men_error(p_cod_error) || ' id value';
            v_msj_error := sqlerrm;
          when others then
            p_cod_error := 1001;
            p_msj_error := fu_bus_men_error(p_cod_error) || ' id value';
            v_msj_error := sqlerrm;
        end;
      end if;

      --control del state del beneficiario no venga nulo
      if nvl(p_est_ben, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' state';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' state';
      end if;
      --control de la ciudad del beneficiario no venga nulo
      if nvl(p_ciu_ben, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' city';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' city';
      end if;
      --control de que el nombre del beneficiario no venga nulo
      if nvl(p_nom_ben, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) ||
                       ' creditor firstName';
        v_msj_error := fu_bus_men_error(p_cod_error) ||
                       ' creditor firstName';
      end if;
      --control de que el apellido del beneficiario no venga nulo
      if nvl(p_ape_ben, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) ||
                       ' creditor lastName';
        v_msj_error := fu_bus_men_error(p_cod_error) ||
                       ' creditor lastName';
      end if;
      --control de que la moneda de la operacion no venga nulo
      if nvl(p_moneda, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
      end if;
      --control de que el codigo swift del beneficiario no venga nulo
      if nvl(p_cod_swf_ben, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' bankCode';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' bankCode';
      end if;
      --control del codigo motivo no venga nulo
      if nvl(p_cod_mot, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' purpose code';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' purpose code';
      end if;
      --control de que el nombre del solicitante no venga nulo
      if nvl(p_nom_sol, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) ||
                       ' debitor firstName';
        v_msj_error := fu_bus_men_error(p_cod_error) ||
                       ' debitor firstName';
      end if;
      --control de que el apellido del solicitante no venga nulo
      if nvl(p_ape_sol, 'x') = 'x' then
        p_cod_error := 1001;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' debitor lastName';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' debitor lastName';
      end if;
      --control de que la moneda sea solo gs , usd
      --1013 Parametro enviado no encontrado
      if nvl(p_moneda, 'x') not in ('USD', 'PYG') then
        p_cod_error := 1013;
        p_msj_error := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
        v_msj_error := fu_bus_men_error(p_cod_error) || ' paymentCurrency';
      end if;
      --buscamos si el codigo mtcn ya existe en la tabla de operaciones apn
      begin
        select 'S'
          into v_existe_apn
          from ge_apn_datos a
         where a.cod_mtcn = p_mtcn;
      exception
        when no_data_found then
          v_existe_apn := 'N';
      end;
      --control si ya existe el registro en la tabla de operaciones apn
      --1012 Transaccion duplicada
      if nvl(v_existe_apn, 'N') = 'S' then
        p_cod_error := 1012;
        p_msj_error := fu_bus_men_error(p_cod_error);
        v_msj_error := fu_bus_men_error(p_cod_error);
      end if;
      --Validacion para patrocinadores TCE-442
        
         begin
          select 'S', cod_swift_sub, cta_interna_sub,cod_swift_padre
            into v_aler, v_cod_swift_sub, v_cta_sub,v_cod_swift
            from ge_snp_patrocinador_det
           where cod_swift_sub = p_cod_swf_ben
             and estado = 'S';
         exception
            when no_data_found then
              v_aler := 'N';
         end;
         if v_cod_swift is null and v_aler='N' then
            v_cod_swift:= p_cod_swf_ben;
         end if;
      --valida si la cuenta beneficiaria no esta inhabilitada para recibir transferencias
      if p_cod_swf_ben is not null and p_cta_ben is not null then

         select count(*)
         into v_cantidad
         from ge_snp_cta_restringidas re
         where re.nro_cuenta=p_cta_ben
         and re.cod_swi_entidad=(case v_aler
                                 when 'S' then
                                     v_cod_swift_sub
                                 else
                                     v_cod_swift----TCE-442
                                 end)
         and re.estado='A';

         if v_cantidad>0 then
            p_cod_error := 1015;
            p_msj_error := fu_bus_men_error(p_cod_error);
            v_msj_error := fu_bus_men_error(p_cod_error);
         end if;
            
      end if;
       
      --convertimos la moneda de iso al estandar--
      v_cod_moneda := fue_obt_iso_moneda(p_moneda);

      --se agrega control del monto--
      if v_cod_moneda = v_mon_local then
        v_monto_GS := it.PAL_CAM.FU_CON_MON_A_MONEDA(v_mon_fuerte,
                                                     v_cod_moneda,
                                                     v_mto_sup);
        if p_monto >= v_monto_GS then
          p_cod_error  := 1009;
          p_msj_error  := fu_bus_men_error(p_cod_error);
          v_ok_control := 'N';
          v_msj_error  := fu_bus_men_error(p_cod_error);
        end if;
      else
        if p_monto >= v_mto_sup then
          p_cod_error  := 1009;
          p_msj_error  := fu_bus_men_error(p_cod_error);
          v_ok_control := 'N';
          v_msj_error  := fu_bus_men_error(p_cod_error);
        end if;
      end if;


      if nvl(p_cod_error, 0) = 0 then
        --buscamos las cuenta de debito dependiendo de la moneda de wu
/*        v_nro_cuenta_w := fug_obt_pardinamico(p_parametro     => 'CTA_OP_WESTERN',
                                              p_cod_modulo    => null,
                                              p_cod_modalidad => null,
                                              p_cod_moneda    => v_cod_moneda,
                                              p_cod_oficina   => null);*/

        v_cta_wepa := fug_obt_pardinamico(p_parametro     => 'NRO_CTA_OPE_WEPA',
                                              p_cod_modulo    => null,
                                              p_cod_modalidad => null,
                                              p_cod_moneda    => v_cod_moneda,
                                              p_cod_oficina   => null);

        --control de que la cuenta wu no este nulo
        if nvl(v_cta_wepa, 'x') = 'x' then
          p_cod_error := 1011;
          p_msj_error := fu_bus_men_error(p_cod_error);
          v_msj_error := 'No existe cuenta NRO_CTA_OPE_WEPA en la moneda ' ||
                         v_cod_moneda;
        end if;

        if nvl(p_cod_error, 0) = 0 then
          --si no hay error en las validaciones
          --buscamos el tipo de cargo--
          begin
            select nvl(max(t.val_minimo), 'SHA')
              into v_tip_cargo
              from ba_cod_referencias t
             where t.dominio = 'TIP_CAR_SWIFT'
               and t.val_maximo = 'DEFAULT';
          exception
            when no_data_found then
              v_tip_cargo := 'SHA';
          end;
         --------------------------------------------------------------------------
          /*Proyecto SPI 2022*/
          -- se realiza controles para identificar si corresponde a una transf. SPI
           v_tra_spi:=pas_spi.fu_obt_tra_spi(v_cod_moneda,p_monto,'N',v_cod_swift);
           --DA-7984
            if v_tra_spi ='C' then
             v_tra_spi_ind:='C';--cancelar transferencia
             v_tra_spi:='S';
           elsif v_tra_spi ='R' then
             v_tra_spi_ind:='R';--redireccionar a LBTR/ACH
              v_tra_spi:='S';
           end if;
          --si la transf. es una SPI seteamos las variables necesarias para generar una como tal
          if v_tra_spi = 'S' and nvl(v_tra_spi_ind,'N') not in('R') then--(R)Redireccionar DA-7984
            v_tip_transf               := fug_obt_pardinamico( 'COD_SPI_PCD');
            v_cta_pte_sol_bcp          := pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad), v_cod_moneda);
            v_nro_cta_pte_beneficiario := pas_spi.fu_obt_cta_ban_participante(v_cod_swift, v_cod_moneda) ;--TCE-442
            v_plataforma               := 'S';
            v_cta_interb               := pas_spi.fu_obt_cta_bancaria(v_cta_pte_sol_bcp, 'C');
            v_tip_cargo                := 'OUR';
          else
            v_tip_transf               := 103;
            v_cta_pte_sol_bcp          := pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad), v_cod_moneda);
            v_nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(v_cod_swift, v_cod_moneda) ;--TCE-442
            v_plataforma               := 'X';
            v_cta_interb := pas_snp.fu_obt_cta_bancaria(pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),v_cod_moneda),'C');
          end if;
         ---------------------------------------------------------------------------
          --validamos que la fecha ingresada para la transferencia no sea menor a la fecha del sistema ni superior a los 7 dias habiles posteriores a la misma
        if v_tip_transf != fug_obt_pardinamico( 'COD_SPI_PCD' ) then--pacs.008
          if (pag_cal.FU_OBT_FEC_HABIL(v_fec_operacion, 1, null) > v_fec_operacion) then
            --verifica feriados y fin de semanas
            v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
          elsif (to_char(sysdate, 'hh24:mi') >= fug_obt_pardinamico('SNP_HOR_FIN_MT102') and
                pas_snp.fu_obt_est_horario(v_tip_transf,v_cod_tip_ope, v_cod_sub_tip_ope) = 'A' and
                instr(',' ||
                       trim(fug_obt_pardinamico('SNP_COD_MON_ULT_PERIODO')) || ',',
                       ',' || v_cod_moneda || ',') = 0) or
                (to_char(sysdate, 'hh24:mi') >=
                fug_obt_pardinamico('SNP_HOR_FIN_MT102') and
                pas_snp.fu_obt_est_horario(v_tip_transf,
                                            v_cod_tip_ope,
                                            v_cod_sub_tip_ope) = 'A' and
                instr(',' ||
                       trim(fug_obt_pardinamico('SNP_COD_MON_ULT_PERIODO')) || ',',
                       ',' || v_cod_moneda || ',') > 0 and
                p_monto > fug_obt_pardinamico('SNP_MTO_MAX_ULT_PERIODO'))
               -- Control de Monto Total en el ultimo Periodo de intercambio
                or (to_char(sysdate, 'hh24:mi') >=
                fug_obt_pardinamico('SNP_HOR_FIN_MT102') and
                pas_snp.fu_obt_est_horario(v_tip_transf,
                                               v_cod_tip_ope,
                                               v_cod_sub_tip_ope) = 'A' and
                instr(',' ||
                          trim(fug_obt_pardinamico('SNP_COD_MON_ULT_PERIODO')) || ',',
                          ',' || v_cod_moneda || ',') > 0 and
                /*fug_obt_mto_max_cli_periodo(p_cta_ben,
                                                                                                                                             v_fec_operacion,
                                                                                                                                             v_cod_moneda,*/
                p_monto > fug_obt_pardinamico('SNP_MTO_MAX_CLI_ULT_PERIODO',
                                                  NULL,
                                                  NULL,
                                                  v_cod_moneda,
                                                  NULL)) then
            v_fec_sugerida  := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1),
                                                          NULL);
            v_fec_operacion := v_fec_sugerida;

          else
            if (to_char(sysdate, 'hh24:mi') >
               fug_obt_pardinamico('SNP_HOR_FIN_MT102') and
               pas_snp.fu_obt_est_horario(v_tip_transf,
                                           v_cod_tip_ope,
                                           v_cod_sub_tip_ope) != 'A') then
              v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1),
                                                           NULL);

            else
              v_fec_sugerida := pas_snp.fu_obt_fec_transferencia(v_tip_transf,
                                                                 v_cod_tip_ope,
                                                                 v_cod_sub_tip_ope,
                                                                 v_fec_operacion);
            end if;
          end if;
        else
          --DA-7985
          v_fec_sugerida := pas_snp.fu_obt_fec_transferencia(v_tip_transf,v_cod_tip_ope,v_cod_sub_tip_ope, v_fec_operacion);
         -- v_fec_operacion := v_fec_sugerida;
          v_mes_sugerida        := to_number(to_char(v_fec_sugerida, 'MM'));
          v_mes_fec_cal         := to_number(to_char(v_fec_actual, 'MM'));
          if v_fec_operacion > trunc(sysdate) and v_fec_sugerida > v_fec_operacion then
             v_fec_operacion := v_fec_sugerida;
          end if;
          if v_fec_operacion < v_fec_sugerida and v_mes_sugerida <>  v_mes_fec_cal then
             v_fec_operacion:= trunc(sysdate);
          end if;

        end if;
          -- Valida la fecha ingresada para la transferencia
          if trunc(v_fec_operacion) <> trunc(v_fec_sugerida) and v_tip_transf!= fug_obt_pardinamico( 'COD_SPI_PCD' )/*DA-7985*/ then
            v_fec_operacion := v_fec_sugerida;
          end if;
          --validamos si p_hora viene nulo
          --v_hora := fug_obt_mov_hora;
          --TRFS-203
            prs_snp_obt_usu_hor_mov_apn('APNWEPA',
                                           v_usu_mov,
                                           v_hor_mov);
            v_hora :=  v_hor_mov;
          --buscamos si la transferencia entrara por circuito de aprobacion - WF
          v_circuito := fug_obt_pardinamico(p_parametro     => 'TRA_APN_SNP_WF',
                                            p_cod_modulo    => null,
                                            p_cod_modalidad => null,
                                            p_cod_moneda    => v_cod_moneda,
                                            p_cod_oficina   => null);

          --obtenemos la prioridad
          v_prioridad := fus_snp_obt_prioridad(v_tip_transf,
                                               v_cod_tip_ope,
                                               v_cod_sub_tip_ope);
          if v_aler = 'S' and v_tra_spi = 'S' then  --TCE-442( se sume 002 002 ya que no existe alias para APN)                                
             v_cod_tip_ope:='002';
             v_cod_sub_tip_ope:='002';
          elsif v_aler = 'S' and v_tra_spi = 'N' then  --TCE-442( se sume 001 004 ) 
             v_cod_tip_ope:='001';
             v_cod_sub_tip_ope:='004';
          end if;
          --insertamos el registro en ge_snp_transferencia
          begin
            r_gtran.nro_referencia        := pas_snp.fu_obt_sig_nro_referencia;
            r_gtran.nro_lote              := null;
            r_gtran.nro_sec_lote          := null;
            r_gtran.cod_modulo            := v_cod_mod_padre;
            r_gtran.cod_modalidad         := v_cod_mad_padre;
            r_gtran.cod_oficina           := 61;
            r_gtran.cod_msj_swift         := v_tip_transf;
            r_gtran.cod_tip_operacion     := v_cod_tip_ope;
            r_gtran.cod_sub_tip_operacion := v_cod_sub_tip_ope;
            r_gtran.msj_swift             := null;
            r_gtran.fec_valor             := v_fec_operacion; --paw_bel lin.22994
            --r_gtran.fec_ingreso           := v_fec_actual; --paw_bel lin. 23004
            if r_gtran.cod_msj_swift!= fug_obt_pardinamico( 'COD_SPI_PCD' ) then
               r_gtran.fec_ingreso              := v_fec_actual ;
            else
               r_gtran.fec_ingreso              :=  trunc(sysdate);
            end if;
            r_gtran.fec_recepcion         := null;
            --parametro dinamico si S en el estado = S , parametro N estado = A
            --DA-7984
            if  r_gtran.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD' ) and   nvl(v_tra_spi,'N') = 'S' and nvl(v_tra_spi_ind,'N') = 'C'/*cancelar*/ then
                r_gtran.estado := 'R';
                r_gtran.situacion:='C';
                r_gtran.fecha:= null;
                r_gtran.hora   :=null;
                r_gtran.cod_usuario:=null;
                r_gtran.error:='Transferencia cancelada por entidad emisora fuera de SPI';
            elsif r_gtran.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD' ) and  nvl(v_tra_spi,'N') = 'S' and nvl(v_tra_spi_ind,'N') not in ('C','R')/*no sean Cancelar y redireccionar*/ then
             --r_gtran.fecha  := v_fec_actual;
             --r_gtran.hora   := v_hora;
             --r_gtran.cod_usuario                  := user;
             r_gtran.error                        := null;
             r_gtran.estado := 'U'; --valor para que tome el servicio
             r_gtran.situacion:= 'P';
           else
            if nvl(v_circuito, 'N') = 'S' then
              --r_gtran.fecha  := v_fec_actual;
              --r_gtran.hora   := v_hora;
              --r_gtran.cod_usuario                  := user;
              r_gtran.estado := 'S';
              r_gtran.situacion:= 'P';
              r_gtran.error                        := null;
            else
              --r_gtran.fecha  := v_fec_actual;
              --r_gtran.hora   := v_hora;
              r_gtran.estado := 'A';
               --DA-7984
              --r_gtran.cod_usuario                  := user;
              r_gtran.situacion:= 'P';
              r_gtran.error                        := null;
            end if;
           end if;
            --DA-7984
            --r_gtran.cod_usuario                  := user;
            r_gtran.cod_moneda                   := v_cod_moneda;
            r_gtran.monto                        := p_monto;
            r_gtran.cod_per_solicitante          := it.fug_obt_cli_principal(v_cta_wepa);
            r_gtran.nom_solicitante              := it.fue_obt_nom_persona(r_gtran.cod_per_solicitante);
            r_gtran.dir_solicitante              := it.fue_obt_dir_principa(r_gtran.cod_per_solicitante);
            r_gtran.cod_tip_doc_solicitante      := it.fue_obt_doc_principal(r_gtran.cod_per_solicitante);
            r_gtran.nro_doc_solicitante          := substr(fue_obt_nro_doc_persona(r_gtran.cod_per_solicitante),1,20);
            r_gtran.nro_cta_solicitante          := v_cta_wepa;
            r_gtran.cod_swi_pte_solicitante      := 'COMAPYPA';
            r_gtran.cod_swi_suc_solicitante      := null;
            r_gtran.nro_cta_pte_solicitante      := v_cta_pte_sol_bcp;/*pas_snp.fu_obt_cta_ban_participante(r_gtran.cod_swi_pte_solicitante,r_gtran.cod_moneda);*/
            r_gtran.cod_per_beneficiario         := null;
            r_gtran.nom_beneficiario             := UPPER(p_nom_ben || ' ' || p_ape_ben);
            r_gtran.dir_beneficiario             := null;
            r_gtran.nro_doc_beneficiario         := p_nro_doc_ben;
            r_gtran.nro_cta_beneficiario         := p_cta_ben;
            r_gtran.nro_cta_pte_beneficiario     := v_nro_cta_pte_beneficiario; /*pas_snp.fu_obt_cta_ban_participante(p_cod_swf_ben,r_gtran.cod_moneda);*/
            r_gtran.cod_swi_pte_beneficiario     := v_cod_swift;--p_cod_swf_ben;--TCE-442
            r_gtran.cod_swi_suc_beneficiario     := null;
            r_gtran.nro_cta_suc_pte_beneficiario := null;
            r_gtran.concepto                     := p_mtcn;
            r_gtran.observacion                  := '/BNF/APN';
            if v_tra_spi = 'S' and r_gtran.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_PCD') then
              r_gtran.nro_ref_externa := pas_spi.fu_obt_sig_nro_ref_externa;
            else
            r_gtran.nro_ref_externa              := null;
            end if;
            r_gtran.tip_cargo                    := v_tip_cargo;
            r_gtran.ind_valor                    := v_ind_valor;
            --r_gtran.situacion                    := 'P';
            r_gtran.tip_rechazo                  := null;
            r_gtran.mto_cargo                    := null;
            r_gtran.prioridad                    := v_prioridad;
            r_gtran.nro_operacion                := r_gtran.nro_referencia;
            r_gtran.tip_mensaje                  := 'CRED'; --null;
            --r_gtran.error                        := null;
            r_gtran.cod_usu_transaccion          := null;
            r_gtran.ref_oid                      := null;
            r_gtran.imp_inf_hacienda             := null;
            r_gtran.origen                       := v_origen;
            r_gtran.plataforma                   := v_plataforma;
            r_gtran.indemnizado                  := 'N';
            if v_aler = 'S' then  --TCE-442
              r_gtran.cod_swi_suc_beneficiario     := v_cod_swift_sub;
              r_gtran.nro_cta_suc_pte_beneficiario := v_cta_sub;
              
            end if;
            r_gtran.nro_cta_suc_pte_solicitante  := null;
            
            r_gtran.cod_servicio                 := null;
            r_gtran.usu_insercion                := user;
            r_gtran.usu_modificacion             := user;
            r_gtran.cod_tip_doc_beneficiario     := 1; --se toma por defecto el codigo de doc de la cedula
            pas_snp.pr_ins_transferencias(r_gtran);
          exception
            when others then
              p_cod_error := 1011;
              p_msj_error := fu_bus_men_error(p_cod_error);
              v_msj_error := '1- '||pas_snp.g_msj_error || sqlerrm;
          end;
        END IF;
        --validamos que el nro de referencia sea distinto de null para generar el MT103
        if pas_snp.g_cod_error != 00 then
          p_cod_error := 1011;
          p_msj_error := fu_bus_men_error(p_cod_error);
          v_msj_error := '2- '||pas_snp.g_cod_error || '-' || pas_snp.g_msj_error;
          p_msj_error := p_msj_error || v_msj_error;
        else
          if r_gtran.cod_msj_swift = 103 then
            r_gtran.msj_swift := pas_snp.fu_obt_msj_mt103(r_gtran.nro_referencia,
                                                          'N');
          end if;
          if pas_snp.g_cod_error != 00 then
            p_cod_error := 1011;
            p_msj_error := fu_bus_men_error(p_cod_error);
            v_msj_error := '3- '||pas_snp.g_cod_error || '-' ||
                           pas_snp.g_msj_error;
          else
            --actualiza el set de datos--
            pas_snp.pr_set_transferencias(r_gtran);
          end if;
          --se inserta el registros en datos adicionales--
          begin
            insert into ba_tab_dat_adicionales
              (tab_relacion, referencia, parametro, val_parametro)
            values
              ('GE_SNP_TRANSFERENCIAS',
               r_gtran.nro_referencia,
               'SIB_TRA_MOTIVO',
               p_cod_mot);

          end;
          --buscamos si la tranferencia es para pasar por el worflow--
          begin
            select 'S', a.estado
              into v_existe, v_estado
              from ge_snp_transferencias a
             where a.nro_referencia = r_gtran.nro_referencia;
          exception
            when no_data_found then
              v_existe := 'N';
          end;
          if v_existe = 'S' then
            ---parametro dinamico = S
            if v_circuito = 'S' then
              pas_snp.pr_ini_workflow(r_gtran);
            else
              --si no entra por el workflow
              /*Obtiene datos de la cuenta de la cuenta operativa wu*/
              pag_cta.PR_OBT_CUENTA(v_cta_wepa);
              if pag_cta.G_COD_ERROR = 0 then
                v_cod_ofi_ente := pag_cta.G_CTAS.cod_oficina;
                v_cod_mod_ente := pag_cta.G_CTAS.cod_modulo;
                v_cod_mad_ente := pag_cta.G_CTAS.cod_modalidad;
              end if;
              if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
                p_cod_error := 1011;
                p_msj_error := fu_bus_men_error(p_cod_error);
                v_msj_error := '4- '||pag_cta.G_COD_ERROR || '-' ||
                               pag_cta.G_MSJ_ERROR;
              elsif nvl(v_tra_spi_ind,'N') <>'C' then--que no sea cancelar la transferencia--DA-7984
                begin
                  /*Debito a la cuenta operativa Western*/
                  pag_cta.pr_set_referencia(p_mtcn);
                  pag_cta.pr_set_variables(v_usu_mov,--TRFS-203
                         v_fec_actual,
                         v_cod_tra_padre, 'N', 'N',
                         v_nro_secuencia) ;
                  pag_cta.PR_ACT_OPERACION(v_cta_wepa,
                                           v_hora,
                                           'D',
                                           v_cod_moneda,
                                           p_monto,
                                           v_cod_tra_padre,
                                           503,
                                           r_gtran.nro_referencia,
                                           null,
                                           v_cod_ofi_ente,
                                           v_cod_mod_ente,
                                           v_cod_mad_ente,
                                           null,
                                           null,
                                           'Transferencia SIPAP-APN',
                                           'N',
                                           v_nro_secuencia,
                                           v_fec_actual);

                  if pag_cta.G_COD_ERROR != 00 then
                    p_cod_error := 1011;
                    p_msj_error := fu_bus_men_error(p_cod_error);
                    v_msj_error :='5- '||pag_cta.G_COD_ERROR || '-' ||
                                   pag_cta.G_MSJ_ERROR;
                    rollback to transferencia;
                  else
                    /*Credito al cliente*/
                    pag_cta.pr_set_referencia(p_mtcn);
                    pag_cta.pr_set_variables(v_usu_mov,--TRFS-203
                         v_fec_actual,
                         v_cod_tra_padre, 'N', 'N',
                         v_nro_secuencia) ;
                    pag_cta.PR_ACT_OPERACION(v_cta_interb,
                                             v_hora,
                                             'C',
                                             v_cod_moneda,
                                             p_monto,
                                             v_cod_tra_padre,
                                             602,
                                             r_gtran.nro_referencia,
                                             null,
                                             v_cod_ofi_ente,
                                             v_cod_mod_ente,
                                             v_cod_mad_ente,
                                             null,
                                             null,
                                             'Credito por Transferencia SIPAP-APN',
                                             'N',
                                             v_nro_secuencia,
                                             v_fec_actual);
                    if pag_cta.G_COD_ERROR != 00 then
                      p_cod_error := 1011;
                      p_msj_error := fu_bus_men_error(p_cod_error);
                      v_msj_error := '6- '||pag_cta.G_COD_ERROR || '-' ||
                                     pag_cta.G_MSJ_ERROR;
                      rollback to transferencia;
                    end if;

                  end if;
                exception
                  when others then
                    p_cod_error := 1011;
                    p_msj_error := fu_bus_men_error(p_cod_error);
                    rollback to transferencia;
                end;
              end if;
              --TRFS-203
              -- Se setean los movimientos de transferencias una vez realizados los movimientos de acreditacion/debito
                if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
                    BEGIN
                      -- Actualiza la Transferencia
                      update ge_snp_transferencias gt
                         set gt.fecha       = v_fec_actual,
                             gt.hora        = v_hora,
                             gt.cod_usuario = v_usu_mov
                       where gt.nro_referencia = r_gtran.nro_referencia
                         and gt.cod_msj_swift = r_gtran.cod_msj_swift ;
                      if sql%notfound then
                         p_cod_error := 1011;
                         p_msj_error := fu_bus_men_error(p_cod_error);
                         rollback to transferencia;
                      end if;
                 END;
                end if;

            end if;
          end if;
        end if;
        /*verificamos si la transferencia califica para ser enviada al socket*/
        --se envia solo si no entro por el wf , con estado A y el periodo abierto
        if nvl(p_cod_error, 0) = 0 and
           pas_snp.fu_obt_est_horario(v_tip_transf,
                                      v_cod_tip_ope,
                                      v_cod_sub_tip_ope) = 'A' and
           v_estado = 'A' and nvl(v_circuito, 'N') = 'N' then--TRFS-671
          pas_snp.pr_gen_arc_swift(r_gtran.nro_referencia, 'N', v_estado);
          if pas_snp.g_cod_error != 00 then
            p_cod_error := 1011;
            p_msj_error := fu_bus_men_error(p_cod_error);
            v_msj_error := '7- '||pas_snp.g_cod_error || '-' ||
                           pas_snp.g_msj_error;
          end if;
        end if;
      end if;
      if nvl(p_cod_error, 0) = 0 then
        begin
          /**Busca estado de la transferencia */
          select t.situacion
            into v_tra_situacion
            from ge_snp_transferencias t
           where t.nro_referencia = r_gtran.nro_referencia;

          if v_tra_situacion = 'L' then
            v_est_transferencia := 'ACTC';
          elsif v_tra_situacion in ('P', 'V', 'O', 'S', 'D')  then
            v_est_transferencia := 'PNDG';
          elsif v_tra_situacion in ('C', 'T')  then
            v_est_transferencia := 'RJCT';
             p_cod_error := 1011;
             p_msj_error := fu_bus_men_error(p_cod_error);
             v_msj_error := 'Error en la transferencia '||r_gtran.nro_referencia;
          end if;
        exception
          when others then
            p_cod_error := 1011;
            p_msj_error := fu_bus_men_error(p_cod_error);
            v_msj_error := 'Error al obtener transferencia ' ||
                           r_gtran.nro_referencia;
        end;
      end if;
      --datos para la tabla de operaciones ge_apn_datos
      if nvl(p_cod_error, 0) = 0 and nvl(v_ok_control, 'S') = 'S' then
        p_est_transferencia     := v_est_transferencia;
        p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
        p_cod_error             := 0;
        p_msj_error             := fu_bus_men_error(p_cod_error);
      elsif nvl(p_cod_error, 0) != 0 and nvl(v_ok_control, 'S') = 'S' then
        r_gtran.nro_referencia := null;
        p_est_transferencia     := 'RJCT';
        p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
      elsif nvl(v_ok_control, 'S') = 'N' then
        r_gtran.nro_referencia := null;
        p_est_transferencia     := 'FAIL';
        p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
      end if;

      if nvl(p_cod_error, 0) != 0 and  nvl(v_tra_spi_ind,'N') <>'C' then--que no sea cancelar la transferencia DA-7984
        /*Si existe un error en la insercion en la tabla de operaciones APN deshace la operacion*/
        rollback to transferencia;
      end if;

      --insertamos en la tabla de control de operaciones APN para seguimientos de estados de transf--
      pr_ins_dat_apn(p_mtcn, --mtcn
                     r_gtran.nro_referencia, --referencia
                     sysdate, --fecha operacion
                     null, --estado notificado
                     null, --fecha notificado
                     null, --cod. error notificacion
                     null, --sub cod. error notificacion
                     null, --descripcion error notificacion
                     p_est_transferencia, --estado transferencia
                     p_cod_error, --error operacion
                     p_nom_sol,
                     p_ape_sol,
                     p_nom_ben,
                     p_ape_ben,
                     p_ciu_ben,
                     p_est_ben,
                     p_nro_doc_ben,
                     p_cta_ben,
                     p_monto,
                     p_moneda, --formato iso
                     p_cod_mot,
                     p_cod_swf_ben,
                     p_des_motivo,
                     p_msgid,
                     p_pai_sol,
                     v_error,
                     v_respuesta);
      if nvl(v_error, 0) != 0 and nvl(p_cod_error, 0) = 0 then
        r_gtran.nro_referencia := null;
        p_est_transferencia     := 'RJCT';
        p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
        p_cod_error             := 1011;
        p_msj_error             := fu_bus_men_error(p_cod_error);
        v_msj_error             := v_respuesta || ' - ' || v_error;
        /*Si no pudo insertar en ge_apn_datos hacemos rollback*/
        rollback to transferencia;
      end if;

      if nvl(v_error, 0) != 0 or p_cod_error != 0 then
        v_det_error := substr('MTCN ' || p_mtcn || ' Nombre Solic. ' ||
                              p_nom_sol || ' Apellido Solic. ' || p_ape_sol ||
                              ' Nombre Benef. ' || p_nom_ben ||
                              ' Apellido Benef.' || p_ape_ben ||
                              'Doc Benef' || p_nro_doc_ben ||
                              ' Ciudad Benef.' || p_ciu_ben ||
                              ' Est. Benef ' || p_est_ben ||
                              ' Cuenta Benef ' || p_cta_ben ||
                              ' Cod Swift Benef ' || p_cod_swf_ben ||
                              ' Monto Transf ' || p_monto || ' Moneda ' ||
                              p_moneda || ' Motivo Transf ' || p_cod_mot ||
                              ' Fecha ' || p_fec || ' Error: ' ||
                              v_msj_error || '-' || v_respuesta,
                              1,
                              4000);
        PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_APN_TRA_SIPAP',
                              v_det_error,
                              null,
                              p_cta_ben);
      end if;
    end if;

  exception
    when others then
      p_est_transferencia     := 'RJCT';
      p_des_est_transferencia := fu_obt_men_estado(p_est_transferencia);
      p_cod_error             := 1011;
      p_msj_error             := fu_bus_men_error(p_cod_error);
      v_msj_error             := '8- '||DBMS_UTILITY.format_error_backtrace || ' ' ||
                                 DBMS_UTILITY.format_error_stack;

      pr_ins_dat_apn(p_mtcn, --mtcn
                     r_gtran.nro_referencia, --referencia
                     sysdate, --fecha operacion
                     null, --estado notificado
                     null, --fecha notificado
                     null, --cod. error notificacion
                     null, --sub cod. error notificacion
                     null, --descripcion error notificacion
                     p_est_transferencia, --estado transferencia
                     p_cod_error, --error operacion
                     p_nom_sol,
                     p_ape_sol,
                     p_nom_ben,
                     p_ape_ben,
                     p_ciu_ben,
                     p_est_ben,
                     p_nro_doc_ben,
                     p_cta_ben,
                     p_monto,
                     p_moneda, --formato iso
                     p_cod_mot,
                     p_cod_swf_ben,
                     p_des_motivo,
                     p_msgid,
                     p_pai_sol,
                     v_error,
                     v_respuesta);

      v_det_error := substr('MTCN ' || p_mtcn || ' Nombre Solic. ' ||
                            p_nom_sol || ' Apellido Solic. ' || p_ape_sol ||
                            ' Nombre Benef. ' || p_nom_ben ||
                            ' Apellido Benef. ' || p_ape_ben ||
                            ' Doc Benef ' || p_nro_doc_ben ||
                            ' Ciudad Benef. ' || p_ciu_ben ||
                            ' Est. Benef ' || p_est_ben || ' Cuenta Benef ' ||
                            p_cta_ben || ' Cod Swift Benef ' ||
                            p_cod_swf_ben || ' Monto Transf ' || p_monto ||
                            ' Moneda ' || p_moneda || ' Motivo Transf ' ||
                            p_cod_mot || ' Fecha ' || p_fec || ' Error: ' ||
                            sqlerrm,
                            1,
                            4000);
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_APN_TRA_SIPAP',
                            v_det_error,
                            null,
                            p_cta_ben);

  end pr_gen_apn_tra_sipap;

  /*DA-1699  - Reversion de operaciones - WU*/
  /*nrecalde -  Junio2021*/
  procedure pr_gen_rev_operaciones(p_referencia in varchar2,
                                   p_cod_error  out number,
                                   p_msj_error  out varchar2) is

    v_fecha             ge_movimientos.fecha%type;
    v_hora              ge_movimientos.hora%type;
    v_usuario           ge_movimientos.cod_usuario%type;
    v_cod_mod_padre     ge_movimientos.cod_mod_padre%type;
    v_cod_mad_padre     ge_movimientos.cod_mad_padre%type;
    v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;
    v_existe            varchar2(1);
    v_det_error         ge_log_errores.det_error%type;
    v_nro_caja          ge_movimientos.nro_caja%type;
    v_nro_documento     ge_movimientos.nro_documento%type;
    v_concepto          ge_movimientos.concepto%type;
    v_respuesta         varchar2(300);
    v_cod_tra_padre_cja ge_movimientos.cod_tra_padre%type;
    v_hora_rev          ge_movimientos.hor_reversion%type;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    begin
      select 'S',
             t.fecha,
             t.hora,
             t.cod_usuario,
             t.cod_mod_padre,
             t.cod_mad_padre,
             t.cod_tra_padre,
             t.nro_caja,
             t.nro_documento,
             t.concepto
        into v_existe,
             v_fecha,
             v_hora,
             v_usuario,
             v_cod_mod_padre,
             v_cod_mad_padre,
             v_cod_tra_padre,
             v_nro_caja,
             v_nro_documento,
             v_concepto
        from ge_movimientos t
       where t.reversado = 'N'
         and rownum = 1
            /*and t.referencia = p_referencia */
         and t.nro_documento = p_referencia; --hace referencia al movimiento id
    exception
      when no_data_found then
        v_existe    := 'N';
        p_cod_error := 1;
        p_msj_error := 'Error al buscar el movimiento a reversar';

    end;
    savepoint reversion;
    --se llama al procedimiento para reversar las operaciones en el caso que exista el movimiento
    if v_existe = 'S' then
      begin
        v_hora_rev := fug_obt_mov_hora;
        it.prg_rev_operacion(p_fecha             => v_fecha,
                             p_hora              => v_hora,
                             p_cod_usuario       => v_usuario,
                             p_cod_mod_padre     => v_cod_mod_padre,
                             p_cod_mad_padre     => V_cod_mad_padre,
                             p_cod_tra_padre     => v_cod_tra_padre,
                             p_cod_usu_reversion => substr(user, 1, 10),
                             p_hor_reversion     => v_hora_rev/*to_char(sysdate,
                                                            'HH24:MI:SS')*/,
                             p_es_nocturno       => 'N',
                             p_concepto          => 'Reversion Fielcorresponsal',
                             p_nro_ncredito      => null);

        if v_nro_caja is not null then
          --reversion de operaciones de caja
          begin
            select g.cod_tra_padre
              into v_cod_tra_padre_cja
              from cj_movimientos g
             where g.nro_documento = p_referencia
               and g.cod_mod_padre = 9
               and g.cod_mad_padre = 91
               and rownum = 1;
          exception
            when no_data_found then
              p_cod_error := 4;
              p_msj_error := 'Error al buscar el movimiento en caja a reversar';
              rollback to reversion;
            when others then
              p_cod_error := 5;
              p_msj_error := 'Error al buscar el movimiento en caja a reversar';
              rollback to reversion;
          end;

          if nvl(p_cod_error, 0) = 0 then
            begin
              v_respuesta := it.fuj_pro_transaccion_200(p_referencia,
                                                        v_nro_caja,
                                                        v_cod_tra_padre_cja,
                                                        v_nro_documento,
                                                        v_hora,
                                                        'Reversion de ' ||
                                                        v_concepto);

              p_cod_error := 0;
              p_msj_error := v_respuesta;
            exception
              when others then
                p_cod_error := 3;
                p_msj_error := 'Error en el proceso de Reversas operaciones de caja -' ||
                               sqlerrm;
                rollback to reversion;
            end;
          end if;
        end if;

        Begin
           Update bw_pag_servicios b
              set reversado ='S'
            where b.nro_transaccion = p_referencia
              and b.fecha    = v_fecha
              and b.hora     = v_hora
              and b.red_pago in (3,5);

              p_cod_error := 0;
              p_msj_error := 'Se ha generado los movimientos de reversas';
          Exception
              when others then
                p_cod_error := 2;
                p_msj_error := 'Error en el proceso de Reversas';
                v_det_error := substr('Error en el proceso de Reversas ' ||
                                      DBMS_UTILITY.format_error_stack || ' - ' ||
                                      DBMS_UTILITY.format_error_backtrace,
                                      1,
                                      4000);
                rollback to reversion;
          End;

        if  nvl( p_cod_error, 0) = 0 then
            p_cod_error := 0;
            p_msj_error := 'Se ha generado los movimientos de reversas';
        End if;
      exception
        when others then
          p_cod_error := 2;
          p_msj_error := 'Error en el proceso de Reversas -' || sqlerrm;
      end;
    end if;

    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Referencia : ' || p_referencia || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_REV_OPERACIONES',
                            v_det_error,
                            null,
                            null);
    end if;
  exception
    when others then
      p_cod_error := 3;
      p_msj_error := sqlerrm;
      v_det_error := 'Referencia : ' || p_referencia || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_REV_OPERACIONES',
                            v_det_error,
                            null,
                            null);
  end pr_gen_rev_operaciones;
  /*procedimiento que retorna usuario para evitar error de pk en ge_movimientos*/
  procedure pr_obt_usu_hor_rev_wepa(p_usuario    in varchar2,
                                    p_usu_mov    out varchar2,
                                    p_hor_mov    out varchar2)  is
  v_tip_operacion       varchar2(10):='REV';
  v_tip_reversa         ba_cod_referencias.val_maximo%type;
  v_val_minimo          ge_par_dinamicos.val_parametro%type;
  v_val_maximo          ge_par_dinamicos.val_parametro%type;
  v_par_minimo          ge_parametros.parametro%type;
  v_par_maximo          ge_parametros.parametro%type;
  v_can_registro        number(5):=0;
  v_secuencia           varchar2(100);

  begin

        v_tip_reversa:=FUE_OBT_VAL_MAX_REFERENCIA('USU_REV_WEPA',p_usuario);
         --se obtiene el nombre de los parametros de la cant. minima y maxima
        v_par_minimo:= v_tip_reversa||'_CAN_MIN_USU_'||v_tip_operacion;
        v_par_maximo:= v_tip_reversa||'_CAN_MAX_USU_'||v_tip_operacion;
        --se obtiene el valor minimo y maximo para la generacion de usuarios y secuencias
        v_val_minimo:=nvl(fug_obt_pardinamico(v_par_minimo),1);
        v_val_maximo:=nvl(fug_obt_pardinamico(v_par_maximo),5);

        ---se obtiene el usuario
        p_usu_mov:=v_tip_reversa||round(dbms_random.value(v_val_minimo,v_val_maximo));
        --se valida si el usuario esta registrado en ba_usuarios
        select count(*)
        into v_can_registro
        from ba_usuarios us
        where us.cod_usuario=p_usu_mov;

        if v_can_registro=0 then
            p_usu_mov:=p_usuario;
            p_hor_mov:=to_char(sysdate,'HH24:MI:SS');
           return;
        end if;
        --se obtiene la secuencia para generar la hora del movimiento
         v_secuencia:='S_HOR_MOV_REV_'||v_tip_reversa||'_'||p_usu_mov;
        --se obtiene la hora en base a la secuencia
        p_hor_mov:=fuw_obt_mov_hora(v_secuencia);
  exception
       when others then
           p_usu_mov:=p_usuario;
           p_hor_mov:=to_char(sysdate,'HH24:MI:SS');
  end pr_obt_usu_hor_rev_wepa;
    /*procedimiento para reversar movimiento WEPA*/
  procedure pr_gen_rev_ope_wepa(p_mov_id    in varchar2,
                                p_cod_error out number,
                                p_msj_error out varchar2) is

    v_fecha                 ge_movimientos.fecha%type;
    v_hora                  ge_movimientos.hora%type;
    v_usuario               ge_movimientos.cod_usuario%type;
    v_cod_mod_padre         ge_movimientos.cod_mod_padre%type;
    v_cod_mad_padre         ge_movimientos.cod_mad_padre%type;
    v_cod_tra_padre         ge_movimientos.cod_tra_padre%type;
    v_existe                varchar2(1);
    v_det_error             ge_log_errores.det_error%type;
    v_nro_documento         ge_movimientos.nro_documento%type;
    v_concepto              ge_movimientos.concepto%type;
    v_hora_reversion        ge_movimientos.hor_reversion%type;
    v_usu_reversion         ba_usuarios.cod_usuario%type;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    begin
      select 'S',
             t.fecha,
             t.hora,
             t.cod_usuario,
             t.cod_mod_padre,
             t.cod_mad_padre,
             t.cod_tra_padre,
             t.nro_documento,
             t.concepto
        into v_existe,
             v_fecha,
             v_hora,
             v_usuario,
             v_cod_mod_padre,
             v_cod_mad_padre,
             v_cod_tra_padre,
             v_nro_documento,
             v_concepto
        from ge_movimientos t
       where t.reversado = 'N'
         and rownum = 1
         and t.nro_documento = p_mov_id;--ver como guarda
    exception
      when no_data_found then
        v_existe    := 'N';
        p_cod_error := 1;
        p_msj_error := 'Error al buscar el movimiento a reversar';

    end;
    savepoint reversion;
    --se llama al procedimiento para reversar las operaciones en el caso que exista el movimiento
    if v_existe = 'S' then
      begin
       /*procedimiento que retorna usuario para evitar error de pk en ge_movimientos*/
        pr_obt_usu_hor_rev_wepa('WEPACNB',v_usu_reversion,v_hora_reversion);
        it.prg_rev_operacion(p_fecha             => v_fecha,
                             p_hora              => v_hora,
                             p_cod_usuario       => v_usuario,
                             p_cod_mod_padre     => v_cod_mod_padre,
                             p_cod_mad_padre     => V_cod_mad_padre,
                             p_cod_tra_padre     => v_cod_tra_padre,
                             p_cod_usu_reversion => v_usu_reversion,
                             p_hor_reversion     => v_hora_reversion,
                             p_es_nocturno       => 'N',
                             p_concepto          => 'REVERSION WEPA',
                             p_nro_ncredito      => null);
        p_cod_error := 0;
        p_msj_error := 'Se ha generado los movimientos de reversas WEPA';
      exception
        when others then
          p_cod_error := 2;
          p_msj_error := 'Error en el proceso de reversa WEPA -' || sqlerrm;
         rollback;
      end;

    end if;

    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Referencia : ' || p_mov_id || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_REV_OPE_WEPA',
                            v_det_error,
                            null,
                            null);
    end if;
  exception
    when others then
      p_cod_error := 3;
      p_msj_error := sqlerrm;
      v_det_error := 'Referencia : ' || p_mov_id || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_REV_OPE_WEPA',
                            v_det_error,
                            null,
                            null);
  end pr_gen_rev_ope_wepa;

  procedure pr_gen_pag_ser_app(p_cod_serv    in number,
                               p_cod_proc    in number,
                               p_monto_op    in number,
                               p_moneda      in number,
                               p_mov_id      in varchar2,
                               p_cta_ahorro  in varchar2,
                               p_error       out number,
                               p_respuesta   out varchar2) is
    /*Detalle de parametros
    p_cod_serv:  Codigo del servicio de la tabla RAALIB.operaciones
    p_cod_proc:  Codigo de la procesadora de la tabla RAALIB.op_procesadora_canal
    p_monto_op:  Monto de pago del servicio
    p_moneda:    Moneda de pago del servicio
    p_mov_id:    Movimiento id tabla RAALIB.movimiento
    p_cod_persona:Codigo de persona del cliente.
    p_cta_ahorro : Cuenta de ahorro del cliente que opera desde el HB o APP
    p_error :     Codigo de error de salida
    p_respuesta:  Mensaje de respuesta de salida
    */
    r_gmovi               ge_movimientos%ROWTYPE;
    v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_cod_mon_fuerte      ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
    v_nro_cuenta_b        ge_movimientos.nro_cuenta%type; --cuenta operativa bancard
    v_nro_cuenta_fielcob  ge_movimientos.nro_cuenta%type; --cuenta operativa fielcobranzas
    v_hora_actual         VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS');
    v_cod_transaccion_deb NUMBER(4);
    v_cod_transaccion_cre NUMBER(4);
    v_cod_tra_padre       NUMBER(4);
    v_tra_comision        NUMBER(4);
    v_codigo_modulo       NUMBER(3) := 4;
    v_codigo_modalidad    NUMBER(3) := 43;
    v_numero_secuencia    NUMBER(3) := 0;
    v_fecha_actual        DATE := it.pag_cal.fu_obt_fec_actual(v_codigo_modulo);
    v_hora                ge_movimientos.hora%TYPE; /*:= to_char(SYSDATE,
                                                              'hh24:mi:ss');*/
    v_cal_iva             NUMBER;
    v_redondeo            NUMBER := 0;
    v_cod_persona         ba_personas.cod_persona%type;
    v_moneda              ba_monedas.cod_moneda%type := it.fue_obt_mon_bcp(p_moneda);
    v_cod_moneda          ba_monedas.cod_moneda%type;
    v_cod_ente            ge_entes.cod_ente%type;
    v_cod_tasa_fielcob    ge_tasas.cod_tasa%type;
    v_fecha_vig           ge_tas_fechas.fec_vigencia%TYPE;
    v_tip_valor           ge_tasas.tip_valor%TYPE;
    v_tipo_tasa           ge_tasas.tipo%TYPE;
    v_valor_com           ge_movimientos.monto%type;
    v_comision            ge_movimientos.monto%type;
    v_mon_cre             ge_movimientos.monto%type;
    v_val_tasa            ge_tas_fechas.val_tasa%type := 10;
    v_desc_servicio       ba_cod_referencias.significado%type;
    v_tip_cuenta          number(3); -- tipo de cuenta(modalidad)
    v_mod_padre           number(5) := 4;  -- Modulo    Padre Débito
    v_mad_padre           number(5) := 43; -- Modalidad Padre Débito
    v_nro_caja            ge_par_dinamicos.parametro%TYPE := fug_obt_pardinamico('NRO_CAJA_TRA_COBRO');
    v_det_error           ge_log_errores.det_error%type;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    if pae_cnf.fu_obt_est_modulo(1) != 2 then
      p_error     := 99;
      p_respuesta := 'Modulo Cerrado. No se puede operar';
    else
    savepoint pago_app;
    if nvl(p_cod_proc, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Ingresar codigo de procesadora - ' || p_cod_proc;
    end if;
    if nvl(p_cod_serv, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Ingresar codigo de servicio- ' || p_cod_serv;
    end if;
    --Validaciones
    if nvl(p_monto_op, 0) = 0 then
      p_error     := 2;
      p_respuesta := 'Ingresar Monto operacion - ' || p_monto_op;
    end if;
    --Recupera la descripcion del servicio
    begin
      select significado
        into v_desc_servicio
        from ba_cod_referencias
       where dominio = 'DES_OPE_COB_SER'
         and val_minimo = p_cod_serv;
    exception
      when no_data_found then
        p_error     := 2;
        p_respuesta := 'Error al recuperar referencia de servicio - ' ||
                       p_cod_serv;
      when others then
        p_error     := 2;
        p_respuesta := 'Error al recuperar descripcion del servicio - ' ||
                       p_cod_serv;

    end;
    if p_cta_ahorro is null then
      p_error     := 1;
      p_respuesta := 'Ingresar cuenta de ahorro vista';
      rollback to pago_app;
    else
      begin
      select cod_modalidad
        into v_tip_cuenta
        from ge_cuentas a
       where a.nro_cuenta = p_cta_ahorro;
       exception
        when no_data_found then
          p_error     := 2;
          p_respuesta := 'No se encuentra cta de ahorro';
          rollback to pago_app;
        when others then
          p_error     := 2;
          p_respuesta := 'No se encuentra cta de ahorro';
          rollback to pago_app;
       end;
      --TBI-1077 - se agrega la modalidad 41
      if v_tip_cuenta not in (31,38,39,334, 41) then
        p_error     := 2;
        p_respuesta := 'Tipo de cuenta no permite operaciones';
        rollback to pago_app;
      end if;
    end if;
    begin
      select per.cod_persona
        into v_cod_persona
        from ba_personas per, ge_cta_clientes cta
       where per.cod_persona = cta.cod_persona
         and nro_cuenta = p_cta_ahorro
         and relacion = 'P';
    exception
      when no_data_found then
        p_error     := 2;
        p_respuesta := 'Inconveniente al validar cuenta persona con cuenta de ahorro';
      when others then
        p_error     := 2;
        p_respuesta := 'Inconveniente al validar cuenta de ahorro';
    end;
    v_cod_tra_padre       := 8526;
    v_cod_transaccion_deb := 8527;
    v_cod_transaccion_cre := 8016;
    --Recupera la cuenta del cnb de acuerdo a la moneda que se recibe
    IF v_moneda = v_cod_mon_local THEN
      v_cod_moneda := it.pag_gen.fu_obt_mon_local;
    ELSIF v_moneda = v_cod_mon_fuerte THEN
      v_cod_moneda := it.pag_gen.fu_obt_mon_fuerte;
    END IF;
    v_hora:= fug_obt_mov_hora; /*it.fug_obt_hor_disponible(v_fecha_actual,
                                       v_hora_actual,
                                       USER,
                                       'N');*/
    --Analiza por procesadora-parametro p_cod_proc
    --  1 Fielcobranzas
    --  3 Bancard
    /*********************************************/
    /*******Pago de servicio POR BANCARD *********/
    /*********************************************/
    if p_cod_proc = 3 then
      --Aqui genera operacion y movimiento cuando es por BANCARD
      --Recupera por parametro dinamico la cuenta operativa de bancard por moneda
      v_nro_cuenta_b := fug_obt_pardinamico(p_parametro     => 'CTA_OP_BANCARD',
                                            p_cod_modulo    => null,
                                            p_cod_modalidad => null,
                                            p_cod_moneda    => v_moneda,
                                            p_cod_oficina   => null);
      --Debito cta ahorro
      pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
      pag_cta.pr_set_nro_documento3(1);
      pag_cta.pr_set_referencia(p_referencia => p_mov_id);
      pag_cta.pr_nro_caja(p_nro_caja => v_nro_caja);
      pag_cta.pr_act_operacion(p_nro_cuenta      => p_cta_ahorro,
                               p_hora            => v_hora,
                               p_tip_movimiento  => 'D',
                               p_cod_moneda      => v_cod_moneda,
                               p_monto           => p_monto_op,
                               p_cod_tra_padre   => v_cod_tra_padre,
                               p_cod_transaccion => v_cod_transaccion_deb,
                               p_nro_documento   => p_mov_id,
                               p_cotizacion      => null,
                               p_cod_ofi_origen  => 61,
                               p_cod_mod_padre   => v_mod_padre,
                               p_cod_mad_padre   => v_mad_padre,
                               p_cod_tasa        => null,
                               p_val_tasa        => null,
                               p_concepto        => 'Debito pago servicio',
                               p_emi_aviso       => 'N',
                               p_nro_secuencia   => v_numero_secuencia,
                               p_fec_valor       => trunc(sysdate),
                               p_cod_banco       => null,
                               p_cod_causa       => null,
                               p_mto_equ_local   => null);
      if pag_cta.g_cod_error <> 0 then
        -- actualizacion con problemas
        p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
        p_respuesta := pag_cta.g_msj_error;
      else
        --Credito pago servicio
        pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
        pag_cta.pr_set_nro_documento3(1);
        pag_cta.pr_set_referencia(p_referencia => p_mov_id);
        pag_cta.pr_nro_caja(p_nro_caja => v_nro_caja);
        pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_b,
                                 p_hora            => v_hora,
                                 p_tip_movimiento  => 'C',
                                 p_cod_moneda      => v_cod_moneda,
                                 p_monto           => p_monto_op,
                                 p_cod_tra_padre   => v_cod_tra_padre,
                                 p_cod_transaccion => v_cod_transaccion_cre,
                                 p_nro_documento   => p_mov_id,
                                 p_cotizacion      => null,
                                 p_cod_ofi_origen  => 61,
                                 p_cod_mod_padre   => v_codigo_modulo,
                                 p_cod_mad_padre   => v_codigo_modalidad,
                                 p_cod_tasa        => null,
                                 p_val_tasa        => null,
                                 p_concepto        => 'Credito pago servicio Bancard',
                                 p_emi_aviso       => 'N',
                                 p_nro_secuencia   => v_numero_secuencia,
                                 p_fec_valor       => trunc(sysdate),
                                 p_cod_banco       => null,
                                 p_cod_causa       => null,
                                 p_mto_equ_local   => null);
        if pag_cta.g_cod_error <> 0 then
          -- actualizacion con problemas
          p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
          p_respuesta := pag_cta.g_msj_error;
        else
          begin
            insert into bw_pag_servicios
              (nro_cuenta,
               cod_servicio,
               fecha,
               hora,
               nro_transaccion,
               nro_lote,
               ip_usuario,
               terminal,
               cod_moneda,
               mto_transaccion,
               mto_comision,
               mto_mora,
               mto_interes,
               reversado,
               mto_debito,
               cod_mon_servicio,
               red_pago,
               des_servicio,
               par_enviados)
            VALUES
              (p_cta_ahorro,
               p_cod_serv,
               v_fecha_actual,
               v_hora,
               p_mov_id,
               0,
               null,
               null,
               v_cod_moneda,
               p_monto_op,
               null,
               null,
               null,
               'N',
               p_monto_op,
               null,
               3,
               v_desc_servicio,
               null);
          exception
            when others then
              p_error     := 9;
              p_respuesta := 'Error al procesar transaccion' || sqlerrm;
               rollback to pago_app;
          end;
        end if;
      end if;
      if p_error <> 0 then
         rollback to pago_app;
      else
        p_error     := 0;
        p_respuesta := 'Operacion Confirmada';
      end if;
    elsif p_cod_proc = 1 then

      /*********************************************/
      /****Pago de servicio POR FIELCOBRANZAS ******/
      /*********************************************/
      --Debito Pago de Servio CNB por fielcobranzas
      v_cod_tra_padre       := 8526;
      v_cod_transaccion_deb := 8527;
      v_cod_transaccion_cre := 8016;
      v_tra_comision        := 8520;
      pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
      pag_cta.pr_set_nro_documento3(1);
      pag_cta.pr_set_referencia(p_referencia => p_mov_id);
      pag_cta.pr_nro_caja(p_nro_caja => v_nro_caja);
      pag_cta.pr_act_operacion(p_nro_cuenta      => p_cta_ahorro,
                               p_hora            => v_hora,
                               p_tip_movimiento  => 'D',
                               p_cod_moneda      => v_cod_moneda,
                               p_monto           => p_monto_op,
                               p_cod_tra_padre   => v_cod_tra_padre,
                               p_cod_transaccion => v_cod_transaccion_deb,
                               p_nro_documento   => p_mov_id,
                               p_cotizacion      => null,
                               p_cod_ofi_origen  => 61,
                               p_cod_mod_padre   => v_mod_padre,
                               p_cod_mad_padre   => v_mad_padre,
                               p_cod_tasa        => null,
                               p_val_tasa        => null,
                               p_concepto        => 'Debito pago servicio',
                               p_emi_aviso       => 'N',
                               p_nro_secuencia   => v_numero_secuencia,
                               p_fec_valor       => trunc(sysdate),
                               p_cod_banco       => null,
                               p_cod_causa       => null,
                               p_mto_equ_local   => null);
      if pag_cta.g_cod_error <> 0 then
        -- actualizacion con problemas
        p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
        p_respuesta := pag_cta.g_msj_error;
      else

        --Busca el ente y la cuenta operativa definida en ge_par_entes
        --Primero buscv_nro_cuenta_fielcoba el codigo del servicio en el parametro COD_SER_COBSER
        begin
          select cod_ente
            into v_cod_ente
            from ge_par_entes
           where parametro = 'COD_SER_FIELCO'
             and val_parametro = p_cod_serv;
        exception
          when no_data_found then
            p_error     := 5;
            p_respuesta := 'Ente no Registrado para el servicio.' ||
                           p_cod_serv;
          when others then
            p_error     := 5;
            p_respuesta := 'Ente no Registrado para el servicio.' ||
                           p_cod_serv;
        end;
        --Aqui busca la cuenta operativa del servicio ( fielcobranzas)
        v_nro_cuenta_fielcob := it.fug_obt_parentes(v_cod_ente,
                                                    'CTA_OP_FIELCOBRANZAS');

        --Aqui busca la tasa de la comision si corresponde
        v_cod_tasa_fielcob := it.fug_obt_parentes(v_cod_ente,
                                                  'COD_TASA_FIELCOBRANZAS');

        if v_cod_tasa_fielcob is not null then

          -- Si tiene configurado tasa para comision, entonces generar movimiento por comision e IVA

          --Valor de tasa
          pag_gen.pr_obt_val_tasa(null,
                                  null,
                                  1,
                                  null,
                                  v_cod_moneda,
                                  null,
                                  null,
                                  v_cod_tasa_fielcob,
                                  null,
                                  null,
                                  v_valor_com,
                                  v_fecha_vig,
                                  v_tip_valor,
                                  v_tipo_tasa);

          IF v_tip_valor = 'P' THEN
            -- procentaje
            v_comision := round(p_monto_op * v_valor_com / 100, 0);
          ELSE
            -- valor --
            v_comision := v_valor_com;
          END IF;
          -- Monto IVA
          v_cal_iva := round(nvl(v_comision, 0) * (v_val_tasa / 100),
                             v_redondeo);
          --calcula el monto del credito
          v_mon_cre := p_monto_op -
                       (nvl(v_comision, 0) + nvl(v_cal_iva, 0));
          begin
            --- insertamos en ge movimientos
            v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fecha_actual;
            r_gmovi.nro_secuencia   := v_numero_secuencia;
            r_gmovi.nro_cuenta      := null;
            r_gmovi.cod_persona     := v_cod_persona;
            r_gmovi.cod_modulo      := v_codigo_modulo;
            r_gmovi.cod_modalidad   := v_codigo_modalidad;
            r_gmovi.cod_oficina     := 61;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.fec_valor       := trunc(sysdate);
            r_gmovi.cod_tra_padre   := v_cod_tra_padre;
            r_gmovi.cod_mod_padre   := v_codigo_modulo;
            r_gmovi.cod_mad_padre   := v_codigo_modalidad;
            r_gmovi.cod_transaccion := v_tra_comision;
            r_gmovi.monto           := v_comision;
            r_gmovi.nro_documento   := p_mov_id;
            r_gmovi.nro_documento2  := p_cod_serv;
            r_gmovi.nro_documento3  := 1;
            r_gmovi.cod_ofi_origen  := 61;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Credito comision ';
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_rubro       := null;
            r_gmovi.cod_tasa        := v_cod_tasa_fielcob;
            r_gmovi.val_tasa        := v_val_tasa;
            r_gmovi.tip_mov_rubro   := 'C';
            r_gmovi.nro_caja        := v_nro_caja;

            pag_gen.pr_ins_ge_movimiento(r_gmovi);
          exception
            when others then
              -- hubo error en la insercion de registros ge_movimientos
              p_error     := 6;
              p_respuesta := sqlerrm;
              rollback to pago_app;
          end;
          --- inserta credito de la comision
          -- Aumento la secuencia
          begin
            v_numero_secuencia      := v_numero_secuencia + 1;
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fecha_actual;
            r_gmovi.nro_secuencia   := v_numero_secuencia;
            r_gmovi.cod_modulo      := v_codigo_modulo;
            r_gmovi.cod_modalidad   := v_codigo_modalidad;
            r_gmovi.cod_oficina     := 61;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.fec_valor       := trunc(sysdate);
            r_gmovi.cod_tra_padre   := v_cod_tra_padre;
            r_gmovi.cod_mod_padre   := v_codigo_modulo;
            r_gmovi.cod_mad_padre   := v_codigo_modalidad;
            r_gmovi.cod_transaccion := 517;
            r_gmovi.monto           := v_cal_iva;
            r_gmovi.nro_documento   := p_mov_id;
            r_gmovi.nro_documento2  := p_cod_serv;
            r_gmovi.nro_documento3  :=1;
            r_gmovi.cod_ofi_origen  := 61;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Credito iva comision';
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_rubro       := null;
            r_gmovi.cod_tasa        := v_cod_tasa_fielcob;
            r_gmovi.val_tasa        := v_val_tasa;
            r_gmovi.tip_mov_rubro   := 'C';
            r_gmovi.nro_caja        := v_nro_caja;
            r_gmovi.cod_persona     := v_cod_persona;
            pag_gen.pr_ins_ge_movimiento(r_gmovi);
          exception
            when others then
              -- hubo error en la insercion de registros ge_movimientos
              p_error     := 7;
              p_respuesta := sqlerrm;
              rollback to pago_app;
          end;
        elsif v_cod_tasa_fielcob is null then
          v_mon_cre := p_monto_op;
        end if;
        -- Credito pago servicio Bancard
        pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
        pag_cta.pr_set_nro_documento3(1);
        pag_cta.pr_set_referencia(p_referencia => p_mov_id);
        pag_cta.pr_nro_caja(p_nro_caja => v_nro_caja);
        pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_fielcob,
                                 p_hora            => v_hora,
                                 p_tip_movimiento  => 'C',
                                 p_cod_moneda      => v_cod_moneda,
                                 p_monto           => v_mon_cre,
                                 p_cod_tra_padre   => v_cod_tra_padre,
                                 p_cod_transaccion => v_cod_transaccion_cre,
                                 p_nro_documento   => p_mov_id,
                                 p_cotizacion      => null,
                                 p_cod_ofi_origen  => 61,
                                 p_cod_mod_padre   => v_codigo_modulo,
                                 p_cod_mad_padre   => v_codigo_modalidad,
                                 p_cod_tasa        => null,
                                 p_val_tasa        => null,
                                 p_concepto        => 'Credito pago servicio Fielcobranzas',
                                 p_emi_aviso       => 'N',
                                 p_nro_secuencia   => v_numero_secuencia,
                                 p_fec_valor       => trunc(sysdate),
                                 p_cod_banco       => null,
                                 p_cod_causa       => null,
                                 p_mto_equ_local   => null);
        if pag_cta.g_cod_error <> 0 then
          -- actualizacion con problemas
          p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
          p_respuesta := pag_cta.g_msj_error;
        else
          begin
            insert into bw_pag_servicios
              (nro_cuenta,
               cod_servicio,
               fecha,
               hora,
               nro_transaccion,
               nro_lote,
               ip_usuario,
               terminal,
               cod_moneda,
               mto_transaccion,
               mto_comision,
               mto_mora,
               mto_interes,
               reversado,
               mto_debito,
               cod_mon_servicio,
               red_pago,
               des_servicio,
               par_enviados)
            VALUES
              (p_cta_ahorro,
               p_cod_serv,
               v_fecha_actual,
               v_hora,
               p_mov_id,
               0,
               null,
               null,
               v_cod_moneda,
               p_monto_op,
               null,
               null,
               null,
               'N',
               p_monto_op,
               null,
               5,
               v_desc_servicio,
               null);
          exception
            when others then
              p_error     := 9;
              p_respuesta := 'Error al procesar transaccion' || sqlerrm;
             rollback to pago_app;
          end;
        end if;
      end if;
      if p_error <> 0 then
        rollback to pago_app;
      else
        p_error     := 0;
        p_respuesta := 'Operacion Confirmada';
      end if;
    end if;
   end if;
  exception
  when others then
    p_error     := 18;
    p_respuesta := 'NOK - ' || SQLERRM;
    v_det_error := 'Ente: ' || v_cod_persona || ' ID mov: ' || p_mov_id ||
                   ' Monto: ' || p_monto_op ||' Cta Ahorro: ' || p_cta_ahorro ||
                   ' Error: Cod. ' || p_error || '-' || p_respuesta;
    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_PAG_SER_APP',
                          v_det_error,
                          v_cod_persona,
                          p_cta_ahorro);
  end pr_gen_pag_ser_app;
  procedure pr_act_cod_tra_bancard(p_movimiento_id   in number,
                                   p_cod_servicio    in number,
                                   p_nro_transaccion in number,
                                   p_cod_error       out number,
                                   p_msj_error       out varchar2) is

    v_fecha ge_movimientos.fecha%type;
    v_hora  ge_movimientos.hora%type;
    v_cod_usuario ge_movimientos.cod_usuario%type;
    v_error exception;
    v_cod_programa varchar2(50) := 'PAP_SER.PR_GEN_COD_TRA_BANCARD';

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

    p_cod_error := 0;
    p_msj_error := 'Actualizacion Realizada';

    begin
      select g.fecha, g.hora, g.cod_usuario
        into v_fecha, v_hora, v_cod_usuario
        from ge_movimientos g
       where g.referencia = p_movimiento_id
         and g.Cod_Tra_Padre = 8526
         and rownum = 1;

    exception
      when others then
        p_msj_error := substr(sqlerrm, 1, 4000);
        p_cod_error := 1;
    end;
    if nvl(p_cod_error, 0) = 0 then
      if p_nro_transaccion is not null then

        update bw_pag_servicios s
           set s.nro_transaccion = p_nro_transaccion
         where s.nro_transaccion = p_movimiento_id
           and s.fecha = v_fecha
           and s.hora = v_hora
           and s.cod_servicio = p_cod_servicio;
        if sql%notfound then
          p_msj_error := 'Registro no encontrado en bw_pag_servicios';
          p_cod_error := 2;
        end if;
         update ge_movimientos t
            set t.referencia   = p_nro_transaccion
          where t.fecha        = v_fecha
            and t.hora         = v_hora
            and t.cod_usuario  = v_cod_usuario
            and t.referencia   = p_movimiento_id;
        if sql%notfound then
          p_msj_error := 'Registro no encontrado en ge_movimientos';
          p_cod_error := 2;
        end if;
      else
        p_msj_error := 'Numero de transaccion nula';
        p_cod_error := 3;
      end if;
    end if;

  exception
    when v_error then
      prg_ins_log_programas(v_cod_programa,
                            'Error: ' || p_cod_error || '-' || p_msj_error ||
                            ' # ' || p_movimiento_id || ' # ' ||
                            p_cod_servicio || ' # ' || p_nro_transaccion);

    when others then
      p_cod_error := 2;
      p_msj_error := substr(sqlerrm, 1, 4000);
      prg_ins_log_programas(v_cod_programa,
                            p_cod_error || '-' || p_msj_error || ' # ' ||
                            p_movimiento_id || ' # ' || p_cod_servicio ||
                            ' # ' || p_nro_transaccion);

  end pr_act_cod_tra_bancard;

procedure pr_gen_pag_ser_fielco(p_cod_ente      in varchar2,
                                p_cod_serv      in number,
                                p_cod_proc      in number,
                                p_monto_op      in number,
                                p_moneda        in number,
                                p_tip_ser       in varchar2,
                                p_mov_id        in varchar2,
                                p_usuario       in varchar2,
                                p_nro_documento in varchar2,
                                p_nombre        in varchar2,
                                p_error         out number,
                                p_respuesta     out varchar2,
                                p_nro_factura   out varchar2) is
  /*Detalle de parametros
  p_cod_ente:  Ente del CNB
  p_cod_serv:  Codigo del servicio de la tabla RAALIB.operaciones
  p_cod_proc:  Codigo de la procesadora de la tabla RAALIB.op_procesadora_canal
  p_monto_op:  Monto de pago del servicio
  p_moneda:    Moneda de pago del servicio
  p_tip_ser:   Tipo de envio: 1(Fielco),0(CNB)
  p_mov_id:    Movimiento id tabla RAALIB.movimiento
  p_usuario;   Usuario cajero - Solo para pagos que ingresen desde sucursales FIELCO y por FIELCORRESPONSAL
  p_error :     Codigo de error de salida
  p_respuesta:  Mensaje de respuesta de salida
  */
  r_gmovi               ge_movimientos%ROWTYPE;
  v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_cod_mon_fuerte      ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  v_nro_cuenta_cnb      ge_movimientos.nro_cuenta%type; --cuenta operativa cnb
  v_nro_cuenta_b        ge_movimientos.nro_cuenta%type; --cuenta operativa bancard
  v_nro_cuenta_fielcob  ge_movimientos.nro_cuenta%type; --cuenta operativa fielcobranzas
  v_hora_actual         VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS');
  v_cod_transaccion_deb NUMBER(4);
  v_cod_transaccion_cre NUMBER(4);
  v_cod_tra_padre       NUMBER(4);
  v_tra_comision        NUMBER(4);
  v_codigo_modulo       NUMBER(3) := 4;
  v_codigo_modalidad    NUMBER(3) := 43;
  v_numero_secuencia    NUMBER(3) := 0;
  v_fecha_actual        DATE := it.pag_cal.fu_obt_fec_actual(v_codigo_modulo);
  v_hora                ge_movimientos.hora%TYPE;/* := to_char(SYSDATE,
                                                            'hh24:mi:ss');*/
  v_cal_iva             NUMBER;
  v_redondeo            NUMBER := 0;
  v_cod_persona         ba_personas.cod_persona%type;
  v_respuesta           varchar2(300);
  v_error               number(3);
  v_moneda              ba_monedas.cod_moneda%type := it.fue_obt_mon_bcp(p_moneda);
  v_cod_moneda          ba_monedas.cod_moneda%type;
  v_cod_ente            ge_entes.cod_ente%type;
  v_cod_tasa_fielcob    ge_tasas.cod_tasa%type;
  v_fecha_vig           ge_tas_fechas.fec_vigencia%TYPE;
  v_tip_valor           ge_tasas.tip_valor%TYPE;
  v_tipo_tasa           ge_tasas.tipo%TYPE;
  v_valor_com           ge_movimientos.monto%type;
  v_comision            ge_movimientos.monto%type;
  v_mon_cre             ge_movimientos.monto%type;
  v_val_tasa            ge_tas_fechas.val_tasa%type := 10;
  v_desc_servicio       ba_cod_referencias.significado%type;
  v_cod_per_cli         ba_personas.cod_persona%type;
  v_cod_per_fac         ba_personas.cod_persona%type := null;
  v_det_error           ge_log_errores.det_error%type;
  v_usuario             varchar2(15);
  v_hora_c              ge_movimientos.hora%TYPE;


begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  if pae_cnf.fu_obt_est_modulo(1) != 2 then
    p_error     := 99;
    p_respuesta := 'Modulo Cerrado. No se puede operar';
  else

    savepoint pago_servicio;
    if nvl(p_cod_proc, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Ingresar codigo de procesadora - ' || p_cod_proc;
    end if;
    if nvl(p_cod_serv, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Ingresar codigo de servicio- ' || p_cod_serv;
    end if;
    if p_tip_ser is null then
      p_error     := 1;
      p_respuesta := 'Ingresar tipo de servicio 1(Fielco),0(CNB) ';
    end if;
    --Validaciones
    if p_tip_ser = 0 then
      if p_cod_ente is null then
        p_error     := 1;
        p_respuesta := 'Ingresar ente - ' || p_cod_ente;
      end if;
    end if;
    if p_tip_ser = 1 then
      if p_usuario is null then
        p_error     := 1;
        p_respuesta := 'Ingresar parametro de usuario - cajero ' ||
                       p_usuario;
      end if;
    end if;
    if nvl(p_monto_op, 0) = 0 then
      p_error     := 2;
      p_respuesta := 'Ingresar Monto operacion - ' || p_monto_op;
    end if;
    --Recupera la descripcion del servicio
    begin
      select significado
        into v_desc_servicio
        from ba_cod_referencias
       where dominio = 'DES_OPE_COB_SER'
         and val_minimo = p_cod_serv;
    exception
      when no_data_found then
        null;
      when others then
        p_error     := 2;
        p_respuesta := 'Error al recuperar descripcion del servicio - ' ||
                       p_cod_serv;

    end;
    --verifica si el parametro ingresado como nro de documento existe, sino existe, crea
    if p_nro_documento is not null and (p_nombre is not null or trim(p_nombre)!='')
       and p_cod_serv = 757/*credito agricola*/ then
       begin
         lp_reg_persona(p_nombre, p_nro_documento);
       exception
         when others then
           p_error:=97;
           p_respuesta:= 'Error al insertar persona. Verificar';
       end;
    end if;
    if nvl(p_error,0) = 0 and g_cod_persona is null and p_cod_serv = 757 then/*credito agricola*/
      /*and p_nro_documento is not null and
       p_cod_proc = 1 and p_nro_documento not like '0%'*/
       --si es numero de celular no debe entrar
      begin
        select cod_persona
          into v_cod_per_cli
          from ba_personas
         where nro_documento = p_nro_documento;
      exception
        when no_data_found then
          p_error     := 4;
          p_respuesta := 'Cliente no Registrado en el sistema - ' ||
                         p_nro_documento;
        when others then
          p_error     := 4;
          p_respuesta := 'Error al recuperar cliente - ' || p_nro_documento;
      end;
    end if;
    /*********************************************/
    /*******Pago de servicio POR CNB *************/
    /*********************************************/
    if p_tip_ser = 0 then
      if nvl(p_cod_ente, 0) <> 0 then
        --se busca persona del ente
        begin
          select cod_persona
            into v_cod_persona
            from ge_entes b
           where b.cod_ente = p_cod_ente;
        exception
          when no_data_found then
            p_error     := 4;
            p_respuesta := 'Ente no Registrado en el sistema - ' ||
                           p_cod_ente;
          when others then
            p_error     := 5;
            p_respuesta := 'Error a buscar ente';
        end;
      end if;
      v_cod_tra_padre       := 8526;
      v_cod_transaccion_deb := 8015;
      v_cod_transaccion_cre := 8016;
      --Recupera la cuenta del cnb de acuerdo a la moneda que se recibe
      IF v_moneda = v_cod_mon_local THEN
        v_nro_cuenta_cnb := it.fug_obt_parentes(p_cod_ente, 'CTA_OP_CNB_GS');
        v_cod_moneda     := it.pag_gen.fu_obt_mon_local;
      ELSIF v_moneda = v_cod_mon_fuerte THEN
        v_nro_cuenta_cnb := it.fug_obt_parentes(p_cod_ente,
                                                'CTA_OP_CNB_USD');
        v_cod_moneda     := it.pag_gen.fu_obt_mon_fuerte;
      END IF;
      --Analiza por procesadora-parametro p_cod_proc
      --  1 Fielcobranzas
      --  3 Bancard
      /*********************************************/
      /*******Pago de servicio POR BANCARD *********/
      /*********************************************/
      v_hora := fug_obt_mov_hora;/*it.fug_obt_hor_disponible(v_fecha_actual,
                                          v_hora_actual,
                                          USER,
                                          'N');*/
      if p_cod_proc = 3 then
        --Aqui genera operacion y movimiento cuando es por BANCARD
        --Recupera por parametro dinamico la cuenta operativa de bancard por moneda
        v_nro_cuenta_b := fug_obt_pardinamico(p_parametro     => 'CTA_OP_BANCARD',
                                              p_cod_modulo    => null,
                                              p_cod_modalidad => null,
                                              p_cod_moneda    => v_moneda,
                                              p_cod_oficina   => null);
        --Debito Pago de Servicio CNB por Bancard
        pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
        pag_cta.pr_set_nro_documento3(p_cod_ente);
        pag_cta.pr_nro_caja(p_nro_caja => null);
        pag_cta.pr_set_referencia(p_referencia => p_mov_id);
        ----------------------------------------------------------
        v_usuario := fu_obt_mov_user('FIELCOCNB');
        v_hora_c := fu_obt_hora(v_usuario);
        pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => 61,
                                 p_cod_mod_padre => v_codigo_modulo,
                                 p_cod_mad_padre => v_codigo_modalidad);
        ----------------------------------------------------------
        pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_cnb,
                                 p_hora            => v_hora_c,
                                 p_tip_movimiento  => 'D',
                                 p_cod_moneda      => v_cod_moneda,
                                 p_monto           => p_monto_op,
                                 p_cod_tra_padre   => v_cod_tra_padre,
                                 p_cod_transaccion => v_cod_transaccion_deb,
                                 p_nro_documento   => p_mov_id,
                                 p_cotizacion      => null,
                                 p_cod_ofi_origen  => 61,
                                 p_cod_mod_padre   => v_codigo_modulo,
                                 p_cod_mad_padre   => v_codigo_modalidad,
                                 p_cod_tasa        => null,
                                 p_val_tasa        => null,
                                 p_concepto        => 'Debito pago servicio CNB',
                                 p_emi_aviso       => 'N',
                                 p_nro_secuencia   => v_numero_secuencia,
                                 p_fec_valor       => trunc(sysdate),
                                 p_cod_banco       => null,
                                 p_cod_causa       => null,
                                 p_mto_equ_local   => null);
        if pag_cta.g_cod_error <> 0 then
          -- actualizacion con problemas
          p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
          p_respuesta := pag_cta.g_msj_error;
        else
          --Credito pago servicio cnb
          pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
          pag_cta.pr_set_nro_documento3(p_cod_ente);
          pag_cta.pr_nro_caja(p_nro_caja => null);
          pag_cta.pr_set_referencia(p_referencia => p_mov_id);
          pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_b,
                                   p_hora            => v_hora_c,
                                   p_tip_movimiento  => 'C',
                                   p_cod_moneda      => v_cod_moneda,
                                   p_monto           => p_monto_op,
                                   p_cod_tra_padre   => v_cod_tra_padre,
                                   p_cod_transaccion => v_cod_transaccion_cre,
                                   p_nro_documento   => p_mov_id,
                                   p_cotizacion      => null,
                                   p_cod_ofi_origen  => 61,
                                   p_cod_mod_padre   => v_codigo_modulo,
                                   p_cod_mad_padre   => v_codigo_modalidad,
                                   p_cod_tasa        => null,
                                   p_val_tasa        => null,
                                   p_concepto        => 'Credito pago servicio Bancard',
                                   p_emi_aviso       => 'N',
                                   p_nro_secuencia   => v_numero_secuencia,
                                   p_fec_valor       => trunc(sysdate),
                                   p_cod_banco       => null,
                                   p_cod_causa       => null,
                                   p_mto_equ_local   => null);
          if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
            p_respuesta := pag_cta.g_msj_error;
          else
            begin
              insert into bw_pag_servicios
                (nro_cuenta,
                 cod_servicio,
                 fecha,
                 hora,
                 nro_transaccion,
                 nro_lote,
                 ip_usuario,
                 terminal,
                 cod_moneda,
                 mto_transaccion,
                 mto_comision,
                 mto_mora,
                 mto_interes,
                 reversado,
                 mto_debito,
                 cod_mon_servicio,
                 red_pago,
                 des_servicio,
                 par_enviados)
              VALUES
                (v_nro_cuenta_cnb,
                 p_cod_serv,
                 v_fecha_actual,
                 v_hora,
                 p_mov_id,
                 0,
                 null,
                 null,
                 v_cod_moneda,
                 p_monto_op,
                 null,
                 null,
                 null,
                 'N',
                 p_monto_op,
                 null,
                 3,
                 v_desc_servicio,
                 null);
            exception
              when others then
                p_error     := 9;
                p_respuesta := 'Error al procesar transaccion' || sqlerrm;
                rollback to pago_servicio;
            end;
          end if;
        end if;
        if p_error <> 0 then
          rollback to pago_servicio;
        else
          p_error     := 0;
          p_respuesta := 'Operacion Confirmada';
        end if;

      elsif p_cod_proc = 1 then
        v_hora := fug_obt_mov_hora;/*it.fug_obt_hor_disponible(v_fecha_actual,
                                            v_hora_actual,
                                            USER,
                                            'N');*/
        /*********************************************/
        /****Pago de servicio POR FIELCOBRANZAS ******/
        /*********************************************/
        --Debito Pago de Servio CNB por fielcobranzas
        v_cod_tra_padre       := 8526;
        v_cod_transaccion_deb := 8015;
        v_cod_transaccion_cre := 8016;
        v_tra_comision        := 8520;
        --verificar codigo de persona para factura
        if g_cod_persona is null then
          v_cod_per_fac := v_cod_per_cli;
        else
          v_cod_per_fac := g_cod_persona;
        end if;
        pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
        pag_cta.pr_set_nro_documento3(p_cod_ente);
        pag_cta.pr_set_referencia(p_referencia => p_mov_id);
        pag_cta.pr_nro_caja(p_nro_caja => null);

        v_usuario := fu_obt_mov_user('FIELCOCNB');
        v_hora_c := fu_obt_hora(v_usuario);

        pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => 61,
                                 p_cod_mod_padre => v_codigo_modulo,
                                 p_cod_mad_padre => v_codigo_modalidad);

        pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_cnb,
                                 p_hora            => v_hora_c,
                                 p_tip_movimiento  => 'D',
                                 p_cod_moneda      => v_cod_moneda,
                                 p_monto           => p_monto_op,
                                 p_cod_tra_padre   => v_cod_tra_padre,
                                 p_cod_transaccion => v_cod_transaccion_deb,
                                 p_nro_documento   => p_mov_id,
                                 p_cotizacion      => null,
                                 p_cod_ofi_origen  => 61,
                                 p_cod_mod_padre   => v_codigo_modulo,
                                 p_cod_mad_padre   => v_codigo_modalidad,
                                 p_cod_tasa        => null,
                                 p_val_tasa        => null,
                                 p_concepto        => 'Debito pago servicio CNB',
                                 p_emi_aviso       => 'N',
                                 p_nro_secuencia   => v_numero_secuencia,
                                 p_fec_valor       => trunc(sysdate),
                                 p_cod_banco       => null,
                                 p_cod_causa       => null,
                                 p_mto_equ_local   => null);
        if pag_cta.g_cod_error <> 0 then
          -- actualizacion con problemas
          p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
          p_respuesta := pag_cta.g_msj_error;
        else

          --Busca el ente y la cuenta operativa definida en ge_par_entes
          --Primero buscv_nro_cuenta_fielcoba el codigo del servicio en el parametro COD_SER_COBSER
          begin
            select cod_ente
              into v_cod_ente
              from ge_par_entes
             where parametro = 'COD_SER_FIELCO'
               and val_parametro = p_cod_serv;
          exception
            when no_data_found then
              p_error     := 5;
              p_respuesta := 'Ente no Registrado para el servicio.' ||
                             p_cod_serv;
            when others then
              p_error     := 5;
              p_respuesta := 'Ente no Registrado para el servicio.' ||
                             p_cod_serv;
          end;
          --Aqui busca la cuenta operativa del servicio ( fielcobranzas)
          v_nro_cuenta_fielcob := it.fug_obt_parentes(v_cod_ente,
                                                      'CTA_OP_FIELCOBRANZAS');

          --Aqui busca la tasa de la comision si corresponde
          v_cod_tasa_fielcob := it.fug_obt_parentes(v_cod_ente,
                                                    'COD_TASA_FIELCOBRANZAS');

          if v_cod_tasa_fielcob is not null then

            -- Si tiene configurado tasa para comision, entonces generar movimiento por comision e IVA

            --Valor de tasa
            pag_gen.pr_obt_val_tasa(null,
                                    null,
                                    1,
                                    null,
                                    v_cod_moneda,
                                    null,
                                    null,
                                    v_cod_tasa_fielcob,
                                    null,
                                    null,
                                    v_valor_com,
                                    v_fecha_vig,
                                    v_tip_valor,
                                    v_tipo_tasa);

            IF v_tip_valor = 'P' THEN
              -- procentaje
              v_comision := round(p_monto_op * v_valor_com / 100, 0);
            ELSE
              -- valor --
              v_comision := v_valor_com;
            END IF;
            -- Monto IVA
            v_cal_iva := round(nvl(v_comision, 0) * (v_val_tasa / 100),
                               v_redondeo);
            --calcula el monto del credito
            v_mon_cre := p_monto_op -
                         (nvl(v_comision, 0) + nvl(v_cal_iva, 0));
            begin
              --- insertamos en ge movimientos
              v_numero_secuencia      := nvl(v_numero_secuencia, 0) + 1;
              r_gmovi.cod_usuario     := v_usuario;
              r_gmovi.hora            := v_hora_c;
              r_gmovi.fecha           := v_fecha_actual;
              r_gmovi.nro_secuencia   := v_numero_secuencia;
              r_gmovi.nro_cuenta      := null;
              r_gmovi.cod_persona     := v_cod_per_fac;
              r_gmovi.cod_modulo      := v_codigo_modulo;
              r_gmovi.cod_modalidad   := v_codigo_modalidad;
              r_gmovi.cod_oficina     := 61;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := trunc(sysdate);
              r_gmovi.cod_tra_padre   := v_cod_tra_padre;
              r_gmovi.cod_mod_padre   := v_codigo_modulo;
              r_gmovi.cod_mad_padre   := v_codigo_modalidad;
              r_gmovi.cod_transaccion := v_tra_comision;
              r_gmovi.monto           := v_comision;
              r_gmovi.referencia      := p_mov_id;
              r_gmovi.nro_documento2  := p_cod_serv;
              r_gmovi.nro_documento3  := p_cod_ente;
              r_gmovi.cod_ofi_origen  := 61;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Credito comision ';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := null;
              r_gmovi.cod_tasa        := v_cod_tasa_fielcob;
              r_gmovi.val_tasa        := v_val_tasa;
              r_gmovi.tip_mov_rubro   := 'C';
              r_gmovi.nro_caja        := null;

              pag_gen.pr_ins_ge_movimiento(r_gmovi);
            exception
              when others then
                -- hubo error en la insercion de registros ge_movimientos
                p_error     := 6;
                p_respuesta := sqlerrm;
            end;
            --- inserta credito de la comision
            -- Aumento la secuencia
            begin
              v_numero_secuencia      := v_numero_secuencia + 1;
              r_gmovi.cod_usuario     := v_usuario;
              r_gmovi.hora            := v_hora_c;
              r_gmovi.fecha           := v_fecha_actual;
              r_gmovi.nro_secuencia   := v_numero_secuencia;
              r_gmovi.cod_modulo      := v_codigo_modulo;
              r_gmovi.cod_modalidad   := v_codigo_modalidad;
              r_gmovi.cod_oficina     := 61;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := trunc(sysdate);
              r_gmovi.cod_tra_padre   := v_cod_tra_padre;
              r_gmovi.cod_mod_padre   := v_codigo_modulo;
              r_gmovi.cod_mad_padre   := v_codigo_modalidad;
              r_gmovi.cod_transaccion := 517;
              r_gmovi.monto           := v_cal_iva;
              r_gmovi.referencia      := p_mov_id;
              r_gmovi.nro_documento   := p_mov_id;
              r_gmovi.nro_documento2  := p_cod_serv;
              r_gmovi.nro_documento3  := p_cod_ente;
              r_gmovi.cod_ofi_origen  := 61;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Credito iva comision';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := null;
              r_gmovi.cod_tasa        := v_cod_tasa_fielcob;
              r_gmovi.val_tasa        := v_val_tasa;
              r_gmovi.tip_mov_rubro   := 'C';
              r_gmovi.nro_caja        := null;
              r_gmovi.cod_persona     := v_cod_per_fac;
              pag_gen.pr_ins_ge_movimiento(r_gmovi);
            exception
              when others then
                -- hubo error en la insercion de registros ge_movimientos
                p_error     := 7;
                p_respuesta := sqlerrm;
            end;
            if nvl(p_error, 0) = 0 then

              begin
                pr_gen_fac_ope(p_referencia => p_mov_id,
                               p_persona    => v_cod_per_fac,
                               p_tipo_ente  => p_tip_ser,
                               p_cod_error  => p_error,
                               p_msj_error  => p_respuesta,
                               p_factura    => p_nro_factura);
              exception
                when others then
                  p_error     := 8;
                  p_respuesta := 'Error al llamar al procedimiento pr_gen_fac_ope';
              end;
            end if;

          elsif v_cod_tasa_fielcob is null then
            v_mon_cre := p_monto_op;
          end if;
        ----------------------------------------------------------
        pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => 61,
                                 p_cod_mod_padre => v_codigo_modulo,
                                 p_cod_mad_padre => v_codigo_modalidad);
        ----------------------------------------------------------
          -- Credito pago servicio Bancard
          pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_serv);
          pag_cta.pr_set_referencia(p_referencia => p_mov_id);
          pag_cta.pr_nro_caja(p_nro_caja => null);
          pag_cta.pr_set_nro_documento3(p_cod_ente);
          pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_fielcob,
                                   p_hora            => v_hora_c,
                                   p_tip_movimiento  => 'C',
                                   p_cod_moneda      => v_cod_moneda,
                                   p_monto           => v_mon_cre,
                                   p_cod_tra_padre   => v_cod_tra_padre,
                                   p_cod_transaccion => v_cod_transaccion_cre,
                                   p_nro_documento   => p_mov_id,
                                   p_cotizacion      => null,
                                   p_cod_ofi_origen  => 61,
                                   p_cod_mod_padre   => v_codigo_modulo,
                                   p_cod_mad_padre   => v_codigo_modalidad,
                                   p_cod_tasa        => null,
                                   p_val_tasa        => null,
                                   p_concepto        => 'Credito pago servicio Fielcobranzas',
                                   p_emi_aviso       => 'N',
                                   p_nro_secuencia   => v_numero_secuencia,
                                   p_fec_valor       => trunc(sysdate),
                                   p_cod_banco       => null,
                                   p_cod_causa       => null,
                                   p_mto_equ_local   => null);
          if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            p_error     := ltrim(to_char(pag_cta.g_cod_error, '000'));
            p_respuesta := pag_cta.g_msj_error;
          else
            begin
              insert into bw_pag_servicios
                (nro_cuenta,
                 cod_servicio,
                 fecha,
                 hora,
                 nro_transaccion,
                 nro_lote,
                 ip_usuario,
                 terminal,
                 cod_moneda,
                 mto_transaccion,
                 mto_comision,
                 mto_mora,
                 mto_interes,
                 reversado,
                 mto_debito,
                 cod_mon_servicio,
                 red_pago,
                 des_servicio,
                 par_enviados)
              VALUES
                (v_nro_cuenta_cnb,
                 p_cod_serv,
                 v_fecha_actual,
                 v_hora,
                 p_mov_id,
                 0,
                 null,
                 null,
                 v_cod_moneda,
                 p_monto_op,
                 null,
                 null,
                 null,
                 'N',
                 p_monto_op,
                 null,
                 5,
                 v_desc_servicio,
                 null);
            exception
              when others then
                p_error     := 9;
                p_respuesta := 'Error al procesar transaccion' || sqlerrm;
                rollback to pago_servicio;
            end;
          end if;
        end if;
        if p_error <> 0 then
          rollback to pago_servicio;
        else
          p_error     := 0;
          p_respuesta := 'Operacion Confirmada';
        end if;

      end if;
    end if;
    /*********************************************/
    /*****Pago de servicio POR FIELCO AGENCIA ****/
    /*********************************************/
    if p_tip_ser = 1 then

      if p_cod_proc = 3 then
        --bancard

        v_respuesta := it.FUJ_PRO_TRANSACCION_8509(p_moneda      => v_moneda,
                                                   p_monto_op    => p_monto_op,
                                                   p_monto_co    => 0,
                                                   p_tip_op      => 'P',
                                                   p_mov_id      => p_mov_id,
                                                   p_mtcn        => null,
                                                   p_usuario     => p_usuario,
                                                   p_cod_persona => null,
                                                   p_cotizacion  => null,
                                                   p_cod_proc    => 3,
                                                   p_cod_serv    => p_cod_serv);
        if v_respuesta != 'OK' then
          p_error     := 999;
          p_respuesta := v_respuesta;
          rollback to pago_servicio;
        else
          p_error     := 0;
          p_respuesta := 'Operacion Confirmada';
        end if;
      elsif p_cod_proc = 1 then
        --fielcobranzas
        --verificar codigo de persona para factura
        if g_cod_persona is null then
          v_cod_per_fac := v_cod_per_cli;
        else
          v_cod_per_fac := g_cod_persona;
        end if;
        v_respuesta := it.fuj_pro_transaccion_8509(p_moneda      => v_moneda,
                                                   p_monto_op    => p_monto_op,
                                                   p_monto_co    => 0,
                                                   p_tip_op      => 'P',
                                                   p_mov_id      => p_mov_id,
                                                   p_mtcn        => null,
                                                   p_usuario     => p_usuario,
                                                   p_cod_persona => v_cod_per_fac,
                                                   p_cotizacion  => null,
                                                   p_cod_proc    => 1,
                                                   p_cod_serv    => p_cod_serv);
        if v_respuesta != 'OK' then
          p_error     := 999;
          p_respuesta := v_respuesta;

        else
          p_error     := 0;
          p_respuesta := 'Operacion Confirmada';
        end if;
        if nvl(p_error, 0) = 0 and v_cod_per_fac is not null then
          --Si no hay errores,genera  isla factura
          begin
            pr_gen_fac_ope(p_referencia => p_mov_id,
                           p_persona    => v_cod_per_fac,
                           p_tipo_ente  => p_tip_ser,
                           p_cod_error  => p_error,
                           p_msj_error  => p_respuesta,
                           p_factura    => p_nro_factura);
          exception
            when others then
              p_error     := 8;
              p_respuesta := 'Error al llamar al procedimiento pr_gen_fac_ope';
          end;
        end if;
      end if;
    end if;
  end if;
exception
  when others then
    p_respuesta := sqlerrm;
    v_det_error := 'Ente : ' || p_cod_ente || ' Mov ID: ' || p_mov_id ||
                   ' Moneda: ' || p_moneda || ' Monto op ' || p_monto_op ||
                   ' Codigo Serv. ' || p_cod_serv || ' Codigo Proces. ' ||
                   p_cod_proc || ' Usuario ' || p_usuario || ' Tip.pago ' ||
                   p_tip_ser || ' Error: ' || p_respuesta;
    PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_PAG_SER_FIELCO',
                          v_det_error,
                          null,
                          null);
end pr_gen_pag_ser_fielco;

  PROCEDURE lp_reg_persona(p_nombre        in varchar2,
                           p_nro_documento in varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    l_existe      varchar2(1);
    l_nombre      ba_personas.nom_completo%type;
    l_apellido    ba_personas.nom_completo%type;
    v_cod_per_cli ba_personas.cod_persona%type;
    v_fec_nacimiento ba_per_fisicas.fec_nacimiento%type;

  BEGIN
    --se calcula la edad de 21 años para dar de alta a la persona. Mejora HA-
    select add_months(trunc(sysdate), -252)
      into v_fec_nacimiento
      from dual;
    select 'S'
      into l_existe
      from ba_personas t
     where t.nro_documento = p_nro_documento;
  exception
    when no_data_found then
      select substr(p_nombre, 1, instr(p_nombre, ',') - 1)
        into l_apellido
        from dual;
      select trim(substr(p_nombre, instr(p_nombre, ',') + 1, 50))
        into l_nombre
        from dual;
      prl_ins_persona(p_nro_documento  => p_nro_documento,
                      p_tip_documento  => 1,
                      p_cod_pais       => 1,
                      p_nombre         => l_nombre,
                      p_apellido       => l_apellido,
                      p_tipo           => 'F',
                      p_fec_nacimiento => v_fec_nacimiento,
                      p_cod_persona    => v_cod_per_cli);
      commit;
      g_cod_persona := v_cod_per_cli;
    when others then
      null;
  END;

  procedure pr_gen_fac_ope(p_referencia in varchar2,
                           p_persona    in varchar2,
                           p_tipo_ente  in number, -- 0=CNB , 1=Fielco
                           p_cod_error  out number,
                           p_msj_error  out varchar2,
                           p_factura    out varchar2) is

    v_fecha     ge_movimientos.fecha%type;
    v_hora      ge_movimientos.hora%type;
    v_usuario   ge_movimientos.cod_usuario%type;
    v_persona   ba_personas.cod_persona%type := p_persona;
    v_existe    varchar2(1);
    v_det_error ge_log_errores.det_error%type;

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;

    begin
      select 'S', t.fecha, t.hora, t.cod_usuario
        into v_existe, v_fecha, v_hora, v_usuario
        from ge_movimientos t
       where (t.referencia = p_referencia or t.nro_documento = p_referencia)
         and rownum = 1;
    exception
      when no_data_found then
        p_cod_error := 1;
        p_msj_error := 'No se encuentra el movimiento a facturar';
    end;
    --solo si existe el registro en movimiento se llama al procedimiento de la facturacion--
    if v_existe = 'S' then
      begin
        it.pab_iva.pr_gen_lib_vta_tmp(v_persona,
                                      v_fecha,
                                      v_hora,
                                      v_usuario);
        p_cod_error := 0;
      exception
        when others then
          p_cod_error := 2;
          p_msj_error := 'No se puede generar los mov. temporales de la factura - '||sqlerrm;
      end;
      --solo si no ocurrio un error en la ejecucion del libro de venta temporal
      if p_cod_error = 0 then
        begin
          p_factura   := it.pab_iva.fu_gen_factura(p_cod_persona => v_persona,
                                                   p_fecha       => v_fecha,
                                                   p_hora        => v_hora,
                                                   p_cod_usuario => v_usuario);
          p_cod_error := 0;
          p_msj_error := 'Generacion de factura exitosa';
        exception
          when others then
            p_cod_error := 3;
            p_msj_error := 'Error al generar la facturacion - '||sqlerrm;
        end;
      end if;
    end if;

    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Tipo Ente: ' || p_tipo_ente || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_FAC_OPE',
                            v_det_error,
                            p_persona,
                            null);
    end if;
  exception
    when others then
      p_cod_error:=4;
      p_msj_error:=sqlerrm;
      v_det_error := 'Tipo Ente: ' || p_tipo_ente || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAP_SER.PR_GEN_FAC_OPE',
                            v_det_error,
                            p_persona,
                            null);
  end pr_gen_fac_ope;

end pap_ser;
/
