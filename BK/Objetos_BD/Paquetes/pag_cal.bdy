CREATE OR REPLACE PACKAGE BODY IT.PAG_CAL IS

/* Obtiene la fecha actual */
FUNCTION FU_OBT_FEC_ACTUAL
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS

V_FECHA GE_CALENDARIOS.FEC_ACTUAL%TYPE;
Begin
--Obtiene la fecha actual del módulo
   select fec_actual
   into v_fecha
   from ge_calendarios
   where cod_modulo = p_cod_modulo;

   return v_fecha;

exception
    when no_data_found then
       raise_application_error(-20000,
       'No existe fecha actual p/'||to_char(p_cod_modulo) ||' - ' ||sqlerrm);

End;

/* Obtiene la fecha anterior */
FUNCTION FU_OBT_FEC_ANTERIOR
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS

V_FECHA GE_CALENDARIOS.FEC_ACTUAL%TYPE;
Begin
--Obtiene la fecha anterior del módulo
   select fec_anterior
   into v_fecha
   from ge_calendarios
   where cod_modulo = p_cod_modulo;

   return v_fecha;

exception
    when no_data_found then
       raise_application_error(-20000,
       'No existe fecha actual p/'||to_char(p_cod_modulo) ||' - ' ||sqlerrm);

End;
/* Obtiene la fecha proxima de GE_CALENDARIOS dado el modulo */
FUNCTION FU_OBT_FEC_PROXIMA
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS

V_FEC_PROXIMA GE_CALENDARIOS.FEC_PROXIMA%TYPE;
Begin
   --Obtiene la fecha actual del módulo
   select fec_proxima
   into v_fec_proxima
   from ge_calendarios
   where cod_modulo = p_cod_modulo;

   return v_fec_proxima;

exception
    when no_data_found then
       raise_application_error(-20000,
       'No existe fecha prox. p/'||to_char(p_cod_modulo) ||' - ' ||sqlerrm);

End;
/* Obtener la siguiente fecha habil segun el factor de la fecha parametro */
FUNCTION FU_OBT_FEC_HABIL
 (P_FECHA IN DATE
 ,P_FACTOR IN NUMBER
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 )
 RETURN DATE
 IS

/* Recupera el parametro que indica si se trabaja sábado o domingo. */
FUNCTION LF_OBT_PAR_SABDOM
 (P_PARAMETRO IN GE_PARAMETROS.PARAMETRO%TYPE
 )
 RETURN VARCHAR2;
v_fec_habil  date;

/* Recupera el parametro que indica si se trabaja sábado o domingo. */
FUNCTION LF_OBT_PAR_SABDOM
 (P_PARAMETRO IN GE_PARAMETROS.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS
v_valor   ge_par_dinamicos.val_parametro%type;
BEGIN
   select d.val_parametro
   into v_valor
   from ge_parametros g, ge_par_dinamicos d
   where g.parametro = p_parametro
   and g.parametro = d.parametro;
   v_valor := ltrim(rtrim(v_valor));

   return v_valor;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Param. '||p_parametro||' no existe');
   when too_many_rows then
      raise_application_error(-20000,
      'Recuperar '||p_parametro||' '||sqlerrm);
END;
BEGIN
   v_fec_habil := p_fecha;
   loop
      --- Verificar si es feriado
      if not fue_ctr_fec_feriado(v_fec_habil,p_cod_oficina) THEN
         --- Verificar si es sabado o domingo
         if (lf_obt_par_sabdom('IND_SABADO')  = 'N' and ltrim(rtrim(upper(to_char(v_fec_habil,'DAY')))) in ('SATURDAY','SABADO','SÁBADO'))
         or (lf_obt_par_sabdom('IND_DOMINGO') = 'N' and ltrim(rtrim(upper(to_char(v_fec_habil,'DAY')))) in ('SUNDAY','DOMINGO')) then
            null;
         else
            exit;  --- Salir si la fecha es HABIL
         end if;
      end if;
      v_fec_habil := v_fec_habil + p_factor;
   end loop;
   return v_fec_habil;

   exception
      when others then
      raise_application_error(-20000, sqlerrm || ' ' ||
      'Obt. fecha hábil: '||TO_CHAR(p_fecha,'DD/MM/YYYY') || ' fallo');

END;
/* Obtiene la anterior fecha hábil */
FUNCTION FU_OBT_FEC_ANT_HAB
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_DIAS IN NUMBER DEFAULT 1
 )
 RETURN DATE
 IS

