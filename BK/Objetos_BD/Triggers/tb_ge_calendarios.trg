CREATE OR REPLACE TRIGGER IT.TB_GE_CALENDARIOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_CALENDARIOS
 FOR EACH ROW
DECLARE
v_linea varchar2(4000);
/* Calcula las fechas de calendario en base a una fecha dada. */
PROCEDURE LP_OBT_FECHAS
 (P_FECHA IN GE_CALENDARIOS.FEC_ACTUAL%TYPE
 ,RP_GCALE IN OUT GE_CALENDARIOS%ROWTYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 );
   r_gcale   ge_calendarios%rowtype;

/* Calcula las fechas de calendario en base a una fecha dada. */
PROCEDURE LP_OBT_FECHAS
 (P_FECHA IN GE_CALENDARIOS.FEC_ACTUAL%TYPE
 ,RP_GCALE IN OUT GE_CALENDARIOS%ROWTYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 )
 IS
v_fecha   date;
BEGIN
   --- Nombre del dia 
   BEGIN
      select rtrim(upper(to_char(p_fecha,'DAY')))
      into rp_gcale.nom_dia
      from dual;
      If rp_gcale.nom_dia    = 'SUNDAY'    then rp_gcale.nom_dia := 'DOMINGO';
      Elsif rp_gcale.nom_dia = 'MONDAY'    then rp_gcale.nom_dia := 'LUNES';
      Elsif rp_gcale.nom_dia = 'TUESDAY'   then rp_gcale.nom_dia := 'MARTES' ;
      Elsif rp_gcale.nom_dia = 'WEDNESDAY' then rp_gcale.nom_dia := 'MIERCOLES' ;
      Elsif rp_gcale.nom_dia = 'THURSDAY'  then rp_gcale.nom_dia := 'JUEVES' ;
      Elsif rp_gcale.nom_dia = 'FRIDAY'    then rp_gcale.nom_dia := 'VIERNES'  ;
      Elsif rp_gcale.nom_dia = 'SATURDAY'  then rp_gcale.nom_dia := 'SABADO' ;
      End if;
   END;
   --- Nombre del mes
   BEGIN
      select decode(to_number(to_char(p_fecha,'MM')),1,'ENERO',2,'FEBRERO',
             3,'MARZO',4,'ABRIL',5,'MAYO',6,'JUNIO',7,'JULIO',8,'AGOSTO',
             9,'SETIEMBRE',10,'OCTUBRE',11,'NOVIEMBRE',12,'DICIEMBRE')
      into rp_gcale.nom_mes
      from dual;
   END;
   --- Obtener fecha proxima
   rp_gcale.fec_proxima := pag_cal.fu_obt_fec_habil(p_fecha+1,1,p_cod_oficina);
   --- Obtener fecha anterior
   rp_gcale.fec_anterior := pag_cal.fu_obt_fec_habil(p_fecha-1,-1,p_cod_oficina);
   --- Obtener primer dia del mes
   v_fecha := to_date('01'||to_char(p_fecha,'MMYYYY'),'DDMMYYYY');
   rp_gcale.pri_dia_mes := v_fecha;
   --- Obtener primer dia habil del mes
   rp_gcale.pri_dia_mes_habil := pag_cal.fu_obt_fec_habil(v_fecha,1,p_cod_oficina);
   --- Obtener ultimo dia del mes
   v_fecha := last_day(p_fecha);
   rp_gcale.ult_dia_mes := v_fecha;
   --- Obtener ultimo dia habil del mes
   rp_gcale.ult_dia_mes_habil := pag_cal.fu_obt_fec_habil(v_fecha,-1,p_cod_oficina);
   --- Obtener numero del trimestre
   rp_gcale.nro_trimestre := to_char(p_fecha,'Q');
   --- Obtener mes inicial y final del trimestre
   if rp_gcale.nro_trimestre = 1 then
      rp_gcale.mes_ini_trimestre := 1;
      rp_gcale.mes_fin_trimestre := 3;
   elsif rp_gcale.nro_trimestre = 2 then
      rp_gcale.mes_ini_trimestre := 4;
      rp_gcale.mes_fin_trimestre := 6;
   elsif rp_gcale.nro_trimestre = 3 then
      rp_gcale.mes_ini_trimestre := 7;
      rp_gcale.mes_fin_trimestre := 9;
   elsif rp_gcale.nro_trimestre = 4 then
      rp_gcale.mes_ini_trimestre := 10;
      rp_gcale.mes_fin_trimestre := 12;
   end if;
   --- Obtener primer dia del trimestre
   v_fecha := to_date('01'||lpad(to_char(rp_gcale.mes_ini_trimestre),2,'0')||to_char(p_fecha,'YYYY'),'DDMMYYYY');
   rp_gcale.pri_dia_trimestre := v_fecha;
   --- Obtener primer dia habil del trimestre
   rp_gcale.pri_dia_hab_trimestre := pag_cal.fu_obt_fec_habil(v_fecha,1,p_cod_oficina);
   --- Obtener ultimo dia del trimestre
   v_fecha := last_day(to_date(lpad(to_char(rp_gcale.mes_fin_trimestre),2,'0')||to_char(p_fecha,'YYYY'),'MMYYYY'));
   rp_gcale.ult_dia_trimestre := v_fecha;
   --- Obtener ultimo dia habil del trimestre
   rp_gcale.ult_dia_hab_trimestre := pag_cal.fu_obt_fec_habil(v_fecha,-1,p_cod_oficina);
   --- Obtener dias del año
   if MOD(to_number(to_char(p_fecha,'YYYY')),4) <> 0 then
      rp_gcale.can_dia_ano := 365;
   else
      rp_gcale.can_dia_ano := 366;
   end if;
