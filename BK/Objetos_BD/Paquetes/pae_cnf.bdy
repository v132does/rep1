CREATE OR REPLACE PACKAGE BODY IT.PAE_CNF IS

v_fec_actual date;

/* Función que registra los cambios de datos ocurridos en los registros. */
FUNCTION FU_REG_AUDITORIA
 (P_TIPO_NOVEDAD IN BA_AUDITORIAS.TIP_NOVEDAD%TYPE
 ,P_CAMPO IN VARCHAR2
 ,P_VALOR_ANTERIOR IN VARCHAR2
 ,P_VALOR_NUEVO IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_detalle ba_auditorias.detalle%type;
   v_campo varchar2(50);
BEGIN
   v_campo := UPPER(p_campo);
   if p_tipo_novedad = 'E' then
      v_detalle := '~'||v_campo||':<i:'||p_valor_anterior||':f>';
   elsif p_tipo_novedad = 'I' then
      v_detalle := '~'||v_campo||':<i:'||p_valor_nuevo||':f>';
   elsif p_tipo_novedad = 'M' then
      if nvl(p_valor_anterior,'x') <> nvl(p_valor_nuevo,'x') then
         v_detalle := '~'||v_campo||':<i:'||p_valor_anterior||':f><i:'||p_valor_nuevo||':f>';
      end if;
   end if;
   return v_detalle;
END;
/* Controla si el modulo se encuentra activo para realizar operaciones. */
PROCEDURE PR_CTR_MODULO
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 IS
v_est_proceso ba_modulos.estado%type;
BEGIN
   -- El primer modulo es el que contiene al modulo base
   v_est_proceso := fu_obt_est_modulo(p_cod_modulo);
   if nvl(v_est_proceso,2) <> 2 and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
      raise_application_error(-20000,
      'El modulo '||to_char(p_cod_modulo)||' no se encuentra habilitado para operaciones');
   end if;
END;
/* Insertar datos en la tabla BA_AUDITORIAS */
PROCEDURE PR_INS_BA_AUDITORIA
 (RP_EAUDI IN BA_AUDITORIAS%ROWTYPE
 )
 IS
BEGIN
   if rp_eaudi.detalle is not null then
      insert into ba_auditorias
      (tabla, clave, usuario,
       fec_sistema,  fec_calendario,
       tip_novedad,  origen,
       terminal, detalle)
      values
      (rp_eaudi.tabla, rp_eaudi.clave, USER,
       SYSDATE, rp_eaudi.fec_calendario, rp_eaudi.tip_novedad,
       PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_eaudi.detalle);
   end if;
END;
/* Setea el registro de auditoria a ser grabado en detalle. */
FUNCTION FU_REG_AUDITORIA
 (P_TIPO_NOVEDAD IN BA_AUDITORIAS.TIP_NOVEDAD%TYPE
 ,P_CAMPO IN VARCHAR2
 ,P_VALOR_ANTERIOR IN DATE
 ,P_VALOR_NUEVO IN DATE
 ,P_TIPO_FECHA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_detalle ba_auditorias.detalle%type;
   v_valor_anterior varchar2(30);
   v_valor_nuevo varchar2(30);
   v_campo varchar2(50);
BEGIN
   --- OBS: En tipo de fecha hay que enviar el valor 'F' cuando es solo formato fecha
   --- y 'H' cuando es formato fecha y hora
   v_detalle := null;
   v_campo := UPPER(p_campo);
   if p_valor_anterior is not null then
      if p_tipo_fecha = 'F' then --- Solo fecha
         v_valor_anterior := to_char(p_valor_anterior,'DD/MM/YYYY');
      else --- Fecha y hora
         v_valor_anterior := to_char(p_valor_anterior,'DD/MM/YYYY HH24:MI:SS');
      end if;
   end if;
   if p_valor_nuevo is not null then
      if p_tipo_fecha = 'F' then --- Solo fecha
         v_valor_nuevo := to_char(p_valor_nuevo,'DD/MM/YYYY');
      else --- Fecha y hora
         v_valor_nuevo := to_char(p_valor_nuevo,'DD/MM/YYYY HH24:MI:SS');
      end if;
   end if;
   if p_tipo_novedad = 'E' then
      v_detalle := '~'||v_campo||':<i:'||v_valor_anterior||':f>';
   elsif p_tipo_novedad = 'I' then
      v_detalle := '~'||v_campo||':<i:'||v_valor_nuevo||':f>';
   elsif p_tipo_novedad = 'M' then
      if nvl(p_valor_anterior,trunc(sysdate)) <> nvl(p_valor_nuevo,trunc(sysdate)) then
         v_detalle := '~'||v_campo||':<i:'||v_valor_anterior||':f><i:'||v_valor_nuevo||':f>';
      end if;
   end if;
   return v_detalle;
END;
/* Setea el registro de auditoria a ser grabado en detalle. */
FUNCTION FU_REG_AUDITORIA
 (P_TIPO_NOVEDAD IN BA_AUDITORIAS.TIP_NOVEDAD%TYPE
 ,P_CAMPO IN VARCHAR2
 ,P_VALOR_ANTERIOR IN NUMBER
 ,P_VALOR_NUEVO IN NUMBER
 ,P_TIPO_MONTO IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_detalle ba_auditorias.detalle%type;
   v_valor_anterior varchar2(30);
   v_valor_nuevo varchar2(30);
   v_campo varchar2(50);
BEGIN
   --- OBS: En tipo de monto hay que enviar el valor 'N' cuando es solo formato numerico
   --- y 'M' cuando es formato monto
   v_detalle := null;
   v_campo := UPPER(p_campo);
   if p_valor_anterior is not null then
      if p_tipo_monto = 'N' then --- Solo codigo
         v_valor_anterior := ltrim(rtrim(to_char(p_valor_anterior)));
      else --- tipo monto
         v_valor_anterior := ltrim(rtrim(to_char(p_valor_anterior,'9999,999,999,999,999,999.99')));
      end if;
   end if;
   if p_valor_nuevo is not null then
      if p_tipo_monto = 'N' then --- Solo codigo
         v_valor_nuevo := ltrim(rtrim(to_char(p_valor_nuevo)));
      else --- tipo monto
         v_valor_nuevo := ltrim(rtrim(to_char(p_valor_nuevo,'9999,999,999,999,999,999.99')));
      end if;
   end if;
   if p_tipo_novedad = 'E' then
      v_detalle := '~'||v_campo||':<i:'||v_valor_anterior||':f>';
   elsif p_tipo_novedad = 'I' then
      v_detalle := '~'||v_campo||':<i:'||v_valor_nuevo||':f>';
   elsif p_tipo_novedad = 'M' then
      if nvl(p_valor_anterior,0) <> nvl(p_valor_nuevo,0) then
         v_detalle := '~'||v_campo||':<i:'||v_valor_anterior||':f><i:'||v_valor_nuevo||':f>';
      end if;
   end if;
   return v_detalle;
END;
/* Obtiene la fecha del calendario */
FUNCTION FU_OBT_FEC_ACTUAL
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS

V_FECHA DATE;

/* Objetiene la fecha de la tabla GE_CALENDARIOS */
FUNCTION LF_OBT_FEC_CALENDAR
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE;
v_tab_calendarios all_objects.object_name%type;

/* Objetiene la fecha de la tabla GE_CALENDARIOS */
FUNCTION LF_OBT_FEC_CALENDAR
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN DATE
 IS

V_FECHA DATE;
TYPE t_tipo_cursor IS REF CURSOR;
   c_cursor    t_tipo_cursor;
   v_sentencia varchar2(2000);
BEGIN
   v_sentencia := 'select fec_actual from ge_calendarios where cod_modulo = :p_modulo';
   open c_cursor for v_sentencia using p_cod_modulo;
   loop
      fetch c_cursor into v_fecha;
      exit when c_cursor%notfound;
   end loop;
   close c_cursor;
   if v_fecha is null then
      return sysdate;
   else
      return v_fecha;
   end if;
END;
BEGIN

   --if v_fec_actual is null  then --  NO FUNCIONA CORRECTAMENTE
     /* anulado
     select object_name
     into v_tab_calendarios
     from all_objects
     where object_name = 'GE_CALENDARIOS'
     and object_type = 'TABLE';*/
  
     --v_fecha := lf_obt_fec_calendar(p_cod_modulo);
     v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(p_cod_modulo);
     v_fec_actual := v_fecha;
   --else
   --  v_fecha := v_fec_actual;
   --end if;

   return v_fecha;
exception
   when no_data_found then
      return sysdate;
   when others then
        raise_application_error(-20000,
        'FU_OBT_FEC_CALENDAR' || to_char(p_cod_modulo) || '-' || sqlerrm);
END;
/* Obtener terminal del usuario. */
FUNCTION FU_OBT_TERMINAL
 RETURN VARCHAR2
 IS
cv_terminal varchar2(20);
BEGIN
   select userenv('TERMINAL')
   into cv_terminal
   from dual;
   return cv_terminal;
exception
   when others then
     raise_application_error(-20000,
     'Obt. Terminal '||sqlerrm);
END;
/* Obtener el estado del módulo. */
FUNCTION FU_OBT_EST_MODULO
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN VARCHAR2
 IS
v_est_proceso ba_modulos.estado%type;
BEGIN
   select estado
   into v_est_proceso
   from ba_modulos
   where cod_modulo = p_cod_modulo;
   return v_est_proceso;
exception
   when no_data_found then
      raise_application_error(-20000,
      'El módulo '||to_char(p_cod_modulo)||' no registrado');
END;
/* Obtener el código de programa */
FUNCTION FU_OBT_COD_PROGRAMA
 RETURN VARCHAR2
 IS
BEGIN
 return g_programa;
END;

/* SETEO DE VARIABLES */
PROCEDURE PR_SET_VARIABLES
 (p_hora in varchar2 default null,
  p_nro_secuencia in number default null) is
BEGIN
  G_HORA          := p_hora;
  G_NRO_SECUENCIA := p_nro_secuencia;

END; 

/* OBTIENE Y SECUENCIA EL NRO DE SECUENCIA */
FUNCTION FU_OBT_SIG_SECUENCIA RETURN NUMBER is
BEGIN
  G_NRO_SECUENCIA := G_NRO_SECUENCIA + 1;
  RETURN G_NRO_SECUENCIA;
END;   

/* Registro de auditoria de programas */
PROCEDURE PR_REG_PRO_AUDITORIA
   (P_FECHA IN DATE,
    P_REFERENCIA IN VARCHAR DEFAULT NULL, 
    P_TIP_NOVEDAD IN VARCHAR2 DEFAULT NULL,
    P_DETALLE IN VARCHAR2 DEFAULT NULL,
    P_COD_PROGRAMA IN BA_PROGRAMAS.COD_PROGRAMA%TYPE DEFAULT NULL) IS
PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion                                  
BEGIN  
   INSERT INTO BA_PRO_AUDITORIAS
      (cod_programa, referencia ,cod_usuario, fec_sistema, fec_calendario, tip_novedad, detalle)
   VALUES
      (nvl(P_COD_PROGRAMA,pae_cnf.g_programa), p_referencia, user, sysdate, p_fecha, p_tip_novedad, p_detalle);
   COMMIT; 
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Al insertar ba_auditoria = '||SQLERRM);  
END;
/* Obtener el report server activo */
FUNCTION fu_obt_rep_server RETURN VARCHAR2 IS
  BEGIN
     RETURN g_rep_server;
  END;
  BEGIN
     g_rep_server := fug_obt_pardinamico('REPSERVER');
END PAE_CNF;
/

