CREATE OR REPLACE PROCEDURE IT.PRG_REP_ENV_MSJ_SIPAP(p_fecha in date default pag_cal.fu_obt_fec_actual(1),
                                                  p_estado in varchar default 'P') is
  v_servidor   constant varchar2(20) := fug_obt_pardinamico('SNP_SCK_DIR');
  v_puerto     constant number(4) := fug_obt_pardinamico('SNP_SCK_PUERTO');
  v_tie_espera constant number(4) := fug_obt_pardinamico('SNP_SCK_TIE_ESPERA');
  v_resp          varchar2(4000) := null;
  v_ok            varchar2(1) := 'N';
  v_new_socket    varchar2(1) := nvl(fug_obt_pardinamico('HAB_NEW_SOCKET_ENV'),'N');
  v_msj_error     varchar2(4000) := null;
  v_reversar      varchar2(1) := 'N';
  v_fecha         ge_movimientos.fecha%type;
  v_hora          ge_movimientos.hora%type;
  v_cod_usuario   ge_movimientos.cod_usuario%type;
  v_cod_mod_padre ge_movimientos.cod_mod_padre%type;
  v_cod_mad_padre ge_movimientos.cod_mad_padre%type;
  v_cod_tra_padre ge_movimientos.cod_tra_padre%type;
  v_concepto      ge_movimientos.concepto%type;
  v_hor_reversion ge_movimientos.hora%type := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_dir_correo    ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CAM_MAR_DIR_SAU');
  --- Define el cursor ---
  CURSOR MEN_REP IS
    SELECT A.NRO_REFERENCIA,
           A.SITUACION,
           A.COD_MSJ_SWIFT,
           A.FEC_VALOR,
           A.MSJ_SWIFT,
           A.NOM_ARCHIVO,
           A.NOM_PRO_INSERTA,
           A.REV_AUTOMATICO
      FROM GE_SNP_MEN_ENVIADOS A
     WHERE A.FEC_VALOR = P_FECHA
       AND A.NOM_ARCHIVO IS NULL
       AND A.SITUACION = P_ESTADO;

  PROCEDURE pr_ins_sb_snp_log_envios(p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                     p_accion         in varchar2,
                                     p_situacion      in ge_snp_transferencias.situacion%type default null,
                                     p_error          in ge_snp_transferencias.error%type default null) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_secuencia number := 0;
  BEGIN
    if p_accion = 'I' then
      if p_situacion != 'N' then
        --hallar la última secuencia del estado
        begin
          select secuencia + 1
            into v_secuencia
            from sb_snp_log_envios
           where nro_referencia = p_nro_referencia
             and situacion = p_situacion;
        exception
          when others then
            v_secuencia := 0;
        end;
      end if;

      insert into sb_snp_log_envios
        (nro_referencia, situacion, secuencia, error)
      values
        (p_nro_referencia, p_situacion, v_secuencia, p_error);
      commit;

    elsif p_accion = 'A' then
      select nvl(max(secuencia), 0) + 1
        into v_secuencia
        from sb_snp_log_envios
       where nro_referencia = p_nro_referencia
         and situacion = 'E';

      update sb_snp_log_envios
         set situacion = p_situacion,
             secuencia = v_secuencia,
             error     = p_error
       where nro_referencia = p_nro_referencia
         and situacion = 'N';
      commit;
    end if;
  EXCEPTION
    when DUP_VAL_ON_INDEX then
      select NVL(MAX(secuencia), 0) + 1
        into v_secuencia
        from sb_snp_log_envios
       where nro_referencia = p_nro_referencia
         and situacion = 'E';

      insert into sb_snp_log_envios
        (nro_referencia, situacion, secuencia, error)
      values
        (p_nro_referencia,
         'E',
         v_secuencia,
         'Transferencia en estado de envío al Socket REPROCESO');
      commit;

      raise_application_error(-20003,'Transferencia en estado de envío al Socket REPROCESO');
  END pr_ins_sb_snp_log_envios;

