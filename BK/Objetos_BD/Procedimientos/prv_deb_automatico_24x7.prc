CREATE OR REPLACE PROCEDURE IT.PRV_DEB_AUTOMATICO_24x7
(
   p_cod_persona    IN VARCHAR2 DEFAULT NULL,
   p_cta_debito     IN VARCHAR2 DEFAULT NULL
) IS
 v_nro_cta_atraso ge_cuentas.nro_cuenta%type;
 v_cod_usu_origen ge_movimientos.cod_usuario%type;
 v_fecha          ge_calendarios.fec_actual%TYPE;
 v_hora           ge_movimientos.hora%TYPE;
 v_nro_secuencia  ge_movimientos.nro_secuencia%TYPE := 0;
 v_cod_modulo     ba_modulos.cod_modulo%TYPE;
 v_nro_documento  cj_movimientos.nro_documento%type;
 v_mto_cobrado    ge_movimientos.monto%type;
 v_error          number;
 v_msj_respuesta  varchar2(2000) := 'Operacion Confirmada'; 
 v_capital        ge_movimientos.monto%type;
 v_moratorio      ge_movimientos.monto%type;
 v_impuesto       ge_movimientos.monto%type;
 v_cargos         ge_movimientos.monto%type;
 v_car_iva        ge_movimientos.monto%type;
 v_punitorio      ge_movimientos.monto%type;
 v_iva            ge_movimientos.monto%type;
 v_dia_mora       pr_cta_prestamos.dia_atraso%type;
 v_tot_a_cobrar   ge_movimientos.monto%type;
 v_sal_disponible ge_movimientos.monto%type;
 v_cod_tra_padre  ge_movimientos.cod_transaccion%type := 139;
 v_nvo_estado     ge_cuentas.estado%type;
 v_procesa        varchar2(01);
 v_estado         ge_movimientos.estado%type := 'P';
 v_obser          ta_cobros.observacion%type;
 v_capital_act    ge_movimientos.monto%type;
 v_moratorio_act  ge_movimientos.monto%type;
 v_impuesto_act   ge_movimientos.monto%type;
 v_cargos_act     ge_movimientos.monto%type;
 v_car_iva_act    ge_movimientos.monto%type;
 v_punitorio_act  ge_movimientos.monto%type;
 v_dia_mora_act   pr_cta_prestamos.dia_atraso%type;
 v_mto_cap_cob    ge_movimientos.monto%type;
 v_rol_referencia varchar2(300) := 'inicio';
 v_fcdehoy       date :=pag_cal.fu_obt_fec_actual(15);
 v_cod_tra_aguinaldo  ge_transacciones.cod_transaccion%type;
 v_mto_aguinaldo      number := 0;
 v_tot_aguinaldo      number := 0;
 v_fec_ini_mes        date;
 v_cod_ente           ah_cta_vistas.cod_ente%type := null;
 v_dia_aguinaldo      ge_par_dinamicos.val_parametro%type;
 v_fec_aguinaldo      date;
 v_blo_sal_agui       varchar2(1) := nvl(fug_obt_pardinamico('BLO_DEB_SAL_AGUINALDO'),'N');
 
  CURSOR c_cta_atrasos IS
      select t.cod_persona, t.nro_cuenta, t.nro_cta_credito,t.cod_modulo,t.cod_modalidad,t.cod_moneda,t.cod_oficina,t.cod_usu_origen
        from ge_cli_cta_atrasos t,ge_cta_dat_adicionales a,ge_cuentas c,ge_par_dinamicos d
       where t.tie_deposito = 'S'
         and t.cod_modulo = 15
         and t.nro_cta_credito = p_cta_debito
         and t.cod_persona = p_cod_persona
         and t.nro_cuenta = a.nro_cuenta(+)
         and a.parametro(+) = 'EXC_COB_24X7'
         and nvl(a.val_parametro,'N') = 'N'
         and t.nro_cta_credito = c.nro_cuenta
         --and nvl(c.cod_sub_modalidad,999) <> 6--Excluye Ctas. Aguinaldo
         and t.cod_modulo = d.cod_modulo
         and d.parametro = 'MOD_COB_24X7'
         and d.val_parametro = 'S'
         and t.mto_mora > nvl(t.tot_cobrado,0) -- No cobrar doble
         and t.procesado = 'N' --Procesar solo una vez
       order by t.dia_atraso desc;
       
  PROCEDURE pr_ins_log_error(p_nro_cuenta   tm_log_nominas.nro_cuenta%type,
                          p_monto        tm_log_nominas.monto%type,
                          p_sal_total    tm_log_nominas.sal_total%type,
                          p_lugar        tm_log_nominas.lugar%type,
                          p_observacion  tm_log_nominas.observacion%type)
    is
    pragma autonomous_transaction;
    begin
      insert into tm_log_nominas
      (nro_cuenta, monto, sal_total, lugar, observacion, fec_insercion)
      values
      (p_nro_cuenta, p_monto, p_sal_total, p_lugar, p_observacion, sysdate);
       Begin 
          update ge_cli_cta_atrasos a
             set a.procesado = 'E'
           where a.cod_persona = p_cod_persona
             and a.nro_cuenta = v_nro_cta_atraso
             and a.nro_cta_credito = p_cta_debito
             and a.procesado <> 'S'
             and a.fec_mov_deb24x7 is null
             and a.hor_mov_deb24x7 is null
             and a.cod_usu_deb24x7 is null
             and a.cod_tra_pad_deb24x7 is null;
       EXCEPTION
          WHEN OTHERS THEN
            null;
       End; 
      commit; -- este commit solo afecta a la transaccion autonoma
    end ; 
    
    FUNCTION lf_obt_mto_aguinaldo(p_nro_cta varchar2) return number IS
    BEGIN
      select sum(a.MONTO)
        into v_mto_aguinaldo
        from gv_movimientos a
       where a.FECHA >= v_fec_ini_mes
         and a.fecha <= v_fecha
         and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
         and a.COD_TRANSACCION = 602
         and a.NRO_CUENTA = p_nro_cta
         and a.REVERSADO = 'N';
      return nvl(v_mto_aguinaldo,0);
    exception
      when no_data_found then
        return 0;
      when others then
        return 0;
    END;

    FUNCTION lf_obt_fec_aguinaldo(p_nro_cta varchar2) return date IS
      v_fec_aguinaldo date;
    BEGIN
      select max(a.fecha)
        into v_fec_aguinaldo
        from gv_movimientos a
       where a.FECHA >= v_fec_ini_mes
         and a.fecha <= v_fecha
         and a.COD_TRA_PADRE = v_cod_tra_aguinaldo
         and a.COD_TRANSACCION = 602
         and a.NRO_CUENTA = p_nro_cta
         and a.REVERSADO = 'N';
      return v_fec_aguinaldo;
    exception
      when no_data_found then
        return null;
      when others then
        return null;
    END;       
