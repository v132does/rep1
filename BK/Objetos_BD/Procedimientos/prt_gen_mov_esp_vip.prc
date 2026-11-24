CREATE OR REPLACE PROCEDURE IT.PRT_GEN_MOV_ESP_VIP IS

  CURSOR salvip IS
   SELECT v.COD_TRANSACCION,  v.FECHA,
            v.NRO_TARJETA,     v.MARCA,
            TIP_TARJETA,       v.COD_SERVICIO,
            v.COD_PRESTACION,  v.TIP_TRANSACCION,
            v.MONTO,           v.COD_RESPUESTA,
            v.NRO_BOLETA,      v.rowid
     FROM TA_COB_ESP_VIP_TMP v
     WHERE to_number(trim(V.COD_TRANSACCION)) IN (20,0)  --  COMPRA EN POS, DEBITOS
       AND V.COD_RESPUESTA  = 0;
	   
	   
  ---VARIABLES
  
  r_gmovi ge_movimientos%rowtype;
  V_COD_TAS_CARGO        GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO        GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO            GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO     GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_MTO_RET_RENTA        GE_MOVIMIENTOS.MONTO%TYPE;
  v_monto             ge_movimientos.monto%type;
  v_nro_secuencia    number(3) := 0;
  v_hora             varchar2(08) ;
  v_fcdehoy          ge_movimientos.fecha%type;
  v_horario          varchar2(1) := 'D'; -- Dia normal
  v_es_mov_noc       varchar2(1) := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc       varchar2(1) := 'N'; -- Graba S/N ctas noctunas
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(5); -- fecha de hoy
  v_ult_cierre       date;
  v_fec_valor        date := v_fec_actual;
  v_cod_respuesta    varchar2(03) := '000'; -- respuesta
  v_cod_ofi_origen   ge_movimientos.cod_ofi_origen%type;
  v_cod_persona      ta_tarjetas.cod_persona%type;
  v_nro_Cuenta       ge_cuentas.nro_cuenta%type;
  v_cod_modalidad    ge_cuentas.cod_modalidad%type;
  v_cod_modulo       ge_cuentas.cod_modulo%type;
  v_cod_oficina      ta_cta_tarjetas.cod_oficina%type;
  v_cod_moneda       ge_cuentas.cod_moneda%type;
  v_cod_Transaccion  ge_movimientos.Cod_Transaccion%type;
  v_procesado        ta_cob_esp_vip_tmp.procesado%type;
  v_observacion      ta_cob_esp_vip_tmp.observacion%type;
  v_lugar            varchar2(100);
  r_espaciovip       ta_cob_esp_vip%rowtype;
  v_nro_tarjeta      ta_cob_esp_vip_tmp.nro_tarjeta%type;
  val_reproceso      varchar2(1):='N';
  v_fec_vigencia     date;
  v_tip_valor        ge_tasas.tip_valor%type;
  v_tipo             ge_Tasas.Tipo%type;
  v_tas_personalizada  ba_personas.tas_personalizada%type;
  v_cod_per_entidad    ge_par_generales.cod_persona%type:= FUG_OBT_PER_ENTIDAD;
  duplicate_exp EXCEPTION;
  PRAGMA EXCEPTION_INIT( duplicate_exp, -20001 );

  -- devuelve el indicador del horario de
  procedure lp_ver_horario is
    v_est_modulo ba_modulos.estado%type;
  begin
    v_horario    := 'D'; -- Dia normal
    v_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
    v_es_cta_noc := 'N';
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

    If v_est_modulo in (6) Then
      -- En cierre.
      v_cod_respuesta := paw_bce.v_cod_sis_cierre;
    elsif v_est_modulo = 2 Then
      -- El modulo esta abierto
      -- Verifica la hora --
      if sysdate > v_ult_cierre and trunc(v_ult_cierre) = v_fec_actual then
        v_horario    := 'T'; -- Tarde
        v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual + 1,1, v_cod_ofi_origen);
        v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      end if;
    else
      v_horario := 'N'; -- Noche
      if v_est_modulo <> 1 then
        v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual + 1, 1, v_cod_ofi_origen);
      end if;
      v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
    end if;
    v_fec_valor       := trunc(sysdate); --v_fec_actual;
    pag_cta.g_horario := v_horario;
  end lp_ver_horario;

  
  -- inserta en la tabla definitiva
  procedure lp_ins_ta_cob_esp_vip(rp_espaciovip in ta_cob_esp_vip%rowtype)
    is
    begin
      insert into ta_cob_esp_vip(cod_transaccion, fecha,   nro_tarjeta,  marca,
                                  tip_tarjeta,     cod_servicio,      cod_prestacion, tip_transaccion,
                                  monto,           cod_respuesta,     nro_boleta,
                                  fec_movimiento,  cod_usu_movimiento,hor_movimiento,
                                  nro_cuenta,      cod_persona,    mto_comision,       iva_comision,
                                  mto_retencion   )
                         values (rp_espaciovip.Cod_Transaccion, rp_espaciovip.Fecha, rp_espaciovip.Nro_Tarjeta, rp_espaciovip.Marca,
                                rp_espaciovip.Tip_Tarjeta, rp_espaciovip.Cod_Servicio, rp_espaciovip.Cod_Prestacion, rp_espaciovip.Tip_Transaccion,
                                rp_espaciovip.Monto,       rp_espaciovip.Cod_Respuesta, rp_espaciovip.Nro_Boleta,
                                rp_espaciovip.Fec_Movimiento,rp_espaciovip.Cod_Usu_Movimiento, rp_espaciovip.Hor_Movimiento,
                                rp_espaciovip.Nro_Cuenta,  rp_espaciovip.Cod_Persona, rp_espaciovip.Mto_Comision,rp_espaciovip.Iva_Comision,
                                rp_espaciovip.mto_retencion);
    exception
       when others then
         v_observacion := v_lugar||'***'||sqlerrm;
         prg_ins_log_errores('PRT_GEN_MOV_ESP_VIP',v_observacion);
         raise_application_error(-20000,'Al ins. en ta_cob_esp_vip '||sqlerrm);
   end;
   --

