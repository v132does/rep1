CREATE OR REPLACE PROCEDURE IT.PRG_OBT_CAR_USO_PRO_ATM
 /* retorna el cargo e iva a ser cobrado por el uso de nuetros atms */
 ( P_NRO_CUENTA           in GE_CUENTAS.NRO_CUENTA%TYPE
  ,P_COD_GRU_TRANSACCION  IN GE_GRU_TRANSACCIONES.COD_GRU_TRANSACCION%TYPE
  ,P_COD_TRANSACCION      IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_PAR_DINAMICO         IN VARCHAR2
  ,P_COD_TAS_CARGO        OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_CARGO        OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_CARGO            OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRA_IMPUESTO     OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_COD_TAS_IMPUESTO     OUT GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_IMPUESTO         OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,p_ind_tra_atm          in varchar2 default 'N'  -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016 - Indicador de transaccion en ATM
   )
   is
   v_can_ope_his    number;
   v_can_ope_dia    number;
   v_can_ope_noc    number;
   v_can_ext_permitidas        number;
   v_fec_inicial    ge_calendarios.fec_actual%type;
   v_fcdehoy        ge_calendarios.fec_actual%type;
   --Datos de la cuenta
   v_cod_modulo     ge_cuentas.cod_modulo%type;
   v_cod_modalidad  ge_cuentas.cod_modalidad%type;
   v_cod_moneda     ge_cuentas.cod_moneda%type;
   v_cod_oficina    ge_cuentas.cod_oficina%type;
   v_fec_apertura   ge_calendarios.fec_actual%type;
   --
   v_cod_bco_entidad number(5) := fug_obt_cod_banco;
   v_cod_bco_fusion  ge_bancos.cod_banco%type := fug_obt_cod_ban_fusion; 
   --
   v_cod_tas_limite ge_mov_sin_costo.cod_tas_limite%type;
   v_redondeo       number;
   ---
   v_cod_tas_cargo  GE_MOVIMIENTOS.COD_TASA%TYPE;
   ---
   v_val_cargo    ge_movimientos.val_tasa%type;
   v_val_tas_imp  ge_movimientos.val_tasa%type;
   v_val_impuesto ge_movimientos.val_tasa%type;
   -- CROMEEXO-1 se almacenan todas las exoneraciones de ATM
   v_tot_ope_dia         number;
   v_val_car_tarifario   ge_movimientos.val_tasa%type;
   v_val_imp_tarifario   ge_movimientos.val_tasa%type;
   v_val_tas_cargo       ge_movimientos.val_tasa%type;
   v_cod_tra_impuesto    ge_movimientos.cod_transaccion%type;
   v_cod_tas_impuesto    ge_movimientos.cod_tasa%type;
--
 function lp_obt_can_ope_atm( p_nro_cuenta       ge_cuentas.nro_cuenta%type,
                              p_gru_transaccion  ge_gru_transacciones.cod_gru_transaccion%type  ) 
          return number is
   v_ret number;
 begin
    select a.cantidad
      into v_ret
      from ge_can_ope_atm_mes a
     where a.nro_cuenta = p_nro_cuenta
       and a.cod_gru_transaccion = p_gru_transaccion;
    return nvl(v_ret,0);
 exception
   when others then
     return nvl(v_ret,0);
 end lp_obt_can_ope_atm;
