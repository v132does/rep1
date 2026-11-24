CREATE OR REPLACE TRIGGER IT.tb_ge_sol_tra_cuentas
  before update of estado on "IT"."GE_SOL_TRA_CUENTAS"
  for each row
declare
  -- local variables here
  v_cta_operativa   ge_cuentas.nro_cuenta%type;
  v_nro_transaccion ge_movimientos.nro_documento%type;
  v_cod_error       number := 0;
  v_men_error       varchar2(4000) := null;
  v_err_codigo      number;
  v_err_mensaje     varchar2(4000);
  v_texto           ge_par_dinamicos.val_parametro%type;
  v_nom_cliente     ba_personas.nom_completo%type;
  v_hora            ge_movimientos.hora%type;
  v_fecha           ge_movimientos.fecha%type;
  v_inf_json        ba_env_correos.parametros%type;
  v_dir_mai_cliente ba_tab_dat_adicionales.val_parametro%type;
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_texto := fug_obt_pardinamico('TXT_SMS_CAN_TRA_CONTACTO');

  if nvl(v_texto, '0') = '0' then
    v_cod_error := 1;
    v_men_error := 'No se encuentra configurado parametro "TXT_SMS_CAN_TRA_CONTACTO"';
  end if;
  if nvl(v_cod_error, 0) = 0 then
    begin
      select initcap(p.pri_nombre || ' ' || p.pri_apellido)
        into v_nom_cliente
        from ba_per_fisicas p
       where p.cod_persona = :new.cod_persona;
    exception
      when no_data_found then
        v_men_error := 'No existe cliente cod.persona ' || :new.cod_persona;
      when others then
        v_men_error := substr('Ocurrio un error al buscar cliente cod.persona ' ||
                              :new.cod_persona || ' Error: ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
    end;
    if nvl(v_cod_error, 0) = 0 then
      begin
        select t.dir_correo
          into v_dir_mai_cliente
          from ba_personas t
         where t.cod_persona = :new.cod_persona;
      exception
        when no_data_found then
          begin
            SELECT a.val_parametro
              INTO v_dir_mai_cliente
              FROM ba_tab_dat_adicionales a
             WHERE tab_relacion = 'BA_PERSONAS'
               AND parametro = 'EMAIL_ONBOARDING'
               and referencia = :new.cod_persona;
          exception
            when no_data_found then
              v_men_error := 'No existe correo para cod.persona ' ||
                             :new.cod_persona;
            when others then
              v_men_error := 'Ocurrio un error al buscar correo para cod.persona ' ||
                             :new.cod_persona || ' ' ||
                             DBMS_UTILITY.format_error_stack || ' - ' ||
                             DBMS_UTILITY.format_error_backtrace;
          end;
        when others then
          v_men_error := substr('Ocurrio un error al buscar cliente cod.persona ' ||
                                :new.cod_persona || ' Error: ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
      end;
    end if;
  end if;
  if :old.estado = 'P' and :new.estado in ('C', 'V') and
     nvl(v_cod_error, 0) = 0 then
    v_cta_operativa := fug_obt_pardinamico('CTA_OPE_TRA_CONTACTO');
    it.paa_alc.pr_gen_tra_cuentas(v_cta_operativa,
                                  :new.nro_cta_debito,
                                  :new.monto,
                                  'N',
                                  null,
                                  'TC',
                                  :new.nro_transferencia,
                                  v_nro_transaccion,
                                  v_hora,
                                  v_fecha,
                                  v_cod_error,
                                  v_men_error);

    /*Envia sms de aviso de cancelacion al beneficiario*/
    v_texto := replace(v_texto, '$NOMBRE_CLIENTE', v_nom_cliente);

    if :new.nro_telefono is not null and v_texto is not null then

      begin
        paa_alc.pr_env_not_sms(:new.nro_telefono,
                               v_texto,
                               v_err_codigo,
                               v_err_mensaje);
      exception
        when others then
          v_men_error := substr('Ocurrio un error al enviar sms al nro. ' ||
                                :new.nro_telefono || ' Error: ' ||
                                v_err_mensaje || ' ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
      end;
    end if;

    /*Envia mail al remitente*/

    v_inf_json := '{' || '"fec_realizado":' || '"' ||
                  to_char(:new.fec_insercion, 'dd/mm/yyyy hh24:mi:ss') || '"' || ',' ||
                  '"fec_transferencia":' || '"' ||
                  to_char(:new.fec_insercion, 'dd/mm/yyyy hh24:mi:ss') || '"' || ',' ||
                  '"monto":' || '"' ||
                  ltrim(rtrim(to_char(:new.monto, '999,999,999,999,999.99'))) || '"' || ',' ||
                  '"nro_transaccion":' || '"' || :new.nro_transferencia || '"' || ',' ||
                  '"nom_cue_debito":' || '"' || v_nom_cliente || '"' || ',' ||
                  '"num_cue_debito":' || '"' || :new.nro_cta_debito || '"' || ',' ||
                  '"nom_beneficiario":' || '"' || :new.nom_beneficiario || '"' || ',' ||
                  '"num_telefono":' || '"' || :new.nro_telefono || '"' || ',' ||
                  '"notas":' || '"' || :new.concepto || '"' || '}';

    if v_inf_json is not null and v_dir_mai_cliente is not null then
      v_err_codigo  := null;
      v_err_mensaje := null;
      begin

        IT.PRG_ENV_NOT_SOL_TRA_CUENTA(:new.cod_persona,
                                      16,
                                      v_inf_json,
                                      v_dir_mai_cliente,
                                      v_err_codigo,
                                      v_err_mensaje);
      exception
        when others then
          v_men_error := substr('Insertar en ba_env_correos al correo ' ||
                                v_dir_mai_cliente || ' Error: ' ||
                                v_err_mensaje || ' ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
      end;
    end if;
  end if;
  if v_men_error is not null then
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
      prg_ins_log_programas('TB_GE_SOL_TRA_CUENTAS',
                            substr('Telefono beneficiario. ' ||
                                   :new.nro_telefono ||
                                   ' Nro Transferencia ' ||
                                   :new.nro_transferencia || ' Monto ' ||
                                   :new.monto || ' Error: ' || v_men_error,
                                   1,
                                   4000),
                            :new.cod_persona,
                            :new.nro_cta_debito);
    end if;
  end if;

  if nvl(v_cod_error, 0) != 0 then
    raise_application_error(-20000,
                            nvl(v_men_error,
                                'Ocurrió un error al hacer la transferencia de devolución a la cuenta ' ||
                                :new.nro_cta_debito));
  end if;
exception
  when others then
    if nvl(v_cod_error, 0) = 0 then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('TB_GE_SOL_TRA_CUENTAS',
                              substr('Telefono beneficiario. ' ||
                                     :new.nro_telefono ||
                                     ' Nro Transferencia ' ||
                                     :new.nro_transferencia || ' Error: ' ||
                                     DBMS_UTILITY.format_error_stack ||
                                     ' - ' ||
                                     DBMS_UTILITY.format_error_backtrace,
                                     1,
                                     4000),
                              null,
                              :new.nro_cta_debito);
      end if;
    end if;
    raise_application_error(-20000,
                            'Ocurrió un error al actualizar estado de la transferencia nro ' ||
                            :new.nro_transferencia);

end tb_ge_sol_tra_cuentas;
/

