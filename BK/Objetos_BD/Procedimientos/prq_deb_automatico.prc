CREATE OR REPLACE PROCEDURE IT.PRQ_DEB_AUTOMATICO
 (P_NRO_CONTRATO IN CS_CONTRATOS.NRO_CONTRATO%TYPE DEFAULT NULL
 )
 IS
  --Variables Utilizadas--
  v_estado        ge_movimientos.estado%type;
  v_obser         ta_cobros.observacion%type;
  v_hora          ge_movimientos.hora%type;
  v_fcdehoy       date;
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  v_cod_tra_padre ge_movimientos.cod_transaccion%type := 987;
  v_nro_contrato  cs_contratos.nro_contrato%type;
  v_nro_cuo_desde cs_con_cuotas.nro_cuota%type;
  v_nro_cuo_hasta cs_con_cuotas.nro_cuota%type;
  v_con_cuotas    number;
  v_lin_sobregiro number(18,2);
  v_sal_dis_total cc_cta_corrientes.sal_total%type;
  v_tot_cuo_pagar number(18,2);
  v_cuo_pagar     varchar2(500);
  v_cod_transaccion ge_transacciones.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_COB_CAJ_SEG');
  v_cod_tra_recargo ge_transacciones.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_REC_CAJ_SEG');
  v_des_transaccion varchar2(100) := 'Deb.Caj.Seg.Con.:';
  v_des_tra_recargo varchar2(100) := 'Deb.Caj.Seg.Rec.Con.:';
  v_mto_cobro     cs_con_cuotas.monto%type;
  v_mto_recargo   cs_con_cuotas.monto%type;
  v_con_exc_visitas    varchar2(100);
  v_cod_moneda ba_monedas.cod_moneda%type;
  v_nro_cta_debito ge_cuentas.nro_cuenta%type;
  --v_cod_oficina   ba_oficinas.cod_oficina%type;

  --Variables para la cuenta de débito--
  v_mto_deu_deb    ge_cuentas.sal_contable%type;
  v_mto_deu        ge_cuentas.sal_contable%type;
  v_cot_mon_tar    ge_cotizaciones.val_conversion%type;
  v_cot_mon_deb    ge_cotizaciones.val_conversion%type;
  v_mto_equ_local  ge_movimientos.mto_equ_local%type;
  v_cotizacion     ge_cotizaciones.val_conversion%type;
  v_nvo_estado     ge_cuentas.estado%type;
  v_sal_disponible ge_cuentas.sal_contable%type;
  v_procesa        varchar2(01);
  v_cod_oficina    ba_oficinas.cod_oficina%type;
  v_redondeo       number;
  v_cod_persona    ge_movimientos.cod_persona%type;

  --Cursor de Contratos--
  cursor c_contratos is
       select con.nro_contrato,
       con.nro_cta_debito,
       cta.cod_modulo,
       con.cod_moneda,
       cta.cod_modalidad,
       cta.nro_cuenta,
       cta.cod_oficina
      From cs_contratos con, ge_cuentas cta
     Where con.Nro_Contrato = nvl(p_Nro_Contrato,con.nro_contrato)
       And con.tip_pago = 'D'
       And con.nro_cta_debito Is Not Null
       And con.nro_cta_debito = cta.nro_cuenta
       And con.estado Not In ('C','R','I','B');--cancelado/rechazado/ingresado

  --Cursor de Cuotas--
  cursor c_cuotas is
    select cuo.nro_contrato,
       cuo.nro_cuota,-- DYDMR-1759/ se agrega el numero de cuota para poder pasar el parametro a paq_caj.pr_cob_cuotas
       cuo.cod_transaccion,
       cuo.fec_desde fec_desde,
       cuo.fec_hasta fec_hasta,
       nvl(cuo.monto,0) monto,
       cuo.nro_cob_exc_visitas
      From cs_Con_Cuotas cuo
     Where cuo.nro_contrato = v_nro_contrato
       and cuo.fec_vencimiento <= v_fcdehoy
       and cuo.fec_pago is null
       and cuo.estado = 'P'
     order by cuo.nro_cuota;

 procedure pr_gen_cobros(p_cod_transaccion in number,
                         p_monto in number,
                         p_des_transaccion in varchar2,
                         p_cuo_pagar in varchar2,
                         p_vis_exesiva in varchar2) is

  --  v_inicio varchar2(1);
 begin
             v_mto_deu := p_monto;
             v_mto_deu_deb := v_mto_deu;
             If v_cod_moneda != pag_cta.g_ctas.cod_moneda then
                 pag_gen.pr_con_mon_a_moneda(v_cod_moneda,
                                             pag_cta.g_ctas.cod_moneda,
                                             v_mto_deu,
                                             v_mto_deu_deb,
                                             v_cot_mon_tar,
                                             v_cot_mon_deb);

             End if;
             if v_estado = 'P' then
             --for cuo in c_cuotas loop
                --- Verificar si puede realizarse la operación sobre la cuenta de débito
                pag_cta.pr_ver_operacion(v_nro_cta_debito,
                                         p_cod_transaccion,
                                         16,
                                         161,
                                         'D',
                                         pag_cta.g_ctas.cod_moneda,
                                         v_mto_deu_deb,
                                         v_cod_oficina,
                                         -- out
                                         pag_cta.g_ctas.cod_modulo,
                                         pag_cta.g_ctas.cod_modalidad,
                                         v_nvo_estado,
                                         v_sal_disponible,
                                         v_procesa);
                if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
                  v_estado:= 'E';
                  v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
                end if;


                ------
                if v_estado = 'P' Then
                    --- DEBITAR de la cuenta
                    if v_cod_moneda != pag_cta.g_ctas.cod_moneda then
                       v_cotizacion := v_cot_mon_deb;
                       v_mto_equ_local := v_mto_deu;

                          IF v_cod_moneda = PAG_GEN.FU_OBT_MON_LOCAL THEN
                          v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,v_cod_moneda);
                          v_mto_equ_local := ROUND(v_mto_equ_local,v_redondeo);
                          END IF;

                    else
                       v_cotizacion := null;
                       v_mto_equ_local := null;
                    end if;

                    pag_cta.pr_act_operacion(v_nro_cta_debito,
                                             v_hora,
                                             'D',
                                             pag_cta.g_ctas.cod_moneda,
                                             v_mto_deu_deb,
                                             p_cod_transaccion,
                                             503,
                                             v_nro_contrato,
                                             v_cotizacion,
                                             v_cod_oficina,
                                             16,
                                             161,
                                             null,
                                             null,
                                             p_des_transaccion||v_nro_contrato,
                                             'S',
                                             v_nro_secuencia ,
                                             v_fcdehoy,
                                             null,
                                             null,
                                             v_mto_equ_local);
                    if pag_cta.g_cod_error <> 0 then
                      v_estado:= 'E';
                      v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
                    end if;

                    --PN DYDMR-1668: Busca la persona del movimiento
                    begin
                      select cod_persona
                        into v_cod_persona
                        from cs_con_personas per
                       where per.nro_contrato = v_nro_contrato
                         and per.tip_relacion = 'T';
                    exception
                    --En caso de que posea 2 titulares
                       when others then
                         begin
                            select per.cod_persona
                              into v_cod_persona
                              from cs_con_personas per, ge_cta_clientes cta
                             where per.nro_contrato = v_nro_contrato
                               and cta.nro_cuenta = v_nro_cta_debito
                               and cta.relacion = 'P'
                               and cta.cod_persona = per.cod_persona
                               and per.tip_relacion = 'T';
                         exception
                            when others then
                              v_cod_persona := null;
                         end;
                       end;

                   PAQ_CAJ.PR_GEN_MOVIMIENTOS
                       (v_nro_contrato,--P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%Type,
                        p_cod_transaccion,--P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                        p_cod_transaccion,--P_COD_TRA_PADRE IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                        v_cod_moneda,--P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE,
                        v_nro_secuencia,--P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
                        v_cod_oficina,--P_COD_OFICNA IN BA_OFICINAS.COD_OFICINA%TYPE,
                        v_des_transaccion,--P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
                        v_fcdehoy,--P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE,
                        v_hora,--P_HORA IN GE_MOVIMIENTOS.FECHA%TYPE,
                        v_mto_deu_deb, --cuo.monto,--P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE)
                        v_cod_persona);

                         paq_caj.pr_cob_cuotas(v_nro_contrato,v_mto_deu_deb,p_cod_transaccion,p_cuo_pagar, p_vis_exesiva,v_hora);

                  End if;
                  end if;
 end ;

 procedure pr_pro_cuotas is

 begin
          v_con_cuotas := 0;
          v_nro_cuo_desde := 0;
          v_nro_cuo_hasta := 0;
          v_tot_cuo_pagar := 0;
          v_cuo_pagar     := '*';
          v_mto_cobro     := 0;
          v_mto_recargo   := 0;
          v_con_exc_visitas := '*';
          for cuo in c_cuotas loop
              v_con_cuotas := nvl(v_con_cuotas,0) + 1;
              if (nvl(v_tot_cuo_pagar,0) + nvl(cuo.monto,0)) <= v_sal_dis_total then
                 v_nro_cuo_hasta := cuo.nro_cuota;
                 v_tot_cuo_pagar := nvl(v_tot_cuo_pagar,0) + nvl(cuo.monto,0);
                 v_cuo_pagar     := v_cuo_pagar||cuo.nro_cuota||'*';
                 v_con_exc_visitas := v_con_exc_visitas||nvl(cuo.nro_cob_exc_visitas,0)||'*';
                 ------------
                 if cuo.cod_transaccion = v_cod_transaccion then --Cobro--
                    v_mto_cobro := nvl(v_mto_cobro,0) + nvl(cuo.monto,0);
                    --v_cuo_pagar     := v_cuo_pagar||cuo.nro_cuota||'*';
                 else --Recargo--
                    v_mto_recargo := nvl(v_mto_recargo,0) + nvl(cuo.monto,0);
                    --v_con_exc_visitas := v_con_exc_visitas||nvl(cuo.nro_cob_exc_visitas,0)||'*';
                 end if;
                 ------------
              else
                 --Salir del ciclo de Cuotas--
                 exit;
              end if;
          end loop;
 end;