BEGIN
  v_lugar:= 'Antes del loop.';
  FOR mov in salvip LOOP
  --
  v_lugar:= 'Iniciando proceso.';
  lp_ver_horario;

  --
  v_cod_ofi_origen := fug_obt_ofi_usuario(user);
  v_fcdehoy        := v_fec_actual;
  v_hora      := to_char( sysdate, 'HH24:MI:SS' );
  v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_mov_noc);
  v_nro_secuencia := 0;
  V_COD_TAS_CARGO := null;
  V_VAL_TAS_CARGO := null;
  V_VAL_CARGO     := null;
  V_COD_TRA_IMPUESTO  :=null;
  V_COD_TAS_IMPUESTO  :=null;
  V_VAL_TAS_IMPUESTO  :=null;
  V_VAL_IMPUESTO      :=null;
  v_monto             :=null;
  V_MTO_RET_RENTA     := NULL;
  v_procesado         := 'S'; -- inicializamos con S
  v_observacion       := null;
  v_lugar             := null;
  r_espaciovip           := null;
  v_nro_tarjeta       := mov.nro_tarjeta;
  val_reproceso       := 'N';
  
  --valida el estado de movimiento en la tabla, solo si fue reversado tiene quepermitir reproceso del registro
  -- val_reproceso: S/N: S= puede reprocesar N= No puede reprocesar, registro ya procesado.
  begin
    select 'N'
      into val_reproceso
      from ta_cob_esp_vip v
    where v.cod_transaccion = mov.cod_transaccion
      and v.fecha = mov.fecha
      and v.nro_tarjeta     = mov.nro_tarjeta
      and v.Cod_Respuesta   = mov.cod_respuesta
      and v.nro_boleta      = mov.nro_boleta;

      if sql%rowcount > 0 then
         v_procesado :='N'; -- PARA QUE NO INSERTE EN TA_COB_ESP_VIP y se duplique
         v_observacion := 'Registro ya procesado. Reversar movimiento previamente.';
         raise duplicate_exp;
      END IF;
 exception
    WHEN duplicate_exp THEN
      raise_application_error( -20001, 'Registro ya procesado. Reversar movimiento previamente '||v_nro_tarjeta );
    when no_data_found then
      val_reproceso:='S';
    when others then
       dbms_output.put_line('Error '||Sqlerrm);
       val_reproceso:='N';
  end;

  --
  -- si el cobro se hizo con una Tarjeta de credito
  if val_reproceso ='S' then
    if mov.cod_prestacion ='TC' then
      -- validamos que la tarjeta este relacionada a una persona en la base.
      v_lugar:= 'Obt. Cod. Persona';
      begin
        select cod_persona, nro_cuenta
         into v_cod_persona, v_nro_cuenta
        from ta_Tarjetas
        where nro_tarjeta = trim(mov.nro_tarjeta);
      exception
        when no_Data_found then
            v_cod_persona:= null;
            v_observacion := 'TDC no encontrada o no válida'||trim(mov.nro_tarjeta);
            v_procesado  :='N';
        when too_many_rows then
            v_procesado := 'N';
            v_observacion := 'Varias TDC con el mismo número. '||trim(mov.nro_tarjeta);
        when others then
             v_observacion := v_lugar||'-'||sqlerrm;
             v_procesado := 'N';
      end;

      if v_cod_persona is not null and v_nro_cuenta is not null then
        begin
          v_lugar := 'Obt. datos cuenta '||v_nro_cuenta;
          select cta.cod_modulo, CTA.COD_MODALIDAD, CTA.COD_MONEDA, CTA.COD_OFICINA
             into v_cod_modulo,   v_cod_modalidad,   v_cod_moneda ,  v_cod_oficina
           from ta_cta_tarjetas cta
           where nro_Cuenta = v_nro_Cuenta;
         -- obtengo los cargos
          v_cod_Transaccion := 1201;
         -- obtengo el desgloce del iva
          v_lugar := 'Obt desglose de iva.';
          prg_obt_desglose(v_cod_ofi_origen,
                           v_nro_cuenta,
                           v_cod_moneda,
                           mov.monto,
                           v_cod_modulo, -- Módulo Tarjeta
                           v_cod_modalidad, -- Modalidad Tarjeta
                           v_cod_Transaccion, -- Transaccion del cobro de ingresos a salones vip
                           v_cod_tra_impuesto,
                           v_cod_tas_impuesto,
                           v_val_tas_impuesto,
                           v_val_impuesto);


          -- obtengo la parte gravada restando
          v_val_cargo := mov.monto - nvl(v_val_impuesto,0);
          --

          if nvl(v_val_cargo, 0) <> 0 and nvl(v_val_impuesto,0) <> 0 then
             v_lugar := 'Asignacion de valores a campos de movimientos '||v_cod_Transaccion;
            -- Movimiento por Cargo.
            v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fcdehoy;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := v_cod_oficina;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.fec_valor       := mov.fecha;
            r_gmovi.cod_tra_padre   := 1200;
            r_gmovi.cod_mod_padre   := 5;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_Transaccion; --
            r_gmovi.monto           := v_val_cargo;
            r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
            r_gmovi.nro_documento2  := mov.nro_boleta;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Acceso a Espacio VIP Banco - TDC:' || mov.nro_Tarjeta;
            r_gmovi.referencia      := mov.nro_tarjeta;
            r_gmovi.cod_persona     := v_cod_persona;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
            r_gmovi.cod_rubro       := NULL;
            r_gmovi.nro_cuenta      := v_nro_cuenta;
            r_gmovi.tip_mov_rubro   := NULL;
            r_gmovi.cod_tasa        := v_cod_tas_cargo;
            r_gmovi.val_tasa        := v_val_cargo;

            --
            v_lugar := 'Ins. movimiento transaccion '||v_cod_Transaccion;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            --
            if nvl(v_val_impuesto, 0) <> 0 then
              -- Movimiento por Impuesto.
              v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
              r_gmovi.cod_usuario     := USER;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fcdehoy;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad; --v_tip_cuenta;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := mov.fecha;
              r_gmovi.cod_tra_padre   := 1200;
              r_gmovi.cod_mod_padre   := 5;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.cod_transaccion := v_cod_tra_impuesto;
              r_gmovi.monto           := v_val_impuesto;
              r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
              r_gmovi.nro_documento2  := mov.nro_boleta;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Acceso a Espacio VIP Banco - TDC:' || mov.nro_tarjeta;
              r_gmovi.referencia      := mov.nro_tarjeta;
              r_gmovi.cod_persona     := v_cod_persona;
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := v_nro_cuenta;
              r_gmovi.tip_mov_rubro   := NULL;
              r_gmovi.cod_tasa        := v_cod_tas_impuesto;
              r_gmovi.val_tasa        := v_val_tas_impuesto;

              --
               v_lugar := 'Ins. movimientos transaccion '||v_cod_tra_impuesto;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            end if;
          end if;



         -- por la comision pagada a Bancard
         -- Se calcula Mto Comision + IVA
         v_cod_Transaccion := 1203;
         v_cod_ofi_origen  := 31;  -- a partir de aca los movimientos son de ofi 31,  definido por FVillalba
         v_cod_oficina     := 31; -- a partir de aca los movimientos son de ofi 31, definido por FVillalba
         v_cod_tas_cargo   := null;
         v_val_tas_cargo   := null;
         v_cod_tas_impuesto:= null;
         v_val_tas_impuesto:= null;
         v_tip_valor       := null;
         v_tipo            := null;
         v_lugar :='Obtener cargos transaccion '||v_cod_Transaccion;

        -- busco el valor de la tasa
          pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad,
               v_cod_ofi_origen, v_nro_cuenta, v_cod_moneda,
               mov.monto, nvl(v_tas_personalizada,'N'), v_cod_tas_cargo,
               v_cod_Transaccion, trunc(sysdate),
               v_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
          if v_tip_valor = 'V' then
             -- si es un valor, se toma directamente
             v_val_cargo := nvl(v_val_tas_cargo,0);
          else
             -- es un porcentaje
             v_val_cargo := round(nvl(mov.monto,0)*
                                     nvl(v_val_tas_cargo,0)/100);
            --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
            v_val_cargo := pag_gen.FU_OBT_VAL_FINAL(v_val_cargo);
          end if;

          -- busco el impuesto asociado a este cargo

          select cod_tra_hijo
            into v_cod_tra_impuesto
            from ge_transacciones_det
           where cod_modulo = v_cod_modulo
             and cod_modalidad = v_cod_modalidad
             and cod_transaccion = v_cod_Transaccion
             and cod_mod_hijo = v_cod_modulo
             and cod_mad_hijo = v_cod_modalidad
             and cod_tra_hijo <> v_cod_Transaccion -- Que la transacción hijo sea diferente de la padre PV 02/11/09
             and rownum = 1;
           -- veo si la cuenta tiene exoneracion de impuestos
           if pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,
                                          v_cod_tra_impuesto,
                                          v_cod_modulo,
                                          v_cod_modalidad) = 'N' then

              -- Traer tasa del impuesto
               v_lugar :='Obtener tasa del impuesto transaccion '||v_cod_tra_impuesto;
              pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad,
                                       v_cod_ofi_origen, v_nro_cuenta, v_cod_moneda,
                                       v_val_cargo, nvl(v_tas_personalizada,'N'), v_cod_tas_impuesto,
                                       v_cod_tra_impuesto, trunc(sysdate),
                                       v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);


             if v_tip_valor = 'V' then
                -- si es un valor, se toma directamente
                v_val_impuesto := nvl(v_val_tas_impuesto,0);
             else
                --
                -- es un porcentaje, se calcula iva sobre el cargo, ya que no viene incluido
                v_val_impuesto := round(nvl(v_val_cargo,0)* nvl(v_val_tas_impuesto,0)/100);
                --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                v_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(v_val_impuesto);
             end if;
         else
             v_val_impuesto:= 0;
         end if;

          --
          -- al valor del cargo se le resta el iva en prg_obt_Cargos.
          -- volvemos a sumar ya el monto es iva incluido
        --  v_val_cargo := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
          --
          if nvl(v_val_cargo, 0) <> 0  and nvl(v_val_impuesto,0) <> 0 then
           v_lugar := 'Asignacion de valores a campos de movimientos '||v_cod_Transaccion;
            -- Movimiento por Cargo.
            v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fcdehoy;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := v_cod_oficina;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.fec_valor       := mov.fecha;
            r_gmovi.cod_tra_padre   := 1200;
            r_gmovi.cod_mod_padre   := v_cod_modulo;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_transaccion; --
            r_gmovi.monto           := v_val_cargo;
            r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
            r_gmovi.nro_documento2  := mov.nro_boleta;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'CRECOM: Comisión Cobro Espacio VIP Banco - TDC:' || mov.nro_Tarjeta;
            r_gmovi.referencia      := '3147002098';
            r_gmovi.cod_persona     := v_cod_per_entidad;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
            r_gmovi.cod_rubro       := NULL;
            r_gmovi.nro_cuenta      := NULL;
            r_gmovi.tip_mov_rubro   := NULL;
            r_gmovi.cod_tasa        := v_cod_tas_cargo;
            r_gmovi.val_tasa        := v_val_cargo;

            --
            v_lugar := 'Ins. movimientos transaccion '||v_cod_Transaccion;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            --
            if nvl(v_val_impuesto, 0) <> 0 then
              v_lugar := 'Asignacion de valores a campos de movimientos Trans.'||v_cod_tra_impuesto;
              -- Movimiento por Impuesto.
              v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
              r_gmovi.cod_usuario     := USER;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fcdehoy;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad; --v_tip_cuenta;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := mov.fecha;
              r_gmovi.cod_tra_padre   := 1200;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.cod_transaccion := v_cod_tra_impuesto;
              r_gmovi.monto           := v_val_impuesto;
              r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
              r_gmovi.nro_documento2  := mov.nro_boleta;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'CRECOM: Iva s/Comisión Espacio VIP Banco - TDC:' || mov.nro_tarjeta;
              r_gmovi.referencia      := '3147002098';
              r_gmovi.cod_persona     := v_cod_per_entidad;
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := NULL;
              r_gmovi.tip_mov_rubro   := NULL;
              r_gmovi.cod_tasa        := v_cod_tas_impuesto;
              r_gmovi.val_tasa        := v_val_tas_impuesto;

              --
              v_lugar := 'Ins. movimientos transaccion '||v_cod_tra_impuesto;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            end if;
          end if;

         -- 1. resto el cargo de la comision y el iva del total
         v_monto := nvl(mov.monto, 0) - nvl(v_val_cargo, 0) - nvl(v_val_impuesto, 0);
         --
         -- por la RETENCION DE RENTA
         -- Se 1% sobre el monto
         v_cod_Transaccion := 1205;
         v_cod_tas_cargo   := null;
         v_val_tas_cargo   := null;
         v_tip_valor       := null;
         v_tipo            := null;
         v_lugar :='Obtener cargos transaccion '||v_cod_Transaccion;

        -- busco el valor de la tasa
          pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad,
               v_cod_ofi_origen, v_nro_cuenta, v_cod_moneda,
               mov.monto, nvl(v_tas_personalizada,'N'), v_cod_tas_cargo,
               v_cod_Transaccion, trunc(sysdate),
               v_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
          if v_tip_valor = 'V' then
             -- si es un valor, se toma directamente
             V_MTO_RET_RENTA := nvl(v_val_tas_cargo,0);
          else
             -- es un porcentaje
             V_MTO_RET_RENTA := round(nvl(mov.monto,0)*
                                     nvl(v_val_tas_cargo,0)/100);
            --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
            V_MTO_RET_RENTA := pag_gen.FU_OBT_VAL_FINAL(V_MTO_RET_RENTA);
          end if;

          v_lugar := 'Asignacion de valores a campos de movimientos Trans.'||v_cod_transaccion;
          v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
          r_gmovi.cod_usuario     := user;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fcdehoy;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_modulo      := v_cod_modulo;
          r_gmovi.cod_modalidad   := v_cod_modalidad;
          r_gmovi.cod_oficina     := v_cod_oficina;
          r_gmovi.cod_moneda      := v_cod_moneda;
          r_gmovi.fec_valor       := mov.fecha;
          r_gmovi.cod_tra_padre   := 1200;
          r_gmovi.cod_mod_padre   := v_cod_modulo;
          r_gmovi.cod_mad_padre   := v_cod_modalidad;
          r_gmovi.cod_transaccion := v_cod_transaccion; --
          r_gmovi.monto           := V_MTO_RET_RENTA;
          r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
          r_gmovi.nro_documento2  := mov.nro_boleta;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Ret.Renta Cobro Espacio VIP Banco - TDC: ' || mov.nro_tarjeta;
          r_gmovi.referencia      := '3147002098';
          r_gmovi.cod_persona     := v_cod_per_entidad;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
          r_gmovi.cod_rubro       := null;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.tip_mov_rubro   := null;
          r_gmovi.cod_tasa        := v_cod_tas_cargo;
          r_gmovi.val_tasa        := v_val_tas_cargo;

          --
           v_lugar := 'Ins. movimientos transaccion '||v_cod_transaccion;
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);


          --2. resto el cargo calculado por Retencion
          v_monto := v_monto - NVL(V_MTO_RET_RENTA,0);
          --
          -- Movimiento por Total.
          v_cod_transaccion := 1202;
          v_lugar := 'Asignacion de valores a campos de movimientos Trans.'||v_cod_transaccion;
          v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
          r_gmovi.cod_usuario     := user;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fcdehoy;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_modulo      := v_cod_modulo;
          r_gmovi.cod_modalidad   := v_cod_modalidad;
          r_gmovi.cod_oficina     := v_cod_oficina;
          r_gmovi.cod_moneda      := v_cod_moneda;
          r_gmovi.fec_valor       := mov.fecha;
          r_gmovi.cod_tra_padre   := 1200;
          r_gmovi.cod_mod_padre   := v_cod_modulo;
          r_gmovi.cod_mad_padre   := v_cod_modalidad;
          r_gmovi.cod_transaccion := v_cod_transaccion; --
          r_gmovi.monto           := v_monto;
          r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
          r_gmovi.nro_documento2  := mov.nro_boleta;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Acceso Espacio VIP Banco - TDC: ' || mov.nro_tarjeta;
          r_gmovi.referencia      := '3147002098';
          r_gmovi.cod_persona     := v_cod_per_entidad;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
          r_gmovi.cod_rubro       := null;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.tip_mov_rubro   := null;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;

          --
           v_lugar := 'Ins. movimientos transaccion '||v_cod_transaccion;
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);


       exception
         when others then
           v_observacion:= v_lugar || '-'||sqlerrm;
           v_procesado :='N';
       end;
     end if; -- end if numero de cta is not null
