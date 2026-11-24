CREATE OR REPLACE PROCEDURE IT.PRG_COB_MOV_PENDIENTES
(p_nro_cuenta in varchar2 default null,
 p_cod_movimiento in ge_mov_pendientes.cod_movimiento%type default null) is

 
 
/* Proceso que intenta debitar los movimientos pendientes a las cuentas */
/* Si recibe p_nro_cuenta y p_cod_movimiento es llamado desde el programa y levanta errores */
/* Si recibe sólo p_nro_cuenta viene de plan sueldo, no debe levantar errores */
/* Si no recibe parámetros viene desde el proceso de fin de día y no levanta errores, sólo marca los registros */

/* Modificaciones:
   RAMG: 06-may-2010. Se modifico en el parametro de transaccion para el calculo de impuesto, la tran.padre por la hija
   
*/

  v_mto_cargo         GE_MOVIMIENTOS.monto%TYPE;
  v_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  v_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  v_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_mto_impuesto      GE_MOVIMIENTOS.monto%TYPE;
  v_des_error         ge_mov_pendientes.motivo%type;
  v_cod_ofi_origen    ge_movimientos.cod_oficina%type;

  v_hor_actual        varchar2(08) ;
  v_fec_actual        date;
  v_fec_movim         date;
  --v_nro_secuencia     number(3) := nvl(pae_cnf.G_NRO_SECUENCIA,0);
  v_nro_Secuencia     ge_movimientos.nro_secuencia%type := -999;
  v_fila              varchar2(200);
  v_nvo_estado        ge_cuentas.estado%type;
  v_sal_disponible    ge_cuentas.sal_contable%type;
  v_procesa           varchar2(01) := 'N';
  v_hubo_error        varchar2(01) := 'N';
  v_es_plan_sueldo    varchar2(01) := 'N';
  --RI: 15/12/2010: Parametro creado para determinar si se procesa cuenta de nomina
  v_pro_cta_nomina varchar2(1) := nvl(fug_obt_pardinamico('PRO_CTA_NOMINA'),'S');

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
  v_error varchar2(1);
  v_mto_cotizacion    ge_movimientos.cotizacion%type;
  v_cod_mon_local     ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_cod_movimiento    ge_movimientos.nro_documento3%type;
  v_es_pag_sueldo     varchar2(1):='N';
  v_cod_mov_sueldo    number(30):=null;
  v_est_modulo        ba_modulos.estado%type;
  v_es_nocturno       varchar2(1) default 'N';

cursor ctas is
  select a.cod_movimiento fila,a.nro_cuenta,a.cod_moneda,a.cod_modulo,a.cod_modalidad,a.saldo,
  a.cod_transaccion,a.car_manual,a.cod_tasa,a.val_tasa,a.nro_documento,a.cod_tra_padre,
  a.cod_mod_padre,a.cod_mad_padre,a.cod_oficina,a.cod_movimiento,a.concepto,a.fecha,
  a.cod_persona,a.referencia,a.fec_vencimiento
    from ge_mov_pendientes a
   where nro_cuenta = nvl(p_nro_cuenta, nro_cuenta)
     and estado = 'I' --sólo pendientes de cobro (Ingresado) y con saldo
     and nvl(saldo,0) > 0
     and cod_movimiento = nvl(p_cod_movimiento, cod_movimiento)
    /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
     and (not exists (Select 1 from cc_cta_corrientes c
                       where c.nro_cuenta = a.nro_cuenta and c.cod_ente is not null
                         and v_pro_cta_nomina = 'N')
      or v_pro_cta_nomina = 'S')
     and (not exists(Select 1 from ah_cta_vistas c
                      where c.nro_cuenta = a.nro_cuenta and c.cod_ente is not null
                        and v_pro_cta_nomina = 'N')
      or v_pro_cta_nomina = 'S');