BEGIN
     BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END; 
     FOR cta IN c_cta_atrasos LOOP
       v_rol_referencia := cta.nro_cuenta||'OPEVEN24X7';
       prg_cre_savepoint(v_rol_referencia);
       --Setea Variables
       v_nro_cta_atraso := cta.nro_cuenta;
       v_cod_usu_origen := cta.cod_usu_origen;

       v_cod_modulo := 15;
       v_fecha      := pag_cal.fu_obt_fec_actual(v_cod_modulo);
       
       v_hora       := to_char(sysdate,'HH24:MI:SS');
       v_hora       := fug_obt_hor_disponible(v_fecha,v_hora,v_cod_usu_origen/*user*/,'N');

       v_nro_secuencia := nvl(v_nro_secuencia,0) + 1; 
       v_dia_aguinaldo  := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);
       v_cod_ente       := null;
       begin
        select a.cod_ente
          into v_cod_ente
          from ah_cta_vistas a
         where a.nro_cuenta = cta.nro_cta_credito;
       exception
          when no_data_found then
            v_cod_ente := null;
          when others then
            v_cod_ente := null;
       end;
       if v_cod_ente is not null and nvl(v_blo_sal_agui,'N') = 'S' then
          v_cod_tra_aguinaldo := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_AGUINALDO');
          pag_cal.PR_OBT_DAT_CALENDAR(1);
          v_fec_ini_mes := pag_cal.G_PRI_DIA_MES;
          v_tot_aguinaldo := lf_obt_mto_aguinaldo(cta.nro_cta_credito);
          v_fec_aguinaldo := lf_obt_fec_aguinaldo(cta.nro_cta_credito);
       end if;
       
       --- Inicializo el numero de documento
         Begin
            v_nro_documento := fug_obt_lla_pardinamico('NRO_RECIBO', cta.cod_modulo, cta.cod_modalidad, cta.cod_moneda, cta.cod_oficina)+1;
            prg_act_par_dinamico('NRO_RECIBO',cta.cod_modulo, cta.cod_modalidad, cta.cod_moneda, cta.cod_oficina, v_nro_documento);
         Exception
            When others then
                  pr_ins_log_error(v_nro_cta_atraso,
                                   0,
                                   0,
                                   'PRV_DEB_AUTOMATICO_24x7 1',
                                   substr(SQLERRM, 1, 299));
               --- Siguiente registro
               GOTO siguiente_registro;
               <<siguiente_registro>> NULL;
         End;
         
       --Obtiene datos de la Cta. Vencida
       pav_ove.PR_OBT_DEU_OPE_VENCIDA (cta.nro_cuenta,
                                       v_fecha,
                                       v_mto_cobrado,
                                       v_error,
                                       v_msj_respuesta,
                                       v_capital,
                                       v_moratorio,
                                       v_punitorio,
                                       v_impuesto,
                                       v_cargos,--v_tot_cargo,
                                       v_car_iva,
                                       v_dia_mora,
                                       139);                                       
       if v_error is not null then
          v_estado := 'E'; 
       end if;
       if v_estado = 'P' then
           v_tot_a_cobrar:= nvl(v_capital,0) + nvl(v_moratorio,0) +
                            nvl(v_punitorio,0) + nvl(v_impuesto,0) +
                            nvl(v_cargos,0) + nvl(v_iva,0) ;   
                                
            ----- Recuperar datos de la cuenta, de la que va a debitar
            pag_cta.pr_obt_cuenta(p_cta_debito);
              
            If cta.cod_moneda != pag_cta.g_ctas.cod_moneda then
                If fug_obt_tip_implementacion in (1,7) then
                    v_estado    := 'E';
                    v_obser := 'Cobro en diferentes monedas no permitido';
                End if;
            End if;
            
            if nvl(v_blo_sal_agui,'N') = 'S' then 
              if v_cod_ente is not null and ((v_fcdehoy - v_fec_aguinaldo) <= v_dia_aguinaldo) then
                  if nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) > 0 then
                    if nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) < (nvl(v_tot_a_cobrar,0)) then
                      v_tot_a_cobrar := nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0);
                    end if;
                  else
                    v_estado := 'E';
                    v_obser  := 'Saldo no cubre la deuda.';
                  end if;
              end if;
            end if;
            
        End if;
        If v_estado = 'P' then     
            -- verifico el saldo
            pag_cta.pr_ver_operacion(p_cta_debito,
                                     v_cod_tra_padre,
                                     cta.cod_modulo,
                                     cta.cod_modalidad,
                                     'D',
                                     cta.cod_moneda,
                                     v_tot_a_cobrar,
                                     cta.cod_oficina,
                                     pag_cta.g_ctas.cod_modulo, 
                                     pag_cta.g_ctas.cod_modalidad,
                                     v_nvo_estado,
                                     v_sal_disponible,
                                     v_procesa,
                                     503);                                     
             if v_procesa = 'N' and v_sal_disponible > 0 then
                v_tot_a_cobrar := v_sal_disponible; 
                v_procesa := 'S'; 
             end if;  
             -- No debe cobrar si no cubre el cargo por lo menos. 
             if v_sal_disponible < nvl(v_cargos,0) then
                v_estado := 'E';
             end if; 
         End if;    
         If v_estado = 'P' and v_procesa = 'S' then  
             --genera los movimientos x el detalle de cobro --y actualiza los saldos de la operación vencida
          Begin    
              pav_ove.pr_cob_ope_vencida(cta.nro_cuenta, 
                                            v_tot_a_cobrar, 
                                            cta.cod_oficina,
                                            'Cobro Operación Vencida 24x7', 
                                            v_fecha, 
                                            v_hora, 
                                            v_nro_secuencia, 
                                            139,
                                            cta.cod_modulo,
                                            cta.cod_modalidad, 
                                            v_nro_documento,
                                            'N',
                                            v_cod_usu_origen);  
                                                   
              Exception 
                 when others then 
                 v_estado := 'E';
                 pr_ins_log_error(v_nro_cta_atraso,
                                  v_tot_a_cobrar,
                                  0,
                                  'PRV_DEB_AUTOMATICO_24x7 2',
                                  substr(SQLERRM, 1, 299));
                 --- Siguiente registro
                 GOTO siguiente_registro;
                 <<siguiente_registro>> NULL; 
          End; 
          If v_estado = 'P' then              
                  -- DEBITAR de la cuenta
                  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1; 
                  --**--
                   pag_cta.pr_set_variables(v_cod_usu_origen, v_fecha,
                                      v_cod_tra_padre,
                                      'N',--estado mvto
                                      'N',--reversado
                                      v_nro_secuencia,
                                      'N', -- estado pasa a N
                                      cta.cod_oficina,
                                      cta.cod_modulo,
                                      cta.cod_modalidad);
                  --**--                          
                   -- Actualiza la Cuenta débito / Destino
                   Begin
                       pag_cta.pr_act_operacion( p_cta_debito,
                                                 v_hora,--HORA
                                                 'D',
                                                 pag_cta.g_ctas.cod_moneda ,      --Moneda de la Operación
                                                 v_tot_a_cobrar,
                                                 139,-- Cobro de operacion vencida 
                                                 503,-- Debito
                                                 null,--nro_documento
                                                 NULL,--COTIZACION
                                                 cta.cod_oficina,--cod_ofi_origen
                                                 cta.cod_modulo,--cod_mod_padre
                                                 cta.cod_modalidad,--cod_mad_padre
                                                 null,--cod_tasa
                                                 null, --val_tasa
                                                 'Cobro de ope. vencida 24x7 '||cta.nro_cuenta,
                                                 'S',
                                                 v_nro_secuencia,
                                                 v_fecha);  
               
                     IF pag_cta.g_cod_error <> 0 THEN
                       v_estado := 'E';
                       pr_ins_log_error(v_nro_cta_atraso,
                                        v_tot_a_cobrar,
                                        0,
                                        'PRV_DEB_AUTOMATICO_24x7 3',
                                        substr(pag_cta.FU_OBT_MSJ_ERROR||'-'||SQLERRM, 1, 299));
                       --- Siguiente registro
                       GOTO siguiente_registro;
                       <<siguiente_registro>> NULL;
                     END IF;         
                End; 
            End if;      
          If v_estado = 'P' then  
               --Obtiene datos Actualizados de la Cta. Vencida
               pav_ove.PR_OBT_DEU_OPE_VENCIDA (cta.nro_cuenta,
                                               v_fecha,
                                               v_mto_cobrado,
                                               v_error,
                                               v_msj_respuesta,
                                               v_capital_act,
                                               v_moratorio_act,
                                               v_punitorio_act,
                                               v_impuesto_act,
                                               v_cargos_act,
                                               v_car_iva_act,
                                               v_dia_mora_act,
                                               139);       
                   v_mto_cap_cob := v_capital - v_capital_act;                                           
                   --Acá actualiza tabla atrasos
                   Begin
                     update ge_cli_cta_atrasos a
                       set a.procesado = 'S',
                           a.tot_cobrado = nvl(a.tot_cobrado,0) + nvl(v_mto_cap_cob,0),
                           a.fec_mov_deb24x7 = v_fecha,
                           a.hor_mov_deb24x7 = v_hora,
                           a.cod_usu_deb24x7 = v_cod_usu_origen,
                           a.cod_tra_pad_deb24x7 = v_cod_tra_padre
                       where a.cod_persona = p_cod_persona
                         and a.nro_cuenta = v_nro_cta_atraso
                         and a.nro_cta_credito = p_cta_debito;
                   EXCEPTION
                   WHEN OTHERS THEN
                     null;
                   End;
           End if;                                                                                  
         End if;   
         IF v_estado = 'E' then 
            prg_rol_savepoint(v_rol_referencia);
         ELSE
           COMMIT;   
         End if;   
         IF pag_cta.g_cod_error <> 0 THEN
            pr_ins_log_error(v_nro_cta_atraso,
                             v_tot_a_cobrar,
                             0,
                             'PRV_DEB_AUTOMATICO_24x7 4',
                             substr(pag_cta.FU_OBT_MSJ_ERROR||'-'||SQLERRM, 1, 299));
             --- Siguiente registro
             GOTO siguiente_registro;
             <<siguiente_registro>> NULL;
         END IF;                                                                              
     END LOOP;  
END;
/

