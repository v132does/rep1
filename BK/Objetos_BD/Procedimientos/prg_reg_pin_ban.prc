create or replace procedure it.prg_reg_pin_ban(p_cod_persona  in ge_ope_sin_tarjetas.cod_persona%TYPE,
                                               p_nro_telefono in ge_ope_sin_tarjetas.nro_telefono%TYPE,
                                               p_nro_cta      in ge_ope_sin_tarjetas.nro_cuenta%type,
                                               p_cod_moneda   in ge_ope_sin_tarjetas.cod_moneda%type,
                                               p_accion       varchar2,
                                               p_cod_error    out number,
                                               p_men_error    out varchar2) IS

  --variables
  v_url_reg_pin varchar2(4000) := fug_obt_pardinamico('WS_REG_PIN_BAN'); --url servicio
  v_url         varchar2(4000);
  v_content     varchar2(4000);
  v_lugar       varchar2(10);
  v_cod_moneda  varchar2(3);
  v_men_error   varchar2(4000);
  v_cod_err_ws  number(6);
  v_error exception;
  v_nom_programa  varchar2(50) := 'IT.PR_REG_PIN_BAN';
  v_err_sql       number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
  v_cod_msg_exito number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200);
  v_pro_correcto  number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);

begin
  --http://fo-sandbox01-srv.lnx.elcomercio.local:4101/ms-credit-cards/bancard-ws/bancardJpos?an={p_nro_cta}&curr=PYG&phone_nbr={p_celular}&action_code={p_cod_action}&action={p_action}&verif_code={p_verf}
  v_lugar := '01';
  v_url   := v_url_reg_pin;
  v_url   := replace(v_url, '{p_nro_cta}', p_nro_cta);
  v_url   := replace(v_url, '{p_celular}', p_nro_telefono);
  v_url   := replace(v_url, '{p_cod_action}', p_accion);
  v_url   := replace(v_url, '{p_action}', 'manage_account');
  v_url   := replace(v_url, '{p_verf}', '0000');
  --creamos estructura JSON

  v_lugar := '02';
  if p_cod_moneda = 'GS' then
    v_cod_moneda := 'PYG';
  else
    v_cod_moneda := 'USD';
  end if;

  v_content := '{"origin": {"cmr_id":' || 3 || ',"cmr_bra":' || 1 || '},' ||
               '"account":{ "fic":"' ||
               fug_obt_pardinamico('COD_ENT_INFONET') || '",' || '"an":' ||
               p_nro_cta || ',' || '"curr":"' || v_cod_moneda || '",' ||
               '"phone_nbr":"' || p_nro_telefono || '",' ||
               '"action_code":"' || p_accion || '" } }';
  --llamamos WS
  v_lugar := '03';
  pat_tgl.pr_ws_conector(v_content,
                         v_url,
                         p_nro_cta,
                         p_cod_persona,
                         'M',
                         'GET',
                         v_cod_err_ws,
                         v_men_error); -- llama al web Service
  --validamos resultado del WS
  v_lugar := '04';
  if v_cod_err_ws != v_cod_msg_exito THEN
    p_cod_error := v_err_sql;
    p_men_error := v_men_error;
  else
    p_cod_error := v_pro_correcto;
    p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                       'Transaccion Exitosa!');
  
    v_lugar := '05';
    begin
      insert into it.ge_ope_sin_tar_logs --se inserta en el historico de acciones
        (cod_persona, celular, accion, nro_cuenta, observacion)
      values
        (p_cod_persona, p_nro_telefono, p_accion, p_nro_cta, v_men_error);
    exception
      when others then
        it.prg_ins_log_programas(v_nom_programa,
                                 substr('Lugar: ' || v_lugar || ' - ' ||
                                        sqlerrm,
                                        1,
                                        4000),
                                 p_cod_persona,
                                 p_nro_cta);
    end;
  
    if p_accion = '005' then
      --005 baja
      v_lugar := '06';
      begin
        update ge_ope_sin_tarjetas s
           set estado             = 'A',
               s.fec_modificacion = sysdate,
               s.usu_modificacion = user
         where cod_persona = p_cod_persona
           and cod_moneda = p_cod_moneda
           and nro_cuenta = p_nro_cta;
      exception
        when others then
          it.prg_ins_log_programas(v_nom_programa,
                                   substr('Lugar: ' || v_lugar || ' - ' ||
                                          sqlerrm,
                                          1,
                                          4000),
                                   p_cod_persona,
                                   p_nro_cta);
      end;
    end if;
  
    if p_accion = '003' then
      --005 CAMBIO DE NUMERO
      v_lugar := '07';
      begin
        update ge_ope_sin_tarjetas s
           set estado             = 'A',
               s.fec_modificacion = sysdate,
               s.usu_modificacion = user
         where cod_persona = p_cod_persona
           and cod_moneda = p_cod_moneda
           and nro_cuenta = p_nro_cta;
      exception
        when others then
          it.prg_ins_log_programas(v_nom_programa,
                                   substr('Lugar: ' || v_lugar || ' - ' ||
                                          sqlerrm,
                                          1,
                                          4000),
                                   p_cod_persona,
                                   p_nro_cta);
      end;
    end if;
    commit;
  end if;

exception
  when others then
    p_cod_error := v_err_sql;
    p_men_error := 'Error en proceso it.pr_reg_pin_ban. ' ||
                   substr('Lugar: ' || v_lugar || ' - ' || sqlerrm, 1, 4000);
    it.prg_ins_log_programas(v_nom_programa,
                             substr('Lugar: ' || v_lugar || ' - ' ||
                                    sqlerrm,
                                    1,
                                    4000),
                             p_cod_persona,
                             p_nro_cta);
end;
/

