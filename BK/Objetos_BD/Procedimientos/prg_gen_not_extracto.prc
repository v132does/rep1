create or replace procedure it.PRG_GEN_NOT_EXTRACTO (p_canal varchar2,
                                                  p_tip_extracto varchar2 default null,
                                                  p_cod_modulo number default null,
                                                  p_nro_cuenta varchar2 default null,
                                                  p_cod_persona varchar2,
                                                  p_motivo number default null) is
  v_fecha ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
  v_canal ge_reg_tip_extracto.canal%type;
  v_tip_persona ba_personas.tipo%type;
  v_tip_novedad ge_reg_tip_extracto.tip_novedad%type;
  v_direccion bw_not_cli_destino.direccion%type;
  v_email ba_personas.dir_correo%type;
  v_tip_ext_cliente  ge_clientes.tip_extracto%type;
  v_ind_callcenter varchar2(1);
  v_ret number;
  v_can_registros number := 0;
  v_can_cta_tarjetas number := 0;
  v_can_cta_cte_nor number := 0;
  v_can_aho_vis_nor number := 0;
  v_can_cta_tar_nor number := 0;
  v_ret_tarjeta ge_reg_tip_extracto.ret_tarjeta%type;
  v_ret_cuenta ge_reg_tip_extracto.ret_cuenta%type;
  v_ind_notificar varchar2(1);
  v_ind_cta_nomina varchar2(1);
  v_msj_not_alta ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('EXT_MSG_MAIL_BIENVENIDA');
  v_msj_not_baja ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('EXT_MSG_MAIL_BAJA');
  v_cod_modalidad ge_modalidades.cod_modalidad%type;
  v_dir_ema_entidad ba_usuarios.dir_correo%type;
  --