--Par cuentas de sueldo
cursor mov_cli is
 select a.cod_movimiento
    from ge_mov_pendientes a
   where nro_cuenta = p_nro_cuenta
     and estado = 'I' --sólo pendientes de cobro (Ingresado) y con saldo
     and nvl(saldo,0) > 0
     /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */
     and (not exists (Select 1 from cc_cta_corrientes c
                       where c.nro_cuenta = a.nro_cuenta and c.cod_ente is not null
                         and v_pro_cta_nomina = 'N')
      or v_pro_cta_nomina = 'S')
     and (not exists(Select 1 from ah_cta_vistas c
                      where c.nro_cuenta = a.nro_cuenta and c.cod_ente is not null
                        and v_pro_cta_nomina = 'N')
      or v_pro_cta_nomina = 'S');

cursor ctas_sue (v_cod_mov_sueldo number)is
  select a.nro_cuenta,a.cod_moneda,a.cod_modulo,a.cod_modalidad,a.saldo,
  a.cod_transaccion,a.car_manual,a.cod_tasa,a.val_tasa,a.nro_documento,a.cod_tra_padre,
  a.cod_mod_padre,a.cod_mad_padre,a.cod_oficina,a.concepto,a.fecha,
  a.cod_persona,a.referencia,a.fec_vencimiento,a.cod_movimiento fila,v_cod_mov_sueldo cod_movimiento
    from ge_mov_pendientes a
   where a.cod_movimiento=   v_cod_mov_sueldo ;

/* actualiza el movimiento si hubo error en el cobro */
procedure lp_act_mov_pendiente is
begin
   update ge_mov_pendientes
      set estado = 'X',
          motivo = substr(motivo || v_des_error, 1, 100)
    where /*rowid*/cod_movimiento = v_fila;
end;

begin
  prg_cre_savepoint(p_nro_cuenta);
  v_fec_actual := pag_cal.fu_obt_fec_actual(3);
  v_hor_actual := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_cod_ofi_origen := FUG_OBT_OFI_USUARIO(user);
  
  --DYDMR-12288 - Se agrega verificacion de modulo--
  --Para que si el programa se junta con el inicio--
  --inserta correctamente, y no se pierdan movimientos--
  v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
  If v_est_modulo = 2 then
     v_es_nocturno := 'N';
     v_fec_movim  := v_fec_actual;
  else
     v_es_nocturno := 'S';
     v_fec_movim   := pag_cal.fu_obt_fec_proxima(3);
  end if;

  if p_nro_cuenta is not null then
     v_nro_secuencia   := nvl(pae_cnf.G_NRO_SECUENCIA,0);
  end if;

  if p_nro_cuenta is not null and p_cod_movimiento is null then
     pag_sue.pr_ins_log(p_nro_cuenta,0,'MOV_PENDIENTES','Proceso de Débito de Mov. pendientes');
     v_es_pag_sueldo:='S';
  end if;

