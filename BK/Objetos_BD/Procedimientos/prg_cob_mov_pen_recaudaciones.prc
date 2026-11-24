CREATE OR REPLACE PROCEDURE IT.prg_cob_mov_pen_recaudaciones
   IS
   /*Proceso ajustado MAY-2015 para realizar la cobranza de la tabla
ge_mov_pen_cobranzas, similar al cobro de movimientos pendientes pero con contrapartida
de crédito a empresas*/

  v_hor_actual       varchar2(08) ;
  v_fec_actual       date default pag_cal.fu_obt_fec_actual(1);
  v_cod_ente         ge_entes.cod_ente%type;
  v_nro_cuenta       ge_cuentas.nro_cuenta%type;
  v_cod_mod_cre      ge_cuentas.cod_modulo%type;
  v_cod_mad_cre      ge_cuentas.cod_modalidad%type;
  v_cod_ofi_cre      ge_cuentas.cod_oficina%type;
  v_cod_mon_cre      ge_cuentas.cod_moneda%type;
  v_nro_registro     varchar2(50);
  v_monto            number(18,2);

  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;
  v_total_general    number(18,2);
  v_mto_cargo         GE_MOVIMIENTOS.monto%TYPE;
  v_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  v_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  v_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_mto_impuesto      GE_MOVIMIENTOS.monto%TYPE;
  v_des_error         ge_mov_pendientes.motivo%type;
  v_cod_ofi_origen    ge_movimientos.cod_oficina%type;

  --v_nro_secuencia     number(3) := nvl(pae_cnf.G_NRO_SECUENCIA,0);
  v_nro_Secuencia     ge_movimientos.nro_secuencia%type;
  v_fila              varchar2(200);
  v_nvo_estado        ge_cuentas.estado%type;
  v_sal_disponible    ge_cuentas.sal_contable%type;
  v_procesa           varchar2(01) := 'N';
  v_hubo_error        varchar2(01) := 'N';
  v_mto_debito        GE_MOVIMIENTOS.monto%TYPE;
  r_gmovi             ge_movimientos%rowtype;
  v_cod_tasa          ge_movimientos.cod_tasa%type;
  v_val_tasa          ge_movimientos.val_tasa%type;
  v_cod_transaccion   ge_movimientos.cod_transaccion%type;
  v_cod_tra_padre     ge_movimientos.cod_transaccion%type;
  v_cod_mod_padre     ge_movimientos.cod_mod_padre%type;
  v_cod_mad_padre     ge_movimientos.cod_mad_padre%type;
  v_nro_documento     ge_movimientos.nro_documento%type;
  v_nro_sec_anterior  ge_movimientos.nro_secuencia%type;
  v_nro_sec_final     ge_movimientos.nro_secuencia%type;
  v_mto_cotizacion    ge_movimientos.cotizacion%type;
  v_cod_mon_local     ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_cod_movimiento    ge_movimientos.nro_documento3%type;
  v_mto_credito       ge_movimientos.monto%type:=0;
  v_cod_ent_aux       ge_entes.cod_ente%type;
  v_cod_mon_aux       ba_monedas.cod_moneda%type;
  --
  v_can_dias          number default nvl(fug_obt_pardinamico('CAN_DIA_NOT_VTO_SEGURO'),30);
  v_fec_desde           date;
  v_fec_hasta           date;
  v_sig_dia_habil       date;
  v_diferencia          number;
  v_hora varchar2(20);
  v_error varchar2(3000);

  --Agregado por rpavob para ajuste de Incideencia DYDMR-5768--
  --Se obtiene el codigo de ente y moneda y a los cursores de detalle y total se envia el ente y moneda
  --como parametros para filtro con ello se graba al finalizar el detalle de debitos el credito por el
  --total dentro de la misma hora, se incrementa la hora por cada ente y quedan agrupados los movimientos.
  CURSOR c_ent_cod_distintos is
    select to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))) cod_ente,
           a.cod_moneda,
           count(*) cantidad, sum(nvl(a.monto,0)) total
      from ge_mov_pen_cobranzas a
     where estado = 'I' --sólo pendientes de cobro (Ingresado) y con saldo
       and nvl(saldo,0) > 0
       and nro_cuenta =  nro_cuenta
       and cod_movimiento = cod_movimiento
     group by a.cod_moneda, to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1)));

  cursor c_ent_det_cobrar is
  select rowid, a.*--nro_cuenta,cod_moneda,cod_oficina, saldo
    from ge_mov_pen_cobranzas a
   where estado = 'I' --sólo pendientes de cobro (Ingresado) y con saldo
     and nvl(saldo,0) > 0
     and nro_cuenta =  nro_cuenta
     and cod_movimiento = cod_movimiento
     and to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))) = v_cod_ent_aux
     and a.cod_moneda = v_cod_mon_aux;

   CURSOR c_ent_tot_acreditar is
    select sum(a.monto) total, a.cod_moneda, to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))) cod_ente
       from ge_mov_pen_cobranzas a
      where (trunc(a.fec_cobro) = trunc(v_fec_actual))
        and a.estado = 'P'
        --and a.concepto like '%Cobranza de Seguros.%'
        and nvl(a.cierre,'N')='S'
        and to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))) = v_cod_ent_aux
        and a.cod_moneda = v_cod_mon_aux
        group by to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))),a.cod_moneda
        order by to_number(trim(substr(a.concepto, 1, instr(a.concepto,'-') -1))),a.cod_moneda;

    CURSOR c_ent_reg_cobrados is
     select *
       from ge_mov_pen_cobranzas a
      where (trunc(a.fec_cobro) = trunc(v_fec_actual))
        and a.estado = 'P'
        --and a.concepto like '%Cobranza de Seguros.%'
        and nvl(a.cierre,'N')='S';
        
        
    CURSOR c_ent_reg_vto is
      select a.cod_persona, a.cod_ente,a.fec_final, a.codigo, a.nro_poliza
       from ge_pol_seguros  a
          where (trunc(a.fec_final) between trunc(v_fec_desde) and trunc(v_fec_hasta))
          and not exists (select 1 from ge_ren_pol_seguros r
                           where r.nro_seg_ant = a.codigo)    
          and a.estado <> 4 -- Vencida
          --Que no se renovaron
          and a.nro_poliza not in (select w.referencia from Ge_Pol_Seguros w where w.referencia=a.nro_poliza
                                      and w.codigo> a.codigo)
          -- seguros que no se notificarán por renovación                            
          AND exists (select 1 from ba_cod_referencias where dominio = 'EXC_ENT_REN_SEG' 
                         and val_minimo = decode(a.seccion, 'V', decode(a.cod_sub_seccion, '0401', 'P', a.seccion), a.seccion)||a.cod_ente
                         and val_maximo = 'S')
        order by a.fec_final desc;  

  /* actualiza el movimiento si hubo error en el cobro */
    procedure lp_act_mov_pendiente is
    begin
       update ge_mov_pen_cobranzas
          set estado = 'X',
              motivo = substr(motivo || v_des_error, 1, 100)
        where rowid = v_fila;
    end;