begin
  begin
    select tipo
      into v_tip_persona
      from ba_personas
     where cod_persona = p_cod_persona;
  exception
    when others then
      v_tip_persona := 'J';
  end;

  if v_tip_persona = 'F' then
    if p_cod_modulo = 4 then
       begin
         select decode(cod_ente, null, 'N', 'S')
           into v_ind_cta_nomina
           from cc_cta_corrientes
          where nro_cuenta = p_nro_cuenta;
       exception
         when others then
           v_ind_cta_nomina := 'N';
       end;
    elsif p_cod_modulo = 3 then
      begin
         select decode(cod_ente, null, 'N', 'S')
           into v_ind_cta_nomina
           from ah_cta_vistas
          where nro_cuenta = p_nro_cuenta;
       exception
         when others then
           v_ind_cta_nomina := 'N';
       end;
    else
       v_ind_cta_nomina := 'N';
    end if;

    if p_cod_modulo = 5 and p_nro_cuenta is not null then
       select cod_modalidad
         into v_cod_modalidad
         from ta_cta_tarjetas
        where nro_cuenta= p_nro_cuenta;

       if nvl(fug_obt_pardinamico('EXC_NOT_EXT_TAR',p_cod_modulo,v_cod_modalidad),'N') = 'S' then
          v_ind_notificar := 'N';
       else
          v_ind_notificar := 'S';
       end if;
    else
      v_ind_notificar := 'S';
    end if;

    if nvl(v_ind_cta_nomina, 'N')= 'S' then
       begin
         select count(*)
           into v_can_cta_cte_nor
           from ge_cta_clientes g, cc_cta_corrientes c
          where g.cod_persona = p_cod_persona
            and g.nro_cuenta = c.nro_cuenta
            and g.relacion = 'P'
            and c.estado in ('A','N')
            and c.cod_ente is null;
       exception
         when others then
           v_can_cta_cte_nor := 0;
       end;

       begin
         select count(*)
           into v_can_aho_vis_nor
           from ge_cta_clientes g, ah_cta_vistas c
          where g.cod_persona = p_cod_persona
            and g.nro_cuenta = c.nro_cuenta
            and g.relacion = 'P'
            and c.estado in ('A','N')
            and c.cod_ente is null;
       exception
         when others then
           v_can_cta_cte_nor := 0;
       end;

       begin
         select count(t.nro_cuenta)
           into v_can_cta_tar_nor
           from ge_cta_clientes c, ta_cta_tarjetas t, ge_cta_dat_adicionales d
          where c.cod_persona = p_cod_persona
            and c.relacion = 'P'
            and c.nro_cuenta = t.nro_cuenta
            and t.estado = 'N'
            and c.nro_cuenta = d.nro_cuenta
            and d.parametro = 'RET_EXTRACTO'
            and nvl(fug_obt_pardinamico('EXC_NOT_EXT_TAR',t.cod_modulo,t.cod_modalidad), 'N') <>'S'
            and d.val_parametro = 'S';
       exception
         when others then
           v_can_cta_tar_nor := 0;
       end;

       if nvl(v_can_cta_cte_nor, 0) = 0 and nvl(v_can_aho_vis_nor, 0) = 0 and nvl(v_can_cta_tar_nor, 0) = 0  then
          v_ind_notificar := 'N';
       end if;
    end if;

   -- si es tarjeta si notifica --
    if nvl(v_ind_notificar, 'N') = 'S' and nvl(v_ind_cta_nomina, 'N')<> 'S'  then
      if p_canal = 'ITGF' then
         begin
           select 'S'
             into v_ind_callcenter
             from ba_usuarios u, ba_cod_referencias t
            where u.cod_usuario = user
              and t.dominio = 'COD_ARE_CALLCENTER'
              and u.cod_oficina = t.val_minimo
              and u.cod_area = t.val_maximo;
          exception
            when others then
               v_ind_callcenter := 'N';
          end;


          if nvl(v_ind_callcenter, 'N') = 'S' then
             v_canal := 'CALL CENTER';
          else
             v_canal := p_canal;
          end if;
      elsif p_canal = 'BANCARD' then
        v_canal := 'ITGF';
      else
        v_canal := p_canal;
      end if;

      if p_cod_modulo = 5 then
         v_ret_tarjeta := 'S';
         v_ret_cuenta := 'N';
      else
         v_ret_tarjeta := 'N';
         v_ret_cuenta := 'S';
      end if;

      if p_tip_extracto = 'N' then
         v_tip_novedad := 'A';
      else
         v_tip_novedad := 'B';
      end if;


      begin
        insert into ge_reg_tip_extracto (fecha,
                                         canal,
                                         tip_novedad,
                                         cod_usuario,
                                         ret_cuenta,
                                         ret_tarjeta,
                                         nro_cuenta,
                                         cod_persona,
                                         motivo)
                                 values (v_fecha,
                                         v_canal,
                                         v_tip_novedad,
                                         user,
                                         v_ret_cuenta,
                                         v_ret_tarjeta,
                                         p_nro_cuenta,
                                         p_cod_persona,
                                         p_motivo);
      exception
        when others then
          if p_canal <> 'BANCARD' then
            raise_application_error(-20000,'No se ha podido registrar el cambio de Tipo de Impresión. '||sqlerrm);
          else
            pat_imp.pr_log( 'ITC-00030: No se ha podido registar el cambio de Tipo de Impresión ' || p_nro_cuenta ||'. '||SQLERRM );
          end if;
      end;

      if p_canal <> 'WEB' AND nvl(fug_obt_pardinamico('EXC_NOT_EXTRACTO',p_cod_modulo), 'N') <>'S' THEN
        v_dir_ema_entidad := fug_obt_dir_correo;
        if p_tip_extracto = 'N' then
           v_direccion := substr(paw_not.fu_obt_cli_des_activo(p_cod_persona), 1, 200);

           IF paw_not.fu_obt_suscripcion(p_cod_persona) = 'N' OR v_direccion IS NULL THEN
             v_ret := paw_not.fu_alt_notificacion(p_cod_persona, v_direccion);
           END IF;

           v_email := substr(fug_obt_dir_mail_per( p_cod_persona ), 1, 80);

           IF v_email IS NOT NULL THEN
             /*v_can_registros := paw_not.fu_env_email_prueba(v_email,
                                                            utl_url.escape(nvl(v_msj_not_alta,'Estimado usuario, bienvenida al servicio de Extracto Clic'), TRUE, 'UTF-8'),
                                                            'ITGF');*/
            /* it_mail.mail(v_dir_ema_entidad, v_email, 'Aviso al Cliente',
                  utl_url.escape(nvl(v_msj_not_alta,'Estimado usuario, bienvenida al servicio de Extracto Clic'), TRUE, 'UTF-8'));*/-- DYDMR-11545 - Se comenta para quitar el utl_url.escape
               it_mail.mail(v_dir_ema_entidad, v_email, 'Aviso al Cliente',
                           -- nvl(v_msj_not_alta,'Estimado usuario, bienvenida al servicio de Extracto Clic'));-- DYDMR-11545 - se quitó el utl_url.escape
                            nvl(v_msj_not_alta,'Estimado usuario, '||fug_obt_nom_entidad||' le da la bienvenida al servicio de Extracto Clic'));-- DYDMR-11545 - se quitó el utl_url.escape
           
           END IF;
         else
           v_email := substr(fug_obt_dir_mail_per( p_cod_persona ), 1, 80);

           IF v_email IS NOT NULL THEN
             /*v_can_registros := paw_not.fu_env_email_prueba(v_email,
                                                            utl_url.escape(nvl(v_msj_not_baja,'Estimado usuario, acorde a su solicitud, banco le confirma que procederá a reactivar el servicio de impresión de su/s Extracto/s en papel.'), TRUE, 'UTF-8'),
                                                            'ITGF');*/
           
         /*    it_mail.mail(v_dir_ema_entidad, v_email, 'Aviso al Cliente',
                  utl_url.escape(nvl(v_msj_not_baja,'Estimado usuario, acorde a su solicitud,  le confirma que procederá a reactivar el servicio de impresión de su/s Extracto/s en papel.'), TRUE, 'UTF-8'));*/-- DYDMR-11545 - Se comenta para quitar el utl_url.escape
           
               it_mail.mail(v_dir_ema_entidad, v_email, 'Aviso al Cliente',
                           -- nvl(v_msj_not_baja,'Estimado usuario, acorde a su solicitud, le confirma que procederá a reactivar el servicio de impresión de su/s Extracto/s en papel.'));-- DYDMR-11545 - se quitó el utl_url.escape
                            nvl(v_msj_not_baja,'Estimado usuario, acorde a su solicitud, '||fug_obt_nom_entidad||' le confirma que procederá a reactivar el servicio de impresión de su/s Extracto/s en papel.'));-- DYDMR-11545 - se quitó el utl_url.escape
     
          END IF;
         end if;
       END IF;
     end if;
  end if;
end PRG_GEN_NOT_EXTRACTO;
/

