CREATE OR REPLACE PROCEDURE IT."PRC_LIQ_SOBREGIROS"
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null
-- ,P_PROCESAR IN VARCHAR2 default null
-- ,P_IMPUESTO OUT NUMBER 
-- ,P_INTERES OUT NUMBER 
 )
 IS
/*proceso que calcula interes e impuesto para liquidar los sobregiros
-si se corre diariamente, trata de cobrar si la cuenta tiene saldos
-si se corre a fin de mes se liquida de todas maneras, es decir, se cobra y se sigue sobregirando
-si no se recibe la cuenta como parámetro procesa todos las cuentas con sobregiros
-si PROCESAR = S calcula interés y liquida
-si PROCESAR = N sólo calcula interés 
-También puede ser llamado desde el proceso de cierre*/ 
  V_ULTDIAM GE_CALENDARIOS.ULT_DIA_MES%TYPE;
  V_ULT_DIA GE_CALENDARIOS.ULT_DIA_MES%TYPE;
  RV_GCALE GE_CALENDARIOS%ROWTYPE;
  v_nro_cuenta cc_sobregiros.nro_cuenta%type;
  v_fecha      date;
  v_monto      cc_sobregiros.saldo%type;
  v_cont       number;
  v_fcdehoy    date;
  v_liquida    varchar2(1) := 'N';
  v_impuesto   ge_movimientos.monto%type;
  v_interes    ge_movimientos.monto%type;
  v_manual     varchar2(1);
  v_nro_cta_cte cc_sobregiros.nro_cuenta%type;
  v_valor      number;
  v_cod_modulo number;
  v_cod_modalidad number;
  v_cod_transaccion number;
  v_rowcount PLS_INTEGER := 0;
  v_mensaje varchar2(3000);
  v_cant_registros PLS_INTEGER := 0;
