CREATE OR REPLACE TRIGGER IT.TA_GE_SNP_TRANSFERENCIAS
  --AFTER UPDATE OF SITUACION, ESTADO ON GE_SNP_TRANSFERENCIAS
  AFTER INSERT OR UPDATE OF SITUACION, ESTADO ON "IT"."GE_SNP_TRANSFERENCIAS"
  FOR EACH ROW
DECLARE
  v_es_apn    varchar2(1);
  v_error     number;
  v_respuesta varchar2(500);
  v_det_error ge_log_errores.det_error%type;
  v_ind_pat varchar2(1);
  v_notifica varchar2(1);
  v_cod_error                   number(10);
  v_men_error                    varchar2(2000);
  v_inf_json                 long:=null;
  v_aviso                    varchar2(2000);
  v_existe varchar2(1);--BWP-818
    procedure lp_act_des_error (p_cod_mot_rechazo ge_apn_datos.cod_mot_rechazo%type,
                               p_cod_msj_swift   ge_snp_transferencias.cod_msj_swift%type,
                               p_est_transf      ge_apn_datos.est_transf%type,
                               p_mtcn            ge_apn_datos.cod_mtcn%type,
                               p_referencia      ge_apn_datos.referencia%type) is

 v_mot_rechazo ge_apn_datos.mot_rechazo%type;
 begin
   if nvl(p_est_transf, 'X') = 'RJCT' then
     if nvl(p_cod_msj_swift, 0) = to_number(fug_obt_pardinamico('COD_SPI_PCD')) then
      v_mot_rechazo := fue_obt_des_refcodes(P_DOMINIO => 'TIP_REC_SPI',
                                               P_VALOR   => p_cod_mot_rechazo,
                                               P_TIPO    => null);
     else
       v_mot_rechazo := fue_obt_des_refcodes(P_DOMINIO => 'TIP_REC_SNP',
                                               P_VALOR   => p_cod_mot_rechazo,
                                               P_TIPO    => null);
     end if;
     if v_mot_rechazo is not null then
     begin
     update it.ge_apn_datos s
             set s.cod_mot_rechazo = p_cod_mot_rechazo, --- null por defecto DA-9239 - GLOPEZ
                 s.mot_rechazo     = v_mot_rechazo --- Null por defecto -- DA-9239 GLOPEZ
           where s.cod_mtcn = p_mtcn
            and s.referencia = p_referencia;
    exception
      when others then
        null;
    end;
    end if;
   end if;
 end;

