create or replace procedure it.pra_act_sal_promedio is
  v_fec_actual date;
  v_mes        ah_sal_mensuales.mes%type;
  v_ano        ah_sal_mensuales.ano%type;
  v_val_parametro   ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('CTA_EXC_SAL_PROMEDIO'),'0');
  v_men_error       varchar2(400);
  v_contador        number(10) := 0;
  cursor c_dat is
    select a.nro_cuenta,
           nvl(can_dia_acumulado, 0) can_dia_acumulado,
           sal_acu_diario
      from ah_sal_mensuales a
     where a.ano = v_ano
       and a.mes = v_mes
       and instr(v_val_parametro, nro_cuenta) = 0;
  
  TYPE account_tab_type IS TABLE OF c_dat%ROWTYPE;
  v_accounts account_tab_type;
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_fec_actual := pag_cal.fu_obt_fec_actual(3);
  v_mes        := to_char(v_fec_actual, 'MM');
  v_ano        := to_char(v_fec_actual, 'YYYY');
  OPEN c_dat;
  LOOP
    FETCH c_dat BULK COLLECT
      INTO v_accounts;
  FOR i IN 1 .. v_accounts.COUNT LOOP
    begin
      update ge_cuentas a
         set a.sal_promedio = round(decode(v_accounts(i).can_dia_acumulado,0,0,v_accounts(i).sal_acu_diario / v_accounts(i).can_dia_acumulado),2)
       where a.nro_cuenta = v_accounts(i).nro_cuenta;
     exception
       when others then
         v_contador := nvl(v_contador,0) + 1;
         v_men_error := substr(sqlerrm,1,399);
         insert into it.ge_log_errores (cod_programa, det_error, nro_cuenta,fecha)
         values                        ('PRA_ACT_SAL_PROMEDIO', v_men_error, v_accounts(i).nro_cuenta,v_fec_actual); 
     end;
     commit;
  end loop;
    EXIT WHEN c_dat%NOTFOUND;
  END LOOP;
  close c_dat;
  if nvl(v_contador,0) > 0 then
            it_mail.mail (fug_obt_dir_correo,
                     fug_obt_pardinamico('ENV_EMA_GUA_CIERRE'),
                     'Error en Proceso de Actualizacion de Saldo Promedio', 
                     'Cantidad de error encontrados: '||v_contador||' Verificar tabla GE_LOG_ERRORES cod_programa = PRA_ACT_SAL_PROMEDIO');
    end if;
end;
/