END;
BEGIN
   if inserting or updating then
      lp_obt_fechas(:new.fec_actual, r_gcale,null );
      :new.nom_dia               := r_gcale.nom_dia;
      :new.nom_mes               := r_gcale.nom_mes;
      :new.nro_trimestre         := r_gcale.nro_trimestre;
      :new.fec_proxima           := r_gcale.fec_proxima;
      :new.fec_anterior          := r_gcale.fec_anterior;
      :new.pri_dia_mes           := r_gcale.pri_dia_mes;
      :new.pri_dia_mes_habil     := r_gcale.pri_dia_mes_habil;
      :new.ult_dia_mes           := r_gcale.ult_dia_mes;
      :new.ult_dia_mes_habil     := r_gcale.ult_dia_mes_habil;
      :new.pri_dia_trimestre     := r_gcale.pri_dia_trimestre;
      :new.pri_dia_hab_trimestre := r_gcale.pri_dia_hab_trimestre;
      :new.ult_dia_trimestre     := r_gcale.ult_dia_trimestre;
      :new.ult_dia_hab_trimestre := r_gcale.ult_dia_hab_trimestre;
      :new.mes_ini_trimestre     := r_gcale.mes_ini_trimestre;
      :new.mes_fin_trimestre     := r_gcale.mes_fin_trimestre;
      :new.can_dia_ano           := r_gcale.can_dia_ano;
       /*
       || DYDMR-1 Balance de saldos medios DIC-12- URGENTE - SPI 1162
       || xpy0038 - 20/mayo/2014
       || En el primer día hábil de diciembre,
       || actualizar el parámetro ULT_FEC_SAL_PROMEDIO
       || con la última fecha hábil del calendario para el módulo 2/Contabilidad
       */
      if :old.cod_modulo = 2 and :new.nom_mes = 'DICIEMBRE' and :old.nom_mes = 'NOVIEMBRE' then
         begin
            insert into BA_TAB_DAT_ADICIONALES (TAB_RELACION, REFERENCIA, PARAMETRO, VAL_PARAMETRO)
            values ('GE_CALENDARIOS', '2', 'ULT_FEC_SAL_PROMEDIO', to_char(:new.ult_dia_mes_habil,'DD/MM/YYYY'));
         exception
            when dup_val_on_index then
               update BA_TAB_DAT_ADICIONALES 
                  set VAL_PARAMETRO = to_char(:new.ult_dia_mes_habil,'DD/MM/YYYY')
                where TAB_RELACION = 'GE_CALENDARIOS'
                  and REFERENCIA = '2'
                  and PARAMETRO = 'ULT_FEC_SAL_PROMEDIO';
                if sql%notfound then
                   raise_application_error(-20000, 'Parámetro ULT_FEC_SAL_PROMEDIO no definido');
                end if;
             when others then
                raise_application_error(-20000, 'Al act.ULT_FEC_SAL_PROMEDIO:'||sqlerrm);
         end;
         --- Enviar correo a ep.py@bbva.com
         v_linea := 'Se actualizó el Parámetro Adicional ULT_FEC_SAL_PROMEDIO de la tabla GE_CALENDARIOS'
                 || 'con la última fecha habil del mes de diciembre para el módulo 2 /Contabilidad: '
                 || to_char(:new.ult_dia_mes_habil,'DD/MM/YYYY');
         it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),-- De:
                      fug_obt_pardinamico('CAM_MAR_DIR_EP'), -- Para:
                      'ULTIMA FECHA DE SALDOS PROMEDIOS', -- Asunto:
                      v_linea                             -- Mensaje:
                      );
      end if;
   end if;
   if deleting then
      raise_application_error(-20000,
      'Eliminación no permitida');
   end if;
END;
/

