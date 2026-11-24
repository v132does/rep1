create or replace function it.FUG_OBT_SIG_HOR_USUARIO(p_fecha       in date,
                                                   p_hora        in varchar2,
                                                   p_cod_usuario in varchar2,
                                                   p_es_nocturno in varchar2)
  return varchar2 is
  --COREPESI-1 / Proyecto Mejoras Performance SIPAP--

  --Variables--
  v_hora varchar2(10);
  v_segundo number;
  v_can_res_secuencia  number;
  v_ind_error varchar2(1);
  v_cod_usu_actual BA_USUARIOS.COD_USUARIO%TYPE;
  v_cod_usu_nue_usuario BA_USUARIOS.COD_USUARIO%TYPE;
  v_can_usu_habilitados number;
  v_can_usu_utilizados number;
  v_mod_usuario varchar2(1);
  v_len_usuario number;
  v_cod_usu_pivot ge_par_usuarios.val_parametro%type;
  v_nro_sec_maxima number; --maximo numero entregado por la secuencia
  v_usu_fin_usuario ba_usuarios.cod_usuario%type;
  v_cod_usu_ult_cambio varchar2(10);
  v_nro_ult_cam_secuencia number;
  v_lugar  varchar2(50);
  v_tot_acu_uti_secuencia number;
  v_usu_nro_aux varchar2(10);
  v_cod_usu_sesion BA_USUARIOS.COD_USUARIO%TYPE;
  v_cod_usu_actualizar BA_USUARIOS.COD_USUARIO%TYPE;
  v_nom_secuencia ge_par_usuarios.val_parametro%type;
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
   FUNCTION LF_LLA_REGISTRO
     RETURN VARCHAR2
     IS
     v_can_res_sec_aux ge_par_usuarios.val_parametro%type;
   BEGIN
      select t.val_parametro
        into v_can_res_sec_aux
        from ge_par_usuarios t
       where t.cod_usuario = v_cod_usu_pivot
         and t.parametro = 'COD_USU_PIVOT'
      FOR UPDATE OF t.val_parametro NOWAIT;
      RETURN('S');
   EXCEPTION
     WHEN OTHERS THEN
         RETURN('N');
   END;
   -- Optiene la maxima hora utilizada por el usuario--
   FUNCTION LF_VER_SIG_USU_HORA(p_segundo number, p_es_nocturno in varchar2)
     RETURN number
     IS
     v_hora varchar2(8);
     v_usu_segundo number;
   BEGIN
      if p_es_nocturno = 'N' then
         select max(hora)
           into v_hora
           from ge_movimientos
          where cod_usuario = v_cod_usu_sesion
          and trim(hora) <> '::';
      else
         select max(hora)
           into v_hora
           from ge_movimientos_noc
          where cod_usuario = v_cod_usu_sesion
          and trim(hora) <> '::';
      end if;
      v_usu_segundo := LF_HOR_ANUMERO(v_hora);
      v_usu_segundo := v_usu_segundo + nvl(p_segundo,0); -- se suma sec nueva evita error de pk en concurrencia
      return v_usu_segundo;
   END;
   --Cambia el usuario usuario--
   procedure LP_CAM_USUARIO(p_cod_usu_nuevo out varchar2)
     IS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     p_cod_usu_nuevo := fug_obt_sig_usuario(v_cod_usu_pivot);
     if p_cod_usu_nuevo is not null then
         v_can_usu_utilizados := nvl(v_can_usu_utilizados,0) + 1;
         -- Se cambia usuario a nuevo usuario--
         update ge_con_par_usuarios h
             set h.cod_usu_actual = p_cod_usu_nuevo,
                 h.can_usu_utilizados = v_can_usu_utilizados
           where h.cod_usu_pivot = v_cod_usu_pivot;
         commit;
      end if;
   END;
   --Deshabilita uso secuencia para hora usuario--
   procedure LP_DES_SECUENCIA
     IS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     update ge_con_par_usuarios h
        set h.ind_uti_secuencia = 'N'
      where h.cod_usu_pivot = v_cod_usu_pivot;
     commit;
   END;
   --Consulta existencia de hora para el usuario usuario--
   FUNCTION LF_CON_HOR_USUARIO(p_fecha in date,
                               p_hora in varchar2,
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
          and cod_usuario = v_cod_usu_sesion
          and rownum <= 1;
     else
        select 'S'
          into v_existe
          from ge_movimientos_noc
        where fecha = p_fecha
          and hora = p_hora
          and cod_usuario = v_cod_usu_sesion
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
     v_numero number;
     v_val_nuevo number;
     v_segundo number;
   BEGIN
       v_numero := fug_obt_sig_sec_base(v_nom_secuencia);
       v_segundo := LF_VER_SIG_USU_HORA(0,p_es_nocturno);
       v_val_nuevo := nvl(v_numero,0)-nvl(v_segundo,0);
       -- Llavea el registro para actualizaciones
       if LF_LLA_REGISTRO = 'S' then
          update ge_con_par_usuarios h
             set h.tot_acu_uti_secuencia = v_val_nuevo
           where h.cod_usu_pivot = v_cod_usu_pivot;
       end if;
       v_numero := fug_obt_sig_sec_base(v_nom_secuencia);
       v_segundo := nvl(v_numero,0) - v_val_nuevo;
       return v_segundo;
   END;
   --Obtiene siguiente secuencia, Controla en caso que el nro sea dentro del rango de cambio de usuario--
   FUNCTION LF_CON_SIG_SECUENCIA(p_fecha in date,
                                 p_es_nocturno in varchar2)
     RETURN number
     IS
       v_sig_segundo number;
       v_sig_hora varchar2(10);
       v_contador number :=0;
       v_existe varchar2(1) := 'S';
   BEGIN
     --Recupera siguiente secuencia--
     v_sig_segundo := fug_obt_sig_sec_base(v_nom_secuencia);
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
                                          p_es_nocturno);
          exit when ((v_existe = 'N') or (v_contador>=v_nro_sec_maxima));
          --Recupera siguiente secuencia--
          v_sig_segundo := fug_obt_sig_sec_base(v_nom_secuencia);
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
  v_cod_usu_sesion := p_cod_usuario;
  v_hora := null;
  v_mod_usuario := 'N';
  v_ind_error := 'N';
  v_can_usu_utilizados := null;
  v_nro_sec_maxima := 86399; --maximo numero permitido

  --Recupera Parametros de manejo de Cambio de Usuario--
  v_lugar := 'Parametros de manejo de cambio de usuario';

  select x1.val_parametro
    into v_cod_usu_pivot
    from ge_par_usuarios x1
   where x1.cod_usuario = v_cod_usu_sesion
     and x1.parametro = 'COD_USU_PIVOT';

  select x2.can_res_secuencia, x2.cod_usu_ult_cambio, x2.nro_ult_cam_secuencia,
         x2.tot_acu_uti_secuencia, x2.cod_usu_actual, x2.can_usu_habilitados,
         x2.cod_sec_utilizada
    into v_can_res_secuencia, v_cod_usu_ult_cambio, v_nro_ult_cam_secuencia,
         v_tot_acu_uti_secuencia, v_cod_usu_actual, v_can_usu_habilitados,
         v_nom_secuencia
    from ge_con_par_usuarios x2
   where x2.cod_usu_pivot = v_cod_usu_pivot;

  --Recupera/Controla la secuencia a utilizar--
  v_lugar := 'LF_CON_SIG_SECUENCIA';
  v_segundo := LF_CON_SIG_SECUENCIA(p_fecha, p_es_nocturno);

  -- verif-ica secuencia actual para cambio de usuario y reinicializacion de secuencia
  v_lugar := 'Control de Cambio de Usuario';
  if v_segundo = (v_nro_sec_maxima - v_can_res_secuencia) then
     -- verifica si no cambio en otra sesion
    if (v_cod_usu_sesion = v_cod_usu_actual) then
       v_mod_usuario := 'S';
    end if;
  -- si por alguna razon falla en la verificacion inicial, se intenta a la mitad de la reserva
  elsif v_segundo > v_nro_sec_maxima - round(v_can_res_secuencia/2,0) then
    -- procesar contingencia
    -- verifica usuario actual para detectar cambios
    if (v_cod_usu_sesion = v_cod_usu_actual) then
      -- si aun no cambio, se intenta de nuevo
      v_mod_usuario := 'S'; -- fuerza cambio de usuario
    end if;
  else
    -- verifica usuario actual para detectar cambios
    if (v_cod_usu_sesion <> v_cod_usu_actual ) or
       (v_cod_usu_ult_cambio = v_cod_usu_pivot and nvl(v_nro_ult_cam_secuencia,0) > v_segundo) then
        -- si ya cambio, se busca la siguiente hora para usuario anterior
        if v_segundo < v_can_res_secuencia then-- si es menor ya recibio una sec del usuario nuevo
          v_segundo := nvl(LF_VER_SIG_USU_HORA(v_segundo, p_es_nocturno),v_segundo);
        end if;
    end if;
  end if;
  -- Se cambia el usuario y reinicializa secuencia
  if v_mod_usuario = 'S' then
    v_len_usuario := length(v_cod_usu_pivot);
    v_lugar := 'LF_LLA_REGISTRO';
    -- Llavea el registro para actualizaciones
    if LF_LLA_REGISTRO = 'S' then
      --Recupera el maximo usuario usuario--
      v_lugar := 'Recupera el maximo usuario';
       select max(nvl(to_number(substr(y.cod_usuario,v_len_usuario+1)),0) + 1)
         into v_usu_fin_usuario
         from ge_par_usuarios y
        where y.cod_usuario <> v_cod_usu_pivot
          and y.parametro = 'COD_USU_PIVOT'
          and substr(y.cod_usuario,1,v_len_usuario) = v_cod_usu_pivot;

      --Controlar si ya estamos utilizando el ultimo usuario usuario--
      v_usu_nro_aux := trim(to_char(TO_NUMBER(v_usu_fin_usuario)-1));
      if v_usu_nro_aux = '0' then
         v_usu_nro_aux := null;
      end if;
      v_can_usu_utilizados := to_number(fug_obt_par_secuencia(v_cod_usu_pivot,'CAN_USU_UTILIZADOS'));
      if ((v_cod_usu_actual = v_cod_usu_pivot||v_usu_nro_aux) or
          (v_can_usu_utilizados = v_can_usu_habilitados)) then
         v_ind_error := 'S';--Envia Alerta Roja--
      else
          --Cambio de usuario--
          v_lugar := 'LP_CAM_USUARIO';
          LP_CAM_USUARIO(v_cod_usu_actualizar);
          --Inicializa secuencia--
          v_lugar := 'Inicializa Secuencia - ge_par_usuarios';
          update ge_con_par_usuarios h
             set cod_usu_ult_cambio = v_cod_usu_actualizar,--v_cod_usu_sesion,
                 nro_ult_cam_secuencia = v_segundo,
                 tot_acu_uti_secuencia = nvl(v_tot_acu_uti_secuencia,0) + nvl(v_segundo,0) + 1
           where h.cod_usu_pivot = v_cod_usu_pivot;
      end if;
      --Envio de emails de aviso--
      v_lugar := 'Envio de Emails';
      if v_ind_error = 'S' then
         --Swichea para utilizar metodo de obtencio de hora estandar--
         LP_DES_SECUENCIA;
         --Enviar email por agotamietno de horas y usuario usuario--
         PRG_ENV_MAI_ALE_ATM('ALERTA AMARILLA usuario: Obt.Hora por Secuencia alcanzo Usuario'||v_cod_usu_actual||'. Parametro paso a Obt.Hora por Movim. Verifique.',
                             v_cod_usu_pivot, p_fecha);
         raise_application_error(-20000,'Error3 de Hora. No existe segundo disponible para usuario '||v_cod_usu_actual);
      else
         --Enviar email por cambio de usuario usuario--
         v_cod_usu_nue_usuario := FUG_OBT_PAR_SECUENCIA(v_cod_usu_pivot, 'COD_USU_ACTUAL');
         PRG_ENV_MAI_ALE_ATM('AVISO CAMBIO USUARIO de '||v_cod_usu_actual||' a '||v_cod_usu_nue_usuario||'. Verifique',
                             v_cod_usu_pivot, p_fecha);
      end if;
    end if;
  end if;
  --Controla la hora valida antes de retornar--
  if ((v_segundo < 0) or (v_segundo > v_nro_sec_maxima)) then
     --Swichea para utilizar metodo de obtencio de hora estandar--
     LP_DES_SECUENCIA;
     raise_application_error(-20000,'Error. Hora Invalida-'||v_segundo ||'-verifique la secuencia.');
  end if;
  --Convierte segundos a hora--
  v_hora:= LF_NUM_AHORA(v_segundo);
  commit;
  return(v_hora);
exception
  when others then
       --Swichea para utilizar metodo de obtencio de hora estandar--
       LP_DES_SECUENCIA;
       raise_application_error(-20000,'Error en fug_obt_sig_hor_usuario-'||v_lugar||'-'||sqlerrm);
end FUG_OBT_SIG_HOR_USUARIO;
/