BEGIN
  v_fec_actual := pag_cal.fu_obt_fec_actual(3);
  v_hor_actual := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_cod_ofi_origen := FUG_OBT_OFI_USUARIO(user);
  v_mto_credito:=0;

  for ent in c_ent_cod_distintos loop
      v_cod_ent_aux := ent.cod_ente;
      v_cod_mon_aux := ent.cod_moneda;
      v_nro_Secuencia := -999;
      v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
      for reg in c_ent_det_cobrar loop
           --Limpiar variables
           v_mto_cargo        := null;
           v_cod_tra_impuesto := null;
           v_cod_tas_impuesto := null;
           v_mto_impuesto     := null;
           v_nvo_estado       := null;
           v_sal_disponible   := null;
           v_procesa          := 'N';
           v_hubo_error       := 'N';
           v_des_error        := null;

           --aumentar la secuencia
           if nvl(v_nro_secuencia,999) > 990 then
             v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
             v_nro_secuencia := -999;
           end if;
           v_fila := reg.rowid;
           v_mto_cargo := nvl(reg.saldo,0);
           begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;

           --calcular impuesto
           prg_obt_car_impuesto(v_cod_ofi_origen, reg.nro_cuenta, reg.cod_moneda, reg.cod_modulo, reg.cod_modalidad,
           reg.cod_transaccion, v_mto_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_mto_impuesto);
           v_mto_impuesto := nvl(v_mto_impuesto,0);


           --v_cod_tra_padre   := 5015;--reg.cod_transaccion;
           v_cod_tra_padre := fug_obt_parentes(to_number(trim(substr(reg.concepto, 1, instr(reg.concepto,'-') -1))), 'COD_TRA_PADRE');
           v_cod_mod_padre   := reg.cod_modulo;
           v_cod_mad_padre   := reg.cod_modalidad;
           if nvl(reg.car_manual,'N') = 'N' then --Movs. Pendientes Generados por Procesos, se realiza un Debito por el Cargo y Un Debito por el Impuesto
             v_mto_debito      := nvl(v_mto_cargo,0) + nvl(v_mto_impuesto,0);
             v_cod_tasa        := reg.cod_tasa;
             v_val_tasa        := reg.val_tasa;
             v_cod_transaccion := reg.cod_transaccion;
             v_nro_documento   := reg.nro_cuenta;
           elsif reg.car_manual = 'S' then --Movs. Pendientes por Cobros Manuales, realiza un débito por el total y movs. de referencia para el Cargo e Impuesto
             v_mto_debito      := nvl(v_mto_cargo,0) + nvl(v_mto_impuesto,0);
             v_cod_tasa        := null;
             v_val_tasa        := null;
             v_cod_transaccion := 503;
             v_nro_documento   := reg.nro_documento;
           end if;

           --verificar si se puede realizar el débito del monto completo
           pag_cta.pr_ver_operacion(reg.nro_cuenta,
                                   v_cod_tra_padre,--reg.cod_tra_padre,
                                   reg.cod_mod_padre,
                                   reg.cod_mad_padre,
                                   'D',
                                   reg.cod_moneda,
                                   v_mto_debito, --reg.saldo,
                                   reg.cod_oficina,
                                   pag_cta.g_ctas.cod_modulo, -- out
                                   pag_cta.g_ctas.cod_modalidad,
                                   v_nvo_estado,
                                   v_sal_disponible,
                                   v_procesa,
                                   v_cod_transaccion); --transacción hijo
           --Manejo del error
           if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
             --si recibe parámetros es llamado desde el programa y tiene que levantar el error
               v_hubo_error := 'S';
               --sólo si no es por saldo insuficiente
               if pag_cta.g_cod_error not in(25, 31, 29) then
                 --actualizar el movimiento con error
                 v_des_error := pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR();
                 lp_act_mov_pendiente;
               end if;
           end if;

           --si no hubo error se realiza el débito por el monto del cargo
           if v_nro_secuencia > 990 then
             v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
             v_nro_secuencia := -999;
           end if;
           if v_hubo_error = 'N' then
             pag_cta.G_COD_ERROR := 0;
             If nvl(reg.car_manual,'N') = 'N' then

                   if reg.cod_moneda <> v_cod_mon_local then
                      v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
                   else
                      v_mto_cotizacion := null;
                   end if;

                   PAG_CTA.PR_SET_VARIABLES(user,
                                            v_fec_actual,
                                            v_cod_tra_padre,
                                            'N',--v_estado,
                                            'N',
                                            v_nro_secuencia,
                                            null,
                                            v_cod_ofi_origen,
                                            reg.cod_mod_padre,
                                            reg.cod_mad_padre);

                   if length(reg.cod_movimiento)> 15 then
                      v_cod_movimiento:= substr(to_char(reg.cod_movimiento),length(to_char(reg.cod_movimiento))+1 -15,15);
                   else
                      v_cod_movimiento:= reg.cod_movimiento;
                   end if;

                   pag_cta.PR_SET_NRO_DOCUMENTO3(v_cod_movimiento);

                   pag_cta.pr_act_operacion(reg.nro_cuenta,
                                            v_hor_actual,
                                            'D', -- debito a la cuenta del cliente
                                            reg.cod_moneda,
                                            v_mto_cargo,
                                            --reg.cod_tra_padre,
                                            v_cod_tra_padre,
                                            v_cod_transaccion,--reg.cod_transaccion, -- trans. hijo
                                            v_nro_documento,--reg.nro_cuenta,
                                            v_mto_cotizacion, -- cotizacion
                                            31,/*v_cod_ofi_origen*/
                                            3,--reg.cod_mod_padre,
                                            31,--reg.cod_mad_padre,
                                            v_cod_tasa,--reg.COD_TASa, -- tasa
                                            v_val_tasa,--reg.VAL_TASa, -- valor de tasa
                                            'Aplicación de Mov.Pend.Cobranza: '||reg.concepto, --concepto
                                            'N', -- emitir aviso
                                            v_nro_secuencia, -- nro de secuencia
                                            reg.fecha,-- Fec.Valor
                                            null,          -- P_COD_BANCO
                                            null,          -- P_COD_CAUSA
                                            round(nvl(v_mto_cargo,0)*v_mto_cotizacion,0));
                   v_nro_sec_final := v_nro_secuencia;

             else
               v_nro_sec_anterior := v_nro_secuencia;
               v_nro_secuencia := v_nro_secuencia + 2;


                 if reg.cod_moneda <> v_cod_mon_local then
                    v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
                 else
                    v_mto_cotizacion := null;
                 end if;

                  PAG_CTA.PR_SET_VARIABLES(user,
                                           v_fec_actual,
                                            v_cod_tra_padre,--reg.cod_tra_padre,
                                           'N',--v_estado,
                                           'N',
                                           v_nro_secuencia,
                                           null,
                                           v_cod_ofi_origen,
                                           reg.cod_mod_padre,
                                           reg.cod_mad_padre);


                  if length(reg.cod_movimiento)> 15 then
                     v_cod_movimiento:= substr(to_char(reg.cod_movimiento),length(to_char(reg.cod_movimiento))+1 -15,15);
                  else
                     v_cod_movimiento:= reg.cod_movimiento;
                  end if;

                  pag_cta.PR_SET_NRO_DOCUMENTO3(v_cod_movimiento);

                  pag_cta.pr_act_operacion(reg.nro_cuenta,
                                           v_hor_actual,
                                           'D', -- debito a la cuenta del cliente
                                           reg.cod_moneda,
                                           v_mto_debito,
                                           --reg.cod_tra_padre,
                                           v_cod_tra_padre,
                                           v_cod_transaccion,--reg.cod_transaccion, -- trans. hijo
                                           v_nro_documento,--reg.nro_cuenta,
                                           v_mto_cotizacion, -- cotizacion
                                           31,--v_cod_ofi_origen,
                                           3,--reg.cod_mod_padre,
                                           31,--reg.cod_mad_padre,
                                           v_cod_tasa,--reg.COD_TASa, -- tasa
                                           v_val_tasa,--reg.VAL_TASa, -- valor de tasa
                                           'Aplicación Mov.Pend.Cobranza: '||reg.concepto, --concepto
                                           'N', -- emitir aviso
                                           v_nro_secuencia, -- nro de secuencia
                                           reg.fecha, -- Fec.Valor
                                           null,          -- P_COD_BANCO
                                           null,          -- P_COD_CAUSA
                                           round(nvl(v_mto_debito,0)* v_mto_cotizacion,0));

                v_nro_sec_final := v_nro_secuencia;
                v_nro_secuencia := v_nro_sec_anterior;

             End if;

             --manejo del error
             if pag_cta.g_cod_error <> 0  then
               --si recibe parámetros es llamado desde el programa y tiene que levantar el error

                 v_hubo_error := 'S';
                 --actualizar el movimiento con error
                 --sólo si no es por saldo insuficiente
                  if pag_cta.g_cod_error not in(25, 31, 29) then
                    v_des_error := pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR();
                    lp_act_mov_pendiente;
                  End if;

             end if;

             if nvl(reg.car_manual,'N') = 'N' then
                if v_nro_secuencia > 990 then
                   v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                   v_nro_secuencia := -999;
                end if;
                --Realiza el débito por el monto del impuesto
                if v_mto_impuesto > 0 and  v_hubo_error = 'N' then
                    if reg.cod_moneda <> v_cod_mon_local then
                       v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
                    else
                       v_mto_cotizacion := null;
                    end if;

                    PAG_CTA.PR_SET_VARIABLES(user,
                                            v_fec_actual,
                                            V_COD_TRA_IMPUESTO,
                                            'N',--v_estado,
                                            'N',
                                            v_nro_secuencia,
                                            null,
                                            v_cod_ofi_origen,
                                            reg.cod_mod_padre,
                                            reg.cod_mad_padre);

                   if length(reg.cod_movimiento)> 15 then
                      v_cod_movimiento:= substr(to_char(reg.cod_movimiento),length(to_char(reg.cod_movimiento))+1 -15,15);
                   else
                      v_cod_movimiento:= reg.cod_movimiento;
                   end if;

                   pag_cta.PR_SET_NRO_DOCUMENTO3(v_cod_movimiento);

                   pag_cta.pr_act_operacion(reg.nro_cuenta,
                                            v_hor_actual,
                                            'D', -- debito a la cuenta del cliente
                                            reg.cod_moneda,
                                            v_mto_impuesto,
                                            V_COD_TRA_IMPUESTO,
                                            V_COD_TRA_IMPUESTO, -- trans. hijo
                                            reg.nro_cuenta,
                                            v_mto_cotizacion, -- cotizacion
                                            31,--v_cod_ofi_origen,
                                            3,--reg.cod_mod_padre,
                                            31,--reg.cod_mad_padre,
                                            V_COD_TAS_IMPUESTO, -- tasa
                                            V_VAL_TAS_IMPUESTO, -- valor de tasa
                                            'IVA s/Cargos', --concepto
                                            'N', -- emitir aviso
                                            v_nro_secuencia, -- nro de secuencia
                                            reg.fecha,-- Fec.Valor
                                            null,          -- P_COD_BANCO
                                            null,          -- P_COD_CAUSA
                                            round(nvl(v_mto_impuesto,0)* v_mto_cotizacion,0));
                   v_nro_sec_final := v_nro_secuencia;
                   --manejo del error
                   if pag_cta.g_cod_error <> 0 then
                      --si recibe parámetros es llamado desde el programa y tiene que levantar el error

                         v_hubo_error := 'S';
                         --actualizar el movimiento con error
                         --sólo si no es por saldo insuficiente
                         if pag_cta.g_cod_error not in(25, 31, 29) then
                            v_des_error := pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR();
                            lp_act_mov_pendiente;
                         end if;
                      end if;
                   end if;
                End if;
             elsif reg.car_manual = 'S' then


                if v_nro_secuencia > 990 then
                   v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                   v_nro_secuencia := -999;
                end if;

                if reg.cod_moneda <> v_cod_mon_local then
                   v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
                else
                   v_mto_cotizacion := null;
                end if;

                --Insertar el Movimiento Por el Cargo
                r_gmovi.cod_usuario     := substr(user,1,10);
                r_gmovi.hora            := v_hor_actual;
                r_gmovi.fecha           := v_fec_actual;
                -- Aumento la secuencia
                v_nro_secuencia         := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                --
                r_gmovi.cod_modulo      := reg.cod_modulo;
                r_gmovi.cod_modalidad   := reg.cod_modalidad;
                r_gmovi.cod_oficina     := v_cod_ofi_origen;
                r_gmovi.nro_cuenta      := null;
                r_gmovi.cod_moneda      := reg.cod_moneda;
                r_gmovi.fec_valor       := reg.fecha;
                r_gmovi.cod_tra_padre   := v_cod_tra_padre;--nvl(reg.cod_tra_padre,150);
                r_gmovi.cod_mod_padre   := v_cod_mod_padre;--nvl(reg.cod_mod_padre,3);
                r_gmovi.cod_mad_padre   := v_cod_mad_padre;--nvl(reg.cod_mad_padre,31);
                r_gmovi.cod_transaccion := reg.cod_transaccion;
                r_gmovi.monto           := v_mto_cargo;
                r_gmovi.nro_documento   := v_nro_documento;
                r_gmovi.nro_documento2  := null;
                if length(reg.cod_movimiento)> 15 then
                   r_gmovi.nro_documento3 := substr(to_char(reg.cod_movimiento),length(to_char(reg.cod_movimiento))+1 -15,15);
                else
                   r_gmovi.nro_documento3 := reg.cod_movimiento;
                end if;
                r_gmovi.cotizacion      := v_mto_cotizacion;
                r_gmovi.mto_equ_local   := round(nvl(v_mto_cargo,0)* v_mto_cotizacion,0);
                r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := reg.concepto;
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                r_gmovi.cod_rubro       := null;
                r_gmovi.cod_tasa        := reg.cod_tasa;
                r_gmovi.val_tasa        := reg.val_tasa;
                r_gmovi.tip_mov_rubro   := null;
                r_gmovi.cod_persona     := reg.cod_persona;
                r_gmovi.referencia      := reg.referencia;

                 pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

                if v_nro_secuencia > 990 then
                  v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                  v_nro_secuencia := -999;
                end if;

                 --Insertar el Movimiento Por el Impuesto
                 r_gmovi.cod_usuario     := substr(user,1,10);
                 r_gmovi.hora            := v_hor_actual;
                 r_gmovi.fecha           := v_fec_actual;
                 -- Aumento la secuencia
                 v_nro_secuencia         := v_nro_secuencia + 1;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 --
                 r_gmovi.cod_modulo      := reg.cod_modulo;
                 r_gmovi.cod_modalidad   := reg.cod_modalidad;
                 r_gmovi.cod_oficina     := v_cod_ofi_origen;
                 r_gmovi.nro_cuenta      := null;
                 r_gmovi.cod_moneda      := reg.cod_moneda;
                 r_gmovi.fec_valor       := reg.fecha;
                 r_gmovi.cod_tra_padre   := v_cod_tra_padre;--nvl(reg.cod_tra_padre,150);
                 r_gmovi.cod_mod_padre   := v_cod_mod_padre;--nvl(reg.cod_mod_padre,3);
                 r_gmovi.cod_mad_padre   := v_cod_mad_padre;--nvl(reg.cod_mad_padre,31);
                 r_gmovi.cod_transaccion := v_cod_tra_impuesto;
                 r_gmovi.monto           := v_mto_impuesto;
                 r_gmovi.nro_documento   := v_nro_documento;
                 r_gmovi.nro_documento2  := null;
                 if length(reg.cod_movimiento)> 15 then
                   r_gmovi.nro_documento3 := substr(to_char(reg.cod_movimiento),length(to_char(reg.cod_movimiento))+1 -15,15);
                 else
                   r_gmovi.nro_documento3 := reg.cod_movimiento;
                 end if;
                 r_gmovi.cotizacion      := v_mto_cotizacion;
                 r_gmovi.mto_equ_local   := round(nvl(v_mto_impuesto,0)* v_mto_cotizacion,0);
                 r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.concepto        := reg.concepto;
                 r_gmovi.estado          := 'N';
                 r_gmovi.reversado       := 'N';
                 r_gmovi.cod_rubro       := null;
                 r_gmovi.cod_tasa        := v_cod_tas_impuesto;
                 r_gmovi.val_tasa        := v_val_tas_impuesto;
                 r_gmovi.tip_mov_rubro   := null;
                 r_gmovi.cod_persona     := reg.cod_persona;
                 r_gmovi.referencia      := reg.referencia;

                 pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

             end if;

             --Si fue todo ok actualizar el saldo y el estado
             if v_hubo_error = 'N' then
                update ge_mov_pen_cobranzas
                   set saldo = nvl(saldo,0) - (nvl(v_mto_cargo,0) + nvl(v_mto_impuesto,0)),
                       fec_cobro= pag_cal.FU_OBT_FEC_ACTUAL(1),
                       cierre ='S', --Se cobró en el cierre
                       estado = 'P'
                 where rowid = v_fila;
                -- rab 08/10/2010 p/ Comisiones Diferidas
                update ge_movimientos
                   set fec_fin_retencion = reg.fec_vencimiento
                 where cod_usuario       = substr(user,1,10)
                   and hora              = v_hor_actual
                   and fecha             = v_fec_actual
                   and fug_ver_tra_comision(cod_modulo,cod_modalidad,cod_transaccion) = 'S';
             end if;
      end loop;
      --pae_cnf.G_NRO_SECUENCIA  := v_nro_secuencia;
      --v_nro_secuencia := nvl(v_nro_sec_final, v_nro_secuencia); -- SDC AP 641. Si v_nro_sec_final es nulo entonces retorna v_nro_secuencia.
      --***************Para Movimiento de Crédito********************
      --Para movimiento de Crédito por el total cobrado en el día
      for i in c_ent_tot_acreditar loop

        begin
           v_nro_cuenta:= null;
           v_cod_tra_padre:=null;
           v_total_general:=0;
           begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
           if i.cod_moneda= pag_gen.fu_obt_mon_local then
              v_nro_cuenta := fug_obt_parentes(i.cod_ente, 'NRO_CTA_RECAUDADORA_GS');
           elsif i.cod_moneda= pag_gen.fu_obt_mon_fuerte  then
              v_nro_cuenta := fug_obt_parentes(i.cod_ente, 'NRO_CTA_RECAUDADORA_USD');
           else
              v_nro_cuenta := fug_obt_parentes(i.cod_ente, 'NRO_CTA_RECAUDADORA_EUR');
           end if;
            v_cod_tra_padre := fug_obt_parentes(i.cod_ente, 'COD_TRA_PADRE');
           IF v_nro_cuenta is not null then
               --v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               --v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'S');
               if v_nro_secuencia > 990 then
                   v_hor_actual := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,user,'N');
                   v_nro_secuencia := -999;
               end if;
               --v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               begin
                     select a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
                       into v_cod_mod_cre, v_cod_mad_cre, v_cod_ofi_cre, v_cod_mon_cre
                       from ge_cuentas a
                      where a.nro_cuenta = v_nro_cuenta;
               exception
                    when no_data_found then
                       v_cod_mod_cre := null;
                       v_cod_mad_cre := null;
                       v_cod_ofi_cre := null;
                       v_cod_mon_cre := null;
                    when others then
                       v_cod_mod_cre := null;
                       v_cod_mad_cre := null;
                       v_cod_ofi_cre := null;
                       v_cod_mon_cre := null;
                 end;
                 begin
                   v_total_general:= nvl(v_total_general,0) + nvl(i.total,0);
                    pag_cta.pr_act_operacion(v_nro_cuenta,
                              v_hor_actual,
                              'C',
                              i.cod_moneda,
                              v_total_general,--i.total,
                              v_cod_tra_padre,
                              602,
                              i.cod_ente,           --nro documento
                              null,
                              31/*v_cod_ofi_cre*/, --cod_ofi_origen
                              3,--v_cod_mod_cre,             --cod_mod_padre
                              31,--v_cod_mad_cre,             --cod_mad_padre
                              null,                      --cod_tasa
                              null,                      --val_tasa
                              trim('CRÉDITO POR COBRANZAS')||': '||to_char(v_cod_ent_aux),
                              'S',                       --emi_aviso
                              v_nro_secuencia,
                              v_fec_actual);
                              --commit;
                exception
                   when others then
                    v_det_error:=null;
                    v_det_error := pag_cta.G_MSJ_ERROR;
                    v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
                    v_hfin_mail    := to_char(sysdate,'hh24:mi:ss');
                    INSERT INTO ge_ra_log_mail
                     (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                    VALUES
                     (SYSDATE, 'grab_mov_seg.txt','ERROR', 'Grab.Mov.Seg.', v_det_error, v_hini_mail, v_hfin_mail);
                    --COMMIT;
                    v_det_error:=null;
                end;
            end if;
        EXCEPTION
          when others then
             v_det_error := substr(sqlerrm,1,4000);
              INSERT INTO ge_ra_log_mail
               (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
              VALUES
               (SYSDATE, 'env_mai_cob.txt','ERROR', 'Cobro.Ope', v_det_error, v_hini_mail, v_hfin_mail);
              --COMMIT;

        END;
      end loop;
  end loop;
    --*****************************************************************
    --Para actualización de registros cobrados en la tabla de seguros
     for k in c_ent_reg_cobrados loop
       v_nro_registro:= null;
       v_nro_registro:= trim(substr(k.observacion, 1, instr(k.observacion,'-') -1));
       v_cod_ente := to_number(trim(substr(k.concepto, 1, instr(k.concepto,'-') -1)));

       BEGIN
         begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
         v_monto:=null;
         begin
            select c.monto
              into v_monto
              from ge_pag_recaudaciones_err c
             where c.fec_operacion = trunc(k.fecha)
               and c.cod_ente = v_cod_ente
               and c.nro_cta_debito=k.nro_cuenta
               and c.cod_moneda= k.cod_moneda
               and rownum=1;
         exception
             when no_data_found then
               v_monto:=0;
             when others then
               v_monto:=0;
         end;
         if nvl(v_monto,0)= k.monto then
             --Si es el mismo monto se borra
             delete from ge_pag_recaudaciones_err a
             where a.nro_cta_debito = k.nro_cuenta
               and a.fec_operacion = trunc(k.fecha)
               and a.cod_ente = v_cod_ente;
         elsif nvl(v_monto,0) > 0 then
            --Sino es, se resta del total
            update ge_pag_recaudaciones_err a
             set a.monto= a.monto - k.monto
            where a.nro_cta_debito = k.nro_cuenta
              and a.fec_operacion = trunc(k.fecha)
              and a.cod_ente = v_cod_ente;
         end if;

       EXCEPTION
         when others then
           null;
       END;

       BEGIN
         update ge_pag_recaudaciones g
            set g.estado = 'N'
          where g.nro_cta_debito = k.nro_cuenta
            and g.fec_operacion = trunc(k.fecha)
            and g.cod_ente = v_cod_ente
            and g.nro_documento = to_number(nvl(v_nro_registro,0))
            and g.estado = 'E';
       EXCEPTION
         when others then
           null;
       END;
      --commit;
     end loop;
  --*************************************************************
  -- Se envían los mails por cobranzas del día(17_06).
  begin
    pag_rec.pr_env_mai_cobros;

  exception
    when others then
            v_det_error := substr(sqlerrm,1,4000);
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, 'Env_mai_cob_cie.txt','ERROR', 'Mail.Cob.Seg', v_det_error, v_hini_mail, v_hfin_mail);
            --COMMIT;
  end;
  -- Se excluye por el Requerimiento SDREPOWE-1, las notificaciones se realizarán desde el proceso PRG_GEN_REN_SEGUROS
  --PCCDEEVO-498 Se enviarán Notificaciones de Vto. de Seguros
  v_diferencia:=0;
  --Se debera avisar CAN_DIA_NOT_VTO_SEGURO (30 dias inicial) antes
   v_fec_desde:= trunc(trunc(pag_cal.FU_OBT_FEC_ACTUAL(1)) + v_can_dias);
   --Obtenemos siguiente día habil
   v_sig_dia_habil:= trunc(pag_cal.fu_obt_fec_sig_hab(trunc(pag_cal.FU_OBT_FEC_ACTUAL(1)),NULL,1));
   --Diferencia en días de siguiente fecha habil y hoy
   v_diferencia:= (trunc(v_sig_dia_habil) - trunc(pag_cal.FU_OBT_FEC_ACTUAL(1)));
   --Si es mayor a uno es un feriado o fin de semana
   if nvl(v_diferencia,0) > 1 then
      v_fec_hasta:= trunc(trunc(v_sig_dia_habil) + v_can_dias);
    else
      v_fec_hasta:=v_fec_desde;
   end if;
   
   --excluir notificación de seguros
   
   for z in c_ent_reg_vto loop
       begin
          PRG_GEN_NOT_SEGUROS(z.cod_persona,
                              null,
                              'V',
                              z.cod_ente,
                              z.fec_final,
                              z.nro_poliza);
      exception
        when others then
                 v_hora:= to_char(sysdate,'hh24:mi:ss');
                 v_error:= substr(to_char(sqlerrm),1,3000);
                 INSERT INTO ge_ra_log_mail
                           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                 VALUES
                           (SYSDATE, z.codigo||'-Per: '||z.cod_persona, 'ERROR', 'Not.Vto.Cob.Mov.Pen ', v_error,v_hora , v_hora); 

                
      end;
   end loop;
exception
    when others then
      null;
END;
/