Begin
  if v_new_socket = 'N' then-- Solo procesa cuando el nuevo socket está fuera de servicio
    FOR mn IN MEN_REP LOOP
      v_ok := fue_env_tcp_mensajes(p_servidor   => v_servidor,
                                   p_puerto     => v_puerto,
                                   p_tie_espera => v_tie_espera,
                                   p_mensaje    => mn.msj_swift,
                                   p_respuesta  => v_resp);                                    

      if v_ok != 'S' THEN
        if mn.rev_automatico = 'S' then
          -- Hubo problema en el envío, se actualiza a la situación/estado anterior
          v_msj_error := 'Error durante la conexión con el socket REPROCESO: ' ||substr(v_resp, 1, 3000);
          pr_ins_sb_snp_log_envios(mn.nro_referencia,
                                   'A',
                                   'E',
                                   v_msj_error);
          begin

            update ge_snp_transferencias t
               set t.situacion = 'L', t.estado = 'A'
             where t.nro_referencia = mn.nro_referencia;
            commit;
            --Control para NO reversar si ya se encuentra el 900
            Begin
              Select distinct ('N')
                into v_reversar
                from ge_snp_mensajes b
               where b.nro_ref_externa = to_char(mn.nro_referencia)
                 and b.cod_msj_swift = 900
                 and trunc(b.fec_insercion) = trunc(sysdate);
            exception
              when others then
                -- si el error respondido por el socket es por 02-Limite de tiempo de espera - No se reversa
                if substr(nvl(v_resp, '03'), 1, 2) <> '02' then
                  v_reversar := 'S';
                else
                  v_reversar := 'N';
                end if;
            end;
            if v_reversar = 'S' then
              --> Movimiento a reversar
              Select a.fecha,
                     a.hora,
                     a.cod_usuario,
                     a.Cod_Mod_Padre,
                     a.Cod_Mad_Padre,
                     a.Cod_Tra_Padre
                into v_fecha,
                     v_hora,
                     v_cod_usuario,
                     v_cod_mod_padre,
                     v_cod_mad_padre,
                     v_cod_tra_padre
                From ge_movimientos a
               Where a.nro_documento = mn.nro_referencia
                 and a.reversado = 'N'
                 and a.nro_secuencia = 1;
              v_hor_reversion := fug_obt_hor_disponible(v_fecha,
                                                        v_hor_reversion,
                                                        v_cod_usuario,
                                                        'N');
              v_concepto      := 'Rev. de Mov. por falla del socket REPROCESO';
              prg_rev_operacion_snp(v_fecha,
                                    v_hora,
                                    v_cod_usuario,
                                    v_cod_mod_padre,
                                    v_cod_mad_padre,
                                    v_cod_tra_padre,
                                    user,
                                    v_hor_reversion,
                                    'N',
                                    v_concepto);
              update ge_snp_transferencias t
                 set t.situacion = 'P', t.estado = 'C'
               where t.nro_referencia = mn.nro_referencia;
            end if;
            commit;

            BEGIN
              prg_ins_notificacion(trunc(sysdate),
                                   fug_obt_dir_correo,
                                   v_dir_correo,
                                   'Reversión de Mov. por timeout con el socket REPROCESO',
                                   'Fecha  : ' || v_fecha || chr(10) ||
                                   'Hora : ' || v_hora || chr(10) ||
                                   'Cod. usuario : ' || v_cod_usuario ||
                                   chr(10) || 'Cod. modulo padre : ' ||
                                   v_cod_mod_padre || chr(10) ||
                                   'Cod. modalidad padre : ' ||
                                   v_cod_mad_padre || chr(10) ||
                                   'Cod. transaccion padre : ' ||
                                   v_cod_tra_padre || chr(10) ||
                                   'Nro. Referencia : ' ||
                                   mn.nro_referencia || chr(10) ||
                                   'Atentamente. ');
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          exception
            WHEN OTHERS THEN
              NULL;
          end;
        else
          -- Hubo problema en el envio
          v_msj_error := v_resp;
          pr_ins_sb_snp_log_envios(mn.nro_referencia,
                                   'A',
                                   'N',
                                   v_msj_error);
          BEGIN
            prg_ins_notificacion(trunc(sysdate),
                                 fug_obt_dir_correo,
                                 v_dir_correo,
                                 'Error en envio al Socket REPROCESO',
                                 'Nro. Referencia : ' || mn.nro_referencia ||
                                 chr(10) || v_msj_error || chr(10) ||
                                 'Atentamente. ');
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        End if;
      else
        --Actualiza la situación a Reprocesado en la tabla GE_SNP_MEN_ENVIADOS
        begin
          update ge_snp_men_enviados en
           set en.situacion = 'R',
               en.nom_archivo= 'REPROCESADO'
          WHERE en.nro_referencia = mn.nro_referencia
            and en.cod_msj_swift  = mn.cod_msj_swift;
            commit; 
          exception
             when others then 
            raise_application_error(-20000,sqlerrm);
        end;  
      end if;
    end loop;
  end if;
End;
/

