create or replace procedure it.PRG_CAN_CUO_RES4_v3 is
  v_mto_deu_entidad         ge_clientes.tot_deu_real%type := 1000000000;
  v_mto_deu_sistema         ge_clientes.tot_deu_sistema%type := 2000000000;  
  v_sal_cobrado             pr_cuotas.sal_capital%type;
  v_error                   number;
  v_mensaje                 varchar2(4000);
  v_cod_ofi_origen          pr_cta_prestamos.cod_oficina%type;
  v_sal_capital             pr_cuotas.sal_capital%type;
  v_sal_interes             pr_cuotas.sal_interes%type;
  v_sal_int_ade             pr_cuotas.sal_int_documentado%type;
  v_mora                    pr_cuotas.mto_capital%type;
  v_mora_interes            pr_cuotas.mto_capital%type;
  v_mora_int_ade            pr_cuotas.mto_capital%type;
  v_punitorio               pr_cuotas.mto_capital%type;
  v_impuesto                pr_cuotas.mto_capital%type;
  v_cargo                   pr_cuotas.mto_capital%type;
  v_cargo_iva               pr_cuotas.mto_capital%type;
  v_int_descontado          pr_cuotas.mto_interes%type;
  v_mto_devengado           pr_cuotas.dev_no_cobrado%type;
  v_mto_dev_suspenso        pr_cuotas.dev_suspenso%type;
  v_dia_mora                pr_cta_prestamos.dia_atraso%type;
  v_cod_tra_padre           ge_transacciones.cod_transaccion%type := 360;
  v_cancelacion             varchar2(1);
  v_renueva                 varchar2(1);
  v_cancel_rrr              varchar2(1);
  v_tot_deuda               ge_cla_operaciones.tot_deu_real%type;
  v_hora                    ge_movimientos.hora%type := to_char(sysdate,'HH24:MI:SS');
  v_nro_secuencia           ge_movimientos.nro_secuencia%type := -999;
  v_cod_rub_contable        ge_movimientos.cod_rubro%type := '240402600204199'; 
  v_fec_actual              date := pae_cnf.fu_obt_fec_actual(6);
  r_gmovi                   ge_movimientos%rowtype;
  v_rol_referencia          varchar2(15) := 'inicio';
  v_rol_ejecuta             varchar2(1) := 'N';
  v_commitea                varchar2(1) := 'N';
  v_fec_inicio              date := to_date(nvl(fug_obt_pardinamico('PRE_FEC_INI_RES4'),'19/MAR/2020'),'DD/MM/YYYY');
  v_fec_cuo_des             date := to_date(nvl(fug_obt_pardinamico('PRE_FEC_CUO_DES_RES4'),'01/FEB/2020'),'DD/MM/YYYY'); 
  v_fec_cuo_has             date := to_date(nvl(fug_obt_pardinamico('PRE_FEC_CUO_HAS_RES4'),'31/MAY/2020'),'DD/MM/YYYY'); 
  v_dia_atraso              number := trunc(sysdate) - v_fec_cuo_des;
  v_fec_cobro               date := to_date(nvl(fug_obt_pardinamico('PRE_FEC_COB_RES4'),'20/MAR/2020'),'DD/MM/YYYY');
       
  --Cursor prestamos
  cursor C_PRESTAMOS is
     Select * from pr_cta_pre_can_tmp t
      where not exists ( select 0 from pr_cta_pre_can_res4 r where r.nro_cuenta = t.nro_cuenta )
        and exists ( select 0 from pr_cta_pre_can_log l where l.nro_cuenta = t.nro_cuenta );
  
  PROCEDURE lp_ins_cta_pre_tmp IS
  BEGIN   
    INSERT INTO pr_cta_pre_can_tmp( nro_cuenta, cod_persona, cuo_desde, cuo_hasta, cod_oficina, cod_modalidad, cod_moneda, dia_atraso )
    select a.nro_cuenta, c.cod_persona, u.cuo_desde, u.cuo_hasta, a.cod_oficina, a.cod_modalidad, a.cod_moneda, nvl(a.dia_atraso, 0)
     from pr_cta_prestamos a,
          ge_cta_clientes  b,
          ge_clientes      c,
          dw_cli_segmentos sg, (SELECT MIN(u.nro_cuota) cuo_desde, MAX(u.nro_cuota) cuo_hasta, count(u.nro_cuota) can_cuota, u.nro_cuenta
                                  FROM pr_cuotas u
                                 WHERE u.fec_vencimiento BETWEEN v_fec_cuo_des AND v_fec_cuo_has
                                   AND u.mto_capital > 0
                                   AND u.nro_cuota > 0 
                                  GROUP BY u.nro_cuenta) u, 
                                (Select nro_cuenta, count(1) + 1 cant_cuo
                                   from pr_cuotas
                                  where mto_capital <> 0
                                    and nro_cuota > 1 
                               group by nro_cuenta) t   
    where a.fec_inicio <= v_fec_inicio
         --prestamos vigentes:
      and a.estado = 'C'   --and a.nro_cuenta = '0166268518'
      and a.nro_cuenta = b.nro_cuenta
      and b.cod_persona = c.cod_persona
     --Excluyo descuentos de documentos
      and a.cod_modalidad not in ( '60',
                                   '62',
                                   '64',
                                   '602',
                                   '603',
                                   '608',
                                   '620',
                                   '622',
                                   '627',
                                   '631',
                                   '672',
                                   '685',
                                   '689',
                                   '699' )
      and b.relacion = 'P'
      and nvl(a.dia_atraso, 0) <= v_dia_atraso -- con deuda a partir de fecha que se va a cancelar
      and nvl(a.can_cuotas,0) > 2 
      and u.nro_cuenta = a.nro_cuenta
      and t.nro_cuenta = a.nro_cuenta
      and c.cod_usu_oficial <> 'RRHH'
      --SEGMENTAICON
      and c.cod_persona = to_number(sg.nu_cte(+))
      and sg.sgto_valor_2013 in ('03_SMALL',
                                 '04_MICRO',
                                 '05_HNWI',
                                 '06_AFFLU',
                                 '07_MAFFL',
                                 '08_MASS',
                                 '09_INCLU')                            
      -- Con deuda < 1000MM BBVA
      and nvl(c.tot_deu_real,0) <= v_mto_deu_entidad
      -- Con deuda < 2000MM sistema financiero
      and nvl(c.tot_deu_sistema,0) + nvl(c.tot_deu_real,0) <= v_mto_deu_sistema
      -- solo PP mensuales (capital mensual)
      and a.can_cuotas = t.cant_cuo
      -- no incluir clientes que pidieron no refinanciar sus ctas.
      and 0 = ( SELECT COUNT(0)
                  FROM bw_sol_can_productos p
                 WHERE p.cod_persona = b.cod_persona
                   AND p.mot_cancelacion = 'COVID-19' )
      --se excluyen clientes inhibidos
      and not exists (select *
                   from ge_per_inhibidas i
                  where i.cod_persona = b.cod_persona
                    and i.estado = 'I'
                    and i.cod_causa in (294,281,326,346,328,
                                        329,279,163,166,167,
                                        170,288,342,171,284,
                                        176,177,178,150,179,
                                        343,324,182,184,186,
                                        190,278))       
      and not exists ( select 0 from pr_cta_pre_can_res4 r where r.nro_cuenta = a.nro_cuenta )
      and not exists ( select 0 from pr_cta_pre_can_exc e where e.nro_cuenta = a.nro_cuenta );
   END;   
      
   PROCEDURE pr_ins_log_error(p_nro_cuenta   pr_cta_pre_can_log.nro_cuenta%type,
                              p_mensaje      pr_cta_pre_can_log.msg_error%type) 
    is
    pragma autonomous_transaction;
    BEGIN
      BEGIN
        INSERT INTO pr_cta_pre_can_log(nro_cuenta, msg_error) values(p_nro_cuenta, p_mensaje);
      EXCEPTION
        WHEN OTHERS THEN
          null;
      END; 
      commit; -- este commit solo afecta a la transaccion autonoma      
    END;      