--todas las cuentas con sobregiro no liquidado
CURSOR SALDO_DEU IS
   select a.nro_cuenta, nvl(a.sal_total,0) - nvl(a.sal_retenido,0) - nvl(a.sal_bloqueado,0) disponible, estado
     from cc_cta_corrientes a
    where (nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
      and estado NOT IN ('D', 'T', 'C','A','X')
      and exists (select 0 
                    from cc_sobregiros b
                   where b.nro_cuenta = nvl(p_nro_cuenta, a.nro_cuenta)
                     and liquidado = 'N'
                     and fecha <= v_ult_dia);
--     order by nro_cuenta,fecha;
--sobregiros no liquidados     
CURSOR SOBREG IS
   select sob.nro_cuenta, sob.fecha, sob.saldo 
     from cc_sobregiros sob
     where sob.nro_cuenta = v_nro_cta_cte
       and sob.liquidado = 'N'
       and sob.fecha <= v_ult_dia
   order by sob.nro_cuenta,sob.fecha;
  TYPE typ_saldo_deu IS table OF saldo_deu%rowtype;
  reg_sal_deu typ_saldo_deu;
  v_limite CONSTANT PLS_INTEGER := 10000;


BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
  reg_sal_deu :=typ_saldo_deu();
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_ultdiam := rv_gcale.ult_dia_mes_habil;
  v_ult_dia := rv_gcale.ult_dia_mes;
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  DBMS_APPLICATION_INFO.SET_ACTION('PRC_LIQ_SOBREGIROS');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRC_LIQ_SOBREGIROS, Iniciando');
  --recuperamos los sobregiros no liquidados de todas las cuentas corrientes
  BEGIN
    select count(1)
      into v_cant_registros
      from (select 1
             from cc_cta_corrientes a
            where (nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
              and estado NOT IN ('D', 'T', 'C','A','X')
              and exists (select 0 
                            from cc_sobregiros b
                           where b.nro_cuenta = nvl(p_nro_cuenta, a.nro_cuenta)
                             and liquidado = 'N'
                             and fecha <= v_ult_dia));
  EXCEPTION
    WHEN OTHERS THEN
      v_cant_registros := 0;
  END;
  
  select count(0)
    into v_cant_registros
    from cc_sobregiros sob
   where sob.nro_cuenta in
         (select a.nro_cuenta
            from cc_cta_corrientes a
           where estado NOT IN ('D', 'T', 'C', 'A', 'X')
             and exists (select 0
                    from cc_sobregiros b
                   where b.nro_cuenta = a.nro_cuenta
                     and liquidado = 'N'
                     and fecha <= v_ult_dia))
     and sob.liquidado = 'N'
     and sob.fecha <= v_ult_dia;
  --Si es fin de mes o recibe nro_cuenta (es manual) debe procesar
  If v_fcdehoy = v_ultdiam or p_nro_cuenta is not null then 
     if p_nro_cuenta is null then -- desde el cierre
        --setear hora para los movimientos
        --pae_cnf.PR_SET_VARIABLES(fug_ini_hora(sysdate,'HH24:MI:SS'),0);
        --FQ Se reemplaza fug_ini_hora por fug_obt_hor_disponible para evitar error de PK
         pae_cnf.PR_SET_VARIABLES(fug_obt_hor_disponible(v_fcdehoy,to_char(sysdate,'HH24:MI:SS'),user,'N'),0);
     end if;
      OPEN saldo_deu;
      LOOP
        Fetch saldo_deu BULK COLLECT INTO reg_sal_deu LIMIT v_limite;
          EXIT WHEN reg_sal_deu.COUNT = 0;
     --ctas con sobregiros pendientes de liquidar
          for reg1 in 1..reg_sal_deu.count loop 
            v_nro_cta_cte := reg_sal_deu(reg1).nro_cuenta;
            --Actualizar cc_liq_sobregiros, x por cuenta o variación de monto
            v_nro_cuenta := null;
            v_cont       := 0;
            v_liquida    := 'N';
             for reg in SOBREG loop
               --v_cont := v_cont + 1; contaba de más para el corte x monto
               if v_nro_cuenta is null then
                  -- para la primera vez
                  v_nro_cuenta := reg.nro_cuenta;
                  v_fecha      := reg.fecha;
                  v_monto      := reg.saldo;
               end if;
               if reg.nro_cuenta <> v_nro_cuenta OR reg.saldo <> v_monto then
                   --si cambia la cta o el monto, inserta la anterior (esto es para reportes para ver cuántos
                  --días estuvo sobregirada en un monto determinado)
                  insert into cc_liq_sobregiros(fec_liquidacion,nro_cuenta,fecha,saldo,can_dias)
                         values (v_fcdehoy,v_nro_cuenta,v_fecha,v_monto,v_cont);
                  v_liquida    := 'S';
                  v_nro_cuenta := reg.nro_cuenta;
                  v_fecha      := reg.fecha;
                  v_monto      := reg.saldo;
                  v_cont       := 1; --ya cuenta como 1
               else
                   v_cont := v_cont + 1;--contar los días a liquidar
               end if;
               v_rowcount := v_rowcount + 1;
               -- Solo entra aquí cada 10,000 registros
               IF MOD(v_rowcount, 10000) = 0 THEN
                 v_mensaje := v_rowcount||' cuentas procesadas de '||v_cant_registros;
                 DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
               END IF;
             END LOOP;
             --esto es para insertar lo último del ciclo
             If v_cont <> 0 then
                insert into cc_liq_sobregiros(fec_liquidacion,nro_cuenta,fecha,saldo,can_dias)
                       values (v_fcdehoy,v_nro_cuenta,v_fecha,v_monto,v_cont);
                v_liquida    := 'S';
             End if;
             --procesar el cobro de intereses, sólo si generó resumen de liquidación
             if v_liquida = 'S' then
                if P_NRO_CUENTA is not null then --es manual
                   v_manual := 'S';	
                end if;
                PAC_SOB.PR_PRO_LIQ_SOB(reg_sal_deu(reg1).nro_cuenta,'S', v_impuesto, v_interes, v_manual);	
             end if;
          END LOOP;
       END LOOP;   
  else --No es fin de mes, no recibe nro_cuenta, viene del cierre (proceso diario)
      --setear hora para los movimientos
      
      --pae_cnf.PR_SET_VARIABLES(fug_ini_hora(sysdate,'HH24:MI:SS'),0); 
      --FQ Se reemplaza fug_ini_hora por fug_obt_hor_disponible para evitar error de PK
      pae_cnf.PR_SET_VARIABLES(fug_obt_hor_disponible(v_fcdehoy,to_char(sysdate,'HH24:MI:SS'),user,'N'),0);
      
      --sólo procesa si tiene saldo
      --ctas con sobregiros pendientes de liquidar
      OPEN saldo_deu;
      LOOP
          Fetch saldo_deu BULK COLLECT INTO reg_sal_deu LIMIT v_limite;
           EXIT WHEN reg_sal_deu.COUNT = 0;
           for reg1 in 1..reg_sal_deu.count loop  
         -- for reg1 in saldo_deu loop
             v_nro_cta_cte := reg_sal_deu(reg1).nro_cuenta;
             --Actualizar cc_liq_sobregiros
             v_nro_cuenta := null;
             v_cont       := 0;
             v_liquida    := 'N';
             v_impuesto   := 0;
             v_interes    := 0;
             --calcula para ver si cubre con el saldo q tiene x cuenta
             PAC_SOB.PR_PRO_LIQ_SOB(reg_sal_deu(reg1).nro_cuenta,'N',v_impuesto,v_interes);
             If reg_sal_deu(reg1).disponible > (nvl(v_impuesto,0) + nvl(v_interes,0)) or reg_sal_deu(reg1).estado = 'P'	then
                --si cubre recorre los sobregiros para insertar la liquidación x esa cuenta, o si ya es una cuenta CERRADA
                for reg in SOBREG loop
                   ---v_cont := v_cont + 1;
                   if v_nro_cuenta is null then
                      -- para la primera vez
                      v_nro_cuenta := reg.nro_cuenta;
                      v_fecha      := reg.fecha;
                      v_monto      := reg.saldo;
                   end if;
                   if reg.nro_cuenta <> v_nro_cuenta OR reg.saldo <> v_monto then
                      insert into cc_liq_sobregiros(fec_liquidacion,nro_cuenta,fecha,saldo,can_dias)
                           values (v_fcdehoy,v_nro_cuenta,v_fecha,v_monto,v_cont);
                      v_liquida    := 'S';     
                      v_nro_cuenta := reg.nro_cuenta;
                      v_fecha      := reg.fecha;
                      v_monto      := reg.saldo;
                      --v_cont       := 0;
                      v_cont       := 1;--ya cuenta 1
                   else
                      v_cont := v_cont + 1;--
                   end if;
                END LOOP;
                If v_cont <> 0 then
                   insert into cc_liq_sobregiros(fec_liquidacion,nro_cuenta,fecha,saldo,can_dias)
                     values (v_fcdehoy,v_nro_cuenta,v_fecha,v_monto,v_cont);
                   v_liquida    := 'S';
                End if;
                --procesar el cobro de intereses, sólo si generó resumen de liquidación
                if v_liquida = 'S' then
                   -- RI: 31/03/2010 Ya se tiene estos datos, para no repetir la llamada
                   --PAC_SOB.PR_PRO_LIQ_SOB(reg1.nro_cuenta,'N',v_impuesto,v_interes);		
                   If reg_sal_deu(reg1).disponible > (nvl(v_impuesto,0) + nvl(v_interes,0)) then
                      PAC_SOB.PR_PRO_LIQ_SOB(reg_sal_deu(reg1).nro_cuenta,'S',v_impuesto,v_interes);		
                   End if;
                END IF;
             end if; --fin si tiene disponible
          END LOOP;
       END LOOP;  
   End if;
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
EXCEPTION
  WHEN OTHERS THEN
     if sqlcode <= -20000 then
        raise;
     else
      	raise_application_error(-20000,'Liq.Sobregiros '||v_nro_cuenta||'-'||to_char(v_fecha,'dd/mm/yyyy')||'.'||SQLERRM);
     end if;
end;
/
