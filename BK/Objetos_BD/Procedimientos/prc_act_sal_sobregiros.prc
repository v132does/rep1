create or replace procedure it.PRC_ACT_SAL_SOBREGIROS is
/*Proceso Mensual cuyo objetivo es traer el saldo de la cuenta al ultimo dia del mes
  y actualizar segun ese valor los primeros dias no habiles del mes siguiente en la
  tabla CC_SOBREGIROS */
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(4);
  v_fec_proxima       date := pag_cal.fu_obt_fec_proxima(4);
  v_pri_dia_mes       date := to_date('01'||to_char(v_Fec_proxima,'mmyyyy'),'ddmmyyyy');
  v_fecauxi           date;
  v_nro_cuenta        ge_cuentas.nro_cuenta%type;
  v_difdias           number;
  v_existe            number;
  v_can_dias          number;
  v_dia_atraso        cc_sobregiros.can_dias%type;

  --Cursor que trae el saldo por cuenta
  cursor c_cursor is
  select nro_cuenta, 
          NVL(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0) saldo,
         sal_total,sal_retenido, cod_moneda
    FROM cc_cta_corrientes c
   WHERE cod_modalidad = 41
     and estado not in('C','P','X','A');

Begin
  Begin pre_ini_aplicacion;pae_cnf.G_COD_MODULO:=1;end;
  --Ver si los primeros dias del mes siguiente tiene dias no habiles
  If v_pri_dia_mes <> v_fec_proxima then  -- no son iguales, existen dias no habiles al principio
    v_difdias := (v_fec_proxima-v_pri_dia_mes)-1;
    for reg in c_cursor loop
      v_nro_cuenta := reg.nro_cuenta;
      v_can_dias   := 0;
      --Traer la cantidad de dias sobregirado del ultimo dia del mes actual
      Begin
        Select can_dia_sobregiro, can_dias into v_can_dias, v_dia_atraso
          from cc_sobregiros
         where nro_cuenta = reg.nro_cuenta
           and fecha = last_day(v_fec_actual);
      Exception
        when no_data_found then
           v_can_dias := 0;
      end;          
      --
      If reg.saldo >= 0 then
         --No esta sobregirada la cuenta
         Delete cc_sobregiros
          where nro_cuenta = reg.nro_cuenta
            and fecha between v_pri_dia_mes and v_fec_proxima-1
            and liquidado = 'N';
      else
        FOR i IN 0..v_difdias LOOP           
           v_fecauxi := v_pri_dia_mes + i;          
           v_can_dias := nvl(v_can_dias,0) + 1;
           --Verificar si existe el registro para la fecha
           Select count(*) into v_existe
            from cc_sobregiros
           where nro_cuenta = reg.nro_cuenta
             and fecha = v_fecauxi;          
           If  v_existe = 0 then  --Insertar en Cc_sobregiros las fechas que faltan
              INSERT INTO cc_sobregiros
              (nro_cuenta, fecha, saldo, sal_total, sal_retenido, liquidado, mto_linea,
               can_dias, can_dia_sobregiro)
              values
              (reg.nro_cuenta, v_fecauxi, abs(reg.saldo), abs(reg.sal_total),
               abs(reg.sal_retenido), 'N',
               nvl(pag_cta.fu_obt_lin_sobregiro(reg.nro_cuenta, v_fecauxi),0),
               v_dia_atraso,v_can_dias);
           else  -- Actualizar datos        
              Update cc_sobregiros
                 set saldo = ABS(reg.saldo)
               where nro_cuenta = reg.nro_cuenta
                 and fecha = v_fecauxi
                 and liquidado ='N';
           End if;     
        End loop;   
      end if;
    End loop;
  End if;
Exception
  when others then
     raise_application_error(-20000,
                              'PRC_ACT_SAL_SOBREGIROS: Cta.: '||v_nro_cuenta||' - '||
                              SQLERRM);
end PRC_ACT_SAL_SOBREGIROS;
/