begin
  begin
    BEGIN   PRE_INI_APLICACION;   PAE_CNF.G_COD_MODULO := 1;  END; 
    pae_cnf.G_PROGRAMA := 'GPPROFIN';
    --DELETE FROM pr_cta_pre_can_tmp;
    --lp_ins_cta_pre_tmp;
    for P in C_PRESTAMOS loop               
        v_rol_referencia := p.nro_cuenta;
        prg_cre_savepoint(v_rol_referencia);
        v_rol_ejecuta    := 'N';
        v_commitea       := 'N'; 
        pap_pre.pr_ini_autorizacion;
        v_cod_ofi_origen := p.cod_oficina;
        pap_pre.pr_obt_deu_prestamo(p.nro_cuenta, v_fec_cobro, p.cuo_desde, p.cuo_hasta, v_cod_ofi_origen, v_sal_cobrado, v_error, 
        v_mensaje, v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
        v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
        v_dia_mora, v_cod_tra_padre, v_cancelacion,v_renueva,v_cancel_rrr);
        
        v_tot_deuda := nvl(v_sal_capital,0) +
                       nvl(v_sal_interes,0) +
                       nvl(v_mora,0) +
                       nvl(v_mora_interes,0) +
                       nvl(v_mora_int_ade,0) +
                       nvl(v_punitorio,0) +
                       nvl(v_impuesto,0) +
                       nvl(v_cargo,0);
                           
        IF v_tot_deuda > 0 THEN
          BEGIN 
            SELECT SUM(NVL(c.dev_no_cobrado,0)), SUM(NVL(c.dev_suspenso, 0))
              INTO v_mto_devengado, v_mto_dev_suspenso
              FROM pr_cuotas c            
             WHERE c.nro_cuenta = p.nro_cuenta
               AND c.nro_cuota > 0
               AND c.fec_vencimiento between v_fec_cuo_des and v_fec_cuo_has
               AND c.estado <> 'N';
          EXCEPTION
            WHEN OTHERS THEN
              v_mto_devengado := 0;
              v_mto_dev_suspenso := 0;
          END;            
          BEGIN
            INSERT into PR_CTA_PRE_CAN_RES4( nro_cuenta, 
                                             cod_persona, 
                                             sal_capital, 
                                             sal_interes, 
                                             mto_cargo, 
                                             mto_impuesto,
                                             mto_mora,
                                             mto_mor_int,
                                             mto_punitorio, 
                                             mto_devengado, 
                                             mto_dev_suspenso,
                                             tot_deuda, 
                                             cod_moneda, 
                                             dia_atraso )
                                     VALUES( p.nro_cuenta, 
                                             p.cod_persona, 
                                             nvl(v_sal_capital,0),  
                                             nvl(v_sal_interes,0),
                                             nvl(v_cargo,0),
                                             nvl(v_impuesto,0),
                                             nvl(v_mora,0),
                                             nvl(v_mora_interes,0),
                                             nvl(v_punitorio,0),
                                             v_mto_devengado,
                                             v_mto_dev_suspenso, 
                                             v_tot_deuda,
                                             p.cod_moneda,
                                             p.dia_atraso );           
          EXCEPTION
            WHEN OTHERS THEN
              v_mensaje := 'Error al insertar: '||sqlerrm;
              pr_ins_log_error(p.nro_cuenta, v_mensaje);
              GOTO siguiente_registro;  
          END;
          v_nro_secuencia := v_nro_secuencia + 1;
          IF v_nro_secuencia > 970 then
             v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N'); 
             v_nro_Secuencia := -999;
          END IF;
          BEGIN
            pap_pre.pr_cob_prestamo( p.nro_cuenta,
                                     v_tot_deuda,
                                     'N', --- Se pidio autorizacion
                                     v_cod_ofi_origen, --- oficina origen
                                     p.cuo_desde,
                                     p.cuo_hasta,
                                     'CANCELACION DE CUOTA RES N°4 '||p.nro_cuenta,
                                     v_fec_cobro,
                                     v_hora,
                                     v_nro_secuencia,
                                     v_cod_tra_padre, 6, p.cod_modalidad, v_cancelacion,
                                     NULL,NULL,'N');
          EXCEPTION
            WHEN OTHERS THEN
              v_rol_ejecuta := 'S';
              v_mensaje := 'Error al cobrar: '||sqlerrm;
              pr_ins_log_error(p.nro_cuenta, v_mensaje);
              GOTO siguiente_registro;                                 
          END;
          IF p.cod_moneda = 'GS' THEN
             v_cod_rub_contable := '240402600204199';
          ELSE   
            v_cod_rub_contable := '240402600204105';    
          END IF;  
          r_gmovi.cod_usuario     := user;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fec_actual;
          -- Aumento la secuencia
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          --
          r_gmovi.cod_modulo      := 6;
          r_gmovi.cod_modalidad   := p.cod_modalidad;
          r_gmovi.cod_oficina     := v_cod_ofi_origen;
          r_gmovi.cod_moneda      := p.cod_moneda;
          r_gmovi.fec_valor       := v_fec_cobro;
          r_gmovi.cod_tra_padre   := 360;
          r_gmovi.cod_mod_padre   := 6;
          r_gmovi.cod_mad_padre   := p.cod_modalidad;
          r_gmovi.cod_transaccion := 842;
          r_gmovi.monto           := v_tot_deuda;
          r_gmovi.nro_documento   := p.nro_cuenta;
          r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Cobro de cuenta RES N°4 '||p.nro_cuenta;
       	  r_gmovi.estado          := 'N'; -- movimiento confirmado normal
          r_gmovi.reversado       := 'N';
          r_gmovi.cod_rubro       := v_cod_rub_contable;
          r_gmovi.tip_mov_rubro   := 'D'; 

          BEGIN
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
          EXCEPTION
            WHEN OTHERS THEN 
              v_rol_ejecuta := 'S';
              v_mensaje := 'Error al insertar el movimiento de cta contable: '||sqlerrm;
              pr_ins_log_error(p.nro_cuenta, v_mensaje);
              GOTO siguiente_registro;
          END;    
        END IF;     
        v_commitea := 'S';
         <<siguiente_registro>>    
        IF v_rol_ejecuta = 'S' then
           prg_rol_savepoint(v_rol_referencia);
        ELSIF v_commitea = 'S' THEN
           commit;           
        END IF;
    end loop;    
  end;
exception
  when others then
    null;
end;
/