V_FEC_ANTERIOR DATE;
Begin
   --Obtiene la fecha hábil anterior
   v_fec_anterior := pag_cal.fu_obt_fec_habil(p_fecha-p_dias,-1, p_cod_oficina);
   return v_fec_anterior;
exception
   when others then
      raise_application_error(-20000,
      'Obt. Ant. fecha habil: '||TO_CHAR(p_fecha,'DD/MM/YYYY') || ' fallo');
End;
/* Obtiene la Siguiente fecha habil */
FUNCTION FU_OBT_FEC_SIG_HAB
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_DIAS IN NUMBER default 1
 )
 RETURN DATE
 IS

V_FEC_PROXIMA DATE;
BEGIN
--Obtiene la siguiente fecha hábil
--DBMS_OUTPUT.put_line('INICIA '||v_fec_proxima||'-'||p_fecha);
   v_fec_proxima := pag_cal.fu_obt_fec_habil(p_fecha+p_dias,1, p_cod_oficina);
--DBMS_OUTPUT.put_line('FIN '||v_fec_proxima||'-'||p_fecha);
   return v_fec_proxima;
exception
   when others then
      raise_application_error(-20000,
      'Obt Sig.fecha habil: '||TO_CHAR(p_fecha,'DD/MM/YYYY') || ' fallo');
END;
/* Obtiene el registro de GE_CALENDARIO dado un módulo especifico. */
FUNCTION FU_OBT_REG_CAL
 (P_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 )
 RETURN ge_calendarios%rowtype
 IS
BEGIN
--
   SELECT *
   INTO   pag_cal.rg_gcale
   FROM   GE_CALENDARIOS
   WHERE  GE_CALENDARIOS.COD_MODULO = p_modulo;
   RETURN pag_cal.rg_gcale;
EXCEPTION
--
   when no_data_found then
        raise_application_error(-20000,'Fecha Inexistente en GE_CALENDARIOS');
END;
/* Obtener datos del Calendario */
PROCEDURE PR_OBT_DAT_CALENDAR
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 IS
BEGIN
   select fec_actual, nom_dia, nom_mes, nro_trimestre, fec_proxima,
          fec_anterior, pri_dia_mes, pri_dia_mes_habil, ult_dia_mes, ult_dia_mes_habil,
          pri_dia_trimestre, pri_dia_hab_trimestre, ult_dia_trimestre, ult_dia_hab_trimestre, mes_ini_trimestre,
          can_dia_ano, mes_fin_trimestre
   into   g_fec_actual, g_nom_dia, g_nom_mes, g_nro_trimestre, g_fec_proxima,
          g_fec_anterior, g_pri_dia_mes, g_pri_dia_mes_habil, g_ult_dia_mes, g_ult_dia_mes_habil,
          g_pri_dia_trimestre, g_pri_dia_hab_trimestre, g_ult_dia_trimestre, g_ult_dia_hab_trimestre, g_mes_ini_trimestre,
          g_can_dia_ano, g_mes_fin_trimestre
   from   ge_calendarios
   where  cod_modulo = p_cod_modulo;

EXCEPTION
    when no_data_found then
         raise_application_error(-20000,'Fecha Inexistente en GE_CALENDARIOS');
END;
/* Obtener el nombre del día en Español */
FUNCTION FU_OBT_NOM_DIA
 (P_FECHA date
 )
 RETURN VARCHAR2
 IS