if nvl(v_es_pag_sueldo,'N')='N' THEN
  for reg in ctas loop
     --Verifica si la cuenta es de plan sueldo
     v_es_plan_sueldo := fug_es_pla_sueldo(reg.nro_cuenta, reg.cod_modalidad);
     --Sólo para cuentas que no son plan sueldo, o si es de plan sueldo y viene la cuenta específica
     --
     -- RI: 07/05/2010. Se permite cobrar a cuentas nóminas también en el momento del cierre.
     --if v_es_plan_sueldo = 'N' or (v_es_plan_sueldo = 'S' and p_nro_cuenta is not null) then
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
         v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
         v_nro_secuencia := -999;
       end if;
       v_fila := reg.fila;--reg.rowid;
       v_mto_cargo := nvl(reg.saldo,0);

       --calcular impuesto
       prg_obt_car_impuesto(v_cod_ofi_origen, reg.nro_cuenta, reg.cod_moneda, reg.cod_modulo, reg.cod_modalidad,
       reg.cod_transaccion, v_mto_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_mto_impuesto);
       v_mto_impuesto := nvl(v_mto_impuesto,0);


       v_cod_tra_padre   := reg.cod_transaccion;
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
                               reg.cod_tra_padre,
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
         if p_nro_cuenta is not null and p_cod_movimiento is not null then
           raise_application_error(-20001,'Cob.Mov.Pend '||pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR());
         else
           v_hubo_error := 'S';
           --sólo si no es por saldo insuficiente
           if pag_cta.g_cod_error not in(25, 31, 29) then
             --actualizar el movimiento con error
             v_des_error := pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR();
             lp_act_mov_pendiente;
           end if;
         end if;
       end if;

       --si no hubo error se realiza el débito por el monto del cargo
       if v_nro_secuencia > 990 then
         v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
         v_nro_secuencia := -999;
       end if;
       if v_hubo_error = 'N' then
         pag_cta.G_COD_ERROR := 0;
         If nvl(reg.car_manual,'N') = 'N' then
            if p_nro_cuenta is not null and p_cod_movimiento is null then
               pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_cargo,'MOV_PENDIENTES','Carga Automática - Aplicación de Mov.Pendiente: '||v_nro_secuencia);
            end if;

               if reg.cod_moneda <> v_cod_mon_local then
                  v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
               else
                  v_mto_cotizacion := null;
               end if;

               PAG_CTA.PR_SET_VARIABLES(user,
                                        v_fec_actual,
                                        reg.cod_tra_padre,
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
                                        v_cod_ofi_origen,
                                        reg.cod_mod_padre,
                                        reg.cod_mad_padre,
                                        v_cod_tasa,--reg.COD_TASa, -- tasa
                                        v_val_tasa,--reg.VAL_TASa, -- valor de tasa
                                        'Aplicación de Mov.Pendiente: '||reg.concepto, --concepto
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

            if p_nro_cuenta is not null and p_cod_movimiento is null then
               pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_debito,'MOV_PENDIENTES','Carga Manual - Aplicación de Mov.Pendiente '||v_nro_secuencia);
            end if;

             if reg.cod_moneda <> v_cod_mon_local then
                v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
             else
                v_mto_cotizacion := null;
             end if;

              PAG_CTA.PR_SET_VARIABLES(user,
                                       v_fec_actual,
                                       reg.cod_tra_padre,
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
                                       v_cod_ofi_origen,
                                       reg.cod_mod_padre,
                                       reg.cod_mad_padre,
                                       v_cod_tasa,--reg.COD_TASa, -- tasa
                                       v_val_tasa,--reg.VAL_TASa, -- valor de tasa
                                       'Aplicación de Mov.Pendiente: '||reg.concepto, --concepto
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
            if p_nro_cuenta is not null and p_cod_movimiento is not null then
               raise_application_error(-20002,'Cob.cargo '||pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR());
            else
             v_hubo_error := 'S';
             --actualizar el movimiento con error
             --sólo si no es por saldo insuficiente
              if pag_cta.g_cod_error not in(25, 31, 29) then
                v_des_error := pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR();
                lp_act_mov_pendiente;
              End if;
           end if;
         end if;

         if nvl(reg.car_manual,'N') = 'N' then
            if v_nro_secuencia > 990 then
               v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
               v_nro_secuencia := -999;
            end if;
            --Realiza el débito por el monto del impuesto
            if v_mto_impuesto > 0 and  v_hubo_error = 'N' then
                if p_nro_cuenta is not null and p_cod_movimiento is null then
                   pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_impuesto,'MOV_PENDIENTES','Carga Automatica - Débito por el monto del impuesto '||v_nro_secuencia);
                end if;

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
                                        v_cod_ofi_origen,
                                        reg.cod_mod_padre,
                                        reg.cod_mad_padre,
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
                  if p_nro_cuenta is not null and p_cod_movimiento is not null then
                     raise_application_error(-20003,'Cob.Impuesto '||pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR());
                  else
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
           if p_nro_cuenta is not null and p_cod_movimiento is null then
              pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_impuesto,'MOV_PENDIENTES','Carga Manual - Genera Movimiento '||v_nro_secuencia);
           end if;

            if v_nro_secuencia > 990 then
               v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
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
            r_gmovi.fecha           := v_fec_movim;
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
            
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);

            if v_nro_secuencia > 990 then
              v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
              v_nro_secuencia := -999;
            end if;

             --Insertar el Movimiento Por el Impuesto
             r_gmovi.cod_usuario     := substr(user,1,10);
             r_gmovi.hora            := v_hor_actual;
             r_gmovi.fecha           := v_fec_movim;
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

             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);

         end if;

         --Si fue todo ok actualizar el saldo y el estado
         if v_hubo_error = 'N' then
            update ge_mov_pendientes
               set saldo = nvl(saldo,0) - (nvl(v_mto_cargo,0) + nvl(v_mto_impuesto,0)),
                   estado = 'P'
             where cod_movimiento/*rowid*/ = v_fila;
            -- rab 08/10/2010 p/ Comisiones Diferidas
            update ge_movimientos
               set fec_fin_retencion = reg.fec_vencimiento
             where cod_usuario       = substr(user,1,10)
               and hora              = v_hor_actual
               and fecha             = v_fec_actual
               and fug_ver_tra_comision(cod_modulo,cod_modalidad,cod_transaccion) = 'S';
         end if;
       End if;
       v_nro_secuencia := nvl(v_nro_sec_final, v_nro_secuencia); -- SDC AP 641. Si v_nro_sec_final es nulo entonces retorna v_nro_secuencia.
  end loop;