--TD   --
    else  -- si el codigo de prestacion es TD
        -- validamos que la tarjeta este relacionada a una persona en la base.
      v_lugar := 'Obt. Cod. Persona';
      begin
        select c.cod_persona, d.nro_cuenta
         into v_cod_persona, v_nro_cuenta
        from ah_tar_debitos d, ge_cta_clientes c
        where nro_tarjeta = trim(mov.nro_tarjeta)
         and d.nro_cuenta = c.nro_cuenta
         and c.relacion ='P' -- titular de la cuenta
         and tar_activa ='S';
      exception
        when no_Data_found then
           begin
              select c.cod_persona, d.nro_cuenta
               into v_cod_persona, v_nro_cuenta
              from ah_tar_debitos d, ge_cta_clientes c
              where d.nro_cuenta = substr(mov.nro_tarjeta, 7,2) ||'0'||substr(mov.nro_tarjeta,9,1)||substr(mov.nro_tarjeta,10,6)
               and d.nro_cuenta = c.nro_cuenta
               and c.relacion ='P'  -- titular de la cuenta
               and tar_activa ='S' ;
           exception
              when no_data_found then
                v_cod_persona:= null;
                v_observacion := 'TDD no encontrada o no activa. TD '||mov.nro_tarjeta;
                v_procesado :='N';
           end;
        when too_many_rows then
            v_observacion := 'Varias TDD con el mismo número. TD '||mov.nro_tarjeta;
            v_procesado :='N';
        when others then
            v_observacion := v_lugar||'-'||sqlerrm;
             v_procesado := 'N';
            prg_ins_log_errores('PRT_GEN_MOV_ESP_VIP',v_observacion);
      end;

      if v_cod_persona is not null and v_nro_cuenta is not null then
        begin
          v_lugar := 'Obt datos de la cuenta TDD '||mov.nro_tarjeta;
           select cta.cod_modulo, CTA.COD_MODALIDAD, CTA.COD_MONEDA, CTA.COD_OFICINA
             into v_cod_modulo,   v_cod_modalidad,   v_cod_moneda ,  v_cod_oficina
           from ge_cuentas cta
           where nro_Cuenta = v_nro_Cuenta;
           -- obtengo los cargos
          v_cod_Transaccion := 1201;
         -- obtengo el desgloce del iva
         v_lugar := 'Obt desgloce de cargos TDD '||mov.nro_Tarjeta;
          prg_obt_desglose(v_cod_ofi_origen,
                           v_nro_cuenta,
                           v_cod_moneda,
                           mov.monto,
                           v_cod_modulo, -- Módulo Tarjeta
                           v_cod_modalidad, -- Modalidad Tarjeta
                           v_cod_Transaccion, -- Transaccion del cobro de ingresos a salones vip
                           v_cod_tra_impuesto,
                           v_cod_tas_impuesto,
                           v_val_tas_impuesto,
                           v_val_impuesto);


          -- obtengo la parte gravada restando
          v_val_cargo := mov.monto - nvl(v_val_impuesto,0);
          --

          if nvl(v_val_cargo, 0) <> 0 and nvl(v_val_impuesto,0) <> 0 then
            v_lugar := 'Asignacion de valores para la transaccion '||v_cod_Transaccion;
            -- Movimiento por Cargo.
            v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fcdehoy;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := v_cod_oficina;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.fec_valor       := mov.fecha;
            r_gmovi.cod_tra_padre   := 1200;
            r_gmovi.cod_mod_padre   := v_cod_modulo;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_Transaccion; --
            r_gmovi.monto           := v_val_cargo;
            r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
            r_gmovi.nro_documento2  := mov.nro_boleta;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Acceso Espacio VIP Banco - TDD:' || mov.nro_Tarjeta;
            r_gmovi.referencia      := mov.nro_tarjeta;
            r_gmovi.cod_persona     := v_cod_persona;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
            r_gmovi.cod_rubro       := NULL;
            r_gmovi.nro_cuenta      := v_nro_cuenta;
            r_gmovi.tip_mov_rubro   := NULL;
            r_gmovi.cod_tasa        := v_cod_tas_cargo;
            r_gmovi.val_tasa        := v_val_cargo;

            --
            v_lugar := 'Ins.movim. TDD para la transaccion '||v_cod_Transaccion;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            --
            if nvl(v_val_impuesto, 0) <> 0 then
              v_lugar := 'Asigncion de valores TDD para la transaccion '||v_cod_tra_impuesto;
              -- Movimiento por Impuesto.
              v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
              r_gmovi.cod_usuario     := USER;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fcdehoy;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad; --v_tip_cuenta;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := mov.fecha;
              r_gmovi.cod_tra_padre   := 1200;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.cod_transaccion := v_cod_tra_impuesto;
              r_gmovi.monto           := v_val_impuesto;
              r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
              r_gmovi.nro_documento2  := mov.nro_boleta;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Acceso Espacio VIP Banco - TDD:' || mov.nro_tarjeta;
              r_gmovi.referencia      := mov.nro_tarjeta;
              r_gmovi.cod_persona     := v_cod_persona;
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
              r_gmovi.cod_rubro       := NULL;
              r_gmovi.nro_cuenta      := v_nro_cuenta;
              r_gmovi.tip_mov_rubro   := NULL;
              r_gmovi.cod_tasa        := v_cod_tas_impuesto;
              r_gmovi.val_tasa        := v_val_tas_impuesto;

              --
              v_lugar := 'Ins.movim. TDD para la transaccion '||v_cod_tra_impuesto;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            end if;

             v_cod_ofi_origen  := 31;  -- a partir de aca los movimientos son de ofi 31,  definido por FVillalba
             v_cod_oficina     := 31;
             v_monto := nvl(mov.monto, 0);
             v_lugar := 'Asignacion de valores movim TDD rubro 150102570203699';
              -- Movimiento por Total.
              v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
              r_gmovi.cod_usuario     := user;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fcdehoy;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := mov.fecha;
              r_gmovi.cod_tra_padre   := 1200;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.cod_transaccion := null; --
              r_gmovi.monto           := v_monto;
              r_gmovi.nro_documento   := substr(mov.nro_boleta,length(mov.nro_boleta)-7,8);
              r_gmovi.nro_documento2  := mov.nro_boleta;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Acceso Espacio VIP Banco - TDD: ' || mov.nro_tarjeta;
              r_gmovi.referencia      := '3147002098';
              r_gmovi.cod_persona     := v_cod_per_entidad;
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
              r_gmovi.cod_rubro       := 150102570203699;
              r_gmovi.nro_cuenta      := null;
              r_gmovi.tip_mov_rubro   := 'D';
              r_gmovi.cod_tasa        := null;
              r_gmovi.val_tasa        := null;

              --
              v_lugar := 'Ins.movim. TDD para el rubro ';
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
         end if;
          exception
            when others then
              v_observacion := v_lugar ||'-'||sqlerrm;
              v_procesado :='N';
               prg_ins_log_errores('PRT_GEN_MOV_ESP_VIP',v_observacion);
          end ;
       end if;-- end if numero de cta is not null TDD
     end if; -- end if cod_prestacion

  end if;

   -- asigno los datos para vincular con el movimiento
   if v_procesado ='S' then
        r_espaciovip.COD_TRANSACCION := mov.cod_transaccion;
        r_espaciovip.fecha           := mov.fecha;
        r_espaciovip.nro_tarjeta     := mov.nro_tarjeta;
        r_espaciovip.marca           := mov.marca;
        r_espaciovip.tip_tarjeta     := mov.tip_tarjeta;
        r_espaciovip.cod_servicio    := mov.cod_servicio;
        r_espaciovip.cod_prestacion  := mov.cod_prestacion;
        r_espaciovip.tip_transaccion := mov.tip_transaccion;
        r_espaciovip.monto           := mov.monto;
        r_espaciovip.cod_respuesta   := mov.cod_respuesta;
        r_espaciovip.nro_boleta      := mov.nro_boleta;
        r_espaciovip.fec_movimiento  := v_fcdehoy;
        r_espaciovip.COD_USU_MOVIMIENTO := user;
        r_espaciovip.HOR_MOVIMIENTO     := v_hora;
        r_espaciovip.nro_cuenta         := v_nro_Cuenta;
        r_espaciovip.cod_persona        := v_cod_persona;
        r_espaciovip.mto_comision       := v_val_cargo;
        r_espaciovip.iva_comision       := v_val_impuesto;
        r_espaciovip.mto_retencion      := V_MTO_RET_RENTA;

       -- insertamos en la tabla.
       lp_ins_ta_cob_esp_vip(r_espaciovip);

    end if;
     -- actualiza tabla temporal
     v_lugar:='Al actualizar tab Temporal';
    update ta_cob_esp_vip_tmp
      set procesado  = 'S',
          observacion = v_observacion
     where fecha           = mov.fecha
       and cod_transaccion = mov.cod_transaccion
       and nro_tarjeta     = mov.nro_tarjeta
       and monto           = mov.monto
       and nro_boleta      = mov.nro_boleta;

  END LOOP;
exception
  WHEN duplicate_exp THEN
      raise_application_error(-20001, 'Registro ya procesado. Reversar movimiento previamente '||v_nro_tarjeta);
  when others then
     v_observacion := v_lugar||'***'||sqlerrm;
      prg_ins_log_errores('PRT_GEN_MOV_ESP_VIP',v_observacion);
    raise_application_error(-20006, 'Gen Mov:' || v_observacion);

END;
/

