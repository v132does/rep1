CREATE OR REPLACE FUNCTION IT.FUG_OBT_HOR_DISPONIBLE (p_fecha       in date,
                                                   p_hora        in varchar2,
                                                   p_cod_usuario in varchar2,
                                                   p_es_nocturno in varchar2)
return varchar2 is
  /* funcion para obtener la hora que no esté utilizado en movimientos */
  v_existe varchar2(1);
  v_hora   varchar2(8) := p_hora;
  v_can_bus_hora number := 0;
  v_hor_agotada varchar2(1) := 'N';
  v_ind_error varchar2(1) := 'N';
  v_cod_usu_atm_actual BA_USUARIOS.COD_USUARIO%TYPE;
  v_ind_uti_sec_atm varchar2(1);
  v_ind_uti_sec_hbank varchar2(1);
  v_ind_uti_sec_bbvaips varchar2(1);
  v_ind_uti_sec_spi varchar2(1);
  v_can_bus_por_hora number;
  v_ind_uti_sec_usuario varchar2(1);
  v_cod_usu_pivot BA_USUARIOS.COD_USUARIO%TYPE;

begin
  v_ind_uti_sec_atm := fug_obt_pardinamico('IND_UTI_SEC_ATM');
  v_ind_uti_sec_hbank := fug_obt_pardinamico('IND_UTI_SEC_HBANK');
  v_ind_uti_sec_bbvaips := fug_obt_pardinamico('IND_UTI_SEC_BBVAIPS');
  v_ind_uti_sec_spi := fug_obt_pardinamico('IND_UTI_SEC_SPI');
  v_can_bus_por_hora := fug_obt_pardinamico('CAN_BUS_POR_HORA'); -- DESOPIMI-277 a pedido de EP

  --COREPESI-1 / Proyecto Mejoras Performance SIPAP--
  v_cod_usu_pivot := nvl(fug_obt_par_usuario(p_cod_usuario, 'COD_USU_PIVOT'),'#');
  v_ind_uti_sec_usuario := nvl(fug_obt_par_secuencia(v_cod_usu_pivot, 'IND_UTI_SECUENCIA'),'N');

  --DESOPIMI-277 NAF 05/2017 - usuario ATM utiliza funcion personalizada--
  if substr(p_cod_usuario,1,3) = 'ATM' and nvl(v_ind_uti_sec_atm,'N') = 'S' then
    v_hora := FUG_OBT_SIG_HOR_ATM(p_fecha,p_hora,p_cod_usuario,p_es_nocturno);
  elsif substr(p_cod_usuario,1,5) = 'HBANK' and nvl(v_ind_uti_sec_hbank,'N') = 'S' then
    --PCCDEEVO-1045 / Mejora PK usuario HBANK--
    v_hora := FUG_OBT_SIG_HOR_HBANK(p_fecha,p_hora,p_cod_usuario,p_es_nocturno);
  elsif substr(p_cod_usuario,1,7) = 'BBVAIPS' and nvl(v_ind_uti_sec_bbvaips,'N') = 'S' then
    --DYDMR-22560 / Mejora PK usuario BBVAIPS--
    v_hora := FUG_OBT_SIG_HOR_BBVAIPS(p_fecha,p_hora,p_cod_usuario,p_es_nocturno);
  elsif substr(p_cod_usuario,1,7) = 'SPI' and nvl(v_ind_uti_sec_spi,'N') = 'S' then
    --DYDMR-24261 / Mejora PK usuario SPI--
    v_hora := FUG_OBT_SIG_HOR_SPI(p_fecha,p_hora,p_cod_usuario,p_es_nocturno);
 elsif v_ind_uti_sec_usuario = 'S' then
    --COREPESI-1 / Proyecto Mejoras Performance SIPAP--
    v_hora := FUG_OBT_SIG_HOR_USUARIO(p_fecha,p_hora,p_cod_usuario,p_es_nocturno);
  else
    v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
    if p_es_nocturno = 'N' then
      loop
        v_can_bus_hora := nvl(v_can_bus_hora,0) + 1;
        begin
          select 'S'
            into v_existe
            from ge_movimientos
           where fecha = p_fecha
             and hora = v_hora
             and cod_usuario = p_cod_usuario
             and rownum <= 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;
        exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
        if v_can_bus_hora >= nvl(v_can_bus_por_hora,85000) then
           v_hor_agotada := 'S';
        end if;
      end loop;
    else -- es nocturno
      loop
        v_can_bus_hora := nvl(v_can_bus_hora,0) + 1;
        begin
          select 'S'
            into v_existe
            from ge_movimientos_noc
           where fecha = p_fecha
             and hora = v_hora
             and cod_usuario = p_cod_usuario
             and rownum <= 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;
        exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
        if v_can_bus_hora >= nvl(v_can_bus_por_hora,85000) then
           v_hor_agotada := 'S';
        end if;
      end loop;
    end if;
    --C2:Control Horas todos los usaurios--
    if v_hor_agotada = 'S' then
       --C1:Control Movimientos ATM--
       --OBS: Tener en cuenta que los Usuarios ATM deben ser habilitados (creados) siempre con el prefijo ATM--
       --Esto para responder a la logica propuesta y puedan funcionar correctamente--
       if substr(p_cod_usuario,1,3) = 'ATM' then
          --Si hora esta agotada y es usuario ATM--
          prg_ver_uti_usu_atm(v_ind_error);
          if v_ind_error = 'S' then
             --Enviar email por agotamietno de horas y usuario ATM--
             PRG_ENV_MAI_ALE_ATM('ALERTA ROJA ATM: Agotamiento de horas y usuarios ATM. Ultimo '||p_cod_usuario||' Verifique',
                                 p_cod_usuario, p_fecha);
          else
             --Enviar email por cambio de usuario ATM--
             v_cod_usu_atm_actual := fug_obt_pardinamico('COD_USU_ATM_ACTUAL');
             PRG_ENV_MAI_ALE_ATM('AVISO CAMBIO USUARIO ATM / de '||p_cod_usuario||' a '||v_cod_usu_atm_actual||'. Verifique',
                                 p_cod_usuario, p_fecha);
          end if;
          raise_application_error(-20000,'Error1 de Hora. No existe segundo disponible para usuario '||p_cod_usuario);
       else
          --Enviar email por agotamietno de horas otro usuario--
          PRG_ENV_MAI_ALE_ATM('ALERTA USUARIO: Agotamiento de hora para usuario: '||p_cod_usuario||'. Verifique',
          p_cod_usuario, p_fecha);
          raise_application_error(-20000,'Error2 de Hora. No existe segundo disponible para usuario '||p_cod_usuario);
       end if;
    end if;
  end if;
  return v_hora;
end;
/