V_NOM_DIA VARCHAR2(20);
Begin
  v_nom_dia := trim(to_char(p_fecha, 'DAY', 'NLS_DATE_LANGUAGE = SPANISH'));
  Return v_nom_dia;
End;
/* Obtiene fecha fin de retencion */
FUNCTION FU_OBT_FEC_FIN_RET
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_DIAS IN NUMBER DEFAULT 0
 )
 RETURN DATE
 IS
  V_FEC_PROXIMA       date;
  v_can_dias          number(8);
  v_mes               varchar2(2);
  v_ult_dia_mes_habil date;
  v_cod_entidad       ge_par_generales.cod_entidad%type := pag_gen.fu_obt_cod_entidad;
BEGIN
  --- Obtener ultimo dia habil del mes de diciembre del corriente
  v_mes := to_char(p_fecha,'MM');
  If v_mes = 12 then 
    select ult_dia_mes_habil
      into v_ult_dia_mes_habil
      from ge_calendarios 
      where cod_modulo = 1;
  end if;
  
      
  v_can_dias := 0;
  v_fec_proxima := p_fecha;
  /* le agrego por si la fecha inicio ya es feriado o no habil */
  if fue_ctr_fec_feriado(v_fec_proxima,p_cod_oficina) or
     trim(to_char(v_fec_proxima,'DAY')) in ('SATURDAY','SABADO','SÁBADO', 'SUNDAY','DOMINGO') THEN
     v_fec_proxima := FU_OBT_FEC_SIG_HAB(p_fecha, p_cod_oficina, 1);
  else
    /*Si la entidad es una financiera,tiene que tomar el ultimo dia hábil del año 
    como feriado,por el feriado bancario*/
    If v_cod_entidad not between 1000 and 1999 and v_mes = 12 then
      If trunc(v_fec_proxima) = trunc(v_ult_dia_mes_habil) then
        v_fec_proxima := v_fec_proxima + 1;
      End if;
    End if;
  end if;
  loop
    exit when v_can_dias >= p_dias;
    v_fec_proxima := v_fec_proxima + 1;
    --- Verificar si es feriado o sabado o domingo
    if not fue_ctr_fec_feriado(v_fec_proxima,p_cod_oficina) and
       trim(to_char(v_fec_proxima,'DAY')) not in ('SATURDAY','SABADO','SÁBADO', 'SUNDAY','DOMINGO') THEN
       -- no es feriado ni sabado ni domingo(por el Horario BANCARIO)
       -- es un dia habil BANCARIO, puedo contarlo
      If v_cod_entidad not between 1000 and 1999 and v_mes = 12 then
         if trunc(v_fec_proxima) <> trunc(v_ult_dia_mes_habil) then
           v_can_dias := v_can_dias + 1;
         end if;   
      else 
         v_can_dias := v_can_dias + 1;
      end if;
    end if;
  end loop;
  
   -- retorno la proxima fecha
   return v_fec_proxima;
exception
   when others then
      raise_application_error(-20000,
      'Obt fec.ret.: '||TO_CHAR(p_fecha,'DD/MM/YYYY') || ' fallo');
END;
/* Obtiene la fecha del primer día habil del mes de GE_CALENDARIOS dado e */
FUNCTION FU_OBT_FEC_PRI_DIA_MES_HABIL
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS
v_pri_dia_mes_habil GE_CALENDARIOS.PRI_DIA_MES_HABIL%TYPE;
Begin
   --Obtiene la fecha actual del módulo
   select pri_dia_mes_habil
   into v_pri_dia_mes_habil
   from ge_calendarios
   where cod_modulo = p_cod_modulo;

   return v_pri_dia_mes_habil;

exception
    when no_data_found then
       raise_application_error(-20000,
       'No existe fecha prox. p/'||to_char(p_cod_modulo) ||' - ' ||sqlerrm);

End;

END PAG_CAL;
/