BEGIN
  if updating then
    if (:new.situacion <> :old.situacion or :new.estado <> :old.estado) and
       :new.fec_recepcion is null then
      if not (:old.situacion = 'P' and :new.situacion = 'V') then
        -- si pasa de V a P no se tiene que notificar por sigue siendo pendiente
        begin
          v_es_apn := Pap_Ser.fu_ver_mov_es_tra_apn(:new.concepto,
                                                           :new.nro_referencia,
                                                           'SIPAP');
          if v_es_apn = 'S' then
            if :new.situacion = 'L' and :new.estado = 'R' then
              --Si se rechaza en la entidad destino
              Pap_Ser.pr_act_dat_apn(:new.concepto,
                                         :new.nro_referencia,
                                         null,
                                         'RTRN',
                                         'N',
                                         null,
                                         null,
                                         null,
                                         v_error,
                                         v_respuesta);

            elsif :new.situacion = 'L' and :new.estado = 'A' then
              --si se liquida
              Pap_Ser.pr_act_dat_apn(:new.concepto,
                                         :new.nro_referencia,
                                         null,
                                         'ACTC',
                                         'N',
                                         null,
                                         null,
                                         null,
                                         v_error,
                                         v_respuesta);
             --si se rechaza por algun error o cancelacion
            elsif :new.situacion in ('T', 'C', 'E') then
              Pap_Ser.pr_act_dat_apn(:new.concepto,
                                         :new.nro_referencia,
                                         null,
                                         'RJCT',
                                         'N',
                                         null,
                                         null,
                                         null,
                                         v_error,
                                         v_respuesta);
               --DA-9239
              lp_act_des_error(:new.tip_rechazo, :new.cod_msj_swift,'RJCT',:new.concepto,:new.nro_referencia  ) ;

            elsif :new.estado = 'C' then
               Pap_Ser.pr_act_dat_apn(:new.concepto,
                                         :new.nro_referencia,
                                         null,
                                         'RJCT',
                                         'N',
                                         null,
                                         null,
                                         null,
                                         v_error,
                                         v_respuesta);
             --DA-9239
            lp_act_des_error(:new.tip_rechazo, :new.cod_msj_swift,'RJCT',:new.concepto,:new.nro_referencia  ) ;

            end if;
          end if;

          if v_error != 0 then
            v_det_error := 'MTCN: ' || :new.concepto || ' Referencia: ' ||
                           :new.nro_referencia || ' Error: ' || v_respuesta;
            PRG_INS_LOG_PROGRAMAS('TA_GE_SNP_TRANSFERENCIAS',
                                  v_det_error,
                                  null,
                                  null);
          end if;
        exception
          when others then
            null;
        end;

      end if;
      --BWP-818
          begin
            select 'S'
              into v_existe
              from it.bw_mov_pendientes t
             where t.cod_tip_mensaje in ( '036','075')
               and t.nro_ope_relacionada = :new.nro_referencia
               and t.estado='P';
          exception
            when no_data_found then
              v_existe := 'N';
            when others then
              v_existe := 'N';
          end;
          if nvl(v_existe,'N') ='S' then
                 if  :new.situacion = 'T' OR :new.situacion = 'C' then
                           begin
                             update bw_mov_pendientes
                               set estado = 'A'
                             where nro_ope_relacionada = :new.nro_referencia;
                           exception
                                 when no_data_found then
                             null;
                             end;
                 end if;
         end if;
    end if;
    if  nvl(pae_cnf.g_programa, '~')  IN ('GMSNP103') and  :new.cod_msj_swift=103 then
       if :new.cod_swi_suc_beneficiario is null then-- no corresponde a patrocinador
          v_ind_pat:='N';
       else
          v_ind_pat:='S';-- corresponde a patrocinador
       end if;
      if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' then
          v_notifica:=pas_spi.fu_obt_tra_spi_notificacion(:new.cod_moneda,
                                                     :new.monto,
                                                     v_ind_pat,
                                                     :new.cod_swi_pte_beneficiario,
                                                     'PEI');
         if nvl(v_notifica,'N')= 'S' then
                        --Envio de sms
                        begin
                          prg_env_sms_spi(:new.cod_per_solicitante,
                                          455,
                                          'GEN_ENV_SMS_TRA_SPI_LBTR',
                                          v_cod_error,
                                          v_men_error);
                        exception
                          when others then
                            null; --no realiza accion si da error envio de sms
                        end;
                        --Envio de mail
                        begin
                          v_aviso    := fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_LBTR');
                          v_inf_json := '{' || '"fec_transferencia":' || '"' ||
                                        to_char(:new.fec_insercion,
                                                'DD/MM/YYYY HH24:MI:SS') || '"' || ',' ||
                                        '"nom_beneficiario":' || '"' ||
                                        :new.nom_beneficiario || '"' || ',' ||
                                        '"monto":' || '"' ||
                                        ltrim(rtrim(to_char(:new.monto,
                                                            '999,999,999,999,999.99'))) || ' ' ||
                                        initcap(:new.cod_moneda) || '.' || '"' || ',' ||
                                        '"aviso":' || '"' || v_aviso || '"' || '}';
                          --Insertar correo para el solicitante
                          pas_spi.pr_env_alerta(:new.cod_per_solicitante,
                                                fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                                           'ENVNOTRED2'),
                                                v_inf_json);
                        exception
                          when others then
                            null; --no realiza accion si da error envio de correo
                        end;
         end if;
       end if;
    end if;
  end if;
  if inserting  then
    if :new.cod_swi_suc_beneficiario is null then-- no corresponde a patrocinador
      v_ind_pat:='N';
    else
       v_ind_pat:='S';-- corresponde a patrocinador
    end if;
    if :new.cod_msj_swift=102 then-- condicion SPI- Beneficiario inactivo temporalmente transferencias enviadas (redirección al ACH)
      if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' then
           v_notifica:=pas_spi.fu_obt_tra_spi_notificacion(:new.cod_moneda,
                                                     :new.monto,
                                                     v_ind_pat,
                                                     :new.cod_swi_pte_beneficiario,
                                                     'PBI');
         if nvl(v_notifica,'N')= 'S' then
                          --Envio de sms
                        begin
                          prg_env_sms_spi(:new.cod_per_solicitante,
                                          455,
                                          'GEN_ENV_SMS_TRA_SPI_ACH',
                                          v_cod_error,
                                          v_men_error);
                        exception
                          when others then
                            null; --no hace realiza accion si da error envio de sms
                        end;
                        --Envio de mail
                        begin
                          v_aviso    := fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_ACH');
                          v_inf_json := '{' || '"fec_transferencia":' || '"' ||
                                        to_char(:new.fec_insercion,
                                                'DD/MM/YYYY HH24:MI:SS') || '"' || ',' ||
                                        '"nom_beneficiario":' || '"' ||
                                        :new.nom_beneficiario || '"' || ',' ||
                                        '"monto":' || '"' ||
                                        ltrim(rtrim(to_char(:new.monto,
                                                            '999,999,999,999,999.99'))) || ' ' ||
                                        initcap(:new.cod_moneda) || '.' || '"' || ',' ||
                                        '"aviso":' || '"' || v_aviso || '"' || '}';
                          --Insertar correo para el solicitante
                          pas_spi.pr_env_alerta(:new.cod_per_solicitante,
                                                fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                                           'ENVNOTRED'),
                                                v_inf_json);
                        exception
                          when others then
                            null; --no hace realiza accion si da error envio de correo
                        end;
         end if;
      else
         v_notifica:=pas_spi.fu_obt_tra_spi_notificacion(:new.cod_moneda,
                                                     :new.monto,
                                                     v_ind_pat,
                                                     :new.cod_swi_pte_beneficiario,
                                                     'PEI');
         if nvl(v_notifica,'N')= 'S' then
                        --Envio de sms
                        begin
                          prg_env_sms_spi(:new.cod_per_solicitante,
                                          455,
                                          'GEN_ENV_SMS_TRA_SPI_ACH1',
                                          v_cod_error,
                                          v_men_error);
                        exception
                          when others then
                            null; --no hace realiza accion si da error envio de sms
                        end;
                        --Envio de mail
                        begin
                          v_aviso    := fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_ACH1');
                          v_inf_json := '{' || '"fec_transferencia":' || '"' ||
                                        to_char(:new.fec_insercion,
                                                'DD/MM/YYYY HH24:MI:SS') || '"' || ',' ||
                                        '"nom_beneficiario":' || '"' ||
                                        :new.nom_beneficiario || '"' || ',' ||
                                        '"monto":' || '"' ||
                                        ltrim(rtrim(to_char(:new.monto,
                                                            '999,999,999,999,999.99'))) || ' ' ||
                                        initcap(:new.cod_moneda) || '.' || '"' || ',' ||
                                        '"aviso":' || '"' || v_aviso || '"' || '}';
                          --Insertar correo para el solicitante
                          pas_spi.pr_env_alerta(:new.cod_per_solicitante,
                                                fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                                           'ENVNOTRED1'),
                                                v_inf_json);
                        exception
                          when others then
                            null; --no hace realiza accion si da error envio de correo
                        end;
         end if;
      end if;
     elsif :new.cod_msj_swift=103 then

       if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' then
          v_notifica:=pas_spi.fu_obt_tra_spi_notificacion(:new.cod_moneda,
                                                     :new.monto,
                                                     v_ind_pat,
                                                     :new.cod_swi_pte_beneficiario,
                                                     'PEI');
         if nvl(v_notifica,'N')= 'S' then
                        --Envio de sms
                        begin
                          prg_env_sms_spi(:new.cod_per_solicitante,
                                          455,
                                          'GEN_ENV_SMS_TRA_SPI_LBTR',
                                          v_cod_error,
                                          v_men_error);
                        exception
                          when others then
                            null; --no realiza accion si da error envio de sms
                        end;
                        --Envio de mail
                        begin
                          v_aviso    := fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_LBTR');
                          v_inf_json := '{' || '"fec_transferencia":' || '"' ||
                                        to_char(:new.fec_insercion,
                                                'DD/MM/YYYY HH24:MI:SS') || '"' || ',' ||
                                        '"nom_beneficiario":' || '"' ||
                                        :new.nom_beneficiario || '"' || ',' ||
                                        '"monto":' || '"' ||
                                        ltrim(rtrim(to_char(:new.monto,
                                                            '999,999,999,999,999.99'))) || ' ' ||
                                        initcap(:new.cod_moneda) || '.' || '"' || ',' ||
                                        '"aviso":' || '"' || v_aviso || '"' || '}';
                          --Insertar correo para el solicitante
                          pas_spi.pr_env_alerta(:new.cod_per_solicitante,
                                                fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                                           'ENVNOTRED2'),
                                                v_inf_json);
                        exception
                          when others then
                            null; --no realiza accion si da error envio de correo
                        end;
         end if;
       end if;
      elsif :new.cod_msj_swift=8 then
        if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' and  nvl(fug_obt_pardinamico( 'SPI_DISP_BCP' ),'N')='S' then
           v_notifica:=pas_spi.fu_obt_tra_spi_notificacion(:new.cod_moneda,
                                                     :new.monto,
                                                     v_ind_pat,
                                                     :new.cod_swi_pte_beneficiario,
                                                     'PEP');
          if v_notifica='S' then--Participante emisor con problemas de conexion en SPI y y el servicio del SPI en el BCP se encuentra disponible

                       --Envio de sms
                        begin
                          prg_env_sms_spi(:new.cod_per_solicitante,
                                          455,
                                          'GEN_ENV_SMS_TRA_SPI_RV',
                                          v_cod_error,
                                          v_men_error);
                        exception
                          when others then
                            null; --no realiza accion si da error envio de sms
                        end;
                        --Envio de mail
                        begin
                          v_aviso    := fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_RV');
                          v_inf_json := '{' || '"fec_transferencia":' || '"' ||
                                        to_char(:new.fec_insercion,
                                                'DD/MM/YYYY HH24:MI:SS') || '"' || ',' ||
                                        '"nom_beneficiario":' || '"' ||
                                        :new.nom_beneficiario || '"' || ',' ||
                                        '"monto":' || '"' ||
                                        ltrim(rtrim(to_char(:new.monto,
                                                            '999,999,999,999,999.99'))) || ' ' ||
                                        initcap(:new.cod_moneda) || '.' || '"' || ',' ||
                                        '"aviso":' || '"' || v_aviso || '"' || '}';
                          --Insertar correo para el solicitante
                          pas_spi.pr_env_alerta(:new.cod_per_solicitante,
                                                fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                                           'ENVNOTREVSPI'),
                                                v_inf_json);
                        exception
                          when others then
                            null; --no realiza accion si da error envio de correo
                        end;
          end if;
        end if;
     end if;
  end if;

exception
  when others then
    null;
END;
/

