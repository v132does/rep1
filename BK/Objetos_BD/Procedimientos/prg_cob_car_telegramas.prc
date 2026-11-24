CREATE OR REPLACE PROCEDURE IT.PRG_COB_CAR_TELEGRAMAS
 IS
v_fcdehoy          date;
  v_hora             ge_movimientos.hora%type;
  v_nro_secuencia    ge_movimientos.nro_secuencia%type;
  v_monlocal         ba_monedas.cod_moneda%type;
  v_cod_tas_cargo    ge_movimientos.cod_tasa%type;
  v_val_tas_cargo    ge_movimientos.val_tasa%type;
  v_val_cargo        ge_movimientos.val_tasa%type;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
  v_val_tas_impuesto ge_movimientos.val_tasa%type;
  v_val_impuesto     ge_movimientos.val_tasa%type;
  v_cod_transaccion  ge_movimientos.cod_transaccion%type;
  v_montcar     number;
  v_montimp     number;
  v_tot_car     number;
  v_tra_prohibida  varchar2(1);
  v_cod_modulo     cc_cta_corrientes.cod_modulo%type;
  v_cod_modalidad  cc_cta_corrientes.cod_modalidad%type;
  v_estado         cc_cta_corrientes.estado%type;
  v_sal_disponible cc_cta_corrientes.sal_total%type;
  v_procesa        varchar2(1);
  v_mto_cobrar     number;
  --v_cod_mon_local  varchar2(4) := pag_gen.FU_OBT_MON_LOCAL;
  v_redondeo number(3) := 0;
  v_ref_cuentas    ge_telegramas.ref_cuentas%type;
  v_nro_cuenta     ge_cuentas.nro_cuenta%type;
  v_pos            number(8);
  v_cod_mod_cta    cc_cta_corrientes.cod_modulo%type;
  v_cod_mad_cta    cc_cta_corrientes.cod_modalidad%type;
  v_cod_moneda     ba_monedas.cod_moneda%type;
  v_cod_oficina    cc_cta_corrientes.cod_oficina%type;

cursor telegramas is 
  select ref_cuentas, cod_causa, cod_telegrama, zona, rowid fila
    from ge_telegramas
   where fec_entrega = v_fcdehoy --entregados el dia de hoy
     and cobrado = 'N';
  ---
  v_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PRG_COB_CAR_TELEGRAMAS');
  v_db_prod     VARCHAR2(1) := fug_ind_produccion;
  v_val_exo_cargo    ge_movimientos.val_tasa%type;
  v_val_exo_impuesto ge_movimientos.val_tasa%type;
  v_tip_valor        ge_tasas.tip_valor%type;