--
begin  
  v_fcdehoy     := pag_cal.fu_obt_fec_actual(3);
  v_fec_inicial := to_date('01/'||to_char(v_fcdehoy,'MM/YYYY'),'DD/MM/YYYY');
  --
  begin
    select cod_modulo, cod_modalidad, cod_moneda,cod_oficina, fec_apertura
      into v_cod_modulo, v_cod_modalidad, v_cod_moneda,v_cod_oficina, v_fec_apertura
      from ge_cuentas
     where nro_cuenta = p_nro_cuenta;
  exception
    when others then
      raise_application_error(-20000,'En obtener datos de la cuenta '||sqlerrm);
  end;
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
  begin
     select a.cod_tas_limite
       into v_cod_tas_limite
       from ge_mov_sin_costo a
      where a.cod_gru_transaccion = p_cod_gru_transaccion;
  end;
  if v_fec_apertura < v_fec_inicial then
      -- Obtener cantidad de operaciones realizadas en el mes
      if v_cod_modulo in (3,4) then
         v_can_ope_his := lp_obt_can_ope_atm(p_nro_cuenta,p_cod_gru_transaccion);
      end if;
      if v_cod_modulo in (3,4) then
          select count(1)
            into v_can_ope_dia
            from ge_movimientos
           where nro_cuenta = p_nro_cuenta
             and estado = 'N'
             and reversado = 'N'
             and nvl(monto,0) >= 0 -- DYDMR-11036 Excluye Extornos de Op. no marcados como reversion
             and (nvl(cod_banco,-1) = v_cod_bco_entidad  -- DYDMR-5533
             or nro_documento2 /* nro_atm*/ IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
             or nvl(cod_banco,-1) = v_cod_bco_fusion)
             and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                     from ge_gru_transacciones_det x
                                                                    where x.cod_gru_transaccion = p_cod_gru_transaccion);
  
        
          -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 04/2016 --
          -- Para operacion en ATM tener en cuenta movimientos nocturnos                                                            
          if nvl(p_ind_tra_atm,'N') = 'S' then
            select count(1)
            into v_can_ope_noc
            from ge_movimientos_noc
           where nro_cuenta = p_nro_cuenta
             and estado = 'N'
             and reversado = 'N'
             and nvl(monto,0) >= 0 --- DYDMR-11036 Excluye Extornos de Op. no marcados como reversion
             and (nvl(cod_banco,-1) = v_cod_bco_entidad  -- DYDMR-5533
             or nro_documento2 /* nro_atm*/ IN (select g.cod_atm
                                              from cj_atm_entidades g
                                             where g.estado = 'A')
             or nvl(cod_banco,-1) = v_cod_bco_fusion)
             and (cod_mod_padre, cod_mad_padre, cod_tra_padre) in (select cod_modulo, cod_modalidad, cod_transaccion
                                                                     from ge_gru_transacciones_det x
                                                                    where x.cod_gru_transaccion = p_cod_gru_transaccion);
                                                                    
            v_can_ope_dia := nvl(v_can_ope_dia,0) + nvl(v_can_ope_noc,0);      
          end if;   
          --                                                            
      end if;
      v_tot_ope_dia := v_can_ope_dia; -- CROMEEXO-1 almacena cantidad de operaciones del día
      --Obtener la cantidad de uso de otros atms
      v_can_ext_permitidas := fug_obt_can_permitidas(p_nro_cuenta, v_cod_tas_limite, P_PAR_DINAMICO);
      if nvl(v_can_ext_permitidas,0) > nvl(v_can_ope_his,0) then
        v_can_ext_permitidas :=  nvl(v_can_ext_permitidas,0) - nvl(v_can_ope_his,0); -- le bajo las ya realizadas hasta ayer
      else
        v_can_ext_permitidas := 0; -- ya no tiene permitida ninguna transaccion, porque ya se exedio en la historia
      end if; 
         
      --Si las operaciones realizadas superan a las permitidas, si cobra el cargo
      If nvl(v_can_ope_dia,0) > v_can_ext_permitidas  then
         prg_obt_cargos(v_cod_oficina,
                        p_nro_cuenta,
                        v_cod_moneda,
                        NULL,
                        v_cod_modulo,
                        v_cod_modalidad,
                        p_cod_transaccion,--Transaccion para el cobro de cargos
                        p_cod_tas_cargo,
                        p_val_tas_cargo,
                        p_val_cargo,
                        p_cod_tra_impuesto,
                        p_cod_tas_impuesto,
                        p_val_tas_impuesto,
                        p_val_impuesto);
                        
         v_can_ope_dia := nvl(v_can_ope_dia,0) - nvl(v_can_ext_permitidas,0);
         -- se calcula el valor por la cantidad
         -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016
         -- Si es una transaccion de ATM retornar solo el costo de la misma
         if nvl(p_ind_tra_atm,'N') != 'S' then
            p_val_cargo := (p_val_cargo + p_val_impuesto) * v_can_ope_dia;
         else
            p_val_cargo := (p_val_cargo + p_val_impuesto);
         end if;
         p_val_impuesto := round(nvl(p_val_cargo,0)*
                                    nvl(p_val_tas_impuesto,0)/(100+p_val_tas_impuesto),v_redondeo);
         p_val_Cargo    := round(p_val_Cargo - p_val_impuesto,v_redondeo);          
         -- MDPMATNT-1 - Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016
         -- Si es una transaccion de ATM retornar solo el costo de la misma
         if nvl(p_ind_tra_atm,'N') != 'S' then
           /*
           || PCC-Exoneración y Extorno de Comisiones y Tasas
           */
           -- veo si la cuenta tiene transaccion prohibida
           v_cod_tas_cargo := p_cod_tas_cargo;
           --v_val_base      := 0;
           -- busco el valor de la tasa        
           begin
               v_val_cargo := fug_obt_val_tasa(v_cod_modulo,
                                              v_cod_modalidad,
                                              v_cod_oficina,
                                              null,
                                              v_cod_moneda,
                                              0, 'N', NULL,
                                              p_cod_transaccion,
                                              v_fcdehoy);
                v_val_car_tarifario := v_val_cargo;
           exception
              when others then
                 raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
           end;
           begin
              v_val_tas_imp := fug_obt_val_tasa(v_cod_modulo,
                                             v_cod_modalidad,
                                             v_cod_oficina,
                                             null,
                                             v_cod_moneda,
                                             0, 'N', NULL,
                                             p_cod_tra_impuesto,
                                             v_fcdehoy);
           exception
              when others then
                 raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
           end;
           -- DYDMR-9207 - IEC01 - Relevamiento y Ajustes a PRA_COB_CAR_USO_ATM
           -- Se iguala el calculo de impuesto sobre el total para evitar diff por redondeo
           if nvl(p_ind_tra_atm,'N') != 'S' then
              v_val_cargo    := nvl(v_val_cargo, 0) * v_can_ope_dia;
           end if;
           v_val_impuesto := round(nvl(v_val_cargo, 0) * nvl(v_val_tas_imp, 0)
                             / (100 + v_val_tas_imp), v_redondeo);         
           -- DYDMR-9207 - IEC01 - Se iguala calculo con el de p_val_cargo para comparar solo cargo sin IVA
           v_val_cargo    := round(v_val_cargo - v_val_impuesto, v_redondeo);
           if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                           p_cod_transaccion,
                                           v_cod_modulo,
                                           v_cod_modalidad) = 'S' or
              nvl(v_val_cargo, 0) <> nvl(p_val_cargo, 0) or
              nvl(v_val_cargo, 0) = 0 then
         
              prg_ins_exoneracion(p_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                                  v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                  (nvl(v_val_cargo, 0) - nvl(p_val_cargo, 0)),
                                 v_val_cargo, null,
                                (nvl(v_val_cargo, 0) - nvl(p_val_cargo, 0)));
           end if;
           if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                           p_cod_tra_impuesto,
                                           v_cod_modulo,
                                           v_cod_modalidad) = 'S' or
              nvl(v_val_impuesto, 0) <> nvl(p_val_impuesto, 0) or
              nvl(v_val_impuesto, 0) = 0 then
              
              prg_ins_exoneracion(p_cod_tra_impuesto, v_cod_modulo, v_cod_modalidad,
                                  v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                  (nvl(v_val_impuesto, 0) - nvl(p_val_impuesto, 0)),
                                   v_val_impuesto, null,
                                  (nvl(v_val_impuesto, 0) - nvl(p_val_impuesto, 0)));
           end if;
           
           -- CROMEEXO-1 se verifica hay operaciones libres pendientes de registrar en exoneraciones
           if nvl(v_tot_ope_dia,0)-nvl(v_can_ope_dia,0) > 0 then
              -- registrar exoneraciones 100% por la diferencia
              v_val_car_tarifario    := nvl(v_val_car_tarifario, 0) * (nvl(v_tot_ope_dia,0)-nvl(v_can_ope_dia,0));
              
              v_val_imp_tarifario := round(nvl(v_val_car_tarifario, 0) * nvl(v_val_tas_imp, 0)
                                / (100 + v_val_tas_imp), v_redondeo);         
              v_val_car_tarifario    := round(v_val_car_tarifario - v_val_imp_tarifario, v_redondeo);
              if( v_val_car_tarifario > 0) then
               prg_ins_exoneracion(p_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                                        v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                        v_val_car_tarifario,
                                        v_val_car_tarifario, null,
                                        v_val_car_tarifario);
              end if;
              if( v_val_imp_tarifario > 0) then
                 prg_ins_exoneracion(p_cod_tra_impuesto, v_cod_modulo, v_cod_modalidad,
                                          v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                          v_val_imp_tarifario,
                                          v_val_imp_tarifario, null,
                                          v_val_imp_tarifario);
              end if;
           end if;           
         end if;
         ---
      else
         -- CROMEEXO-1 - registra exoneracion 100% para operaciones libres
         if nvl(p_ind_tra_atm,'N') != 'S' then
           -- busca tasa generica
           prg_obt_dat_cargos(v_cod_oficina,
                          p_nro_cuenta,
                          v_cod_moneda,
                          v_cod_modulo,
                          v_cod_modalidad,
                          p_cod_transaccion,--Transaccion para el cobro de cargos
                          v_cod_tas_cargo,
                          v_val_tas_cargo,
                          v_val_cargo,
                          v_cod_tra_impuesto,
                          v_cod_tas_impuesto,
                          v_val_tas_imp,
                          v_val_impuesto,
                          v_fcdehoy);
           -- se calcula el valor por la cantidad
           v_val_cargo := (v_val_cargo + v_val_impuesto) * v_can_ope_dia;
           v_val_impuesto := round(nvl(v_val_cargo,0)*
                                      nvl(v_val_tas_imp,0)/(100+v_val_tas_imp),v_redondeo);
           v_val_cargo    := round(v_val_cargo - v_val_impuesto,v_redondeo);
           if( v_val_cargo > 0) then           
             prg_ins_exoneracion(p_cod_transaccion, v_cod_modulo, v_cod_modalidad,
                                      v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                      v_val_cargo,
                                      v_val_cargo, null,
                                      v_val_cargo);
            end if;
            if( v_val_impuesto > 0) then
               prg_ins_exoneracion(v_cod_tra_impuesto, v_cod_modulo, v_cod_modalidad,
                                        v_cod_moneda, p_nro_cuenta, null, v_cod_tas_cargo,
                                        v_val_impuesto,
                                        v_val_impuesto, null,
                                        v_val_impuesto);
            end if;                     
          end if;
      end if;
   end if;
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'En obtener cargos'||' - '||sqlerrm);
    End if;
end prg_obt_car_uso_pro_atm;
/

