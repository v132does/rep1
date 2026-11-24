CREATE OR REPLACE FUNCTION IT.FUG_PUE_COBRAR
 (P_FRECUENCIA  IN GE_COB_SER_CUENTAS.FRECUENCIA%TYPE
 ,P_FRE_DIA     IN GE_COB_SER_CUENTAS.FRE_DIA%TYPE)
 RETURN VARCHAR2
 IS
v_puede_cobrar varchar2(1) := 'N';
v_nom_dia varchar2(20);
v_fre_dia ge_cob_ser_cuentas.fre_dia%type;
v_sem_desde  number(2);
v_sem_hasta  number(2);
v_nro_dia    number(3);
v_dia        varchar2(10);
/*verifica si se puede cobrar el servicio en el día.
  si la fecha de cobro del servicio cae fin de semana o feriado se cobra antes*/
begin
   --antes de invocar se deben obtener los datos del calendario, ya q usa las var.públicas del package
   v_nom_dia   := upper(substr(pag_cal.g_nom_dia, 1, 3));
   v_sem_desde := to_char(pag_cal.g_fec_actual,'D')-1;
   v_sem_hasta := to_char(pag_cal.g_fec_proxima,'D')-1;
   if v_sem_hasta < v_sem_desde then
      v_sem_hasta := 6;
   end if;
   v_fre_dia   := upper(p_fre_dia);
   -- verificar frecuencia
   if p_frecuencia = 'D' then --diaria
      --siempre cobra porque el proceso se corre los días hábiles
      v_puede_cobrar := 'S';      	
   elsif p_frecuencia = 'S' then --semanal
      --si el día es igual a hoy se cobra
      if v_fre_dia = v_nom_dia then
         v_puede_cobrar := 'S';
      else --si es menor q la fecha próxima, es no hábil, cobrar
        v_nro_dia := (trunc(instr('LUN%MAR%MIE%JUE%VIE',v_fre_dia) / 4)+1);
        if v_nro_dia > v_sem_desde and v_nro_dia < v_sem_hasta then--para q tome lo de la semana actual
           v_puede_cobrar := 'S';
         end if;	
      end if;
   elsif p_frecuencia = 'M' then --mensual
      --si es el día del mes actual cobrar, si el mes no tiene 29/30/31 también cobrar
      v_dia := to_char(pag_cal.g_fec_actual,'yyyymm')||v_fre_dia;
      if v_dia >= to_char(pag_cal.g_fec_actual,'yyyymmdd') and v_dia < to_char(pag_cal.g_fec_proxima,'yyyymmdd') then
         v_puede_cobrar := 'S';
      end if;   
   elsif p_frecuencia = 'A' then --anual
      --si es el día del año actual se cobra, si el mes no tiene 29/30/31 también se cobra
      v_dia := to_char(pag_cal.g_fec_actual,'yyyy')||substr(v_fre_dia,4,2)||substr(v_fre_dia,1,2);
      if v_dia >= to_char(pag_cal.g_fec_actual,'yyyymmdd') and v_dia < to_char(pag_cal.g_fec_proxima,'yyyymmdd') then
         v_puede_cobrar := 'S';
      end if;   
   end if;
   return v_puede_cobrar;
end;
/