begin
  v_fcdehoy       := pag_cal.fu_obt_fec_actual(4);
  v_hora          := FUG_INI_HORA(SYSDATE,'HH24:MI:SS');
  v_nro_secuencia := 0;
  v_monlocal      := pag_gen.fu_obt_mon_local;
  for i in telegramas loop
     v_tra_prohibida := 'N';--incializa variable para poder cobrar
     v_cod_transaccion := null;
       --Obtener la transaccion para el cobro de cargos
  	 begin
  	    select val_parametro
  	      into v_cod_transaccion
  	      from ge_par_causales
  	      where cod_causa = i.cod_causa
  	        and parametro = decode(i.zona,'R','COD_TRA_CAR_RURAL'
  	                                     ,'U','COD_TRA_CAR_URBANAS');
  	 exception
  	 	when no_data_found then
  	  	  v_cod_transaccion := null;
  	 end;
     --si no encuentra transaccion para el cargo,pasar al siguiente registro
     if v_cod_transaccion is null then
        goto siguiente;
     end if;
     v_ref_cuentas := i.ref_cuentas;
     v_nro_cuenta  := null;
     loop --para ir separando las cuentas
         --limpia variables
         v_cod_modulo     := null;
         v_cod_modalidad  := null;
         v_cod_moneda     := null;
         v_cod_oficina    := null;
         v_pos := instr(v_ref_cuentas,',');
         if v_pos > 0 then
            v_nro_cuenta := substr(v_ref_cuentas,1,v_pos-1);
            v_ref_cuentas := substr(v_ref_cuentas,v_pos+1);
         else
            v_nro_cuenta := v_ref_cuentas;
            v_ref_cuentas :=null;
         end if;  
         --obtener los datos de la cuenta
         begin
            select cod_modulo, cod_modalidad, cod_moneda, cod_oficina
              into v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_oficina
              from ge_cuentas
             where nro_cuenta = v_nro_cuenta;
         exception
            when no_data_found then
               raise_application_error(-20000,'Cuenta inexistente '||v_nro_cuenta);
            when others then
               raise_application_error(-20000,'Datos cuenta '||v_nro_cuenta);
         end;
         
         --verificar q la cuenta no tenga transaccion prohibida
         v_tra_prohibida := pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,v_cod_transaccion,v_cod_modulo,v_cod_modalidad);
         
      	 If v_cod_transaccion is not null /*and nvl(v_tra_prohibida,'N') = 'N'*/ then
            --limpiar variables
            v_estado         := null;
            v_sal_disponible := 0;
            v_procesa        := null;
            v_mto_cobrar     := 0;
            v_montcar        := 0;
            v_montimp        := 0;
            v_tot_car        := 0;
            v_cod_tas_cargo  := 0;
            v_val_tas_cargo  := 0;
            v_val_cargo      := 0;
            v_cod_tra_impuesto := 0; 
            v_cod_tas_impuesto := 0;
            v_val_tas_impuesto := 0;
            v_val_impuesto     := 0;
            PRG_OBT_CARGOS
                  (v_cod_oficina
                  ,v_nro_cuenta
                  ,v_cod_moneda
                  ,null
                  ,v_cod_modulo
                  ,v_cod_modalidad
                  ,v_cod_transaccion
                  ,v_cod_tas_cargo
                  ,v_val_tas_cargo
                  ,v_val_cargo
                  ,v_cod_tra_impuesto
                  ,v_cod_tas_impuesto
                  ,v_val_tas_impuesto
                  ,v_val_impuesto);
             v_tot_car := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
             /*
             || PCC-Exoneración y Extorno de Comisiones y Tasas
             || Se ejecuta si el proceso no es mensual
             || o la base de datos no es producción
             */
             IF v_fre_proceso <> 'M' OR v_db_prod = 'N' THEN
                -- busco el valor de la tasa
                begin
                   v_val_exo_cargo := fug_obt_val_tasa(v_cod_modulo,
                                                       v_cod_modalidad,
                                                       v_cod_oficina,
                                                       null,
                                                       v_cod_moneda,
                                                       0, 'N', NULL,
                                                       v_cod_transaccion,
                                                       v_fcdehoy);
                exception
                   when others then
                      raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                end;
                v_tip_valor := fug_obt_tip_val_tasa(v_cod_tas_cargo);
                v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                  v_cod_modulo,
                                                  v_cod_modalidad,
                                                  v_cod_moneda);                
                IF v_tip_valor = 'V' THEN
                   -- si es un valor, se toma directamente
                   v_val_exo_cargo := nvl(v_val_exo_cargo, 0);
                ELSE
                   -- es un porcentaje
                   v_val_exo_cargo := round(nvl(null, 0) * nvl(v_val_exo_cargo, 0) / 100, v_redondeo);
                   --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                   v_val_exo_cargo := pag_gen.fu_obt_val_final(v_val_exo_cargo);
                END IF;
                if nvl(v_tra_prohibida,'N') = 'S' then
                   prg_ins_exoneracion(v_cod_transaccion, v_cod_modulo,
                                       v_cod_modalidad, v_cod_moneda,
                                       v_nro_cuenta, null, v_cod_tas_cargo,
                                       nvl(v_val_exo_cargo, 0),
                                       nvl(v_val_exo_cargo, 0), null,
                                       nvl(v_val_exo_cargo, 0));
                elsif (nvl(v_val_cargo, 0) <> nvl(v_val_exo_cargo, 0)) or
                      (nvl(v_val_cargo, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0) then
                   prg_ins_exoneracion(v_cod_transaccion, v_cod_modulo,
                                       v_cod_modalidad, v_cod_moneda,
                                       v_nro_cuenta, null, v_cod_tas_cargo,
                                       (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)),
                                        v_val_exo_cargo, null,
                                       (nvl(v_val_exo_cargo, 0) - nvl(v_val_cargo, 0)));
                end if;
                begin
                   v_val_exo_impuesto := fug_obt_val_tasa(v_cod_modulo,
                                                          v_cod_modalidad,
                                                          v_cod_oficina,
                                                          null,
                                                          v_cod_moneda,
                                                          0, 'N', NULL,
                                                          v_cod_tra_impuesto,
                                                          v_fcdehoy);
                exception
                   when others then
                      raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
                end;
                IF v_tip_valor = 'V' THEN
                   -- si es un valor, se toma directamente
                   v_val_exo_impuesto := nvl(v_val_exo_impuesto, 0);
                ELSE
                   -- es un porcentaje, se considera incluido en el cargo
                   v_val_exo_impuesto := round(nvl(v_val_exo_cargo, 0) * nvl(v_val_exo_impuesto, 0) /
                                          (100 + v_val_exo_impuesto), v_redondeo);
                   --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                   v_val_exo_impuesto := pag_gen.fu_obt_val_final(v_val_exo_impuesto);
                END IF;
                if pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,
                                                v_cod_tra_impuesto,
                                                v_cod_modulo,
                                                v_cod_modalidad) = 'S' then
                   prg_ins_exoneracion(v_cod_tra_impuesto, v_cod_modulo,
                                       v_cod_modalidad, v_cod_moneda,
                                       v_nro_cuenta, null, v_cod_tas_impuesto,
                                       nvl(v_val_exo_impuesto, 0),
                                       nvl(v_val_exo_impuesto, 0), null,
                                       nvl(v_val_exo_impuesto, 0));
                elsif nvl(v_tra_prohibida,'N') = 'S' then
                   null;
                elsif (nvl(v_val_impuesto, 0) <> nvl(v_val_exo_impuesto, 0)) or
                      (nvl(v_val_impuesto, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
                   prg_ins_exoneracion(v_cod_tra_impuesto, v_cod_modulo,
                                       v_cod_modalidad, v_cod_moneda,
                                       v_nro_cuenta, null, v_cod_tas_impuesto,
                                       (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)),
                                        v_val_exo_impuesto, null,
                                       (nvl(v_val_exo_impuesto, 0) - nvl(v_val_impuesto, 0)));
                end if;
             end if;
          end if;
          ---
          If v_cod_transaccion is not null and nvl(v_tra_prohibida,'N') = 'N' then                     
             --verificar si puede realizarse el debito
             PAG_CTA.PR_VER_OPERACION(v_nro_cuenta,
                                      v_cod_transaccion,   --transaccion padre
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      'D',
                                      v_cod_moneda,
                                      v_tot_car,
                                      v_cod_oficina,
                                      v_cod_mod_cta,
                                      v_cod_mad_cta,
                                      v_estado,
                                      v_sal_disponible,
                                      v_procesa,
                                      v_cod_transaccion);
             --cobrar solo el monto que puede cubrir
             if v_sal_disponible >= v_tot_car then
                 null;
             elsif v_sal_disponible > 1 then
                 -- recalculo para cobrarle hasta el monto disponible
                 v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
                 v_val_cargo := round(v_sal_disponible * v_val_cargo / v_tot_car, v_redondeo);
                 v_val_impuesto := v_sal_disponible - v_val_cargo;
                 v_tot_car := nvl(v_val_cargo,0) + nvl(v_val_impuesto, 0);               
             else 
                  v_tot_car := 0;
             end if;  
             if v_tot_car > 0 then     
               --inicializar secuencia
               if v_nro_secuencia >= 995 then
                  v_hora := pag_gen.fu_obt_sig_segundo(v_hora);  
                  v_nro_secuencia := 0; 
               end if;
               -- cargo
               PAG_CTA.PR_ACT_OPERACION(v_nro_cuenta,
                                        v_hora,
                                        'D',
                                        v_cod_moneda,
                                        v_val_cargo,
                                        v_cod_transaccion,   --transaccion padre
                                        v_cod_transaccion,   --transaccion hijo
                                        i.cod_telegrama, -- nro_documento
                                        NULL,   --cotizacion
                                        v_cod_oficina,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        NULL,  --cod_tasa
                                        NULL,  --val_tasa
                                        'Cobro de cargos',
                                        'S',   --emi_aviso
                                        v_nro_secuencia,
                                        v_fcdehoy);
               if pag_cta.fu_obt_cod_error() <> 0 then
                 raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error());
               elsif v_val_impuesto > 0 then -- impuesto
                   PAG_CTA.PR_ACT_OPERACION(v_nro_cuenta,
                                            v_hora,
                                            'D',
                                            v_cod_moneda,
                                            v_val_impuesto,
                                            v_cod_tra_impuesto,   --transaccion padre
                                            v_cod_tra_impuesto,   --transaccion hijo
                                            i.cod_telegrama, -- nro_documento
                                            NULL,   --cotizacion
                                            v_cod_oficina,
                                            v_cod_modulo,
                                            v_cod_modalidad,
                                            NULL,  --cod_tasa
                                            NULL,  --val_tasa
                                            'Cobro de Impuesto',
                                            'S',   --emi_aviso
                                            v_nro_secuencia,
                                            v_fcdehoy);
                   if pag_cta.fu_obt_cod_error() <> 0 then
                     raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error());
                   End if; 
               end if;  
               if v_tot_car > 0 and pag_cta.fu_obt_cod_error() = 0 then   
                 update ge_telegramas set cobrado = 'S'
                   where rowid = i.fila;  
               end if;                          
             end if;
         End if;
         -- salgo del ciclo de cuentas si ya se cobro o ya no hay cuentas
         exit when v_ref_cuentas is null or v_tot_car > 0;           
     end loop; 
     --siguiente registro
     <<siguiente>>
     null;
  end loop;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Cobro de cargos de Telegramas '||sqlerrm);
    End if;
end;
/