ELSE
  --************** Para Pago de Sueldos****************************
  for mov in mov_cli loop
    v_cod_mov_sueldo:=null;
    v_cod_mov_sueldo :=mov.cod_movimiento;
    for reg in ctas_sue(v_cod_mov_sueldo) loop
     --Verifica si la cuenta es de plan sueldo
     v_es_plan_sueldo := fug_es_pla_sueldo(reg.nro_cuenta, reg.cod_modalidad);
     --Sólo para cuentas que no son plan sueldo, o si es de plan sueldo y viene la cuenta específica
     --
     -- RI: 07/05/2010. Se permite cobrar a cuentas nóminas también en el momento del cierre.
     --if v_es_plan_sueldo = 'N' or (v_es_plan_sueldo = 'S' and p_nro_cuenta is not null) then
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
         v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
         v_nro_secuencia := -999;
       end if;
       v_fila := reg.fila;--reg.rowid;
       v_mto_cargo := nvl(reg.saldo,0);

       --calcular impuesto
       prg_obt_car_impuesto(v_cod_ofi_origen, reg.nro_cuenta, reg.cod_moneda, reg.cod_modulo, reg.cod_modalidad,
       reg.cod_transaccion, v_mto_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_mto_impuesto);
       v_mto_impuesto := nvl(v_mto_impuesto,0);


       v_cod_tra_padre   := reg.cod_transaccion;
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
                               reg.cod_tra_padre,
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
         if p_nro_cuenta is not null and p_cod_movimiento is not null then
           raise_application_error(-20001,'Cob.Mov.Pend '||pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR());
         else
           v_hubo_error := 'S';
           --sólo si no es por saldo insuficiente
           if pag_cta.g_cod_error not in(25, 31, 29) then
             --actualizar el movimiento con error
             v_des_error := pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR();
             lp_act_mov_pendiente;
           end if;
         end if;
       end if;

       --si no hubo error se realiza el débito por el monto del cargo
       if v_nro_secuencia > 990 then
         v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
         v_nro_secuencia := -999;
       end if;
       if v_hubo_error = 'N' then
         pag_cta.G_COD_ERROR := 0;
         If nvl(reg.car_manual,'N') = 'N' then
            if p_nro_cuenta is not null and p_cod_movimiento is null then
               pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_cargo,'MOV_PENDIENTES','Carga Automática - Aplicación de Mov.Pendiente: '||v_nro_secuencia);
            end if;

               if reg.cod_moneda <> v_cod_mon_local then
                  v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
               else
                  v_mto_cotizacion := null;
               end if;

               PAG_CTA.PR_SET_VARIABLES(user,
                                        v_fec_actual,
                                        reg.cod_tra_padre,
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
                                        v_cod_ofi_origen,
                                        reg.cod_mod_padre,
                                        reg.cod_mad_padre,
                                        v_cod_tasa,--reg.COD_TASa, -- tasa
                                        v_val_tasa,--reg.VAL_TASa, -- valor de tasa
                                        'Aplicación de Mov.Pendiente: '||reg.concepto, --concepto
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

            if p_nro_cuenta is not null and p_cod_movimiento is null then
               pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_debito,'MOV_PENDIENTES','Carga Manual - Aplicación de Mov.Pendiente '||v_nro_secuencia);
            end if;

             if reg.cod_moneda <> v_cod_mon_local then
                v_mto_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
             else
                v_mto_cotizacion := null;
             end if;

              PAG_CTA.PR_SET_VARIABLES(user,
                                       v_fec_actual,
                                       reg.cod_tra_padre,
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
                                       v_cod_ofi_origen,
                                       reg.cod_mod_padre,
                                       reg.cod_mad_padre,
                                       v_cod_tasa,--reg.COD_TASa, -- tasa
                                       v_val_tasa,--reg.VAL_TASa, -- valor de tasa
                                       'Aplicación de Mov.Pendiente: '||reg.concepto, --concepto
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
            if p_nro_cuenta is not null and p_cod_movimiento is not null then
               raise_application_error(-20002,'Cob.cargo '||pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR());
            else
             v_hubo_error := 'S';
             --actualizar el movimiento con error
             --sólo si no es por saldo insuficiente
              if pag_cta.g_cod_error not in(25, 31, 29) then
                v_des_error := pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR();
                lp_act_mov_pendiente;
              End if;
           end if;
         end if;

         if nvl(reg.car_manual,'N') = 'N' then
            if v_nro_secuencia > 990 then
               v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
               v_nro_secuencia := -999;
            end if;
            --Realiza el débito por el monto del impuesto
            if v_mto_impuesto > 0 and  v_hubo_error = 'N' then
                if p_nro_cuenta is not null and p_cod_movimiento is null then
                   pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_impuesto,'MOV_PENDIENTES','Carga Automatica - Débito por el monto del impuesto '||v_nro_secuencia);
                end if;

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
                                        v_cod_ofi_origen,
                                        reg.cod_mod_padre,
                                        reg.cod_mad_padre,
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
                  if p_nro_cuenta is not null and p_cod_movimiento is not null then
                     raise_application_error(-20003,'Cob.Impuesto '||pag_cta.g_cod_error ||'-'||pag_cta.FU_OBT_MSJ_ERROR());
                  else
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
           if p_nro_cuenta is not null and p_cod_movimiento is null then
              pag_sue.pr_ins_log(reg.nro_cuenta,v_mto_impuesto,'MOV_PENDIENTES','Carga Manual - Genera Movimiento '||v_nro_secuencia);
           end if;

            if v_nro_secuencia > 990 then
               v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
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
            r_gmovi.fecha           := v_fec_movim;
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
            
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);

            if v_nro_secuencia > 990 then
              v_hor_actual := fug_obt_hor_disponible(v_fec_movim,v_hor_actual,user,v_es_nocturno);
              v_nro_secuencia := -999;
            end if;

             --Insertar el Movimiento Por el Impuesto
             r_gmovi.cod_usuario     := substr(user,1,10);
             r_gmovi.hora            := v_hor_actual;
             r_gmovi.fecha           := v_fec_movim;
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
             
             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);

         end if;

         --Si fue todo ok actualizar el saldo y el estado
         if v_hubo_error = 'N' then
            update ge_mov_pendientes
               set saldo = nvl(saldo,0) - (nvl(v_mto_cargo,0) + nvl(v_mto_impuesto,0)),
                   estado = 'P'
             where cod_movimiento/*rowid*/ = v_fila;
            -- rab 08/10/2010 p/ Comisiones Diferidas
            update ge_movimientos
               set fec_fin_retencion = reg.fec_vencimiento
             where cod_usuario       = substr(user,1,10)
               and hora              = v_hor_actual
               and fecha             = v_fec_actual
               and fug_ver_tra_comision(cod_modulo,cod_modalidad,cod_transaccion) = 'S';
         end if;
       End if;
       v_nro_secuencia := nvl(v_nro_sec_final, v_nro_secuencia); -- SDC AP 641. Si v_nro_sec_final es nulo entonces retorna v_nro_secuencia.
  end loop;
  end loop;
END IF;
  pae_cnf.G_NRO_SECUENCIA  := v_nro_secuencia;
exception
    when others then
    if p_nro_cuenta is not null and p_cod_movimiento is null then
        prg_rol_savepoint(p_nro_cuenta);
    end if;
end prg_cob_mov_pendientes;
/

