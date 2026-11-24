create or replace function it.FUG_OBT_SIG_HOR_SPI(p_fecha       in date,
                                               p_hora        in varchar2,
                                               p_cod_usuario in varchar2,
                                               p_es_nocturno in varchar2)
  return varchar2 is
  --DYDMR-24261 / Mejora PK usuario SPI--
  v_hora varchar2(10);
  v_segundo number;
  v_can_res_secuencia  GE_CON_PAR_SPI.CAN_RES_SECUENCIA%TYPE;
  v_ind_error varchar2(1);
  v_cod_usu_act_SPI BA_USUARIOS.COD_USUARIO%TYPE;
  v_cod_usu_nue_SPI BA_USUARIOS.COD_USUARIO%TYPE;
  v_cod_usu_SPI BA_USUARIOS.COD_USUARIO%TYPE;
  v_can_usu_uti_SPI BA_USUARIOS.COD_USUARIO%TYPE;
  v_mod_usuario varchar2(1);
  v_nro_sec_maxima number; --maximo numero entregado por la secuencia
  v_usu_fin_SPI ba_usuarios.cod_usuario%type;
  v_cod_usu_ult_cambio varchar2(10);
  v_nro_ult_cam_secuencia number;
  v_lugar  varchar2(50);
  v_tot_acu_uti_secuencia GE_CON_PAR_SPI.TOT_ACU_UTI_SECUENCIA%TYPE;
  v_usu_nro_aux varchar2(10);

  PRAGMA AUTONOMOUS_TRANSACTION;

  --Convierte el valor numerico a Hora--
  function LF_NUM_AHORA( p_numero number)
    return varchar2 is
    v_hora varchar2(8);
   begin
     v_hora := TO_CHAR(TRUNC(nvl(p_numero,0)/3600),'FM9900') || ':' ||
            TO_CHAR(TRUNC(MOD(nvl(p_numero,0),3600)/60),'FM00') || ':' ||
            TO_CHAR(MOD(nvl(p_numero,0),60),'FM00');
     return v_hora;
   end;
  --Convierte la Hora a Segundos--
  function LF_HOR_ANUMERO( p_hora varchar)
    return number is
    v_numero number;
   begin
     v_numero := to_number(substr(trim(nvl(p_hora,0)),1,2))*3600; --convierte hora
     v_numero := v_numero + to_number(substr(trim(nvl(p_hora,0)),4,2))*60; --convierte minuto
     v_numero := v_numero + to_number(substr(trim(nvl(p_hora,0)),7,2)); --convierte segundo
     return v_numero;
   end;
   --Llavea registro de parametros para evitar perdider control durante cambio usuario--
   FUNCTION LF_LLA_REGISTRO(p_nro_sec_reserva in number)
     RETURN VARCHAR2
     IS
     v_can_res_secuencia number;
   BEGIN
      select t.can_res_secuencia
      into v_can_res_secuencia
      from GE_CON_PAR_SPI t
      where can_res_secuencia = p_nro_sec_reserva
      FOR UPDATE OF can_res_secuencia NOWAIT;
      RETURN('S');
   EXCEPTION
     WHEN OTHERS THEN
         RETURN('N');
   END;
   -- Optiene la maxima hora utilizada por el usuario--
   FUNCTION LF_VER_SIG_USU_HORA(p_cod_usuario in varchar, p_segundo number, p_es_nocturno in varchar2)
     RETURN number
     IS
     v_hora varchar2(8);
     v_usu_segundo number;
   BEGIN
      if p_es_nocturno = 'N' then
         select max(hora)
           into v_hora
           from ge_movimientos
          where cod_usuario = p_cod_usuario
          and trim(hora) <> '::';
      else
         select max(hora)
           into v_hora
           from ge_movimientos_noc
          where cod_usuario = p_cod_usuario
          and trim(hora) <> '::';
      end if;
      v_usu_segundo := LF_HOR_ANUMERO(v_hora);
      v_usu_segundo := v_usu_segundo + nvl(p_segundo,0); -- se suma sec nueva evita error de pk en concurrencia
      return v_usu_segundo;
   END;
   --Cambia el usuario SPI--
   procedure LP_CAM_USUARIO(p_cod_usuario in varchar2 default null)
     IS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     v_cod_usu_SPI := nvl(p_cod_usuario,fug_obt_sig_usu_SPI);
     v_can_usu_uti_SPI := NVL(TO_NUMBER(SUBSTR(v_cod_usu_SPI,6)),0) + 1;
     -- Se cambia usuario SPI
     prg_act_par_dinamico('COD_USU_ACT_SPI',null,null,null,null,v_cod_usu_SPI,null);
     prg_act_par_dinamico('CAN_USU_UTI_SPI',null,null,null,null,v_can_usu_uti_SPI,null);
     commit;
   END;
   --Deshabilita uso secuencia para hora SPI--
   procedure LP_DES_SECUENCIA
     IS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     prg_act_par_dinamico('IND_UTI_SEC_SPI',null,null,null,null,'N',null);
     commit;
   END;
   --Consulta existencia de hora para el usuario SPI--
   FUNCTION LF_CON_HOR_USUARIO(p_fecha in date,
                               p_hora in varchar2,
                               p_cod_usuario in varchar2,
                               p_es_nocturno in varchar2)
     RETURN varchar2
     IS
       v_existe varchar2(1) := 'N';
   BEGIN
     if p_es_nocturno = 'N' then
        select 'S'
          into v_existe
          from ge_movimientos
        where fecha = p_fecha
          and hora = p_hora
          and cod_usuario = p_cod_usuario
          and rownum <= 1;
     else
        select 'S'
          into v_existe
          from ge_movimientos_noc
        where fecha = p_fecha
          and hora = p_hora
          and cod_usuario = p_cod_usuario
          and rownum <= 1;
     end if;
     return v_existe;
   EXCEPTION
     when NO_DATA_FOUND THEN
         RETURN 'N';
     WHEN OTHERS THEN
         RETURN 'S';
   END;
   --Controla y corrige el valor de la secuancia actual en caso que salga del rango valido--
   function LF_CON_VAL_SECUENCIA(p_es_nocturno in varchar2)
     RETURN number
     IS
     v_numero GE_CON_PAR_SPI.TOT_ACU_UTI_SECUENCIA%TYPE;
     v_val_nuevo GE_CON_PAR_SPI.TOT_ACU_UTI_SECUENCIA%TYPE;
     v_segundo number;
   BEGIN
       v_cod_usu_act_SPI := fug_obt_pardinamico('COD_USU_ACT_SPI');
       select S_SIG_HOR_SPI.Nextval into v_numero from dual;
       v_segundo := LF_VER_SIG_USU_HORA(v_cod_usu_act_SPI,0,p_es_nocturno);
       v_val_nuevo := nvl(v_numero,0)-nvl(v_segundo,0);
       -- Llavea el registro para actualizaciones
       if LF_LLA_REGISTRO(v_can_res_secuencia) = 'S' then
          update GE_CON_PAR_SPI
              set tot_acu_uti_secuencia = v_val_nuevo;
       end if;
       select S_SIG_HOR_SPI.Nextval into v_numero from dual;
       v_segundo := nvl(v_numero,0) - v_val_nuevo;
       return v_segundo;
   END;
   --Obtiene siguiente secuencia, Controla en caso que el nro sea dentro del rango de cambio de usuario--
   FUNCTION LF_CON_SIG_SECUENCIA(p_fecha in date,
                               p_cod_usuario in varchar2,
                               p_es_nocturno in varchar2)
     RETURN number
     IS
       v_sig_segundo number;
       v_sig_hora varchar2(10);
       v_contador number :=0;
       v_existe varchar2(1) := 'S';
   BEGIN
     --Recupera siguiente secuencia--
     select S_SIG_HOR_SPI.Nextval into v_sig_segundo from dual;
     v_sig_segundo := nvl(v_sig_segundo,0)-nvl(v_tot_acu_uti_secuencia,0);
     if (v_sig_segundo < 0) or (v_sig_segundo > v_nro_sec_maxima)then
       v_sig_segundo := LF_CON_VAL_SECUENCIA(p_es_nocturno);
     end if;
     --Si esta dentro del rango de cambio controla existencia de la hora--
     if v_sig_segundo > (v_nro_sec_maxima - v_can_res_secuencia) then
       loop
          v_sig_hora := LF_NUM_AHORA(v_sig_segundo);
          v_contador := v_contador + 1;
          v_existe := LF_CON_HOR_USUARIO( p_fecha,
                                          v_sig_hora,
                                          p_cod_usuario,
                                          p_es_nocturno);
          exit when ((v_existe = 'N') or (v_contador>=v_nro_sec_maxima));
          --Recupera siguiente secuencia--
          select S_SIG_HOR_SPI.Nextval into v_sig_segundo from dual;
          v_sig_segundo := nvl(v_sig_segundo,0)-nvl(v_tot_acu_uti_secuencia,0);
          if v_sig_segundo < 0 then
             v_sig_segundo := LF_CON_VAL_SECUENCIA(p_es_nocturno);
          end if;
       end loop;
     end if;
     return v_sig_segundo;
   END;