Begin
  --Procesos Inciales--
  paq_caj.pr_gen_cuotas(P_NRO_CONTRATO);--genera todas las cuotas de los contratos
  paq_caj.pr_gen_recargos(P_NRO_CONTRATO);--genera todos los recargos (visitas a caja de seguridad)

  --Obtener Datos para utilizar--
  v_cod_oficina := fug_obt_ofi_usuario(user);
  v_fcdehoy       := pag_cal.fu_obt_fec_actual(16);
  v_hora          := to_char(sysdate,'HH24:MI:SS');
  v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
  v_nro_secuencia := 0;

  --Procesamiento de Contratos--
  for con in c_contratos loop
      if v_nro_secuencia > 997 then
         v_nro_secuencia := 1;
         v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
      else
         v_nro_secuencia := v_nro_secuencia +1;
      end if;
      --Cargar Variables por Contrato--
      v_cod_moneda := con.cod_moneda;
      v_cod_oficina := con.cod_oficina;
      v_nro_cta_debito := con.nro_cta_debito;
      v_nro_contrato := con.nro_contrato;
      v_estado := 'P';
      v_obser := 'Registro procesado';

      --Traer datos de la cuenta de debito--
      pag_cta.pr_obt_cuenta(v_nro_cta_debito);
      if pag_cta.g_cod_error <> 0 then
        v_estado    := 'E';
        v_obser := fug_obt_err_sueldos(pag_cta.g_cod_error);
      end if;

      --Buscar Saldo Disponible de la Cuenta--
      v_lin_sobregiro := 0;
      IF pag_cta.g_ctas.cod_modalidad = 41 THEN
         v_lin_sobregiro := nvl(pag_cta.fu_obt_lin_sobregiro(con.nro_cta_debito, v_fcdehoy), 0);
      END IF;
      v_sal_dis_total := nvl(pag_cta.g_ctas.sal_disponible, 0) + nvl(pag_cta.g_ctas.sal_dis_combinada, 0) + v_lin_sobregiro;

      --Intenta procesar solo si tiene saldo disponible--
      if nvl(v_sal_dis_total,0) > 0 then --Solo si tiene saldo, intenta cobrar algo--
         --Procesamiento de Cuotas--
          pr_pro_cuotas;
          ------debito---
          if nvl(v_tot_cuo_pagar,0) > 0 then --Puede Debitar algo--
              --Procesamiento de Recargo--
             if nvl(v_mto_recargo,0) > 0 THEN
                pr_gen_cobros(v_cod_tra_recargo, v_mto_recargo, v_des_tra_recargo, '*0*', v_con_exc_visitas);
             end if;
             --Procesamiento de Cobro--
             if nvl(v_mto_cobro,0) > 0 THEN
                pr_gen_cobros(v_cod_transaccion, v_mto_cobro, v_des_transaccion, v_cuo_pagar,'*0*');
             end if;
          end if;
          ---------------
      end if;
  end loop;
end;
/