begin
  --Inicializar Variables--
  v_hora := null;
  v_mod_usuario := 'N';
  v_ind_error := 'N';
  v_cod_usu_SPI := null;
  v_can_usu_uti_SPI := null;
  v_nro_sec_maxima := 86399; --maximo numero permitido
  v_cod_usu_act_SPI := fug_obt_pardinamico('COD_USU_ACT_SPI');
  --Recupera Parametros de manejo de Cambio de Ususario--
  v_lugar := 'Parametros de manejo de cambio de usuario';
  select nvl(t.can_res_secuencia,100), nvl(t.cod_usu_ult_cambio,''), nvl(t.nro_ult_cam_secuencia,0), nvl(t.tot_acu_uti_secuencia,0)
    into v_can_res_secuencia, v_cod_usu_ult_cambio, v_nro_ult_cam_secuencia, v_tot_acu_uti_secuencia
    from GE_CON_PAR_SPI t;
  --Recupera/Controla la secuencia a utilizar--
  v_lugar := 'LF_CON_SIG_SECUENCIA';
  v_segundo := LF_CON_SIG_SECUENCIA(p_fecha,
                                    p_cod_usuario,
                                    p_es_nocturno);
  -- verifica secuencia actual para cambio de usuario y reinicializacion de secuencia
  v_lugar := 'Control de Cambio de Usuario';
  if v_segundo = (v_nro_sec_maxima - v_can_res_secuencia) then
     -- verifica si no cambio en otra sesion
    if (p_cod_usuario = v_cod_usu_act_SPI) then
       v_mod_usuario := 'S';
    end if;
  -- si por alguna razon falla en la verificacion inicial, se intenta a la mitad de la reserva
  elsif v_segundo > v_nro_sec_maxima - round(v_can_res_secuencia/2,0) then
    -- procesar contingencia
    -- verifica usuario actual para detectar cambios
    if (p_cod_usuario = v_cod_usu_act_SPI) then
      -- si aun no cambio, se intenta de nuevo
      v_mod_usuario := 'S'; -- fuerza cambio de usuario
    end if;
  else
    -- verifica usuario actual para detectar cambios
    if (p_cod_usuario <> v_cod_usu_act_SPI ) or
       (v_cod_usu_ult_cambio = p_cod_usuario and nvl(v_nro_ult_cam_secuencia,0) > v_segundo) then
        -- si ya cambio, se busca la siguiente hora para usuario anterior
        if v_segundo < v_can_res_secuencia then-- si es menor ya recibio una sec del usuario nuevo
          v_segundo := nvl(LF_VER_SIG_USU_HORA(p_cod_usuario, v_segundo, p_es_nocturno),v_segundo);
        end if;
    end if;
  end if;
  -- Se cambia el usuario y reinicializa secuencia
  if v_mod_usuario = 'S' then
    v_lugar := 'LF_LLA_REGISTRO';
    -- Llavea el registro para actualizaciones
    if LF_LLA_REGISTRO(v_can_res_secuencia) = 'S' then
      --Recupera el maximo usuario SPI--
      v_lugar := 'Recupera el maximo usuario SPI';
      select max(nvl(to_number(substr(x.cod_usuario,6)),0) + 1)
        into v_usu_fin_SPI
        from ba_usuarios x
        where substr(x.cod_usuario,1,5) = 'SPI';
      --Controlar si ya estamos utilizando el ultimo usuario SPI--
      v_usu_nro_aux := trim(to_char(v_usu_fin_SPI-1));
      if v_usu_nro_aux = '0' then
         v_usu_nro_aux := null;
      end if;
      if p_cod_usuario = 'SPI'||v_usu_nro_aux then
      --if v_can_aux_uti_SPI = v_can_aux_hab_SPI then
         v_ind_error := 'S';--Envia Alerta Roja--
      else
          --Cambio de usuario--
          v_lugar := 'LP_CAM_USUARIO';
          LP_CAM_USUARIO;
          --Inicializa secuencia--
          v_lugar := 'Inicializa Secuencia - GE_CON_PAR_SPI';
          update GE_CON_PAR_SPI
             set cod_usu_ult_cambio = p_cod_usuario,
                 nro_ult_cam_secuencia = v_segundo,
                 tot_acu_uti_secuencia = nvl(v_tot_acu_uti_secuencia,0) + nvl(v_segundo,0) + 1;
      end if;
      --Envio de emails de aviso--
      v_lugar := 'Envio de Emails';
      if v_ind_error = 'S' then
         --Swichea para utilizar metodo de obtencio de hora estandar--
         LP_DES_SECUENCIA;
         --Enviar email por agotamietno de horas y usuario SPI--
         PRG_ENV_MAI_ALE_ATM('ALERTA AMARILLA SPI: Obt.Hora por Secuencia alcanzo Usuario'||p_cod_usuario||'. Parametro paso a Obt.Hora por Movim. Verifique.',
                             p_cod_usuario, p_fecha);
         raise_application_error(-20000,'Error3 de Hora. No existe segundo disponible para usuario '||p_cod_usuario);
      else
         --Enviar email por cambio de usuario SPI--
         v_cod_usu_nue_SPI := fug_obt_pardinamico('COD_USU_ACT_SPI');
         PRG_ENV_MAI_ALE_ATM('AVISO CAMBIO USUARIO SPI: de '||p_cod_usuario||' a '||v_cod_usu_nue_SPI||'. Verifique',
                             p_cod_usuario, p_fecha);
      end if;
    end if;
  end if;
  --Controla la hora valida antes de retornar--
  if ((v_segundo < 0) or (v_segundo > v_nro_sec_maxima)) then
     raise_application_error(-20000,'Error. Hora Invalida, verifique la secuencia.');
  end if;
  --Convierte segundos a hora--
  v_hora:= LF_NUM_AHORA(v_segundo);
  commit;
  return(v_hora);
exception
  when others then
       raise_application_error(-20000,'Error en fug_obt_sig_hor_SPI-'||v_lugar||'-'||sqlerrm);
end FUG_OBT_SIG_HOR_SPI;
/

